# Generate a mobile app

This guide walks through creating a new Expo + React Native + TypeScript mobile app inside this monorepo. Follow it top-to-bottom and you (or Claude Code) will end up with a working, conventions-compliant mobile app that loads in Expo Go.

> **Read this in full before starting.** Mobile has more setup gotchas than web — Metro's monorepo quirks, pnpm's symlink layout, and Firebase's per-app native config all trip up first-time setup.

## 1. Prerequisites

Run all commands from the **repo root**.

- **Node 20** — `node --version` should print `v20.x` (use `nvm use`)
- **pnpm 9** — `pnpm --version` should print `9.x`
- A clean working tree

For testing the app:

- **Easiest path — Expo Go** on your phone (iOS App Store / Google Play). No Xcode or Android Studio needed.
- **Native builds** — required if you add modules with native code (Firebase, camera, push). Then you also need:
  - macOS + Xcode 15+ for iOS
  - Android Studio with an emulator for Android

For the **template app** in this guide, **Expo Go is sufficient** — we don't import any native modules until the dev moves to a dev-client build (covered later).

## 2. Decide the app name

Use **kebab-case**. The name shows up in three places:

| Where                  | Form                         | Example                  |
| ---------------------- | ---------------------------- | ------------------------ |
| Folder                 | kebab-case                   | `apps/customer-app`      |
| `package.json#name`    | `@<org>/<name>`              | `@template/customer-app` |
| Expo `app.json#slug`   | kebab-case (no scope)        | `customer-app`           |

For the rest of this guide, replace `<app-name>` with your name and `<org>` with your scope (use `template` if you don't have one yet).

## 3. Bootstrap with Expo

```bash
cd apps
pnpm create expo <app-name> --template blank-typescript
cd <app-name>
```

This produces a minimal Expo + TS app with `App.tsx`, `app.json`, `tsconfig.json`, and `package.json`. We're going to keep the structure but rewire several files.

## 4. CRITICAL: Metro monorepo configuration

> **This is the step everyone gets wrong.** Metro (the React Native bundler) doesn't understand monorepos out of the box. By default it only watches the app's directory and only resolves `node_modules` from there — so workspace packages like `@template/types` are invisible to it. Without this config, you'll get cryptic "module not found" errors at runtime.

Create `apps/<app-name>/metro.config.js` (the file does **not** exist yet — Expo's blank template has no Metro config):

```js
// Learn more: https://docs.expo.dev/guides/monorepos/
const { getDefaultConfig } = require('expo/metro-config');
const path = require('node:path');

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, '../..');

const config = getDefaultConfig(projectRoot);

// 1. Watch the entire monorepo, so HMR picks up edits in workspace packages
config.watchFolders = [workspaceRoot];

// 2. Tell Metro exactly where to look up node_modules — in this order
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(workspaceRoot, 'node_modules'),
];

// 3. Disable Node's hierarchical resolution; we declared the lookup paths above
config.resolver.disableHierarchicalLookup = true;

// 4. pnpm uses symlinks heavily — let Metro follow them
config.resolver.unstable_enableSymlinks = true;
config.resolver.unstable_enablePackageExports = true;

module.exports = config;
```

### What each line does

- **`watchFolders: [workspaceRoot]`** — by default Metro only watches `apps/<app-name>/`. With workspaces, edits to `packages/types/src/index.ts` need to trigger HMR in the mobile app. This line broadcasts the watch up to the repo root.
- **`nodeModulesPaths: [...]`** — Metro's default module resolver does its own walk-up of the filesystem, but with pnpm's isolated installs and disabled hierarchical lookup, we have to be explicit: look in **this app's** `node_modules` first (where pnpm symlinks workspace packages), then in the **workspace root's** `node_modules` (where hoisted deps live).
- **`disableHierarchicalLookup: true`** — without this, Metro can pick up packages from arbitrary parent directories, leading to **duplicate React** errors that crash the app on startup. We've already declared the canonical paths above; turn off the fallback walk.
- **`unstable_enableSymlinks: true`** — pnpm installs every dep as a symlink. Older Metro versions wouldn't follow symlinks; newer Metro can but only when this flag is set.
- **`unstable_enablePackageExports: true`** — required for some workspace packages (like `@template/ui`) that use the `exports` field in `package.json` for deep imports. Without it, `import { cn } from '@template/ui/lib/utils'` fails.

### When this config is wrong

Symptoms and fixes:

| Symptom                                                              | Likely cause                                              |
| -------------------------------------------------------------------- | --------------------------------------------------------- |
| `Unable to resolve module @template/types`                           | Missed `nodeModulesPaths` — Metro can't see hoisted deps  |
| `Invariant Violation: Module AppRegistry is not a registered ...`    | Duplicate React — drop `disableHierarchicalLookup` flag   |
| HMR doesn't fire when editing a workspace package                    | `watchFolders` not set, or didn't include `workspaceRoot` |
| `Unable to resolve "@template/ui/lib/utils"`                         | Missed `unstable_enablePackageExports`                    |
| Package resolves at type-time but crashes at runtime                 | Missed `unstable_enableSymlinks`                          |

## 5. Update `package.json`

Overwrite the bootstrap-generated `package.json` with:

```json
{
  "name": "@<org>/<app-name>",
  "version": "0.0.0",
  "private": true,
  "main": "expo/AppEntry",
  "description": "<one-line purpose of this app>",
  "scripts": {
    "start": "expo start",
    "android": "expo start --android",
    "ios": "expo start --ios",
    "web": "expo start --web",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@react-native-firebase/analytics": "^21.0.0",
    "@react-native-firebase/app": "^21.0.0",
    "@react-native-firebase/crashlytics": "^21.0.0",
    "@react-navigation/native": "^6.1.18",
    "@react-navigation/native-stack": "^6.11.0",
    "@template/types": "workspace:*",
    "expo": "~52.0.0",
    "expo-status-bar": "~2.0.0",
    "react": "18.3.1",
    "react-native": "0.76.0",
    "react-native-safe-area-context": "4.12.0",
    "react-native-screens": "~4.4.0"
  },
  "devDependencies": {
    "@babel/core": "^7.25.0",
    "@template/config-eslint": "workspace:*",
    "@template/config-ts": "workspace:*",
    "@types/react": "~18.3.12",
    "eslint": "^9.0.0",
    "typescript": "^5.6.2"
  }
}
```

> **About the React version:** mobile is pinned to **React 18** for now — React Native's stable line still tracks 18.x. Don't bump to React 19 in mobile until the RN team officially supports it; that mismatch is what `pnpm.overrides` at the root manages.

> **About Firebase deps:** the three `@react-native-firebase/*` packages are installed but **not imported** in the template feature. They contain native code that Expo Go does **not** bundle, so importing them in code that runs under Expo Go would crash. The deps live in `package.json` so the surface is ready when you move to a dev-client build (see [README's Firebase setup](#11-readme-and-firebase-setup) below). Don't `import '@react-native-firebase/app'` in the template feature.

## 6. Replace `tsconfig.json`

```json
{
  "extends": "@template/config-ts/react-native.json",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src", "App.tsx", "metro.config.js", "babel.config.js"]
}
```

The `@/*` path lets you write `import { HelloScreen } from '@/features/hello'` instead of relative paths.

## 7. Add `eslint.config.mjs`

Create the file (Expo's blank template doesn't ship one):

```js
import config from '@template/config-eslint/react-native.mjs';

export default config;
```

The shared preset gives you `@typescript-eslint`, React + React Hooks rules, RN globals (`__DEV__`, `fetch`, etc.), `eslint-plugin-import`, `eslint-plugin-unused-imports`, Prettier compatibility, and the **no-`.js`-files-in-`src/`** rule.

## 8. Folder structure

The full layout you'll end up with:

```
apps/<app-name>/
├── App.tsx                  ← entry: providers + root navigator
├── CLAUDE.md
├── README.md
├── app.json                 ← Expo config (name, slug, bundle ids)
├── babel.config.js          ← from Expo bootstrap
├── eslint.config.mjs
├── metro.config.js          ← monorepo wiring (step 4)
├── package.json
├── tsconfig.json
└── src/
    ├── lib/
    │   └── api-client.ts    ← fetch wrapper for the backend
    ├── navigation/
    │   └── RootNavigator.tsx
    └── features/
        └── hello/           ← one folder per feature, never shared/
            ├── components/  feature-scoped UI
            ├── api/         backend calls (REST or React Query if added)
            ├── types/
            ├── hooks/       custom hooks
            ├── screens/     route-level screens (NOT pages/)
            └── index.ts     public surface
```

> **Convention — feature-based structure (mandatory).** No top-level `src/components/`, `src/screens/`, `src/api/`. Everything lives under `src/features/<name>/` or `src/lib/` (for cross-cutting infra) or `src/navigation/` (for the root navigator).

> **Mobile uses `screens/`, not `pages/`.** Same intent — route-level components — but the platform vocabulary differs. Don't mix the two terms in the same app.

> **Coupling rule.** Code stays inside its feature folder until **2+ features** need it. App-internal helpers go to `src/lib/`; cross-app code goes to a new `packages/<name>` workspace. Don't preemptively share.

Create the directories:

```bash
mkdir -p src/lib src/navigation src/features/hello/{components,api,types,hooks,screens}
```

## 9. `src/lib/api-client.ts`

A single typed `fetch` wrapper. Every backend call goes through this — no `fetch()` directly in screens or hooks.

```ts
const BASE_URL = process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000/api/v1';

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

type RequestOptions = {
  method?: Method;
  body?: unknown;
  headers?: Record<string, string>;
  signal?: AbortSignal;
};

export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', body, headers = {}, signal } = options;

  const response = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
    signal,
  });

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`API ${method} ${path} failed: ${response.status} ${text}`);
  }

  return (await response.json()) as T;
}
```

`EXPO_PUBLIC_*` env vars are exposed to the client bundle. Anything not prefixed stays server-only.

## 10. `src/navigation/RootNavigator.tsx`

```tsx
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

import { HelloScreen } from '@/features/hello';

export type RootStackParamList = {
  Hello: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen name="Hello" component={HelloScreen} options={{ title: '<app-name>' }} />
        {/* Add one screen per feature page. Screens live in features/<x>/screens/. */}
      </Stack.Navigator>
    </NavigationContainer>
  );
}
```

`RootStackParamList` is the typed registry of routes — every screen pushed onto the stack must be listed here. This makes `navigation.navigate('Hello')` typecheck.

## 11. `App.tsx`

Replace the bootstrap-generated `App.tsx` entirely:

```tsx
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { RootNavigator } from '@/navigation/RootNavigator';

export default function App() {
  return (
    <SafeAreaProvider>
      <StatusBar style="auto" />
      <RootNavigator />
    </SafeAreaProvider>
  );
}
```

Keep `App.tsx` thin. It only sets up providers (safe area, status bar, query client when you add one, error boundary, etc.) and renders the root navigator. **No business logic, no routes, no styling.**

## 12. Reference feature: `hello`

This is the canonical feature. Copy this folder when creating a new feature, then rename and gut the contents.

The reference shows: a screen typed against `User` from `@template/types`, styled with `StyleSheet`, structured into components/types/screens.

### `src/features/hello/types/hello-state.ts`

```ts
import type { User } from '@template/types';

export type HelloState = {
  user: User;
  greeting: string;
};
```

> **Shared types rule.** Domain types come from `@template/types`. **Never redefine `User`, `Order`, etc. locally.** If you need a feature-specific projection, use `Pick<User, ...>` or a wrapper type (as `HelloState` does above).

### `src/features/hello/components/UserCard.tsx`

```tsx
import { StyleSheet, Text, View } from 'react-native';

import type { User } from '@template/types';

type UserCardProps = {
  user: User;
};

export function UserCard({ user }: UserCardProps) {
  return (
    <View style={styles.card}>
      <Text style={styles.label}>User</Text>
      <Text style={styles.email}>{user.email}</Text>
      <Text style={styles.id}>id: {user.id}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    padding: 16,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#e5e4e7',
    gap: 4,
  },
  label: {
    fontSize: 12,
    fontWeight: '600',
    color: '#6b6375',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  email: {
    fontSize: 16,
    fontWeight: '500',
  },
  id: {
    fontSize: 12,
    color: '#6b6375',
    fontFamily: 'Menlo',
  },
});
```

> **Styling rule.** Use **`StyleSheet.create()`** for styles. **No inline `style={{ ... }}` literals**, no third-party styling libs. The decision on whether to adopt NativeWind (Tailwind for RN) is a Week-N decision — until then, plain StyleSheet is the only sanctioned option. Co-locate styles at the bottom of the component file.

### `src/features/hello/screens/HelloScreen.tsx`

```tsx
import { useState } from 'react';
import { Button, ScrollView, StyleSheet, Text, View } from 'react-native';

import type { User } from '@template/types';

import { UserCard } from '../components/UserCard';
import type { HelloState } from '../types/hello-state';

const DEMO_USER: User = {
  id: 'demo-user',
  email: 'hello@example.com',
  createdAt: new Date(),
};

export function HelloScreen() {
  const [state, setState] = useState<HelloState>({
    user: DEMO_USER,
    greeting: 'Hello, Mobile!',
  });

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{state.greeting}</Text>
      <Text style={styles.subtitle}>End-to-end wiring: @template/types in a feature module.</Text>

      <UserCard user={state.user} />

      <View style={styles.action}>
        <Button
          title="Refresh greeting"
          onPress={() =>
            setState((s) => ({ ...s, greeting: `Hello again at ${new Date().toLocaleTimeString()}` }))
          }
        />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 24,
    gap: 24,
    flexGrow: 1,
    justifyContent: 'center',
  },
  title: {
    fontSize: 32,
    fontWeight: '600',
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 14,
    color: '#6b6375',
    textAlign: 'center',
  },
  action: {
    alignSelf: 'stretch',
  },
});
```

### `src/features/hello/index.ts` — public surface

```ts
export { HelloScreen } from './screens/HelloScreen';
export type { HelloState } from './types/hello-state';
```

Other features (and the navigator) import only from `'@/features/hello'` — never reach into `components/`, `screens/`, etc. directly. The barrel is the public API.

## 13. `apps/<app-name>/CLAUDE.md`

App-specific context. The repo's root [`CLAUDE.md`](../CLAUDE.md) covers cross-cutting standards; this file is owned by the app's devs.

```md
# <app-name>

## Overview

## Tech stack

## Project structure

## Feature module conventions

## Navigation

## State management

## Data fetching

## Styling

## Native modules and config plugins

## Firebase setup

## Environment variables

## Testing

## Build and release (EAS)

## Common tasks
```

Start with empty section bodies — fill them as the app grows.

## 14. `app.json`

Update the Expo config to match the app:

```json
{
  "expo": {
    "name": "<App Name>",
    "slug": "<app-name>",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "userInterfaceStyle": "automatic",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "com.<org>.<app-name>"
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      },
      "package": "com.<org>.<app_name>"
    },
    "web": {
      "favicon": "./assets/favicon.png"
    },
    "plugins": [
      "@react-native-firebase/app",
      "@react-native-firebase/crashlytics"
    ]
  }
}
```

> The `bundleIdentifier` (iOS) and `package` (Android) are **per-app** and must be globally unique once you ship to stores. Reverse-DNS your org. Android packages don't allow hyphens — use underscores.

## 15. README and Firebase setup

Create `apps/<app-name>/README.md`:

````md
# <app-name>

Expo + React Native + TypeScript mobile app in the monorepo.

## Quickstart (Expo Go — no native build)

```bash
pnpm install                              # from repo root
pnpm --filter @<org>/<app-name> start
```

Press `i` for iOS simulator, `a` for Android, or scan the QR with Expo Go on your phone.

The template feature works in Expo Go because it doesn't import any native modules.

## Scripts

| Command          | What it does                  |
| ---------------- | ----------------------------- |
| `pnpm start`     | Expo dev server with QR code  |
| `pnpm ios`       | Open in iOS simulator         |
| `pnpm android`   | Open on Android device/emu    |
| `pnpm lint`      | ESLint                        |
| `pnpm typecheck` | `tsc --noEmit`                |

## Firebase setup (per-app, **not** template-level)

Firebase requires per-project credentials. The template doesn't ship working Firebase — each app does this once during onboarding.

1. **Create a Firebase project** for this app (or use an existing one) at <https://console.firebase.google.com>.
2. **Register the iOS app** with bundle id matching `app.json#expo.ios.bundleIdentifier`. Download `GoogleService-Info.plist` and place it at `apps/<app-name>/GoogleService-Info.plist`.
3. **Register the Android app** with package name matching `app.json#expo.android.package`. Download `google-services.json` and place it at `apps/<app-name>/google-services.json`.
4. **Reference the files** in `app.json`:

   ```jsonc
   {
     "expo": {
       "ios": {
         "googleServicesFile": "./GoogleService-Info.plist"
       },
       "android": {
         "googleServicesFile": "./google-services.json"
       }
     }
   }
   ```

5. **Build a dev client** (Expo Go cannot include Firebase native modules):

   ```bash
   pnpm dlx eas-cli@latest build --profile development --platform ios
   pnpm dlx eas-cli@latest build --profile development --platform android
   ```

6. **Initialize Firebase** in code only after step 5. Don't add `import '@react-native-firebase/app'` to anything that runs under Expo Go — it will crash on launch.

For details, follow the official guides — they're authoritative and update faster than this doc:

- React Native Firebase install — <https://rnfirebase.io/>
- Expo + Firebase config plugin — <https://docs.expo.dev/guides/using-firebase/>
- EAS dev clients — <https://docs.expo.dev/develop/development-builds/introduction/>

## Environment variables

```bash
cp apps/<app-name>/.env.example apps/<app-name>/.env
```

Vars must be prefixed with `EXPO_PUBLIC_` to be exposed to the JS bundle.

## Conventions

See the root [CLAUDE.md](../../CLAUDE.md) and [docs/generate-mobile.md](../../docs/generate-mobile.md). Don't deviate.
````

## 16. `.env.example`

```bash
# Backend API base URL (no trailing slash). Includes /api/v1.
EXPO_PUBLIC_API_URL=http://localhost:3000/api/v1
```

> Only env vars prefixed with `EXPO_PUBLIC_` are visible to the JS bundle at runtime. Anything else stays in the build environment. **Don't put secrets in `.env`** — the bundle ships to user devices and is trivially extractable.

## 17. Source maps and Crashlytics

Mobile production builds upload **source maps** to Crashlytics so crash stacks symbolicate back to original TypeScript. This is automated:

- **CI handles it** — the source-map upload runs as part of the EAS production build pipeline. Source maps **never** ship inside the app binary.
- **Set up in Week 4** of project onboarding. For the template, no action needed — manual source maps are fine while iterating locally.
- See [`docs/deployment.md`](./deployment.md#source-maps-and-crashlytics-mobile) for the full flow once you reach release readiness.

## 18. Verification

From the repo root:

```bash
# 1. Install — should detect the new workspace project + link @template/* packages
pnpm install

# 2. Start the Expo dev server
pnpm --filter @<org>/<app-name> start
```

Then either press `i`/`a` for a simulator, or scan the QR in **Expo Go** on a physical device. Verify:

- ✅ App opens to the **Hello** screen with the `<app-name>` title in the header
- ✅ Title text "Hello, Mobile!" renders
- ✅ The **UserCard** shows the demo user's email and id
- ✅ Tapping **Refresh greeting** updates the greeting text with the current time
- ✅ No red error overlay; Metro logs are clean

Then:

```bash
pnpm turbo lint typecheck --filter=@<org>/<app-name>
```

Both tasks must pass with **zero warnings**. **Don't commit until they do.**

> **`pnpm turbo build`** is intentionally not run here — Expo apps are "built" via `eas build` (cloud) or `expo prebuild + xcodebuild/gradlew`, not via a local turbo task. Wire EAS into CI separately when you reach release readiness.

---

## Conventions cheat sheet

Pin this somewhere visible:

- ✅ Feature-based folder structure — **`screens/`, not `pages/`**
- ✅ Coupling rule — keep code inside the feature until **2+ features** need it
- ✅ Domain types from `@template/types` — **never redefine** `User`, `Order`, etc.
- ✅ Styles via **`StyleSheet.create()`** — no inline `style={{...}}`, no styling libs (NativeWind decision is post-foundation)
- ✅ All API calls go through `src/lib/api-client.ts` — **no raw `fetch()` in screens or hooks**
- ✅ No new `.js` files in `src/` — ESLint blocks it
- ✅ **Don't import `@react-native-firebase/*`** in template / Expo-Go code paths — Firebase needs a dev-client build first
- ✅ Don't skip the Metro monorepo config — every workspace dep depends on it
- ✅ pnpm symlinks need `unstable_enableSymlinks: true` in `metro.config.js`
- ✅ Don't ship source maps **inside** the app binary — upload to Crashlytics in CI
