# monorepo-template

Opinionated starter for fullstack **MERN + React Native** projects, wired with shared TypeScript / ESLint / domain-types packages and per-stack scaffolding guides.

## Stack

| Layer        | Tooling                                                            |
| ------------ | ------------------------------------------------------------------ |
| Runtime      | **Node 20** (LTS), **pnpm 9**                                      |
| Build        | **Turborepo** 2.x with cached `build` / `lint` / `typecheck` tasks |
| Language     | **TypeScript** strict + `noUncheckedIndexedAccess`                 |
| Web          | **React 18**, **Vite**, **Tailwind**                               |
| Backend      | **Express** + Mongoose, **Swagger** via JSDoc, **zod** validation  |
| Mobile       | **Expo** (latest) + **React Native**, Metro tuned for monorepos    |
| Shared types | `packages/types` (add on demand) — backend owns, FE + mobile import |

## Quick start

1. **"Use this template"** on GitHub → clone the new repo locally.
2. **Rename to your org.** Open [`RENAME.md`](./RENAME.md) and run the four steps (one script does the heavy lifting):

   ```bash
   ./scripts/rename.sh <your-org>
   ```

3. **Install:**

   ```bash
   pnpm install
   ```

4. **Verify the workspace builds:**

   ```bash
   pnpm turbo build typecheck
   ```

5. **Create your first app.** `apps/` starts empty by design — pick the matching guide:

   | App type | Guide                                                    |
   | -------- | -------------------------------------------------------- |
   | Backend  | [`docs/generate-backend.md`](./docs/generate-backend.md) |
   | Web      | [`docs/generate-web.md`](./docs/generate-web.md)         |
   | Mobile   | [`docs/generate-mobile.md`](./docs/generate-mobile.md)   |

   Follow the guide top-to-bottom. Don't scaffold freehand.

## What's inside

```
.
├── apps/         (empty — you create apps from docs/generate-*.md)
├── packages/     shared libraries — built and used by every app
│   ├── config-ts        TypeScript presets (base, react, node, react-native)
│   └── config-eslint    ESLint 9 flat-config presets matching the TS presets
│   (add more on demand — e.g. a `types` package once a domain type is shared)
├── docs/         workflow docs + per-stack generation guides
└── scripts/      one-off automation (rename, etc.)
```

> **`apps/` starts empty by design.** Apps are NOT pre-generated. This keeps the template free of assumptions about which stack you'll need first; you scaffold each app from its dedicated guide when you actually need it.

## Conventions

The repo's coding standards live in [`CLAUDE.md`](./CLAUDE.md) — that file is read automatically by Claude Code, but it's useful for humans too. Read it before your first PR.

Process docs (branching, commits, deployment, testing) live in [`docs/`](./docs/):

- [`docs/branching-and-prs.md`](./docs/branching-and-prs.md) — `main` / `dev` / feature-branch flow, PR rules, branch protection
- [`docs/commit-conventions.md`](./docs/commit-conventions.md) — Conventional Commits, `/commit`, 5–8 file commits, rebase-clean-before-PR
- [`docs/feature-folder-template.md`](./docs/feature-folder-template.md) — required structure for every feature in every app
- [`docs/deployment.md`](./docs/deployment.md) — nginx for FE, PM2 for BE, Crashlytics for mobile
- [`docs/testing.md`](./docs/testing.md) — `.md` spec → Playwright MCP → `.spec.ts`
- [`docs/event-naming.md`](./docs/event-naming.md) — placeholder until mobile analytics rollout

## Need to add a shared package?

If you find yourself wanting to share code across two or more apps, add it under `packages/` rather than copy-pasting. The existing packages are minimal and good references — copy `packages/config-ts/` as a starting point. A common first addition is a `packages/types` package: the backend owns it, and the web/mobile apps import the shared domain types.

## License

UNLICENSED. Replace with your org's license before first ship.
