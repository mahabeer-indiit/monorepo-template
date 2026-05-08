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

| Where                  | Form                  | Example                     |
| ---------------------- | --------------------- | --------------------------- |
| Folder                 | kebab-case            | `apps/admin-dashboard`      |
| `package.json#name`    | `@<org>/<name>`       | `@template/admin-dashboard` |
| `pnpm --filter` target | matches package name  | `--filter @template/admin-dashboard` |

Pick a name that says **what the app is for**: `admin-dashboard`, `customer-portal`, `marketing-site` — not `web2`, `react-app`.

For the rest of this guide, replace `<app-name>` with your name and `<org>` with your scope (use `template` if you don't have one yet).

## 3. Bootstrap with Vite

```bash
cd apps
pnpm create vite <app-name> --template react-ts
cd <app-name>
```

Vite scaffolds a starter app. **Most of it has to go.**

### Delete the Vite cruft

Before doing anything else, remove the demo content:

```bash
# from apps/<app-name>/
rm -rf src/assets public
rm -f src/App.css src/index.css src/App.tsx
rm -f tsconfig.app.json tsconfig.node.json eslint.config.js
```

What stayed: `src/main.tsx`, `src/vite-env.d.ts`, `index.html`, `vite.config.ts`, `package.json`, `tsconfig.json`. We'll rewrite the first five and overwrite the sixth.

> **Why so aggressive?** Vite ships with TypeScript 6, ESLint 10, and React 19 by default — versions that don't yet align with our shared configs. We replace `package.json` wholesale to pin the versions the workspace expects. The deleted `tsconfig.app.json` / `tsconfig.node.json` collapse into a single `tsconfig.json` that extends our shared preset.

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
    "@template/ui": "workspace:*",
    "axios": "^1.7.7",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^6.27.0"
  },
  "devDependencies": {
    "@template/config-eslint": "workspace:*",
    "@template/config-ts": "workspace:*",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.3.0",
    "autoprefixer": "^10.4.20",
    "eslint": "^9.0.0",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.6.2",
    "vite": "^5.4.0"
  }
}
```

> **Do not install `shadcn`, `@radix-ui/*`, `lucide-react`, `class-variance-authority`, etc. directly in this app.** Those belong in `@template/ui`. Adding a UI dep here is a code-review reject.

## 5. Replace `tsconfig.json`

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

## 6. Replace `eslint.config.mjs`

```js
import config from '@template/config-eslint/react.mjs';

export default config;
```

That's it. The shared preset gives you `@typescript-eslint`, React + React Hooks + JSX a11y rules, `eslint-plugin-import` (with `import/order` + `import/no-cycle`), `eslint-plugin-unused-imports`, Prettier compatibility, and the **no-`.js`-files-in-`src/`** rule.

## 7. Update `vite.config.ts`

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

## 8. Tailwind setup

### Install (already covered by the `package.json` above)

`tailwindcss`, `postcss`, and `autoprefixer` are already in devDeps. Just run `pnpm install` from the repo root after step 4 and they'll be linked.

### `tailwind.config.ts`

```ts
import uiPreset from '@template/ui/tailwind.preset';

import type { Config } from 'tailwindcss';

export default {
  presets: [uiPreset],
  content: [
    './index.html',
    './src/**/*.{ts,tsx}',
    '../../packages/ui/src/**/*.{ts,tsx}',
  ],
} satisfies Config;
```

> **Critical:** the `'../../packages/ui/src/**/*.{ts,tsx}'` glob is **not optional**. Without it, Tailwind doesn't see the classes used inside `@template/ui` components and tree-shakes them out of production CSS. Buttons render unstyled in prod. Easy mistake, hard to debug.

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

The shared package owns the base styles, CSS variables, and `@tailwind` directives. Your app just imports them:

```css
@import '@template/ui/styles.css';
```

That's the entire file. **Do not add app-level CSS variables here, do not redeclare `@tailwind base`, do not write per-component CSS.**

## 9. shadcn consumption

> **Hard rule.** This app **does not run `pnpm dlx shadcn@latest add`**. Components come from `@template/ui` only.
>
> If a shadcn component you need isn't in `@template/ui` yet, add it **there**, export it from [`packages/ui/src/index.ts`](../packages/ui/src/index.ts), then import it here. See [`packages/ui/README.md`](../packages/ui/README.md).

Importing components in your app:

```tsx
import { Button, Input, Card, Dialog } from '@template/ui';
```

Importing the `cn` helper or a deep component if needed:

```tsx
import { cn } from '@template/ui/lib/utils';
import { Button } from '@template/ui/components/ui/button';
```

## 10. Folder structure

The full layout you'll end up with:

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
    ├── main.tsx              ← entry: providers + router
    ├── App.tsx               ← routes
    ├── vite-env.d.ts
    ├── index.css             ← only `@import '@template/ui/styles.css';`
    ├── lib/
    │   └── api-client.ts     ← axios wrapper for the backend
    └── features/
        └── hello/            ← one folder per feature, never shared/
            ├── components/   feature-scoped UI
            ├── api/          React Query hooks calling the backend
            ├── types/
            ├── forms/        React Hook Form schemas, defaults
            ├── hooks/        non-API hooks
            ├── pages/        route-level components
            └── index.ts      public surface
```

> **Convention — feature-based structure (mandatory).** No top-level `src/components/`, `src/api/`, `src/hooks/`, `src/utils/`. Everything lives under `src/features/<name>/` or `src/lib/` (for cross-cutting infra like the API client).

> **Coupling rule.** Code stays inside its feature folder until **2+ features** need it. When that happens: app-internal helpers go to `src/lib/`; cross-app code goes to a new `packages/<name>` workspace. Don't preemptively create shared abstractions for "future reuse."

Create the directories:

```bash
mkdir -p src/lib src/features/hello/{components,api,types,forms,hooks,pages}
```

## 11. `src/lib/api-client.ts`

A single axios instance, configured from env. **Every API call in the app goes through this** — no `fetch()` in components, no per-feature axios instances.

```ts
import axios from 'axios';

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1',
  timeout: 10_000,
  headers: { 'Content-Type': 'application/json' },
});

// Add interceptors here for auth tokens, logging, error normalization.
// Keep the file small — feature-specific behavior belongs in the feature.
```

## 12. `src/main.tsx` — entry

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';

import App from './App';

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
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
);
```

## 13. `src/App.tsx` — routes

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

## 14. Reference feature: `hello`

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

> **Shared types rule.** Domain types come from `@template/types`. **Never redefine `User`, `Order`, etc. locally.** If you need a feature-specific projection, use `Pick<User, ...>` or a wrapper type (as `HelloResponse` does above).

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

> **API rule.** All backend calls go through `apiClient` and a React Query `useQuery` / `useMutation` hook in the feature's `api/` folder. **No `fetch()` or `axios.get()` in components or pages.** This keeps loading/error/cache behavior consistent and makes the call sites trivially mockable in tests.

### `src/features/hello/components/PingStatus.tsx`

```tsx
import type { HelloPing } from '../types/hello-response';

type PingStatusProps = {
  data: HelloPing | undefined;
  isLoading: boolean;
  isError: boolean;
};

export function PingStatus({ data, isLoading, isError }: PingStatusProps) {
  if (isLoading) return <p className="text-muted-foreground text-sm">Pinging API…</p>;
  if (isError) return <p className="text-destructive text-sm">API unreachable</p>;
  if (!data) return null;
  return (
    <p className="text-muted-foreground text-sm">
      API up — last ping <code>{data.ts}</code>
    </p>
  );
}
```

### `src/features/hello/components/GreetCard.tsx`

```tsx
import { Button } from '@template/ui';

import type { HelloResponse } from '../types/hello-response';

type GreetCardProps = {
  result: HelloResponse | undefined;
  isPending: boolean;
  onGreet: () => void;
};

export function GreetCard({ result, isPending, onGreet }: GreetCardProps) {
  return (
    <div className="bg-card flex flex-col items-center gap-4 rounded-lg border p-6">
      <Button onClick={onGreet} disabled={isPending}>
        {isPending ? 'Greeting…' : 'Greet "World"'}
      </Button>
      {result && (
        <div className="text-center">
          <p className="text-lg">{result.greeting}</p>
          <p className="text-muted-foreground text-sm">
            User: {result.user.email} (id: <code>{result.user.id}</code>)
          </p>
        </div>
      )}
    </div>
  );
}
```

> **UI rule.** Components from **`@template/ui` only** — no Material UI, Chakra, Ant Design, Mantine, or hand-rolled `<button>` styled with Tailwind that duplicates `<Button>`. Tailwind utilities only — **no `style={{ ... }}` inline styles, no CSS modules, no styled-components.**

### `src/features/hello/pages/HelloPage.tsx`

```tsx
import { GreetCard } from '../components/GreetCard';
import { PingStatus } from '../components/PingStatus';
import { useGreetMutation } from '../api/use-greet-mutation';
import { useHelloPing } from '../api/use-hello-ping';

export function HelloPage() {
  const ping = useHelloPing();
  const greet = useGreetMutation();

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center gap-8 p-8">
      <header className="text-center">
        <h1 className="text-4xl font-semibold">Hello</h1>
        <p className="text-muted-foreground mt-2">
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
export { HelloPage } from './pages/HelloPage';
export { useHelloPing } from './api/use-hello-ping';
export { useGreetMutation } from './api/use-greet-mutation';
export type { HelloResponse, HelloPing } from './types/hello-response';
```

Other features (and `App.tsx`) import only from `'@/features/hello'` — never reach into `components/`, `api/`, etc. directly. The barrel is the public API.

## 15. `apps/<app-name>/CLAUDE.md`

App-specific context. The repo's root [`CLAUDE.md`](../CLAUDE.md) covers cross-cutting standards; this file is owned by the app's devs.

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

## 16. `.env.example`

```bash
# Backend API base URL (no trailing slash). Includes /api/v1.
VITE_API_URL=http://localhost:3000/api/v1
```

> Vite only exposes env vars **prefixed with `VITE_`** to the client bundle. Never put secrets here — anything in `.env` ships in the JS payload visible to users. Real secrets stay server-side.

The actual `.env` is gitignored. Devs copy `.env.example` to `.env` and fill in their local values.

## 17. `apps/<app-name>/index.html`

Replace the scaffolded title:

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

Drop the favicon link if you don't have one yet — re-add when design provides assets.

## 18. `apps/<app-name>/README.md`

```md
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

| Command          | What it does                |
| ---------------- | --------------------------- |
| `pnpm dev`       | Vite dev server with HMR    |
| `pnpm build`     | Vite production build       |
| `pnpm preview`   | Preview the built output    |
| `pnpm lint`      | ESLint                      |
| `pnpm typecheck` | `tsc --noEmit`              |

## Conventions

See the root [CLAUDE.md](../../CLAUDE.md) and [docs/generate-web.md](../../docs/generate-web.md). Don't deviate.
```

## 19. Verification

From the repo root:

```bash
# 1. Install — should detect the new workspace project + link @template/* packages
pnpm install

# 2. Start the backend in another terminal (if you have one)
pnpm --filter @<org>/<backend-name> dev

# 3. Start this app
pnpm --filter @<org>/<app-name> dev
```

Then open <http://localhost:5173> and verify:

- ✅ Page renders without console errors
- ✅ "API up — last ping ..." text appears (React Query hit `/api/v1/hello` successfully)
- ✅ Clicking the **Greet "World"** button shows the greeting + user email + id
- ✅ Network tab shows `GET /api/v1/hello` and `POST /api/v1/hello` to `VITE_API_URL`
- ✅ The button is the shadcn `<Button>` from `@template/ui` (rounded, themed, hover state)

Then the full sweep:

```bash
pnpm turbo build lint typecheck --filter=@<org>/<app-name>
```

All three tasks must pass with **zero warnings**. **Don't commit until they do.**

---

## Conventions cheat sheet

Pin this somewhere visible:

- ✅ Feature-based folder structure — **no `components/`, `api/`, `hooks/` at app root**
- ✅ Coupling rule — keep code inside the feature until **2+ features** need it
- ✅ UI components **only from `@template/ui`** — no MUI, Chakra, Ant, Mantine, hand-rolled buttons
- ✅ **No local shadcn install** — add new components to `packages/ui` and export them
- ✅ Tailwind utilities only — **no inline `style={{...}}`, no CSS modules, no styled-components**
- ✅ Domain types from `@template/types` — **never redefine** `User`, `Order`, etc.
- ✅ All API calls through `src/lib/api-client.ts` + React Query hook in `features/<x>/api/` — **no `fetch()` or `axios.x()` in components**
- ✅ No new `.js` files in `src/` — ESLint blocks it
- ✅ Don't forget the `'../../packages/ui/src/**/*.{ts,tsx}'` glob in `tailwind.config.ts`
