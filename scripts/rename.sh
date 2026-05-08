#!/usr/bin/env bash
# Rename this template repo to your org's scope.
#
# Usage:
#   ./scripts/rename.sh <new-org> [<repo-url>]
#
# Example:
#   ./scripts/rename.sh acme https://github.com/acme/platform
#
# What this does:
#   1. Replaces every "@template/" with "@<new-org>/" across tracked files
#      (skips node_modules, .git, lockfiles, build output)
#   2. Updates root package.json#name from "@template/root" to "@<new-org>/root"
#   3. (Optional) Replaces any reference to this template's repo URL in README.md
#      with the URL passed as the second argument

set -euo pipefail

NEW_ORG="${1:-}"
NEW_REPO_URL="${2:-}"

if [[ -z "$NEW_ORG" ]]; then
  echo "Error: missing <new-org> argument" >&2
  echo "Usage: $0 <new-org> [<repo-url>]" >&2
  exit 1
fi

# Validate org name: alphanumerics, dashes, underscores only — npm scope rules
if ! [[ "$NEW_ORG" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "Error: '$NEW_ORG' is not a valid npm scope name" >&2
  echo "Use lowercase letters, digits, dashes, or underscores; must start with letter/digit" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Renaming @template/ → @${NEW_ORG}/ across the repo..."

# Detect sed in-place flag (BSD vs GNU)
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(-i)        # GNU
else
  SED_INPLACE=(-i '')     # BSD / macOS
fi

# Find all tracked text files, excluding paths we never want to touch
# Using -print0 / xargs -0 is safe for filenames with spaces or unusual chars
find . -type f \
  ! -path './node_modules/*' \
  ! -path './.git/*' \
  ! -path './.turbo/*' \
  ! -path './*/node_modules/*' \
  ! -path './*/dist/*' \
  ! -path './*/build/*' \
  ! -path './*/.turbo/*' \
  ! -path './*/.next/*' \
  ! -name 'pnpm-lock.yaml' \
  ! -name '*.png' ! -name '*.jpg' ! -name '*.jpeg' ! -name '*.gif' \
  ! -name '*.ico' ! -name '*.svg' ! -name '*.woff' ! -name '*.woff2' \
  -print0 |
  xargs -0 sed "${SED_INPLACE[@]}" "s|@template/|@${NEW_ORG}/|g"

echo "    done."

echo "==> Updating root package.json#name → @${NEW_ORG}/root..."
# This was already covered by the bulk find/sed above, but be explicit
# in case the user has customized the root name.
sed "${SED_INPLACE[@]}" "s|\"name\": \"@${NEW_ORG}/root\"|\"name\": \"@${NEW_ORG}/root\"|" package.json
echo "    done."

if [[ -n "$NEW_REPO_URL" ]]; then
  if [[ -f README.md ]]; then
    echo "==> Updating repo URL in README.md → ${NEW_REPO_URL}..."
    # Replace any github.com/.../monorepo-template with the new URL
    # Strip trailing slash if present
    CLEAN_URL="${NEW_REPO_URL%/}"
    sed "${SED_INPLACE[@]}" -E "s|https://github\\.com/[^/]+/monorepo-template|${CLEAN_URL}|g" README.md
    echo "    done."
  else
    echo "    (skipped — README.md not found)"
  fi
fi

echo
echo "==> Verifying with pnpm install..."
if command -v pnpm >/dev/null 2>&1; then
  pnpm install
else
  echo "    pnpm not found on PATH — run 'pnpm install' manually."
fi

echo
echo "✅ Rename complete."
echo
echo "Next steps:"
echo "  1. Delete RENAME.md:           git rm RENAME.md"
echo "  2. Commit:                     git commit -m 'chore: rename template to ${NEW_ORG}'"
echo "  3. Pick a generation guide:    docs/generate-{backend,web,mobile}.md"
