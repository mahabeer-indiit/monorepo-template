#!/usr/bin/env bash
# Copy the repo-root .claude/settings.json into every workspace package.
#
# WHY THIS EXISTS
#   Claude Code reads project settings from .claude/settings.json relative to the
#   directory it was STARTED IN. There is no parent-directory lookup: starting
#   Claude in apps/web loads apps/web/.claude/settings.json and never the root
#   file, so a package without its own copy runs with NO deny rules at all.
#   (settings.local.json is the asymmetric exception — it does resolve from the
#   git root — but it is gitignored, so it cannot carry committed conventions.)
#
# USAGE
#   bash scripts/sync-claude-settings.sh            # write/refresh every copy
#   bash scripts/sync-claude-settings.sh --check    # verify only; exit 1 on drift (CI)
#
# Written for bash 3.2 (macOS default): no mapfile, no associative arrays.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SRC=".claude/settings.json"
MODE="${1:-write}"

if [[ ! -f "$SRC" ]]; then
  echo "error: $SRC not found at repo root ($ROOT)" >&2
  exit 1
fi

# --- Resolve workspace package directories from pnpm-workspace.yaml -----------
# Parsed with sed, not pnpm, so this runs in CI before `pnpm install`.
GLOBS=()
while IFS= read -r g; do
  [[ -z "$g" || "$g" == '!'* ]] && continue   # skip blanks and negated globs
  GLOBS+=("$g")
done < <(sed -n 's/^[[:space:]]*-[[:space:]]*//p' pnpm-workspace.yaml | tr -d "\"'")

if [[ ${#GLOBS[@]} -eq 0 ]]; then
  echo "error: no package globs found in pnpm-workspace.yaml" >&2
  exit 1
fi

shopt -s nullglob
PKG_DIRS=()
for g in "${GLOBS[@]}"; do
  for d in $g; do
    if [[ -d "$d" && -f "$d/package.json" ]]; then PKG_DIRS+=("${d%/}"); fi
  done
done
shopt -u nullglob

if [[ ${#PKG_DIRS[@]} -eq 0 ]]; then
  echo "No workspace packages yet (apps/ is empty in a fresh template) — nothing to sync."
  exit 0
fi

hash_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}
SRC_HASH="$(hash_of "$SRC")"

MISSING=(); DRIFTED=(); OK=0
for d in "${PKG_DIRS[@]}"; do
  target="$d/$SRC"
  if [[ ! -f "$target" ]]; then
    MISSING+=("$target")
  elif [[ "$(hash_of "$target")" != "$SRC_HASH" ]]; then
    DRIFTED+=("$target")
  else
    OK=$((OK + 1))
  fi
done

if [[ "$MODE" == "--check" ]]; then
  if [[ ${#MISSING[@]} -eq 0 && ${#DRIFTED[@]} -eq 0 ]]; then
    echo "OK: .claude/settings.json present and identical in all ${#PKG_DIRS[@]} workspace package(s)."
    exit 0
  fi
  echo "FAIL: agent permission rules are not in force for every workspace package." >&2
  if [[ ${#MISSING[@]} -gt 0 ]]; then for f in "${MISSING[@]}"; do echo "   missing:           $f" >&2; done; fi
  if [[ ${#DRIFTED[@]} -gt 0 ]]; then for f in "${DRIFTED[@]}"; do echo "   differs from root: $f" >&2; done; fi
  cat >&2 <<'MSG'

   Claude Code loads .claude/settings.json from the directory it is started in,
   with no parent lookup, so a package without its own copy runs with no deny
   rules. Fix and commit:

       pnpm agents:sync && git add -A && git commit -m "chore: sync agent settings"
MSG
  exit 1
fi

CHANGED=0
if [[ ${#MISSING[@]} -gt 0 ]]; then
  for f in "${MISSING[@]}"; do mkdir -p "$(dirname "$f")"; cp "$SRC" "$f"; echo "   wrote   $f"; CHANGED=$((CHANGED+1)); done
fi
if [[ ${#DRIFTED[@]} -gt 0 ]]; then
  for f in "${DRIFTED[@]}"; do cp "$SRC" "$f"; echo "   updated $f"; CHANGED=$((CHANGED+1)); done
fi
echo "OK: ${#PKG_DIRS[@]} workspace package(s) in sync (${OK} already current, ${CHANGED} written)."
