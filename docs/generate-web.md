# Generate a web app

This guide walks through creating a new React + Vite + TypeScript + Tailwind web app inside this monorepo. Follow it top-to-bottom and you (or Claude Code) will end up with a working, conventions-compliant frontend.

> **Read this in full before starting.** The conventions are non-negotiable. Drift here propagates into every page.

## 1. Prerequisites

Run all commands from the **repo root**.

- **Node 20** — `node --version` should print `v20.x` (use `nvm use`)
- **pnpm 9** — `pnpm --version` should print `9.x`
- A clean working tree

```bash
node --version    # v20.x
pnpm --version    # 9.x
git status        # clean
```

## 2. Decide the app name

Use **kebab-case**. The name shows up in three places:

| Where                  | Form                 | Example                              |
| ---------------------- | -------------------- | ------------------------------------ |
| Folder                 | kebab-case           | `apps/admin-dashboard`               |
| `package.json#name`    | `@<org>/<name>`      | `@template/admin-dashboard`          |
| `pnpm --filter` target | matches package name | `--filter @template/admin-dashboard` |

Pick a name that says **what the app is for**: `admin-dashboard`, `customer-portal`, `marketing-site` — not `web2`, `react-app`.

For the rest of this guide, replace `<app-name>` with your name and `<org>` with your scope (use `template` if you don't have one yet).

## 3. Bootstrap with Vite

```bash
cd apps
pnpm create vite <app-name> --template react-ts
cd <app-name>
```

Vite scaffolds a starter app on **Vite 8 + plugin-react 6 + React 19**. **Most of the demo content has to go.**

### Delete the Vite cruft

```bash
# from apps/<app-name>/
rm -rf src/assets public
rm -f src/App.css src/index.css src/App.tsx
rm -f tsconfig.app.json tsconfig.node.json eslint.config.js
```

What stayed: `src/main.tsx`, `src/vite-env.d.ts`, `index.html`, `vite.config.ts`, `package.json`, `tsconfig.json`. We'll rewrite the first five and overwrite the sixth.

> **Why so aggressive?** The bootstrap pulls bleeding-edge versions of TypeScript, ESLint, and `@types/node` that don't all match the workspace's pinned versions. We replace `package.json` wholesale so the app aligns with the shared configs from day one. The deleted `tsconfig.app.json` / `tsconfig.node.json` collapse into a single `tsconfig.json` that extends our shared preset.

## 4. Replace `package.json`

```json
{
  "name": "@<org>/<app-name>",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "description": "<one-line purpose of this app>",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@tanstack/react-query": "^5.59.0",
    "@template/types": "workspace:*",
    "axios": "^1.7.7",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-error-boundary": "^4.1.2",
    "react-router-dom": "^6.27.0"
  },
  "devDependencies": {
    "@template/config-eslint": "workspace:*",
    "@template/config-ts": "workspace:*",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^6.0.0",
    "autoprefixer": "^10.4.20",
    "eslint": "^9.0.0",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.6.2",
    "vite": "^8.0.0"
  }
}
```

> **This template is unopinionated about UI component libraries.** There is no shared web UI package. If this app needs a component library (shadcn/ui, Radix, etc.), add it here and own it locally — but get sign-off first per the "no new deps without asking" rule in [`CLAUDE.md`](../CLAUDE.md). Keep styling to Tailwind utilities (see §5 conventions).

## 5. Run `pnpm install`

```bash
# from repo root
pnpm install
```

> **🔁 Anytime you change `package.json`** — adding a dep, bumping a version, renaming a script — run `pnpm install` from the repo root again.

## 6. Replace `tsconfig.json`

```json
{
  "extends": "@template/config-ts/react.json",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src", "vite.config.ts", "tailwind.config.ts", "postcss.config.js"]
}
```

The `@/*` path lets you write `import { apiClient } from '@/lib/api-client'` instead of `'../../../lib/api-client'`. Vite is configured to mirror this alias at runtime (next step).

## 7. Replace `eslint.config.mjs`

```js
import config from '@template/config-eslint/react.mjs';

export default config;
```

That's it — no per-app resolver overrides needed. The shared preset gives you `@typescript-eslint`, React + React Hooks + JSX a11y rules, `eslint-plugin-import` (with `import/order` + `import/no-cycle`), `eslint-plugin-unused-imports`, Prettier compatibility, and the **no-`.js`-files-in-`src/`** rule.

> **About import ordering.** The shared `import/order` rule sorts imports by group — builtin → external → internal → parent/sibling/index — alphabetized within each group. **Type imports interleave naturally with their value-import counterparts** (sorted by source). You don't need to put all `import type` statements last. Just write imports the natural way and Prettier + ESLint will agree.

## 8. Update `vite.config.ts`

```ts
import path from 'node:path';

import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 5173,
  },
});
```

## 9. Type `import.meta.env` — extend `vite-env.d.ts`

The bootstrap leaves `src/vite-env.d.ts` with just `/// <reference types="vite/client" />`. Without extending it, `import.meta.env.VITE_API_URL` types as `string | undefined` and gets no autocomplete. Add an `ImportMetaEnv` interface:

```ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  // Add every new VITE_* env var here. Without it, TS treats
  // `import.meta.env.VITE_FOO` as `unknown` / `string | undefined`.
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

> **Rule.** Every `VITE_*` env var must have a corresponding line in this interface. PR review will reject app code that reads an env var that isn't typed here.

## 10. Tailwind setup

### Install (already covered by the `package.json` above)

`tailwindcss`, `postcss`, and `autoprefixer` are in devDeps. Step 5's `pnpm install` already wired them up.

### `tailwind.config.ts`

```ts
import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {},
  },
} satisfies Config;
```

> **Add your design tokens under `theme.extend`** (colors, radii, spacing) as the app grows. This template ships no shared preset — each app owns its own Tailwind theme.

### `postcss.config.js`

```js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

### `src/index.css`

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

That's the entire file. **Do not write per-component CSS.** If you need design-token CSS variables, declare them here under a `@layer base` block — but keep component styling to Tailwind utilities (see §5).

## 11. UI components

> **Unopinionated by design.** This template ships **no shared UI package**. Build your own presentational components under `src/features/<name>/components/` with Tailwind utilities, or adopt a component library (shadcn/ui, Radix, etc.) scoped to this app.
>
> If you do add a library, get sign-off first (see "no new deps without asking" in [`CLAUDE.md`](../CLAUDE.md)), install it in **this app's** `package.json`, and keep styling to Tailwind utilities — no inline `style={{ ... }}`, no CSS-in-JS.

## 12. Folder structure

```
apps/<app-name>/
├── CLAUDE.md
├── README.md
├── .env.example
├── eslint.config.mjs
├── index.html
├── package.json
├── postcss.config.js
├── tailwind.config.ts
├── tsconfig.json
├── vite.config.ts
└── src/
    ├── main.tsx              ← entry: providers + router + error boundary
    ├── App.tsx               ← routes
    ├── ErrorFallback.tsx     ← top-level error UI
    ├── vite-env.d.ts
    ├── index.css             ← only the three `@tailwind` directives
    ├── lib/
    │   └── api-client.ts     ← axios wrapper for the backend
    └── features/
        └── hello/            ← one folder per feature, never shared/
            ├── components/
            ├── api/
            ├── types/
            ├── forms/
            ├── hooks/
            ├── pages/
            └── index.ts      ← public surface
```

> **Convention — feature-based structure (mandatory).** No top-level `src/components/`, `src/api/`, `src/hooks/`, `src/utils/`. Everything lives under `src/features/<name>/` or `src/lib/` (for cross-cutting infra like the API client).

> **Coupling rule.** Code stays inside its feature folder until **2+ features** need it. App-internal helpers go to `src/lib/`; cross-app code goes to a new `packages/<name>` workspace.

```bash
mkdir -p src/lib src/features/hello/{components,api,types,forms,hooks,pages}
```

## 13. `src/lib/api-client.ts` — axios + auth interceptors

A single axios instance handles base URL, auth token, and 401 redirects. Every API call goes through this — no `fetch()` in components, no per-feature axios instances.

```ts
import axios from 'axios';

const TOKEN_STORAGE_KEY = 'auth.token';

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  timeout: 10_000,
  headers: { 'Content-Type': 'application/json' },
});

// Request interceptor — attach JWT from localStorage if present.
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_STORAGE_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor — clear auth and redirect to /login on 401.
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem(TOKEN_STORAGE_KEY);
      // Use `window.location` (not React Router) so any in-flight queries are aborted.
      if (window.location.pathname !== '/login') {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  },
);

export const authStorage = {
  get: () => localStorage.getItem(TOKEN_STORAGE_KEY),
  set: (token: string) => localStorage.setItem(TOKEN_STORAGE_KEY, token),
  clear: () => localStorage.removeItem(TOKEN_STORAGE_KEY),
};
```

> **If your auth flow differs** (HTTP-only cookies, OAuth, session IDs, refresh tokens) — adapt these interceptors. The pattern stays the same: one place to attach credentials, one place to react to 401s. Don't scatter token reads across features.

## 14. `src/ErrorFallback.tsx` — top-level fallback

Wraps the entire app. A single render error in any feature falls through to this UI rather than blanking the screen.

```tsx
import type { FallbackProps } from 'react-error-boundary';

export function ErrorFallback({ error, resetErrorBoundary }: FallbackProps) {
  return (
    <div
      role="alert"
      className="mx-auto flex min-h-screen max-w-lg flex-col items-center justify-center gap-4 p-8 text-center"
    >
      <h1 className="text-2xl font-semibold">Something went wrong</h1>
      <pre className="max-w-full overflow-auto rounded bg-gray-100 p-4 text-left text-sm text-red-600">
        {error.message}
      </pre>
      <button
        type="button"
        onClick={resetErrorBoundary}
        className="rounded bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-700"
      >
        Try again
      </button>
    </div>
  );
}
```

## 15. `src/main.tsx` — entry

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { ErrorBoundary } from 'react-error-boundary';
import { BrowserRouter } from 'react-router-dom';

import App from './App';
import { ErrorFallback } from './ErrorFallback';

import './index.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary
      FallbackComponent={ErrorFallback}
      onReset={() => {
        // Optional: clear cached query data on retry to avoid re-throwing the same error.
        queryClient.clear();
      }}
    >
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </QueryClientProvider>
    </ErrorBoundary>
  </StrictMode>,
);
```

The error boundary is **outside** all the providers so even a provider crash falls through gracefully.

## 16. `src/App.tsx` — routes

Keep this file thin. It only wires routes to feature pages — no UI logic.

```tsx
import { Route, Routes } from 'react-router-dom';

import { HelloPage } from '@/features/hello';

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<HelloPage />} />
      {/* Add one route per feature page. Pages live in features/<name>/pages/. */}
    </Routes>
  );
}
```

## 17. Reference feature: `hello`

This is the canonical feature. Copy this folder when creating a new feature, then rename and gut the contents.

The reference behavior:

- **GET** `/api/v1/hello` (a health-check ping) — fetched on page load via React Query
- **POST** `/api/v1/hello` (greet by name) — triggered by a button click via React Query mutation
- Both responses are typed using the shared `User` type from `@template/types`

### `src/features/hello/types/hello-response.ts`

```ts
import type { User } from '@template/types';

export type HelloPing = {
  ok: boolean;
  ts: string;
};

export type HelloResponse = {
  greeting: string;
  user: User;
};
```

> **Shared types rule.** Domain types come from `@template/types`. **Never redefine `User`, `Order`, etc. locally.** If you need a feature-specific projection, use `Pick<User, ...>` or a wrapper type.

### `src/features/hello/api/use-hello-ping.ts`

```ts
import { useQuery } from '@tanstack/react-query';

import { apiClient } from '@/lib/api-client';

import type { HelloPing } from '../types/hello-response';

async function fetchHelloPing(): Promise<HelloPing> {
  const { data } = await apiClient.get<HelloPing>('/hello');
  return data;
}

export function useHelloPing() {
  return useQuery({
    queryKey: ['hello', 'ping'],
    queryFn: fetchHelloPing,
  });
}
```

### `src/features/hello/api/use-greet-mutation.ts`

```ts
import { useMutation } from '@tanstack/react-query';

import { apiClient } from '@/lib/api-client';

import type { HelloResponse } from '../types/hello-response';

type GreetInput = { name: string };

async function postGreet(input: GreetInput): Promise<HelloResponse> {
  const { data } = await apiClient.post<HelloResponse>('/hello', input);
  return data;
}

export function useGreetMutation() {
  return useMutation({
    mutationFn: postGreet,
  });
}
```

> **API rule.** All backend calls go through `apiClient` and a React Query `useQuery` / `useMutation` hook in the feature's `api/` folder. **No `fetch()` or `axios.get()` in components or pages.**

### `src/features/hello/components/PingStatus.tsx`

```tsx
import type { HelloPing } from '../types/hello-response';

type PingStatusProps = {
  data: HelloPing | undefined;
  isLoading: boolean;
  isError: boolean;
};

export function PingStatus({ data, isLoading, isError }: PingStatusProps) {
  if (isLoading) return <p className="text-sm text-gray-500">Pinging API…</p>;
  if (isError) return <p className="text-sm text-red-600">API unreachable</p>;
  if (!data) return null;
  return (
    <p className="text-sm text-gray-500">
      API up — last ping <code>{data.ts}</code>
    </p>
  );
}
```

### `src/features/hello/components/GreetCard.tsx`

```tsx
import type { HelloResponse } from '../types/hello-response';

type GreetCardProps = {
  result: HelloResponse | undefined;
  isPending: boolean;
  onGreet: () => void;
};

export function GreetCard({ result, isPending, onGreet }: GreetCardProps) {
  return (
    <div className="flex flex-col items-center gap-4 rounded-lg border bg-white p-6">
      <button
        type="button"
        onClick={onGreet}
        disabled={isPending}
        className="rounded bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-700 disabled:opacity-50"
      >
        {isPending ? 'Greeting…' : 'Greet "World"'}
      </button>
      {result && (
        <div className="text-center">
          <p className="text-lg">{result.greeting}</p>
          <p className="text-sm text-gray-500">
            User: {result.user.email} (id: <code>{result.user.id}</code>)
          </p>
        </div>
      )}
    </div>
  );
}
```

> **UI rule.** Tailwind utilities only — **no `style={{ ... }}` inline styles, no CSS modules, no styled-components.** Build presentational components locally; this template ships no shared UI package.

### `src/features/hello/pages/HelloPage.tsx`

```tsx
import { useGreetMutation } from '../api/use-greet-mutation';
import { useHelloPing } from '../api/use-hello-ping';
import { GreetCard } from '../components/GreetCard';
import { PingStatus } from '../components/PingStatus';

export function HelloPage() {
  const ping = useHelloPing();
  const greet = useGreetMutation();

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center gap-8 p-8">
      <header className="text-center">
        <h1 className="text-4xl font-semibold">Hello</h1>
        <p className="mt-2 text-gray-500">
          Calls <code>/api/v1/hello</code> via React Query.
        </p>
      </header>

      <PingStatus data={ping.data} isLoading={ping.isLoading} isError={ping.isError} />

      <GreetCard
        result={greet.data}
        isPending={greet.isPending}
        onGreet={() => greet.mutate({ name: 'World' })}
      />
    </main>
  );
}
```

### `src/features/hello/index.ts` — public surface

```ts
export { useGreetMutation } from './api/use-greet-mutation';
export { useHelloPing } from './api/use-hello-ping';
export { HelloPage } from './pages/HelloPage';

export type { HelloPing, HelloResponse } from './types/hello-response';
```

Other features (and `App.tsx`) import only from `'@/features/hello'` — never reach into `components/`, `api/`, etc. directly.

## 18. `apps/<app-name>/CLAUDE.md`

App-specific context. The repo's root [`CLAUDE.md`](../CLAUDE.md) covers cross-cutting standards.

```md
# <app-name>

## Overview

## Tech stack

## Project structure

## Feature module conventions

## Routing

## State management

## Data fetching

## Forms

## Styling and design system

## Authentication

## Environment variables

## Testing

## Build and deploy

## Common tasks
```

Start with empty section bodies — fill them as the app grows.

## 19. `.env.example`

```bash
# Backend API base URL (no trailing slash). Includes /api/v1.
VITE_API_URL=http://localhost:3000/api/v1
```

> Vite only exposes env vars **prefixed with `VITE_`** to the client bundle. Never put secrets here — anything in `.env` ships in the JS payload visible to users.

When adding a new `VITE_*` var, also add a line to **`src/vite-env.d.ts`** (step 9) so TypeScript knows about it.

## 20. `apps/<app-name>/index.html`

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><app-name></title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

## 21. `apps/<app-name>/README.md`

````md
# <app-name>

React + Vite + TypeScript web app in the monorepo.

## Quickstart

```bash
pnpm install                                  # from repo root
cp apps/<app-name>/.env.example apps/<app-name>/.env
pnpm --filter @<org>/<app-name> dev
```

Open <http://localhost:5173>. The app expects the backend running on the URL in `VITE_API_URL`.

## Scripts

| Command          | What it does             |
| ---------------- | ------------------------ |
| `pnpm dev`       | Vite dev server with HMR |
| `pnpm build`     | Vite production build    |
| `pnpm preview`   | Preview the built output |
| `pnpm lint`      | ESLint                   |
| `pnpm typecheck` | `tsc --noEmit`           |

## Conventions

See the root [CLAUDE.md](../../CLAUDE.md) and [docs/generate-web.md](../../docs/generate-web.md). Don't deviate.
````

## 22. Verification

```bash
# 1. Install
pnpm install

# 2. Start backend in another terminal (if you have one)
pnpm --filter @<org>/<backend-name> dev

# 3. Start this app
pnpm --filter @<org>/<app-name> dev
```

Open <http://localhost:5173> and verify:

- ✅ Page renders without console errors
- ✅ "API up — last ping ..." text appears
- ✅ Clicking the **Greet "World"** button shows the greeting + user email + id
- ✅ Network tab shows `GET /api/v1/hello` and `POST /api/v1/hello` to `VITE_API_URL`
- ✅ The button is styled with Tailwind utilities (rounded, hover state)
- ✅ Forcing an error in any component falls through to the **Try again** screen, not a blank page

Then:

```bash
pnpm turbo build lint typecheck --filter=@<org>/<app-name>
```

All three tasks must pass with **zero warnings**. **Don't commit until they do.**

---

## Troubleshooting

### "JSX component cannot be used as a JSX component" (or similar React-types errors)

The workspace pins `@types/react` and `@types/react-dom` to `^19.0.0` via `pnpm.overrides` in the **root `package.json`**:

```jsonc
{
  "pnpm": {
    "overrides": {
      "@types/react": "^19.0.0",
      "@types/react-dom": "^19.0.0",
    },
  },
}
```

This prevents type drift between workspace packages (e.g., if your app pulled in `@types/react@18` transitively while another package resolved `@types/react@19`, the two `ReactNode` definitions disagree and shared JSX components look "not assignable").

**Don't try to upgrade `@types/react` in this app's `package.json`** — change the override at the root if a bump is genuinely needed, then run `pnpm install` from the repo root.

### `pnpm lint` errors with "Tsconfig not found ... node_modules/tsconfig.base.json"

You shouldn't see this. `@template/config-eslint` is configured to skip the typescript resolver (it walks tsconfig `extends` chains and breaks on pnpm symlinks). If you see this error, you've added a per-app override to `eslint.config.mjs` that re-enables the typescript resolver — **remove it**. The shared config handles the resolver correctly without per-app config.

### `import.meta.env.VITE_FOO` is `unknown` in TypeScript

Add the var to the `ImportMetaEnv` interface in `src/vite-env.d.ts` (step 9). Every `VITE_*` var must be declared there.

### React Query is not refetching after a code change

That's expected — `staleTime: 30_000` and `refetchOnWindowFocus: false` are set in `main.tsx`. Adjust the defaults per your app, or invalidate specific keys in components when needed.

---

## Conventions cheat sheet

Pin this somewhere visible:

- ✅ Feature-based folder structure — **no `components/`, `api/`, `hooks/` at app root**
- ✅ Coupling rule — keep code inside the feature until **2+ features** need it
- ✅ Tailwind utilities only — **no inline `style={{...}}`, no CSS modules, no styled-components**
- ✅ No shared UI package — build components locally; adopt a UI library per app only with sign-off
- ✅ Domain types from `@template/types` — **never redefine** `User`, `Order`, etc.
- ✅ All API calls through `src/lib/api-client.ts` + React Query hook in `features/<x>/api/` — **no `fetch()` in components**
- ✅ Every `VITE_*` env var declared in `src/vite-env.d.ts`
- ✅ Top-level `<ErrorBoundary>` wraps the app — render errors fall through, not blank screens
- ✅ Auth tokens managed by **`apiClient` interceptors** — never re-implement per feature
- ✅ No new `.js` files in `src/` — ESLint blocks it
- ✅ Don't override `@types/react` in this app — change root `pnpm.overrides` instead
