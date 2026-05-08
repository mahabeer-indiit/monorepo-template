# Generate a backend app

This guide walks through creating a new Express + TypeScript + Swagger backend service inside this monorepo. Follow it top-to-bottom and you (or Claude Code) will end up with a working, conventions-compliant app.

> **Read this in full before starting.** The conventions in this doc are non-negotiable — drift here propagates everywhere.

## 1. Prerequisites

Run all commands from the **repo root** (where this `docs/` lives).

- **Node 20** — `node --version` should print `v20.x`. Use `nvm use` (the repo has a `.nvmrc`).
- **pnpm 9** — `pnpm --version` should print `9.x`. Corepack auto-switches via `package.json#packageManager`.
- A clean working tree — `git status` should show no changes before starting.

```bash
node --version    # v20.x
pnpm --version    # 9.x
git status        # clean
```

## 2. Decide the app name

Use **kebab-case**. The name shows up in three places:

| Where                     | Form                          | Example                |
| ------------------------- | ----------------------------- | ---------------------- |
| Folder                    | kebab-case                    | `apps/user-api`        |
| `package.json#name`       | `@<org>/<name>`               | `@template/user-api`   |
| `pnpm --filter` target    | matches package name          | `--filter @template/user-api` |

Pick a name that says **what the service owns**, not its tech: `user-api`, `billing-api`, `notifications-api` — not `node-server`, `backend2`.

For the rest of this guide, replace `<app-name>` with your name and `<org>` with your scope (use `template` if you don't have one yet).

## 3. Create the folder structure

```bash
mkdir -p apps/<app-name>/src/{config,features/hello}
cd apps/<app-name>
```

The full layout you'll end up with:

```
apps/<app-name>/
├── CLAUDE.md
├── README.md
├── .env.example
├── eslint.config.mjs
├── package.json
├── tsconfig.json
├── tsup.config.ts
└── src/
    ├── index.ts            ← server bootstrap (calls app.listen)
    ├── app.ts              ← Express app: middleware + route mounts
    ├── config/
    │   └── swagger.ts      ← swagger-jsdoc config
    └── features/
        └── hello/          ← one folder per feature, never shared/
            ├── controller.ts
            ├── service.ts
            ├── routes.ts
            ├── schema.ts   ← zod request validation
            ├── types.ts
            └── index.ts    ← public exports for this feature
```

> **Convention — feature-based structure (mandatory).** No top-level `src/controllers/`, `src/services/`, `src/routes/`. Everything lives under `src/features/<name>/`. Cross-cutting infra (Swagger config, db client) lives in `src/config/` or `src/lib/` — never `src/shared/`.

> **Coupling rule.** Code stays inside its feature folder until it's used by **2 or more** features. When that happens, lift it: app-internal helpers go to `src/lib/`; cross-app code goes to a new `packages/<name>` workspace. Don't preemptively create shared abstractions for "future reuse."

## 4. `package.json`

Create `apps/<app-name>/package.json`:

```json
{
  "name": "@<org>/<app-name>",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "description": "<one-line purpose of this service>",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsup",
    "start": "node dist/index.js",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@template/types": "workspace:*",
    "cors": "^2.8.5",
    "express": "^4.21.0",
    "helmet": "^8.0.0",
    "swagger-jsdoc": "^6.2.8",
    "swagger-ui-express": "^5.0.1",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@template/config-eslint": "workspace:*",
    "@template/config-ts": "workspace:*",
    "@types/cors": "^2.8.17",
    "@types/express": "^4.17.21",
    "@types/node": "^20.14.10",
    "@types/swagger-jsdoc": "^6.0.4",
    "@types/swagger-ui-express": "^4.1.6",
    "tsup": "^8.3.0",
    "tsx": "^4.19.0",
    "typescript": "^5.6.2"
  }
}
```

> **Why these scripts?** `dev` uses `tsx` for hot reload; `build` produces a `dist/` artifact via `tsup` (single bundle, fast); `start` runs the **built** artifact (production parity); `lint`/`typecheck` plug into Turbo's pipeline.

## 5. `tsconfig.json`

```json
{
  "extends": "@template/config-ts/node.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
```

The shared preset sets `module: NodeNext` and `moduleResolution: NodeNext`. **This means relative imports must use the `.js` extension** even when the source file is `.ts`:

```ts
// ✅ correct — refers to the emitted .js file
import { helloService } from './service.js';

// ❌ wrong — TS will reject under NodeNext
import { helloService } from './service';
```

`tsx` (dev) and `tsup` (build) both honor this. Don't fight it.

## 6. `eslint.config.mjs`

```js
import config from '@template/config-eslint/node.mjs';

export default config;
```

That's it. The shared preset gives you `@typescript-eslint`, `eslint-plugin-import` (with `import/order` + `import/no-cycle`), `eslint-plugin-unused-imports`, Prettier compatibility, and the **no-`.js`-files-in-`src/`** rule.

## 7. `tsup.config.ts`

```ts
import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm'],
  target: 'node20',
  outDir: 'dist',
  sourcemap: true,
  clean: true,
  dts: false,
  splitting: false,
  minify: false,
});
```

`tsup` produces `dist/index.js` from a single entry. Only the production path runs the bundled output — never `tsx` or `ts-node` in production (see [`docs/deployment.md`](./deployment.md)).

## 8. `src/index.ts` — server bootstrap

Keep this file tiny. It only owns process-level concerns: port binding, signal handlers.

```ts
import { app } from './app.js';

const PORT = Number(process.env.PORT ?? 3000);

const server = app.listen(PORT, () => {
  console.log(`API listening on http://localhost:${PORT}`);
  console.log(`Swagger docs at http://localhost:${PORT}/api/docs`);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down');
  server.close(() => process.exit(0));
});
```

## 9. `src/app.ts` — Express app

```ts
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import swaggerUi from 'swagger-ui-express';

import { swaggerSpec } from './config/swagger.js';
import { helloRoutes } from './features/hello/index.js';

export const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));

// Swagger docs UI — never inside /api/v1
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// All API routes mounted under /api/v1 — versioning is mandatory
app.use('/api/v1/hello', helloRoutes);

// 404 fallthrough
app.use((_req, res) => {
  res.status(404).json({
    error: { code: 'NOT_FOUND', message: 'Route not found' },
  });
});

// Error handler — keep this LAST
app.use(
  (err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error(err);
    res.status(500).json({
      error: { code: 'INTERNAL', message: 'Unexpected server error' },
    });
  },
);
```

> **API versioning rule.** Every route is mounted under `/api/v1/...`. There are **no unversioned routes**, ever. When you bump to v2, run v1 and v2 in parallel for the deprecation window — never break v1 in place.

## 10. `src/config/swagger.ts` — Swagger setup

```ts
import swaggerJsdoc from 'swagger-jsdoc';

export const swaggerSpec = swaggerJsdoc({
  definition: {
    openapi: '3.0.3',
    info: {
      title: '<app-name>',
      version: '1.0.0',
      description: 'API documentation for <app-name>',
    },
    servers: [{ url: '/api/v1', description: 'v1' }],
  },
  // Pick up @openapi JSDoc blocks from every feature's routes + schemas
  apis: ['./src/features/**/routes.ts', './src/features/**/schema.ts'],
});
```

> **Mandatory rule.** Every endpoint **must** carry an `@openapi` JSDoc block on its route handler. Reviewers reject PRs that add a route without one. Internal/admin routes are not exempt.

The Swagger UI is served at `/api/docs`. CI can also dump `swaggerSpec` to JSON for contract tests against the FE.

## 11. Reference feature: `hello`

This is the canonical feature. Copy this folder when creating a new feature, then rename and gut the contents.

### `src/features/hello/types.ts`

```ts
import type { User } from '@template/types';

export type HelloResponse = {
  greeting: string;
  user: User;
};
```

> **Shared types rule.** Domain types come from `@template/types`. **Never redefine `User`, `Order`, etc. locally** — even "just for now." If you need a feature-specific projection, use `Pick<User, ...>` or a wrapper type.

### `src/features/hello/schema.ts` — zod validation

```ts
import { z } from 'zod';

/**
 * @openapi
 * components:
 *   schemas:
 *     HelloRequest:
 *       type: object
 *       required: [name]
 *       properties:
 *         name:
 *           type: string
 *           minLength: 1
 *           example: "Ada"
 */
export const helloRequestSchema = z.object({
  name: z.string().min(1, 'name is required'),
});

export type HelloRequest = z.infer<typeof helloRequestSchema>;
```

> **Validation rule.** Every request body, query, or param that the client controls is parsed through a zod schema **before** the controller logic runs. No `req.body.name` access without `safeParse` first. Co-locate schemas in `schema.ts` so Swagger annotations and runtime validation stay in sync.

### `src/features/hello/service.ts` — business logic

```ts
import type { User } from '@template/types';

import type { HelloResponse } from './types.js';

export const helloService = {
  greet(name: string): HelloResponse {
    const user: User = {
      id: 'demo-user',
      email: `${name.toLowerCase()}@example.com`,
      createdAt: new Date(),
    };
    return {
      greeting: `Hello, ${name}!`,
      user,
    };
  },
};
```

Services are **pure logic** — no `req`, no `res`, no Express imports. Testable in isolation.

### `src/features/hello/controller.ts` — request handlers

```ts
import type { Request, Response } from 'express';

import { helloRequestSchema } from './schema.js';
import { helloService } from './service.js';

export const helloController = {
  ping(_req: Request, res: Response) {
    return res.status(200).json({ ok: true, ts: new Date().toISOString() });
  },

  greet(req: Request, res: Response) {
    const parsed = helloRequestSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid request body',
          details: parsed.error.flatten(),
        },
      });
    }
    const result = helloService.greet(parsed.data.name);
    return res.status(200).json(result);
  },
};
```

Controllers are **thin** — parse, call service, format response. No business logic.

### `src/features/hello/routes.ts` — routing + Swagger annotations

This is where the Swagger annotations live. **One `@openapi` block per route**, no exceptions.

```ts
import { Router } from 'express';

import { helloController } from './controller.js';

export const helloRoutes = Router();

/**
 * @openapi
 * /hello:
 *   get:
 *     summary: Health check for hello feature
 *     tags: [Hello]
 *     responses:
 *       '200':
 *         description: Service is up
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [ok, ts]
 *               properties:
 *                 ok: { type: boolean, example: true }
 *                 ts: { type: string, format: date-time }
 */
helloRoutes.get('/', helloController.ping);

/**
 * @openapi
 * /hello:
 *   post:
 *     summary: Greet a user by name
 *     tags: [Hello]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/HelloRequest'
 *     responses:
 *       '200':
 *         description: A greeting plus a demo user
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [greeting, user]
 *               properties:
 *                 greeting: { type: string, example: "Hello, Ada!" }
 *                 user:
 *                   type: object
 *                   required: [id, email, createdAt]
 *                   properties:
 *                     id:        { type: string, example: "demo-user" }
 *                     email:     { type: string, format: email }
 *                     createdAt: { type: string, format: date-time }
 *       '400':
 *         description: Validation failed
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: object
 *                   properties:
 *                     code:    { type: string, example: VALIDATION_ERROR }
 *                     message: { type: string }
 *                     details: { type: object }
 */
helloRoutes.post('/', helloController.greet);
```

### `src/features/hello/index.ts` — public surface

```ts
export { helloRoutes } from './routes.js';
export type { HelloResponse } from './types.js';
```

Other features (and `app.ts`) import only from `'./features/hello/index.js'` — never reach into `controller.ts`, `service.ts`, etc. directly. The barrel is the public API.

## 12. `apps/<app-name>/CLAUDE.md`

App-specific context. The repo's root [`CLAUDE.md`](../CLAUDE.md) covers cross-cutting standards; this file is owned by the app's devs and fills in service-specific details (database, auth flow, environment).

```md
# <app-name>

## Overview

## Architecture

## Feature module conventions

## API versioning and routing

## Swagger and API docs

## Validation (zod)

## Error handling

## Logging

## Database / external services

## Authentication

## Environment variables

## Testing

## Build and deploy

## Common tasks
```

Start with empty section bodies — fill them as the service grows. Empty headers are a forcing function.

## 13. `.env.example`

```bash
# Server
PORT=3000
NODE_ENV=development

# Add other expected vars here as the service grows.
# Never commit .env (root .gitignore covers it).
```

The actual `.env` stays untracked. CI loads its values from the platform's secret store, not from a file.

## 14. `apps/<app-name>/README.md`

```md
# <app-name>

Express + TypeScript backend service in the monorepo.

## Quickstart

```bash
pnpm install                         # from repo root
cp apps/<app-name>/.env.example apps/<app-name>/.env
pnpm --filter @<org>/<app-name> dev
```

Open <http://localhost:3000/api/docs> for Swagger UI.

## Scripts

| Command       | What it does                       |
| ------------- | ---------------------------------- |
| `pnpm dev`    | Hot-reload via `tsx watch`         |
| `pnpm build`  | Bundle to `dist/` via `tsup`       |
| `pnpm start`  | Run the built `dist/index.js`      |
| `pnpm lint`   | ESLint                             |
| `pnpm typecheck` | `tsc --noEmit`                  |

## Conventions

See the root [CLAUDE.md](../../CLAUDE.md) and [docs/generate-backend.md](../../docs/generate-backend.md). Don't deviate — the structure is enforced.
```

## 15. Verification

From the repo root:

```bash
# 1. Install — should detect the new workspace project
pnpm install

# 2. Run dev — should hot-reload
pnpm --filter @<org>/<app-name> dev
```

In another terminal:

```bash
# 3. Hit the GET endpoint
curl -s http://localhost:3000/api/v1/hello | jq .
# → { "ok": true, "ts": "2026-..." }

# 4. Hit the POST endpoint
curl -s -X POST http://localhost:3000/api/v1/hello \
  -H 'Content-Type: application/json' \
  -d '{"name":"Ada"}' | jq .
# → { "greeting": "Hello, Ada!", "user": { ... } }

# 5. Validation error path
curl -s -X POST http://localhost:3000/api/v1/hello \
  -H 'Content-Type: application/json' \
  -d '{}' | jq .
# → { "error": { "code": "VALIDATION_ERROR", ... } }
```

Then visit <http://localhost:3000/api/docs> — Swagger UI should render with the `Hello` tag, both routes, and the `HelloRequest` schema.

Finally, the full build/lint/typecheck sweep:

```bash
pnpm turbo build lint typecheck --filter=@<org>/<app-name>
```

All three tasks should pass. **If any fail, do not commit** — the conventions exist precisely to keep these green.

---

## Conventions cheat sheet

Pin this somewhere visible:

- ✅ Feature-based folder structure — **no `controllers/`, `services/`, `routes/` at app root**
- ✅ Coupling rule — keep code inside the feature until **2+ features** need it
- ✅ Every endpoint has `@openapi` JSDoc — **PRs without it fail review**
- ✅ Every request body / query / param goes through a **zod schema** before reaching the controller
- ✅ Domain types come from `@template/types` — **never redefine** `User`, `Order`, etc.
- ✅ All routes mounted under `/api/v1` — **no unversioned routes**
- ✅ Errors return `{ error: { code, message, details? } }` with the right HTTP status
- ✅ Production runs `dist/index.js` via PM2 — **never `tsx` or `ts-node`**
