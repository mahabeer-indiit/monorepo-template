# Repo standards for Claude Code

This file is the AI's source of truth for how to work in this repo. Treat every section as a hard rule unless explicitly told otherwise in conversation.

## 1. Stack & versions

- **Node 20** (LTS) — see [`.nvmrc`](./.nvmrc); `engine-strict=true`
- **pnpm 9** — managed via the `packageManager` field in [`package.json`](./package.json); never use `npm` or `yarn`
- **TypeScript strict** everywhere — strict mode + `noUncheckedIndexedAccess` + `noImplicitOverride`
- **Frontend (web):** React 18, Vite, Tailwind
- **Backend (api):** Express + Mongoose
- **Mobile:** React Native via **Expo SDK (latest)**

## 2. Folder structure

- `apps/` — runnable apps; **created on demand**, not pre-scaffolded
- `packages/` — shared libraries (`config-ts`, `config-eslint`, `types`)
- Inside each app: **feature-based** layout under `src/features/<name>/{components,api,types,forms,hooks,pages|screens,index.ts}`. No top-level `src/components/` or `src/api/` mixing concerns across features.

> **Apps are NOT pre-generated.** When the team needs a new app, follow the matching guide:
>
> - Backend → [`docs/generate-backend.md`](./docs/generate-backend.md)
> - Web → [`docs/generate-web.md`](./docs/generate-web.md)
> - Mobile → [`docs/generate-mobile.md`](./docs/generate-mobile.md)

## 3. Code style

- **TS strict.** No `any` unless followed by an inline comment justifying it (`// any: third-party type missing — see #issue`).
- **No new `.js` files in `src/`** — use `.ts` / `.tsx`. The shared ESLint config enforces this.
- **No `// @ts-ignore`** — use `// @ts-expect-error <reason>` when a type error is genuinely necessary.
- Prettier owns formatting; ESLint owns rules. Run `pnpm format` before committing.

## 4. API conventions

- All routes versioned: **`/api/v1/...`** — never expose unversioned routes.
- **Swagger annotations on every endpoint** (JSDoc `@openapi` blocks). No exceptions, including internal/admin routes. PRs without them fail review.
- Request/response shapes are typed via `@template/types`. Backend defines the type, FE imports it — never duplicate.
- Errors return `{ error: { code, message, details? } }` with appropriate HTTP status. No raw 500 stack traces in responses.
- Every request body / query / param goes through a **zod schema** before the controller logic runs.

## 5. UI conventions

- **Tailwind utilities only** on web — no inline `style={{ ... }}`, no CSS-in-JS, no per-component CSS files.
- Mobile uses **`StyleSheet.create()`** (NativeWind decision is post-foundation). Same prohibition on inline styles.
- There is **no shared web UI package** — each web app owns its own components under `src/features/<name>/components/`. If a UI component library is needed, choose it per app; this template stays unopinionated about which one.

## 6. Testing conventions

- **`.md` spec is the source of truth.** Each feature ships a `<thing>.spec.md` describing scenarios in bullet form.
- Claude generates **`.spec.ts`** Playwright tests from the spec via the Playwright MCP server.
- **Both files are committed together** in the same PR. Spec-only or test-only PRs are rejected.
- Unit tests (pure functions, hooks) use Vitest as `<thing>.test.ts`. Anything that crosses the DOM, network, or navigation boundary uses Playwright.
- Full workflow: [`docs/testing.md`](./docs/testing.md).

## 7. Git conventions

- **Conventional Commits** — `<type>(<scope>): <subject>`. Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `perf`, `build`, `ci`.
- **Target 5–8 files per commit.** Split larger changes by layer or by feature. Each commit must build and pass tests on its own.
- **Branch naming:** `<type>/<ticket>-<short-desc>` — for example, `feat/PROJ-123-add-login`. The `<type>` matches the Conventional Commits set above; `<ticket>` is the project's ticket id; `<short-desc>` is 2–5 words, kebab-case. Examples: `feat/PROJ-123-add-login`, `fix/PROJ-456-cart-duplicate-on-rapid-click`, `chore/PROJ-789-bump-react-query`, `docs/PROJ-321-update-readme`. Branches go off **`dev`**, never `main`. Hotfixes (`hotfix/<ticket>-<short-desc>`) are the only exception. Full rules in [`docs/branching-and-prs.md`](./docs/branching-and-prs.md).
- Squash-merge by default. Rebase clean (`git rebase -i origin/dev`) before opening the PR.
- Stage selectively with `git add -p` — never `git add .`. Use `/commit` to draft Conventional Commit messages.

## 8. What Claude should NOT do

- ❌ **Do not scaffold a new app freehand.** Always follow [`docs/generate-backend.md`](./docs/generate-backend.md), [`docs/generate-web.md`](./docs/generate-web.md), or [`docs/generate-mobile.md`](./docs/generate-mobile.md) — top-to-bottom, no shortcuts. Drift here propagates everywhere.
- ❌ **Do not add new dependencies without asking.** Propose the dep, the use case, and the size impact; wait for approval.
- ❌ **Do not refactor unrelated code** while making a focused change. Leave a `TODO` or open an issue, but don't expand the diff.
- ❌ **Do not use `// @ts-ignore`.** Use `// @ts-expect-error <reason>` if a type error is unavoidable.
- ❌ **Do not create new `.js` files in `src/`.** Always `.ts` / `.tsx`. ESLint will block this.
- ❌ **Do not bypass the feature folder structure.** No top-level `src/components/`, `src/utils/`, `src/api/`. If two features need shared logic, lift it to `packages/`.
- ❌ **Do not commit secrets**, `.env` files, or anything matching `.env.*` (the root `.gitignore` covers this; don't override it).
- ❌ **Do not redefine domain types locally.** They come from [`@template/types`](./packages/types).

## 9. Reference paths

**Shared packages**

- Shared ESLint config → [`packages/config-eslint`](./packages/config-eslint) — flat config presets `base.mjs`, `react.mjs`, `node.mjs`, `react-native.mjs`
- Shared TS configs → [`packages/config-ts`](./packages/config-ts) — `base.json`, `react.json`, `node.json`, `react-native.json`
- Shared types → [`packages/types`](./packages/types) — backend owns; FE + mobile consume

**App generation guides** — follow these whenever a new app is needed

- Backend → [`docs/generate-backend.md`](./docs/generate-backend.md) — Express + TS + Swagger + zod
- Web → [`docs/generate-web.md`](./docs/generate-web.md) — React + Vite + TS + Tailwind
- Mobile → [`docs/generate-mobile.md`](./docs/generate-mobile.md) — Expo + RN + TS + Metro monorepo wiring

**Workflow docs** — process, not code

- [`docs/branching-and-prs.md`](./docs/branching-and-prs.md), [`docs/commit-conventions.md`](./docs/commit-conventions.md), [`docs/feature-folder-template.md`](./docs/feature-folder-template.md), [`docs/deployment.md`](./docs/deployment.md), [`docs/testing.md`](./docs/testing.md), [`docs/event-naming.md`](./docs/event-naming.md)
