# Feature folder template

Every feature in a frontend app (`apps/web`, `apps/mobile`) lives in `src/features/<feature-name>/`. This is a hard rule — no top-level `src/components/`, `src/api/`, etc. that mixes concerns across features.

## Required structure

```
src/features/<name>/
├── components/   UI building blocks scoped to this feature
├── api/          API call functions (one per endpoint), return typed data
├── types/        Feature-local types; re-exports from @template/types when shared
├── forms/        React Hook Form schemas, defaults, submit handlers
├── hooks/        Custom hooks: useXxx, data-fetching wrappers, derived state
├── pages/        Route-level components (web) — composes everything else
│                 (or screens/ for React Native)
└── index.ts      Public surface — only export what other features may import
```

Not every feature needs every folder. Skip the empty ones; don't create `forms/` until you have a form. **But never put a file outside this structure** ("temporarily").

## The `index.ts` rule

Other features import from **`@/features/<name>`**, never deeper. The barrel `index.ts` is the public API.

```ts
// ✅ allowed
import { LoginPage, useCurrentUser } from '@/features/auth';

// ❌ rejected in code review
import { LoginForm } from '@/features/auth/components/LoginForm';
import { loginApi } from '@/features/auth/api/login';
```

This makes refactors inside a feature safe: as long as the barrel still exports the same names, callers don't break.

## Reference example

[`apps/_template-web/src/features/hello/`](../apps/_template-web/src/features/hello/) is the canonical reference. It demonstrates:

- `types/hello-user.ts` — feature-local view of a shared type from `@template/types`
- `api/get-hello-user.ts` — typed fetch returning `Promise<User>`
- `hooks/use-hello-user.ts` — wraps the API call in a hook
- `components/HelloButton.tsx` — small, presentational, uses `@template/ui`
- `pages/HelloPage.tsx` — composes hook + components into a route-level view
- `index.ts` — exports `HelloPage`, `HelloButton`, `useHelloUser`, `getHelloUser`, type `HelloUser`

When starting a new feature, **copy this folder, rename, and gut the contents**. The structure carries you; the contents are throwaway.

## Cross-feature dependencies

Features may import from:

- `@template/ui`, `@template/types`, other shared packages
- Other features **only via their `index.ts`**

Features may **not** import from:

- Sibling features' internals (`@/features/X/components/...`)
- App-level top-level shared utility files (these shouldn't exist — promote to a shared package instead)

If two features need the same logic, lift it into a package under `packages/`, not into a "shared" folder inside the app.

## Path aliases

The right alias style depends on which bundler is consuming the code. Don't fight the bundler.

- **Web (Vite):** `@/*` aliases (mapped to `./src/*`) work in source code, in TypeScript, and at runtime via `vite.config.ts#resolve.alias`. They do **not** resolve in ESLint's import plugin — known trade-off (the shared resolver is simplified to avoid pnpm-symlink crashes); `import/order` still sorts correctly, but `import/no-cycle` won't follow aliased paths. Acceptable.
- **Mobile (Metro):** **No `@/*` aliases.** Metro doesn't read `tsconfig.json#paths`; even if TypeScript typechecks the alias, runtime resolution fails. Use relative imports (`'../components/Foo'`). Barrel exports — every feature's `index.ts` — keep cross-feature imports short (`'../features/auth'` instead of `'../features/auth/screens/LoginScreen'`).
- **Backend (Node):** No aliases. Use relative imports with explicit `.js` extensions (NodeNext module resolution requires this even for `.ts` source — the `.js` refers to the emitted file).
