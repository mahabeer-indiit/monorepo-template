# @template/config-ts

Shared TypeScript configurations for apps and packages in this monorepo. Each preset extends the root [`tsconfig.base.json`](../../tsconfig.base.json) and layers target-specific options on top.

## Available configs

| File                | Extend from                             | Use for                                              |
| ------------------- | --------------------------------------- | ---------------------------------------------------- |
| `base.json`         | `@template/config-ts/base.json`         | Generic libraries, shared packages, anything neutral |
| `react.json`        | `@template/config-ts/react.json`        | React web apps and component libraries (DOM + JSX)   |
| `node.json`         | `@template/config-ts/node.json`         | Backend services / Node 20 packages (`NodeNext`)     |
| `react-native.json` | `@template/config-ts/react-native.json` | React Native / Expo apps (no DOM, RN types)          |

## Installation

Add the workspace package as a dev dependency:

```jsonc
// apps/<app>/package.json
{
  "devDependencies": {
    "@template/config-ts": "workspace:*",
  },
}
```

Then `pnpm install` from the repo root.

## Usage

Reference the preset from your app's `tsconfig.json` via the `extends` field. Override `include`, `outDir`, and any project-specific paths locally — leave compiler defaults to the preset.

### React web app

```jsonc
{
  "extends": "@template/config-ts/react.json",
  "include": ["src"],
  "compilerOptions": {
    "outDir": "dist",
  },
}
```

### Node backend

```jsonc
{
  "extends": "@template/config-ts/node.json",
  "include": ["src"],
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src",
  },
}
```

### React Native / Expo app

```jsonc
{
  "extends": "@template/config-ts/react-native.json",
  "include": ["app", "src", "App.tsx"],
}
```

### Shared package (library)

```jsonc
{
  "extends": "@template/config-ts/base.json",
  "include": ["src"],
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src",
  },
}
```

## Notes

- All presets inherit `strict`, `noUncheckedIndexedAccess`, and `noImplicitOverride` from the root base config.
- The `react.json` and `react-native.json` presets set `noEmit: true` because the bundler (Vite, Next, Metro, etc.) handles emit; TypeScript only typechecks.
- The `node.json` preset emits to `dist/` using `NodeNext` so packages can ship dual ESM/CJS output by setting `"type": "module"` (or not) in their own `package.json`.
- Override anything you need at the app level — these are starting points, not laws.
