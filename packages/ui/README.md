# @template/ui

Shared **shadcn/ui** component library for web apps in this monorepo. Source-only — apps' bundlers (Vite, Next, etc.) compile the `.tsx` directly. Tailwind classes inside the components are picked up by the consuming app's Tailwind scan.

## What's included

- **Components:** `Button`, `Input`, `Card`, `Dialog`, `Form`, `Label`, `Select`
- **Tailwind preset** with the design system's colors, radii, animations, and dark-mode wiring
- **CSS variables** (`src/styles.css`) for the slate base color palette
- **`cn` helper** (`@template/ui/lib/utils`) for conditional class merging

The component code lives in `src/components/ui/` and is **owned by this repo** — edit it directly when you need to change behavior or styling.

## Installation in a consuming app

```jsonc
// apps/web/package.json
{
  "dependencies": {
    "@template/ui": "workspace:*",
  },
  "devDependencies": {
    "tailwindcss": "^3.4.0",
  },
}
```

Then `pnpm install` from the repo root.

## 1. Wire up the Tailwind preset

In your app's `tailwind.config.ts`, extend the preset and tell Tailwind to scan both your own files **and** the UI package's components:

```ts
// apps/web/tailwind.config.ts
import type { Config } from 'tailwindcss';
import uiPreset from '@template/ui/tailwind.preset';

export default {
  presets: [uiPreset],
  content: ['./src/**/*.{ts,tsx}', '../../packages/ui/src/**/*.{ts,tsx}'],
} satisfies Config;
```

The relative `../../packages/ui/src/**/*.{ts,tsx}` path is critical — without it, Tailwind won't see the classes used inside the shared components and will tree-shake them out.

## 2. Import the base CSS

Once, in the app's entry stylesheet (e.g. `src/index.css` for Vite, `app/globals.css` for Next):

```css
@import '@template/ui/styles.css';
```

This provides the CSS variables (`--background`, `--primary`, etc.) and Tailwind base layers that the components reference.

## 3. Use components

```tsx
import { Button, Input, Card, CardContent, CardHeader, CardTitle } from '@template/ui';

export function LoginCard() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Sign in</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <Input type="email" placeholder="you@example.com" />
        <Button className="w-full">Continue</Button>
      </CardContent>
    </Card>
  );
}
```

## Adding a new shadcn component

This package is configured as a real shadcn project (see [components.json](./components.json)). To add a component:

```bash
cd packages/ui
pnpm dlx shadcn@latest add <component-name>
```

Examples:

```bash
pnpm dlx shadcn@latest add tabs
pnpm dlx shadcn@latest add dropdown-menu tooltip popover
```

The CLI will:

1. Fetch the component definition from the shadcn registry
2. Install any new Radix / runtime deps into `packages/ui/package.json`
3. Drop the source in `src/components/ui/<component>.tsx` using the `@template/ui/lib/utils` self-reference for the `cn` helper

After adding, **export the new component from [`src/index.ts`](./src/index.ts)** so apps can import it from `@template/ui`.

## Customizing components

Because shadcn ships source code, you customize by editing the component file directly. Want a different default variant for `Button`? Open [`src/components/ui/button.tsx`](./src/components/ui/button.tsx) and change the `cva` definition. Apps consume the change on next reload.

For repo-wide design tokens (colors, radii), edit:

- [`tailwind.preset.ts`](./tailwind.preset.ts) — Tailwind theme extensions
- [`src/styles.css`](./src/styles.css) — CSS variables for light + dark modes

Both flow through to every app via the preset and styles import.

## Build

```bash
pnpm turbo build --filter=@template/ui
```

There's no compile step — `build` runs `tsc --noEmit` to typecheck the whole component surface. Apps' bundlers handle the actual TSX → JS transformation when they import.

## Notes on the monorepo setup

- The package self-references its own name (`@template/ui/lib/utils`, `@template/ui/components/ui/label`) in internal imports. This works because pnpm symlinks the package into its own `node_modules`, and the `exports` map in `package.json` exposes the deep paths.
- `peerDependencies` declares `react`, `react-dom`, and `tailwindcss` — apps must provide these. They're also installed as `devDependencies` of this package so typecheck has types available.
- The `ui:add` script is just a shortcut for `pnpm dlx shadcn@latest add` from inside this directory.
