#!/usr/bin/env bash
# Setup gate — tells the cloner to rename this template before Claude works in it.
#
# Wired into .claude/settings.json on three events, with the event passed as $1:
#
#   session-start  (SessionStart)   -> puts the repo state in Claude's context
#                                      before the user types anything, so Claude
#                                      can explain itself even for /slash-commands
#                                      (UserPromptSubmit does NOT fire for those).
#   prompt         (UserPromptSubmit) -> injects additionalContext so Claude ANSWERS
#                                      in its own voice: "rename first". This does
#                                      NOT block, on purpose — see WHY, below.
#   pre-write      (PreToolUse, matcher Edit|Write|MultiEdit|NotebookEdit)
#                                   -> the actual hard stop: permissionDecision
#                                      "deny", so no file is modified even if the
#                                      model ignores the instruction.
#
# WHY THIS NO LONGER USES decision:"block" ON THE PROMPT
#   The previous version emitted {"decision":"block","systemMessage":"…"} and
#   cloners reported seeing nothing at all. Two things were wrong:
#
#   1. systemMessage is DISCARDED when the same hook output also blocks. Claude
#      Code aggregates a hook's results in a fixed order — blockingError is
#      yielded before systemMessage — and the UserPromptSubmit consumer returns on
#      the first blockingError, so the systemMessage yield is never reached. The
#      long, helpful text went into the one field that a blocking hook throws away.
#      ("reason" IS rendered, as "UserPromptSubmit operation blocked by hook: …",
#      but only the terse one-liner lived there.)
#
#   2. Even a correct "reason" is CLIENT-RENDERED. It is a system/informational
#      transcript line, and that line has been reported missing in the VS Code /
#      Cursor extension and in the Windows desktop app. A hard block also means no
#      model turn runs at all, so Claude can never say anything in its own voice.
#
#   An assistant message has no such dependency: it renders on every surface, on
#   every platform, in every client. So the prompt path now injects context and
#   lets Claude speak, and enforcement moved to PreToolUse where a denial cannot
#   be silent (the model is told why and relays it).
#
# COST: no always-on matcher. SessionStart fires once per session; the prompt hook
# only while the repo is un-renamed; pre-write only on write tools. Once renamed,
# every mode exits 0 with no output.
#
# NOTE: this file deliberately never writes the literal forbidden scope as one
# token. scripts/rename.sh rewrites that exact string across the repo; if it
# appeared here, a real rename would silently rewrite this guard and disable it.
set -uo pipefail
# NOTE: no `set -e`. A gate that dies mid-way must fail open and quiet rather than
# exit non-zero, which Claude Code reports as a "hook error" only the first time
# per session and not at all in print mode.

MODE="${1:-}"

# ---------------------------------------------------------------------------
# Drain stdin. Claude Code writes the hook input JSON to our stdin; on PreToolUse
# that payload contains the whole tool_input (an entire file, for a Write). If we
# never read it, Claude's write can block on a full pipe buffer once the payload
# exceeds the OS pipe size — which looks exactly like a hung session.
# Skipped when stdin is a terminal so the script stays runnable by hand.
# ---------------------------------------------------------------------------
STDIN_JSON=""
if [ ! -t 0 ]; then
  if [ -n "$MODE" ]; then
    cat >/dev/null 2>/dev/null
  else
    # No mode argument: sniff the event out of the payload instead of guessing.
    STDIN_JSON="$(cat 2>/dev/null)"
  fi
fi

if [ -z "$MODE" ]; then
  case "$STDIN_JSON" in
    *'"hook_event_name"'*'"SessionStart"'*)    MODE="session-start" ;;
    *'"hook_event_name"'*'"UserPromptSubmit"'*) MODE="prompt" ;;
    *'"hook_event_name"'*'"PreToolUse"'*)      MODE="pre-write" ;;
    *) MODE="prompt" ;;
  esac
fi

case "$MODE" in
  session-start) EVENT="SessionStart" ;;
  prompt)        EVENT="UserPromptSubmit" ;;
  pre-write)     EVENT="PreToolUse" ;;
  *)
    # Unknown mode = misconfiguration. Emitting a hookSpecificOutput whose
    # hookEventName does not match the firing event makes Claude Code throw and
    # drop the whole result, so say nothing rather than break the session.
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Repo root. git first, so the gate works from any package subdirectory; then
# CLAUDE_PROJECT_DIR; then this file's parent.
# ---------------------------------------------------------------------------
ROOT="$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$ROOT" ]; then ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; fi
if [ -z "$ROOT" ]; then ROOT="${CLAUDE_PROJECT_DIR:-}"; fi
if [ -z "$ROOT" ]; then ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"; fi
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then exit 0; fi
cd "$ROOT" 2>/dev/null || exit 0

# ---------------------------------------------------------------------------
# Escape hatch for people working ON the template itself (not on a project made
# from it). Opt out via either:
#   • the gitignored marker file .claude/allow-template-scope, or
#   • the env var ALLOW_TEMPLATE_SCOPE=1 (shell profile / settings.local.json env)
# Both are local-only, so clones never inherit them and stay gated until renamed.
# ---------------------------------------------------------------------------
if [ -n "${ALLOW_TEMPLATE_SCOPE:-}" ] || [ -f ".claude/allow-template-scope" ]; then
  exit 0
fi

# Assemble the scope from parts so rename.sh's find+sed can't match it here.
_scope_org="template"
FORBIDDEN_SCOPE="@${_scope_org}/"

# ---------------------------------------------------------------------------
# Collect every package.json whose "name" is still under the template scope.
# -prune, not a ! -path filter: a filter still descends into node_modules, which
# makes the gate crawl thousands of directories on every prompt after a
# pnpm install. Newline-delimited string, not an array: "${arr[@]}" on an empty
# array aborts under `set -u` in the bash 3.2 that ships with macOS.
# ---------------------------------------------------------------------------
offenders=""
offender_count=0
while IFS= read -r -d '' pkg; do
  if grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${FORBIDDEN_SCOPE}" "$pkg" 2>/dev/null; then
    offenders="${offenders}  - ${pkg#./}
"
    offender_count=$((offender_count + 1))
    # The pre-write path only needs to know THAT the repo is un-renamed.
    if [ "$MODE" = "pre-write" ]; then break; fi
  fi
done < <(find . \
  \( -type d \( -name node_modules \
              -o -name .git \
              -o -name dist \
              -o -name build \
              -o -name .next \
              -o -name .turbo \
              -o -name .output \
              -o -name coverage \) \) -prune \
  -o -type f -name package.json -print0 2>/dev/null)

# All renamed → say nothing, cost nothing.
if [ "$offender_count" -eq 0 ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Dependency-free JSON string escaper (no jq on the user's box).
# ---------------------------------------------------------------------------
json_escape() {
  local s=$1
  s=${s//\\/\\\\}     # backslash first
  s=${s//\"/\\\"}     # double quote
  s=${s//$'\n'/\\n}   # newline
  s=${s//$'\t'/\\t}   # tab
  s=${s//$'\r'/\\r}   # carriage return
  printf '%s' "$s"
}

RENAME_POSIX="./scripts/rename.sh <your-org>"
RENAME_WIN="bash scripts/rename.sh <your-org>"

# ---------------------------------------------------------------------------
# What Claude is told. This is repository state plus a response constraint; it is
# injected as context, so Claude answers in its own visible voice.
# ---------------------------------------------------------------------------
read -r -d '' instruction <<EOF || true
[monorepo-template setup gate — repository state, injected by scripts/check-template-rename.sh]

This repository was created from a template and has NOT been renamed yet.
${offender_count} package.json file(s) still declare a name under the un-renamed
template scope ${FORBIDDEN_SCOPE} :
${offenders}
Until the rename has been run, a PreToolUse hook denies Edit, Write, MultiEdit and
NotebookEdit, so any file change you attempt will fail.

For this turn, respond with ONLY the following, in your own words, and then stop:
  1. Say that this repo is still on the template scope and has to be renamed
     before you can do any work in it.
  2. Give the exact command, telling them to replace <your-org> with their own npm
     scope:
       macOS / Linux / Git Bash / WSL:   ${RENAME_POSIX}
       Windows (needs Git Bash or WSL):  ${RENAME_WIN}
  3. Say that they should then re-send their message — this gate clears itself as
     soon as the rename is done, with no restart needed.

Do not attempt the task they asked for. Do not read, search or edit files. Do not
run the rename yourself unless they explicitly ask you to; if they do ask, run the
command above with Bash rather than editing package.json files by hand.
EOF

# Short, client-rendered line. On a NON-blocking hook this renders as
# "UserPromptSubmit says: …"; it is dropped if the same output blocks, which is
# one of the reasons this gate no longer blocks here.
notice="Setup gate: this repo is still on the template scope — run ${RENAME_POSIX} before working here."

deny_reason="Blocked by the monorepo-template setup gate: this repo is still on the ${FORBIDDEN_SCOPE} scope, so file changes are not allowed yet. Tell the user to run ${RENAME_POSIX} (Windows: ${RENAME_WIN}) and then re-send their request. This clears itself once the rename is done. Do not try to work around this by editing package.json files or by writing through Bash."

case "$MODE" in
  session-start)
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
      "$EVENT" "$(json_escape "$instruction")"
    ;;
  prompt)
    printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
      "$(json_escape "$notice")" \
      "$EVENT" \
      "$(json_escape "$instruction")"
    ;;
  pre-write)
    printf '{"hookSpecificOutput":{"hookEventName":"%s","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' \
      "$EVENT" "$(json_escape "$deny_reason")"
    ;;
esac
exit 0