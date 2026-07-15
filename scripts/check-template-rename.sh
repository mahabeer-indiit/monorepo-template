#!/usr/bin/env bash
# Setup gate — runs as a Claude Code UserPromptSubmit hook (.claude/settings.json).
#
# Blocks every prompt while any package.json still declares a name under the
# un-renamed template scope. Forces teams to run ./scripts/rename.sh before the
# AI will do any work, so apps never ship as "@template/...".
#
# Clears itself automatically the moment the scope is renamed — no restart needed.
#
# HOW IT BLOCKS (and why not `exit 2`):
#   A UserPromptSubmit hook that exits 2 blocks the prompt but its stderr is NOT
#   reliably surfaced to the user — they just see a generic "hook error" and no
#   explanation of what to do (Claude Code issue #10964). That silent block is
#   exactly what confuses people cloning this template. So instead we exit 0 and
#   emit a JSON control object on stdout:
#     • "decision":"block"  → still hard-blocks the prompt from reaching the model
#     • "systemMessage":"…"  → the documented user-visible warning channel, so the
#                              rename instructions actually show up in the UI
#   This works across the terminal CLI, the VS Code extension, and the web app.
#
# NOTE: this file deliberately never writes the literal forbidden scope as one
# token. scripts/rename.sh rewrites that exact string across the repo; if it
# appeared here, a real rename would silently rewrite this guard and disable it.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

# Escape hatch for people working ON the template itself (not on a project made
# from it). Opt out via either:
#   • the gitignored marker file .claude/allow-template-scope, or
#   • the env var ALLOW_TEMPLATE_SCOPE=1 (shell profile / settings.local.json env)
# Both are local-only, so clones never inherit them and stay gated until renamed.
if [[ -n "${ALLOW_TEMPLATE_SCOPE:-}" || -f ".claude/allow-template-scope" ]]; then
  exit 0
fi

# Assemble "@template/" from parts so rename.sh's find+sed can't match it here.
_scope_org="template"
FORBIDDEN_SCOPE="@${_scope_org}/"

# Collect every package.json whose "name" field is still under the template scope.
offenders=()
while IFS= read -r -d '' pkg; do
  if grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${FORBIDDEN_SCOPE}" "$pkg"; then
    offenders+=("${pkg#./}")
  fi
done < <(find . -name package.json \
  ! -path './node_modules/*' ! -path './*/node_modules/*' \
  ! -path './*/dist/*' ! -path './*/build/*' \
  ! -path './.turbo/*' ! -path './*/.turbo/*' -print0)

# All renamed → let the prompt through.
if [[ ${#offenders[@]} -eq 0 ]]; then
  exit 0
fi

# --- Still on the template scope → block with a visible, actionable message. ---

# Minimal, dependency-free JSON string escaper (no jq required on the user's box).
json_escape() {
  local s=$1
  s=${s//\\/\\\\}     # backslash first
  s=${s//\"/\\\"}     # double quote
  s=${s//$'\n'/\\n}   # newline
  s=${s//$'\t'/\\t}   # tab
  s=${s//$'\r'/\\r}   # carriage return
  printf '%s' "$s"
}

# Build the human-readable offender list.
offender_lines=""
for f in "${offenders[@]}"; do
  offender_lines+="  • ${f}"$'\n'
done

# The message the user actually sees (systemMessage).
read -r -d '' message <<EOF || true
🚫 Setup gate — rename required before the AI will work.

This repo still uses the ${FORBIDDEN_SCOPE} scope. A project made from this
template must be rebranded to its own org scope before any AI feature work, so
apps never ship as ${FORBIDDEN_SCOPE}. Until then, prompts are blocked.

Packages still on ${FORBIDDEN_SCOPE}:
${offender_lines}
Fix it once, for the whole monorepo — copy the line for your shell and replace
"acme" with your org scope:

  • macOS / Linux / Git Bash / WSL:
        ./scripts/rename.sh acme

  • Windows PowerShell or CMD:
        bash scripts/rename.sh acme
    (If "bash" is not found, Git Bash ships with Git for Windows — use its full
    path, e.g. "C:\Program Files\Git\bin\bash.exe" scripts/rename.sh acme)

Then re-send your message — this gate clears automatically, no restart needed.
EOF

reason="Repo still on the ${FORBIDDEN_SCOPE} scope; run ./scripts/rename.sh <your-org> before any AI work."

# Emit the JSON control object on stdout, then exit 0 so Claude Code parses it.
# decision:block stops the prompt; systemMessage shows the instructions to the user.
printf '{"decision":"block","reason":"%s","systemMessage":"%s"}\n' \
  "$(json_escape "$reason")" \
  "$(json_escape "$message")"
exit 0
