# @template/types

The single source of truth for **end-to-end domain types** in this monorepo.

## Ownership and direction of flow

- **Backend owns this package.** When the API's data model changes, the change lands here first. Server code (controllers, validators, ORM mappers) is then updated to satisfy the new contract.
- **Frontend and mobile import from here.** Web (`apps/web`) and React Native (`apps/mobile`) consume these types so their request/response shapes, props, and state never drift from what the API actually returns.
- **Direction is one-way: server → clients.** Clients never define their own copies of domain types; they always import from `@template/types`.

## Why this exists

In a fullstack repo, the same `User` ends up redefined three times — once in the API, once on the web client, once in the mobile app. Each copy starts identical, then drifts:

- API renames `created_at` to `createdAt`. Web app silently keeps reading `created_at` and shows `Invalid Date`.
- A field becomes nullable. Mobile typechecks because mobile's local copy still says non-null.
- A new `role` field is added. Nobody on the client side notices until QA finds the missing UI.

By forcing all three to import from a single package, **adding or changing a field becomes a single PR** that flushes type errors out of every consumer simultaneously. You can't merge the API change without also fixing the web and mobile call sites.

## Installation

Add the workspace package to any consumer that needs domain types:

```jsonc
// apps/web/package.json (and apps/mobile, apps/api, ...)
{
  "dependencies": {
    "@template/types": "workspace:*",
  },
}
```

Then `pnpm install` from the repo root.

## Usage

```ts
import type { User } from '@template/types';

function greet(user: User): string {
  return `Hello, ${user.email}`;
}
```

If types are split across multiple files (e.g. `src/user.ts`, `src/order.ts`), the `./*` exports pattern lets consumers cherry-pick:

```ts
import type { User } from '@template/types/user';
```

## Build

```bash
pnpm turbo build --filter=@template/types
```

Emits `dist/index.js` + `dist/index.d.ts` (with declaration maps) so editor "Go to Definition" jumps back to the source `.ts` files.

## Conventions for adding types

- Prefer `type` aliases over `interface` unless you need declaration merging.
- Keep types pure — **no runtime code**. Validators (Zod schemas, etc.) belong in a separate `@template/schemas` package, not here.
- Use ISO-8601 strings (`string`) for dates over the wire and `Date` only after deserialization. Document which is which in the field name or a JSDoc comment when ambiguous.
- One concept per file once the package grows past a single `index.ts`. Re-export everything from `index.ts`.
