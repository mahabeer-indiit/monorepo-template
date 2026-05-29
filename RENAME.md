# Renaming this template

You just clicked **Use this template** on GitHub (or cloned the repo directly). Before you start coding, do these four steps to take ownership.

## Step 1 — Replace `@template/` with your org scope

Across the entire repo, replace `@template/` with `@<your-org>/`. This renames every workspace package (`@template/config-ts` → `@<your-org>/config-ts`, `@template/config-eslint` → `@<your-org>/config-eslint`, etc.) and every import that references them.

**Automated (recommended):**

```bash
./scripts/rename.sh <your-org>
# example: ./scripts/rename.sh acme
```

The script does steps 1–3 in one shot.

**Manual fallback:**

```bash
# macOS
LC_ALL=C find . -type f \
  ! -path './node_modules/*' ! -path './.git/*' ! -path './.turbo/*' \
  ! -path './*/node_modules/*' ! -path './*/dist/*' ! -path './*/.turbo/*' \
  ! -path './pnpm-lock.yaml' \
  -exec sed -i '' 's|@template/|@<your-org>/|g' {} +

# Linux
LC_ALL=C find . -type f \
  ! -path './node_modules/*' ! -path './.git/*' ! -path './.turbo/*' \
  ! -path './*/node_modules/*' ! -path './*/dist/*' ! -path './*/.turbo/*' \
  ! -path './pnpm-lock.yaml' \
  -exec sed -i 's|@template/|@<your-org>/|g' {} +
```

## Step 2 — Update root `package.json#name`

Change the workspace root's name from `@template/root` to your org's equivalent (the rename script does this).

```jsonc
{
  "name": "@<your-org>/root",
}
```

## Step 3 — Update repo URL in `README.md`

The badges and clone links in `README.md` point at this template's repo. Replace them with your repo's URL (the rename script accepts an optional second arg for this).

## Step 4 — Delete this file

```bash
git rm RENAME.md
git commit -m "chore: rename template to <your-org>"
```

---

## Then what?

**Apps are NOT pre-generated.** The `apps/` folder is empty by design — you create apps on demand from the matching guide:

- Backend (Express + TS + Swagger) → [`docs/generate-backend.md`](./docs/generate-backend.md)
- Web (React + Vite + Tailwind) → [`docs/generate-web.md`](./docs/generate-web.md)
- Mobile (Expo + React Native) → [`docs/generate-mobile.md`](./docs/generate-mobile.md)

Verify the rename worked:

```bash
pnpm install            # should be clean
pnpm turbo build        # 2 packages should still build
```

If those pass, you're done. Pick a generation guide and scaffold your first app.
