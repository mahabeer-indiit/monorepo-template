# Repo standards for Claude Code

This file is the AI's source of truth for how to work in this repo. Treat every section as a hard rule unless explicitly told otherwise in conversation.

## 1. Stack & versions

- **Node 20** (LTS) — see [`.nvmrc`](./.nvmrc); `engine-strict=true`
- **pnpm 9** — managed via the `packageManager` field in [`package.json`](./package.json); never use `npm` or `yarn`
- **TypeScript strict** everywhere — strict mode + `noUncheckedIndexedAccess` + `noImplicitOverride`
- **Frontend (web):** React 18, Vite, Tailwind, **shadcn/ui**
- **Backend (api):** Express + Mongoose
- **Mobile:** React Native via **Expo SDK (latest)**

## 2. Folder structure

- `apps/` — runnable apps (`web`, `mobile`, `api`); each clones from a `_template-*` starter
- `packages/` — shared libraries (`config-ts`, `config-eslint`, `types`, `ui`)
- Inside each app: **feature-based** layout under `src/features/<name>/{components,api,types,forms,hooks,pages,index.ts}`. No `src/components/` or `src/api/` at the app root. See [`docs/feature-folder-template.md`](./docs/feature-folder-template.md).

## 3. Code style

- **TS strict.** No `any` unless followed by an inline comment justifying it (`// any: third-party type missing — see #issue`).
- **No new `.js` files in `src/`** — use `.ts` / `.tsx`. The shared ESLint config enforces this.
- **No `// @ts-ignore`** — use `// @ts-expect-error <reason>` when a type error is genuinely necessary.
- Prettier owns formatting; ESLint owns rules. Run `pnpm format` before committing.

## 4. API conventions

- All routes versioned: **`/api/v1/...`** — never expose unversioned routes.
- **Swagger annotations on every endpoint.** No exceptions, including internal/admin routes. PRs without Swagger blocks fail review.
- Request/response shapes are typed via `@template/types`. Backend defines the type, FE imports it — never duplicate.
- Errors return `{ error: { code, message, details? } }` with appropriate HTTP status. No raw 500 stack traces in responses.

## 5. UI conventions

- Web components come from **`@template/ui` only**. Don't introduce Material UI, Chakra, Ant Design, etc.
- **Tailwind utilities only** — no inline `style={{ ... }}`, no CSS-in-JS, no per-component CSS files.
- New design-system components are added to `packages/ui` via `pnpm dlx shadcn@latest add <name>`, then exported from [`packages/ui/src/index.ts`](./packages/ui/src/index.ts).
- Design tokens (colors, radii, spacing) live in [`packages/ui/tailwind.preset.ts`](./packages/ui/tailwind.preset.ts) and [`packages/ui/src/styles.css`](./packages/ui/src/styles.css). Apps consume via the preset.

## 6. Testing conventions

- **`.md` spec is the source of truth.** Each feature ships a `<thing>.spec.md` describing scenarios in bullet form.
- Claude generates **`.spec.ts`** Playwright tests from the spec via the Playwright MCP server.
- **Both files are committed together** in the same PR. Spec-only or test-only PRs are rejected.
- Unit tests (pure functions, hooks) use Vitest as `<thing>.test.ts`. Anything that crosses the DOM, network, or navigation boundary uses Playwright.
- Full workflow: [`docs/testing.md`](./docs/testing.md).

## 7. Git conventions

- **Conventional Commits** — `<type>(<scope>): <subject>`. Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`.
- **Target 5–8 files per commit.** Split larger changes by layer or by feature. Each commit must build and pass tests on its own.
- Branch naming: **`feature/<ticket>-<short-desc>`** (e.g. `feature/AUTH-142-login-page`). Branches go off **`dev`**, never `main`. Hotfixes are the only exception (see [`docs/branching-and-prs.md`](./docs/branching-and-prs.md)).
- Squash-merge by default. Rebase clean (`git rebase -i origin/dev`) before opening the PR.
- Stage selectively with `git add -p` — never `git add .`. Use `/commit` to draft Conventional Commit messages.

## 8. What Claude should NOT do

- ❌ **Do not add new dependencies without asking.** Propose the dep, the use case, and the size impact; wait for approval.
- ❌ **Do not refactor unrelated code** while making a focused change. If you spot something, leave a `TODO` comment or open an issue, but don't expand the diff.
- ❌ **Do not use `// @ts-ignore`.** Use `// @ts-expect-error <reason>` if a type error is unavoidable.
- ❌ **Do not create new `.js` files in `src/`.** Always `.ts` / `.tsx`. ESLint will block this.
- ❌ **Do not bypass the feature folder structure.** No top-level `src/components/`, `src/utils/`, `src/api/`. If two features need shared logic, lift it to `packages/`.
- ❌ **Do not commit secrets**, `.env` files, or anything matching `.env.*` (the root `.gitignore` covers this; don't override it).

## 9. Reference paths

- Shared ESLint config → [`packages/config-eslint`](./packages/config-eslint) — flat config presets `base.mjs`, `react.mjs`, `node.mjs`, `react-native.mjs`
- Shared TS configs → [`packages/config-ts`](./packages/config-ts) — `base.json`, `react.json`, `node.json`, `react-native.json`
- Shared types → [`packages/types`](./packages/types) — backend owns; FE + mobile consume
- Shared UI → [`packages/ui`](./packages/ui) — shadcn/ui components + Tailwind preset
- Web app reference → [`apps/_template-web`](./apps/_template-web) — clone, rename, build
- Workflow docs → [`docs/`](./docs/) — branching, commits, deployment, testing, feature folders
