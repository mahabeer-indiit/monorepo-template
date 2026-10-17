# AGENTS.md

Hard rules for any AI agent working in this repo. Rules only, no architecture tour — read the
code for that. If a rule here is wrong, change it in a PR and add a line to the decisions index;
do not work around it.

@docs/decisions/INDEX.md

Claude Code inlines that index above, so the reasoning behind these rules is already in context.
Other agents: read `docs/decisions/INDEX.md` before your first edit.

## 0. Setup gate — this repo refuses to work until it is renamed

The template ships under the `@template/` npm scope. Every `package.json#name` must be rebranded
to the project's own scope before any feature work. A `UserPromptSubmit` hook blocks every prompt
until that is true, so this is the first thing to fix, not something to work around.

```bash
./scripts/rename.sh <your-org>        # macOS / Linux / Git Bash / WSL
bash scripts/rename.sh <your-org>     # Windows PowerShell / CMD
```

Never rename packages by hand, never edit `scripts/check-template-rename.sh`, and never create
`.claude/allow-template-scope` (that marker is for maintainers of the template itself).

## 1. Commands

| Task | Command |
| --- | --- |
| Install | `pnpm install` |
| Dev | `pnpm dev` |
| Build / lint / test / typecheck | `pnpm build` · `pnpm lint` · `pnpm test` · `pnpm typecheck` |
| Format | `pnpm format` (write) · `pnpm format:check` (CI) |
| One package only | `pnpm turbo run typecheck --filter=@<org>/api...` |
| Agent settings fan-out | `pnpm agents:sync` · `pnpm agents:check` |

- **pnpm only.** `npm` and `yarn` are blocked by permission rule. `packageManager` pins
  `pnpm@9.15.4`; `.npmrc` sets `engine-strict=true`, so the wrong Node (needs **20**) fails at
  `install`, not at runtime.
- Add dependencies with `pnpm add` in the owning package. Never hand-edit `pnpm-lock.yaml`
  (blocked by permission rule).
- After a change, run `typecheck` and `lint` filtered to the touched package *and its dependents*
  (`--filter=<pkg>...`), then `build`. Do not report work as done before those pass.

## 2. Monorepo gotchas

- **`apps/` is empty by design.** Never scaffold an app freehand. Follow
  `docs/generate-backend.md`, `docs/generate-web.md` or `docs/generate-mobile.md` top to bottom.
- **Turbo's `build` task only watches `src/**`, `tsconfig.json`, `package.json`** (see
  `turbo.json#tasks.build.inputs`). A new build-affecting file — `vite.config.ts`,
  `tailwind.config.ts`, `public/**`, a generated schema — must be added to that `inputs` array, or
  CI serves a stale cached build and the failure looks like a code bug.
- **Every task `dependsOn: ["^build"]`.** A new package without a `build` script silently breaks
  its dependents' task graph. Give it one, even a no-op.
- New package: extend the matching preset from `packages/config-ts` (`base` / `react` / `node` /
  `react-native`) and the matching flat config from `packages/config-eslint`. Do not write a
  standalone `tsconfig.json` or `eslint.config.mjs` from scratch.
- **After adding any workspace package, run `pnpm agents:sync` and commit the result.** Claude Code
  loads `.claude/settings.json` from the directory it was started in with **no parent lookup**, so a
  package without its own copy runs with zero deny rules. CI fails on a missing or drifted copy.
- Root `package.json#pnpm.overrides` pins `@types/react` to `^19` while web apps run React 18.
  That is deliberate and global — do not "fix" it inside a package.
- `.npmrc` has `auto-install-peers=true`; peers resolve silently, so do not add peer packages
  manually to make a type error go away.
- A domain type shared by two or more apps moves into a `packages/types` workspace package
  (created on demand, backend owns it). Never redeclare it per app.

## 3. Code conventions

- TypeScript strict everywhere, plus `noUncheckedIndexedAccess` and `noImplicitOverride`.
- No `any` without an inline comment justifying it. No `// @ts-ignore` — use
  `// @ts-expect-error <reason>`.
- No new `.js` / `.jsx` files under any `src/` (ESLint blocks it). `.ts` / `.tsx` only.
- Feature-based layout, enforced:
  `src/features/<name>/{components,api,types,forms,hooks,pages|screens,index.ts}`. No top-level
  `src/components/`, `src/utils/` or `src/api/`. Shared-across-features logic goes to `packages/`.
- Prettier owns formatting, ESLint owns rules. Do not hand-format or add per-file lint disables.

## 4. API conventions (backend apps)

- Every route is versioned: `/api/v1/...`. Unversioned routes are a review blocker.
- Every endpoint carries a JSDoc `@openapi` Swagger block — internal and admin routes included.
- Every request body, query and param is parsed by a **zod** schema before controller logic runs.
- Errors return `{ error: { code, message, details? } }` with a real status code. Never leak a
  stack trace in a response body.
- The backend owns each domain type and exports it; clients import, never redefine.

## 5. UI conventions

- Web: **Tailwind utilities only.** No inline `style={{}}`, no CSS-in-JS, no per-component CSS file.
- Mobile: `StyleSheet.create()`. Same ban on inline styles.
- There is no shared web UI package. Each web app owns its components under
  `src/features/<name>/components/`. Do not invent a cross-app UI package without a decision entry.

## 6. Tests — not written unless asked

- **Do not write tests for new features unless explicitly asked.** No test files, no spec files, no
  opportunistic coverage while passing through.
- When tests *are* requested: pure functions and hooks → Vitest `<thing>.test.ts` beside the source.
  Anything crossing the DOM, network, navigation or persistence → Playwright `<thing>.spec.ts`
  generated from a committed `<thing>.spec.md` (`docs/testing.md`).
- This rule overrides the "spec and test ship in the same PR" line in `docs/testing.md`; that
  applies only once tests have been asked for.
- Never delete, skip or weaken an existing test to make a change pass. Report the failure instead.

## 7. Git

- Conventional Commits: `<type>(<scope>): <subject>` — `feat` `fix` `chore` `refactor` `docs` `test`
  `style` `perf` `build` `ci`.
- Branch off **`dev`**, never `main`. Name it `<type>/<ticket>-<short-desc>`, e.g.
  `feat/PROJ-123-add-login`. Only `hotfix/<ticket>-<short-desc>` branches off `main`.
- Target 5–8 files per commit; each commit builds on its own. Stage with `git add -p`, never
  `git add .`.
- Rebase onto `origin/dev` before opening the PR; squash-merge by default.
- `git push --force`, `git reset --hard`, `git clean -fd` and `--no-verify` are blocked by
  permission rule. Do not route around them — ask.

## 8. Permission rules are guardrails, not a sandbox

- Deny rules live in `.claude/settings.json`, committed at the repo root and in every workspace
  package (`pnpm agents:check` enforces that in CI).
- A denial means **stop and ask.** Do not reach a denied file through a subprocess (`node -e`,
  `sed -i`, a heredoc, `python -c`): Bash is a separate rule namespace, so it will succeed, and
  doing it is treated as a defect, not a clever workaround.
- `.env*` files, private keys, mobile signing material and service-account JSON are denied for read
  as well as write. Required variables are documented in each app's `.env.example`; ask the human
  for values rather than reading or printing a real `.env`.
- Do not edit `.claude/settings.json`, `.claude/settings.local.json`, `.github/workflows/**` or the
  rename gate script. Propose the change in chat and let a human apply it.

## 9. Do not

- Add a dependency without approval. Propose it with the use case and the size impact first.
- Refactor unrelated code inside a focused change. Leave a TODO or open an issue.
- Commit secrets, `.env` files, or anything matching `.env.*` (`.env.example` excepted).
- Change a standing convention silently. Add or update an entry in `docs/decisions/` in the same PR.

<!-- <org> above = the npm scope this repo was renamed to by scripts/rename.sh. -->
