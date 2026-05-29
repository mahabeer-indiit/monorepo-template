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

| Where                  | Form                 | Example                       |
| ---------------------- | -------------------- | ----------------------------- |
| Folder                 | kebab-case           | `apps/user-api`               |
| `package.json#name`    | `@<org>/<name>`      | `@template/user-api`          |
| `pnpm --filter` target | matches package name | `--filter @template/user-api` |

Pick a name that says **what the service owns**, not its tech: `user-api`, `billing-api`, `notifications-api` — not `node-server`, `backend2`.

For the rest of this guide, replace `<app-name>` with your name and `<org>` with your scope (use `template` if you don't have one yet).

## 3. Create the folder structure

```bash
mkdir -p apps/<app-name>/{scripts,src/{config,lib,features/hello}}
cd apps/<app-name>
```

The full layout you'll end up with:

```
apps/<app-name>/
├── .env.example
├── .gitignore                ← gitignores src/generated/
├── CLAUDE.md
├── README.md
├── eslint.config.mjs
├── package.json
├── tsconfig.json
├── tsup.config.ts
├── scripts/
│   └── generate-swagger.ts   ← runs at build time → src/generated/swagger.json
└── src/
    ├── index.ts              ← server bootstrap (env + logger + listen)
    ├── app.ts                ← Express app: middleware + route mounts
    ├── config/
    │   ├── env.ts            ← zod-validated process.env, exits on bad config
    │   └── swagger.ts        ← imports the pre-generated swagger.json
    ├── generated/            ← gitignored; produced by `pnpm gen:swagger`
    │   └── swagger.json
    ├── lib/
    │   └── logger.ts         ← pino — pretty in dev, JSON in prod
    └── features/
        └── hello/            ← one folder per feature, never shared/
            ├── controller.ts
            ├── service.ts
            ├── routes.ts
            ├── schema.ts     ← zod request validation
            ├── types.ts
            └── index.ts      ← public exports for this feature
```

> **Convention — feature-based structure (mandatory).** No top-level `src/controllers/`, `src/services/`, `src/routes/`. Everything lives under `src/features/<name>/`. Cross-cutting infra (env loader, swagger glue, db client) lives in `src/config/` or `src/lib/` — never `src/shared/`.

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
    "dev": "pnpm gen:swagger && tsx watch src/index.ts",
    "build": "pnpm gen:swagger && tsup",
    "start": "node dist/index.js",
    "gen:swagger": "tsx scripts/generate-swagger.ts",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^4.21.0",
    "express-async-errors": "^3.1.1",
    "helmet": "^8.0.0",
    "pino": "^9.5.0",
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
    "pino-pretty": "^11.3.0",
    "tsup": "^8.3.0",
    "tsx": "^4.19.0",
    "typescript": "^5.6.2"
  }
}
```

> **Why these scripts?**
>
> - `gen:swagger` runs the build-time scanner (step 10) and writes `src/generated/swagger.json`.
> - `dev` runs it once, then hot-reloads via `tsx watch`. Editing `routes.ts` annotations does **not** auto-regenerate the JSON — re-run `pnpm gen:swagger` (or restart `dev`) to see the changes in `/api/docs`.
> - `build` produces a `dist/` artifact via `tsup` (single bundle, fast). The Swagger JSON is generated **before** bundling so it's available in production with no source files on disk.
> - `start` runs the **built** artifact (production parity); never `tsx` or `ts-node` in production.

## 5. Run `pnpm install`

```bash
# from repo root
pnpm install
```

This links the workspace deps (`@template/config-ts`, `@template/config-eslint`) and downloads everything else.

> **🔁 Anytime you change `package.json`** — adding a dep, bumping a version, renaming a script — run `pnpm install` from the repo root again. The workspace state needs to reflect the manifest before any other command will work.

## 6. `tsconfig.json`

```json
{
  "extends": "@template/config-ts/node.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src", "scripts"]
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

## 7. `eslint.config.mjs`

```js
import config from '@template/config-eslint/node.mjs';

export default config;
```

That's it. The shared preset gives you `@typescript-eslint`, `eslint-plugin-import` (with `import/order` + `import/no-cycle`), `eslint-plugin-unused-imports`, Prettier compatibility, and the **no-`.js`-files-in-`src/`** rule.

## 8. `tsup.config.ts`

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

`tsup` produces `dist/index.js` from a single entry. JSON imports (like the generated Swagger spec) are inlined automatically.

## 9. `apps/<app-name>/.gitignore`

```gitignore
# Build output
dist/

# Generated at build time — see scripts/generate-swagger.ts
src/generated/

# TypeScript incremental
*.tsbuildinfo
```

`src/generated/` is **never** committed — it's a build artifact derived from the source annotations. Anyone running `pnpm gen:swagger` or `pnpm build` reproduces it from scratch.

## 10. `scripts/generate-swagger.ts` — build-time spec generator

Globbing source files at runtime breaks in production (the `.ts` files don't exist after `tsup` bundles to `dist/index.js`). Instead, scan the sources at **build time** and emit a static JSON file.

```ts
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import swaggerJsdoc from 'swagger-jsdoc';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');

const spec = swaggerJsdoc({
  definition: {
    openapi: '3.0.3',
    info: {
      title: '<app-name>',
      version: '1.0.0',
      description: 'API documentation for <app-name>',
    },
    servers: [{ url: '/api/v1', description: 'v1' }],
  },
  apis: [
    path.resolve(projectRoot, 'src/features/**/routes.ts'),
    path.resolve(projectRoot, 'src/features/**/schema.ts'),
  ],
});

const outDir = path.resolve(projectRoot, 'src/generated');
mkdirSync(outDir, { recursive: true });

const outPath = path.resolve(outDir, 'swagger.json');
writeFileSync(outPath, `${JSON.stringify(spec, null, 2)}\n`);

console.log(`✓ Swagger spec written to ${path.relative(projectRoot, outPath)}`);
```

Test it:

```bash
pnpm gen:swagger
# → ✓ Swagger spec written to src/generated/swagger.json
```

The first run will fail until step 16 creates the `routes.ts` and `schema.ts` files for the `hello` feature. That's expected — the script just needs the globs to match something. Re-run after step 16.

## 11. `src/config/env.ts` — validated environment

Boot fails fast with a clear error if any required env var is missing or malformed. Other modules import the typed `env` object instead of touching `process.env` directly.

```ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),

  // Comma-separated allowlist of origins permitted to call this API.
  // Examples: "http://localhost:5173" or "https://app.example.com,https://admin.example.com"
  // Use "*" for any origin — DEVELOPMENT ONLY, never in production.
  CORS_ORIGINS: z
    .string()
    .default('http://localhost:5173')
    .transform((s) =>
      s
        .split(',')
        .map((origin) => origin.trim())
        .filter(Boolean),
    ),

  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('❌ Invalid environment variables:');
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
export type Env = typeof env;
```

> **Env validation rule.** Never read `process.env.X` directly outside this file. Always go through the typed `env` object. Adding a new var means adding it to the schema **first** — that's the only way it stays type-safe and validated.

## 12. `src/lib/logger.ts` — pino logger

```ts
import pino from 'pino';

import { env } from '../config/env.js';

export const logger = pino({
  level: env.LOG_LEVEL,
  // Pretty output in dev only. In prod we want JSON for log aggregators.
  ...(env.NODE_ENV === 'development' && {
    transport: {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'HH:MM:ss.l',
        ignore: 'pid,hostname',
      },
    },
  }),
});
```

> **Logging rule.** Use `logger.info` / `logger.warn` / `logger.error` throughout the app. **No `console.log` in committed code** — logger gives you levels, structured fields, request correlation IDs (when you wire them later), and JSON output for prod aggregators. The only exception is `src/config/env.ts`, which has to use `console.error` because the logger isn't loaded yet.

## 13. `src/index.ts` — server bootstrap

Keep this file tiny. It only owns process-level concerns: port binding, signal handlers.

```ts
import { app } from './app.js';
import { env } from './config/env.js';
import { logger } from './lib/logger.js';

const server = app.listen(env.PORT, () => {
  logger.info(`API listening on http://localhost:${env.PORT}`);
  logger.info(`Swagger docs at http://localhost:${env.PORT}/api/docs`);
});

const shutdown = (signal: string) => () => {
  logger.info({ signal }, 'shutdown signal received');
  server.close(() => process.exit(0));
};

process.on('SIGTERM', shutdown('SIGTERM'));
process.on('SIGINT', shutdown('SIGINT'));
```

## 14. `src/app.ts` — Express app

```ts
// Patches Express to forward async errors to the error middleware automatically.
// MUST be imported before any router that contains async handlers.
import 'express-async-errors';

import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import swaggerUi from 'swagger-ui-express';

import { env } from './config/env.js';
import { swaggerSpec } from './config/swagger.js';
import { helloRoutes } from './features/hello/index.js';
import { logger } from './lib/logger.js';

export const app = express();

app.use(helmet());

// CORS allowlist — origin function rejects anything not in CORS_ORIGINS.
app.use(
  cors({
    origin: (origin, callback) => {
      // No origin header → same-origin or non-browser caller (curl, server-to-server). Allow.
      if (!origin) return callback(null, true);
      if (env.CORS_ORIGINS.includes('*')) return callback(null, true);
      if (env.CORS_ORIGINS.includes(origin)) return callback(null, true);
      return callback(new Error(`CORS: origin ${origin} not allowed`));
    },
    credentials: true,
  }),
);

app.use(express.json({ limit: '1mb' }));

// Swagger docs UI — never inside /api/v1
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// All API routes mounted under /api/v1 — versioning is mandatory
app.use('/api/v1/hello', helloRoutes);

// 404 fallthrough — keep above the error handler
app.use((_req, res) => {
  res.status(404).json({
    error: { code: 'NOT_FOUND', message: 'Route not found' },
  });
});

// Error handler — keep this LAST. With `express-async-errors` imported above,
// promise rejections inside async route handlers reach this middleware automatically.
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error({ err }, 'unhandled request error');

  // CORS rejection from the origin function above — translate to a 403.
  if (err.message?.startsWith('CORS:')) {
    return res.status(403).json({
      error: { code: 'CORS_FORBIDDEN', message: err.message },
    });
  }

  return res.status(500).json({
    error: { code: 'INTERNAL', message: 'Unexpected server error' },
  });
});
```

> **API versioning rule.** Every route is mounted under `/api/v1/...`. There are **no unversioned routes**, ever. When you bump to v2, run v1 and v2 in parallel for the deprecation window — never break v1 in place.

> **CORS rule.** `CORS_ORIGINS` in `.env` is the allowlist. Add your frontend's URL there (e.g., `http://localhost:5173` for the Vite dev server, the production CDN URL for prod). **Never ship `*` to production.**

## 15. `src/config/swagger.ts` — load the generated spec

```ts
import swagger from '../generated/swagger.json' with { type: 'json' };

export const swaggerSpec = swagger;
```

That's the entire file. The heavy lifting happened in `scripts/generate-swagger.ts` at build time. At runtime, this is a static JSON import — no glob, no I/O, no race with bundling.

> **Mandatory rule.** Every endpoint **must** carry an `@openapi` JSDoc block on its route handler or schema. Reviewers reject PRs that add a route without one. Internal/admin routes are not exempt. The build-time scan picks up every `@openapi` block in `src/features/**/{routes,schema}.ts`.

## 16. Reference feature: `hello`

This is the canonical feature. Copy this folder when creating a new feature, then rename and gut the contents.

### `src/features/hello/types.ts`

```ts
export type User = {
  id: string;
  email: string;
  createdAt: Date;
};

export type HelloResponse = {
  greeting: string;
  user: User;
};
```

> **Shared types rule.** This service **owns** its domain types. Define them in the feature (or a local `src/types/` module). **The moment a type must be shared with the web/mobile apps, lift it into a `packages/types` workspace package — created on demand — that the backend owns and the clients import.** Don't let two apps maintain their own copies; one owner, everyone else imports.

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
import type { HelloResponse, User } from './types.js';

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

> **Async handlers.** When the service or controller becomes async (e.g., a DB call), just write `async (req, res) => { ... }`. Thanks to `express-async-errors` (imported once in `src/app.ts`), thrown errors and rejected promises are forwarded to the error middleware automatically — no per-route `try/catch` boilerplate, no `next(err)` plumbing.

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

## 17. `apps/<app-name>/CLAUDE.md`

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

## 18. `.env.example`

```bash
# Server
PORT=3000
NODE_ENV=development
LOG_LEVEL=info

# CORS — comma-separated list of origins permitted to call this API.
# Add your frontend's URL here (e.g., http://localhost:5173 for the Vite dev server,
# https://app.example.com for prod). Use "*" for any origin — DEV ONLY.
CORS_ORIGINS=http://localhost:5173

# Add other expected vars here as the service grows. Mirror them in src/config/env.ts.
# Never commit .env (root .gitignore covers it).
```

The actual `.env` stays untracked. CI loads its values from the platform's secret store, not from a file.

## 19. `apps/<app-name>/README.md`

````md
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

| Command            | What it does                                             |
| ------------------ | -------------------------------------------------------- |
| `pnpm dev`         | `gen:swagger` + `tsx watch` (hot reload)                 |
| `pnpm build`       | `gen:swagger` + `tsup` → `dist/`                         |
| `pnpm start`       | Run the built `dist/index.js`                            |
| `pnpm gen:swagger` | Regenerate `src/generated/swagger.json` from annotations |
| `pnpm lint`        | ESLint                                                   |
| `pnpm typecheck`   | `tsc --noEmit`                                           |

## Conventions

See the root [CLAUDE.md](../../CLAUDE.md) and [docs/generate-backend.md](../../docs/generate-backend.md). Don't deviate — the structure is enforced.
````

## 20. Verification

From the repo root:

```bash
# 1. Install — should detect the new workspace project
pnpm install

# 2. Run dev — should generate swagger.json then hot-reload
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

Verify the **production path** also works:

```bash
pnpm --filter @<org>/<app-name> build
pnpm --filter @<org>/<app-name> start
# in another terminal — Swagger UI should still render at /api/docs
curl -s http://localhost:3000/api/docs/swagger.json | jq '.info.title'
# → "<app-name>"
```

This proves the Swagger spec made it into the bundle (no source-file glob at runtime).

Finally, the full sweep:

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
- ✅ Swagger spec is **generated at build time** to `src/generated/swagger.json` (gitignored). No runtime globbing.
- ✅ Every request body / query / param goes through a **zod schema** before reaching the controller
- ✅ All env vars validated by the zod schema in **`src/config/env.ts`** — never read `process.env` directly elsewhere
- ✅ `import 'express-async-errors';` at the top of `src/app.ts` — async handler rejections reach the error middleware automatically
- ✅ `CORS_ORIGINS` is an allowlist — **never ship `*` to production**
- ✅ Use **`logger.info` / `logger.warn` / `logger.error`** — no `console.log` in committed code
- ✅ Backend **owns** domain types — define locally, then lift to a `packages/types` package (created on demand) once shared with clients
- ✅ All routes mounted under `/api/v1` — **no unversioned routes**
- ✅ Errors return `{ error: { code, message, details? } }` with the right HTTP status
- ✅ Production runs `dist/index.js` via PM2 — **never `tsx` or `ts-node`**
