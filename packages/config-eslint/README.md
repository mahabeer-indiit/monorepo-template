# @template/config-eslint

Shared **ESLint 9 (flat config)** presets for the monorepo. Each preset is a complete `eslint.config.mjs`-style array — import it from your app and either re-export it directly or spread it to add overrides.

## Available presets

| Preset                                     | Use for                             | Built on                                  |
| ------------------------------------------ | ----------------------------------- | ----------------------------------------- |
| `@template/config-eslint/base.mjs`         | Generic TS/JS code, shared packages | `@eslint/js` + `typescript-eslint`        |
| `@template/config-eslint/react.mjs`        | React web apps                      | base + `react`, `react-hooks`, `jsx-a11y` |
| `@template/config-eslint/node.mjs`         | Node 20 backend services            | base + Node globals                       |
| `@template/config-eslint/react-native.mjs` | React Native / Expo apps            | base + `react`, `react-hooks`, RN globals |

All presets include:

- `@typescript-eslint` recommended rules
- `eslint-plugin-import` with `import/order` (sorted, alphabetized, grouped) and `import/no-cycle`
- `eslint-plugin-unused-imports` (auto-removable unused imports)
- `eslint-config-prettier` (turns off all formatting rules — Prettier owns formatting)
- A guard rule that **bans new `.js` / `.jsx` files inside any `src/` directory** — use TypeScript instead

## Installation

Add the workspace package as a dev dependency:

```jsonc
// apps/<app>/package.json
{
  "devDependencies": {
    "@template/config-eslint": "workspace:*",
    "eslint": "^9.0.0",
    "typescript": "^5.6.0",
  },
}
```

Then `pnpm install` from the repo root. Plugins (`@typescript-eslint`, `eslint-plugin-import`, etc.) are bundled as `dependencies` of this package, so consumers don't need to install them individually.

## Usage

Create `eslint.config.mjs` in your app and re-export the preset that matches its target.

### React web app

```js
// apps/web/eslint.config.mjs
import config from '@template/config-eslint/react.mjs';

export default config;
```

### Node backend

```js
// apps/api/eslint.config.mjs
import config from '@template/config-eslint/node.mjs';

export default config;
```

### React Native / Expo app

```js
// apps/mobile/eslint.config.mjs
import config from '@template/config-eslint/react-native.mjs';

export default config;
```

### Adding app-specific overrides

Spread the preset and append your own config blocks. ESLint flat config merges later blocks on top of earlier ones.

```js
// apps/web/eslint.config.mjs
import config from '@template/config-eslint/react.mjs';

export default [
  ...config,
  {
    files: ['**/*.test.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },
  {
    ignores: ['src/generated/**'],
  },
];
```

## Run lint

Wire it into your app's `package.json`:

```json
{
  "scripts": {
    "lint": "eslint . --max-warnings=0",
    "lint:fix": "eslint . --fix"
  }
}
```

Then from the repo root, `pnpm turbo run lint` will fan out across every workspace package.

## The `no .js in src/` rule

The base preset includes:

```js
{
  files: ['**/src/**/*.{js,jsx,cjs,mjs}'],
  rules: {
    'no-restricted-syntax': ['error', {
      selector: 'Program',
      message: 'JavaScript files are not allowed in src/. Use TypeScript (.ts / .tsx) instead.',
    }],
  },
}
```

It uses a file-pattern restriction scoped to `src/` so config files at the project root (e.g. `vite.config.js`, `tailwind.config.js`, `metro.config.js`) are unaffected. The `Program` selector matches the entire source file, so the error fires exactly once per offending `.js` file with a clear message pointing to the fix.

If you genuinely need to allow a single legacy `.js` file in `src/`, override it locally:

```js
{
  files: ['src/legacy/old-thing.js'],
  rules: { 'no-restricted-syntax': 'off' },
}
```
