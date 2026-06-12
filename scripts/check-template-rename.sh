#!/usr/bin/env bash
# Setup gate — runs as a Claude Code UserPromptSubmit hook (.claude/settings.json).
#
# Blocks every prompt (exit code 2) while any package.json still declares a name
# under the un-renamed template scope. Forces teams to run ./scripts/rename.sh
# before the AI will do any work, so apps never ship as "@template/...".
#
# Clears itself automatically the moment the scope is renamed — no restart needed.
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

# Still on the template scope → block. stderr is surfaced to the user; exit 2
# tells Claude Code to stop the prompt before it ever reaches the model.
{
  echo "🚫 Setup gate: this repo still uses the ${FORBIDDEN_SCOPE} scope — rename it before the AI will proceed."
  echo
  echo "Packages still on ${FORBIDDEN_SCOPE}:"
  for f in "${offenders[@]}"; do echo "  • ${f}"; done
  echo
  echo "Fix it once, for the whole monorepo:"
  echo "    ./scripts/rename.sh <your-org>        # e.g. ./scripts/rename.sh acme"
  echo
  echo "Then re-send your message — this gate clears automatically."
} >&2
exit 2
