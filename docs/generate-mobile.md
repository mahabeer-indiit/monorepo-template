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

| Where                | Form                  | Example                  |
| -------------------- | --------------------- | ------------------------ |
| Folder               | kebab-case            | `apps/customer-app`      |
| `package.json#name`  | `@<org>/<name>`       | `@template/customer-app` |
| Expo `app.json#slug` | kebab-case (no scope) | `customer-app`           |

For the rest of this guide, replace `<app-name>` with your name and `<org>` with your scope (use `template` if you don't have one yet).

## 3. Bootstrap with Expo

```bash
cd apps
pnpm create expo-app <app-name> --template blank-typescript
cd <app-name>
```

> **Why `expo-app` (not `expo`)?** `pnpm create expo` only resolves on some Expo CLI versions; `pnpm create expo-app` is the canonical, stable command. If your installed CLI complains about `--template`, the new flag may be `-t` — check `pnpm dlx create-expo-app --help` for the active syntax.

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
- **`unstable_enablePackageExports: true`** — required for workspace packages that use the `exports` field in `package.json` for deep imports.

### When this config is wrong

| Symptom                                                           | Likely cause                                              |
| ----------------------------------------------------------------- | --------------------------------------------------------- |
| `Unable to resolve module @template/types`                        | Missed `nodeModulesPaths` — Metro can't see hoisted deps  |
| `Invariant Violation: Module AppRegistry is not a registered ...` | Duplicate React — drop `disableHierarchicalLookup` flag   |
| HMR doesn't fire when editing a workspace package                 | `watchFolders` not set, or didn't include `workspaceRoot` |
| `Unable to resolve a workspace package's deep import (`pkg/sub`)` | Missed `unstable_enablePackageExports`                    |
| Package resolves at type-time but crashes at runtime              | Missed `unstable_enableSymlinks`                          |

If symptoms persist after the config above, see the **Troubleshooting** section at the end of this guide.

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
    "@tanstack/react-query": "^5.59.0",
    "@template/types": "workspace:*",
    "expo": "~52.0.0",
    "expo-status-bar": "~2.0.0",
    "react": "18.3.1",
    "react-native": "0.76.0",
    "react-native-error-boundary": "^1.2.5",
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

> **About the React version:** mobile is pinned to **React 18** for now — React Native's stable line still tracks 18.x. Don't bump to React 19 in mobile until the RN team officially supports it.

> **About Firebase deps:** the three `@react-native-firebase/*` packages are installed but **not imported** in the template feature. They contain native code that Expo Go does **not** bundle, so importing them in code that runs under Expo Go would crash. The deps live in `package.json` so the surface is ready when you move to a dev-client build (see [README's Firebase setup](#16-readme-and-firebase-setup) below). Don't `import '@react-native-firebase/app'` in the template feature.

## 6. Run `pnpm install`

```bash
# from repo root
pnpm install
```

> **🔁 Anytime you change `package.json`** — adding a dep, bumping a version, renaming a script — run `pnpm install` from the repo root again.

## 7. Replace `tsconfig.json`

```json
{
  "extends": "@template/config-ts/react-native.json",
  "include": ["src", "App.tsx", "metro.config.js", "babel.config.js"]
}
```

> **No `@/*` path aliases on mobile.** Metro does not read `tsconfig.json#paths` at runtime. Even if TypeScript typechecks the alias correctly, Metro will fail with `Unable to resolve module @/foo` when it bundles. We use **relative imports throughout** (`'../features/hello'`, `'../../navigation/types'`). It's slightly more verbose but bulletproof — no dual config to keep in sync between TS and Metro.

## 8. Add `eslint.config.mjs`

Create the file (Expo's blank template doesn't ship one):

```js
import config from '@template/config-eslint/react-native.mjs';

export default config;
```

The shared preset gives you `@typescript-eslint`, React + React Hooks rules, RN globals (`__DEV__`, `fetch`, etc.), `eslint-plugin-import`, `eslint-plugin-unused-imports`, Prettier compatibility, and the **no-`.js`-files-in-`src/`** rule.

## 9. Folder structure

The full layout you'll end up with:

```
apps/<app-name>/
├── App.tsx                    ← entry: error boundary + providers + root navigator
├── CLAUDE.md
├── README.md
├── app.json                   ← Expo config (name, slug, bundle ids)
├── babel.config.js            ← from Expo bootstrap
├── eslint.config.mjs
├── metro.config.js            ← monorepo wiring (step 4)
├── package.json
├── tsconfig.json
└── src/
    ├── ErrorFallback.tsx      ← top-level error UI for the boundary
    ├── lib/
    │   └── api-client.ts      ← fetch wrapper for the backend
    ├── navigation/
    │   ├── RootNavigator.tsx
    │   └── types.ts           ← RootStackParamList — typed routes
    └── features/
        └── hello/             ← one folder per feature, never shared/
            ├── components/    feature-scoped UI
            ├── api/           backend calls (React Query hooks)
            ├── types/
            ├── hooks/         non-API custom hooks
            ├── screens/       route-level screens (NOT pages/)
            └── index.ts       public surface
```

> **Convention — feature-based structure (mandatory).** No top-level `src/components/`, `src/screens/`, `src/api/`. Everything lives under `src/features/<name>/` or `src/lib/` (cross-cutting infra) or `src/navigation/` (root navigator + route types).

> **Mobile uses `screens/`, not `pages/`.** Same intent — route-level components — but the platform vocabulary differs.

> **Coupling rule.** Code stays inside its feature folder until **2+ features** need it.

```bash
mkdir -p src/lib src/navigation src/features/hello/{components,api,types,hooks,screens}
```

## 10. `src/lib/api-client.ts`

A typed `fetch` wrapper. Every backend call goes through this — no raw `fetch()` in screens or hooks.

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

## 11. `src/navigation/types.ts` — typed routes

Single source of truth for route names + their params. Lives in its own file so screens can import the param list without circular imports back through the navigator.

```ts
export type RootStackParamList = {
  Hello: undefined;
  Details: { name: string };
};
```

> **Rule.** Every route registered in `RootNavigator` must appear here. Adding a route without updating this type means `useNavigation()` calls become silently `any` — that's the bug we're preventing.

## 12. `src/navigation/RootNavigator.tsx`

```tsx
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

import { DetailsScreen, HelloScreen } from '../features/hello';

import type { RootStackParamList } from './types';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  return (
    <NavigationContainer>
      <Stack.Navigator>
        <Stack.Screen name="Hello" component={HelloScreen} options={{ title: 'Hello' }} />
        <Stack.Screen name="Details" component={DetailsScreen} options={{ title: 'Details' }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
```

Screens are imported from each feature's `index.ts` barrel via **relative paths** — never reach into `features/hello/screens/...` directly.

## 13. Error boundary + `App.tsx`

A top-level error boundary catches render errors anywhere in the tree. Without one, a single bad component blanks the screen (in prod) or shows the red error overlay (in dev) — neither is a recoverable user experience.

### `src/ErrorFallback.tsx`

Functional, not pretty. `<View>` + `<Text>` + `<Pressable>` only — no shadcn here (that's web).

```tsx
import { Pressable, StyleSheet, Text, View } from 'react-native';
import type { ErrorBoundaryProps } from 'react-native-error-boundary';

export function ErrorFallback({ error, resetError }: ErrorBoundaryProps) {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Something went wrong</Text>
      <Text style={styles.message}>{error.message}</Text>
      <Pressable
        style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}
        onPress={resetError}
        accessibilityRole="button"
      >
        <Text style={styles.buttonText}>Try again</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 24,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 16,
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 22,
    fontWeight: '600',
  },
  message: {
    fontSize: 13,
    color: '#b91c1c',
    fontFamily: 'Menlo',
    textAlign: 'center',
  },
  button: {
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 8,
    backgroundColor: '#08060d',
  },
  buttonPressed: {
    opacity: 0.85,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '500',
  },
});
```

### `App.tsx`

Replace the bootstrap-generated `App.tsx` entirely. The error boundary is the **outermost** wrapper so even provider crashes fall through gracefully.

```tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StatusBar } from 'expo-status-bar';
import ErrorBoundary from 'react-native-error-boundary';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { ErrorFallback } from './src/ErrorFallback';
import { RootNavigator } from './src/navigation/RootNavigator';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

export default function App() {
  return (
    <ErrorBoundary
      FallbackComponent={ErrorFallback}
      onError={(error) => {
        // Hook into Crashlytics here once Firebase is wired (per-app, dev-client only).
        console.error(error);
      }}
    >
      <QueryClientProvider client={queryClient}>
        <SafeAreaProvider>
          <StatusBar style="auto" />
          <RootNavigator />
        </SafeAreaProvider>
      </QueryClientProvider>
    </ErrorBoundary>
  );
}
```

Keep `App.tsx` thin. It only sets up the boundary + providers + status bar and renders the root navigator. **No business logic, no routes, no styling.**

## 14. Reference feature: `hello`

The canonical feature. Copy this folder when creating a new feature, then rename and gut the contents. Demonstrates: typed routes, React Query hook calling the backend, safe-area handling, typed navigation, `User` type from `@template/types`.

### `src/features/hello/types/hello-state.ts`

```ts
import type { User } from '@template/types';

export type HelloPing = {
  ok: boolean;
  ts: string;
};

export type GreetRequest = {
  name: string;
};

export type GreetResponse = {
  greeting: string;
  user: User;
};
```

> **Shared types rule.** Domain types come from `@template/types`. **Never redefine `User`, `Order`, etc. locally.**

### `src/features/hello/api/use-hello-ping.ts`

```ts
import { useQuery } from '@tanstack/react-query';

import { apiRequest } from '../../../lib/api-client';

import type { HelloPing } from '../types/hello-state';

export function useHelloPing() {
  return useQuery({
    queryKey: ['hello', 'ping'],
    queryFn: () => apiRequest<HelloPing>('/hello'),
  });
}
```

### `src/features/hello/api/use-greet.ts`

Mirrors the web guide's `useGreetMutation` — `useMutation` posting `{ name }` to `/api/v1/hello` and returning the typed response.

```ts
import { useMutation } from '@tanstack/react-query';

import { apiRequest } from '../../../lib/api-client';

import type { GreetRequest, GreetResponse } from '../types/hello-state';

export function useGreet() {
  return useMutation({
    mutationFn: (input: GreetRequest) =>
      apiRequest<GreetResponse>('/hello', { method: 'POST', body: input }),
  });
}
```

> **API rule.** All backend calls go through `apiRequest` and a React Query hook in the feature's `api/` folder. **No raw `fetch()` in screens or components.** Queries (`useQuery`) read; mutations (`useMutation`) write. The two hooks above demonstrate both patterns.

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

> **Styling rule.** Use **`StyleSheet.create()`**. **No inline `style={{ ... }}` literals**, no third-party styling libs. The decision on whether to adopt NativeWind is post-foundation.

### `src/features/hello/screens/HelloScreen.tsx`

The reference screen — pings the backend on load, lets the user submit a name to greet (mutation), shows loading/error/data states for both, applies safe-area top inset, and demos typed navigation.

```tsx
import { useNavigation } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import type { RootStackParamList } from '../../../navigation/types';
import { useGreet } from '../api/use-greet';
import { useHelloPing } from '../api/use-hello-ping';
import { UserCard } from '../components/UserCard';

export function HelloScreen() {
  const insets = useSafeAreaInsets();
  // Typed navigation — `navigation.navigate('Details', { name: ... })` is fully type-checked.
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();

  const ping = useHelloPing();
  const greet = useGreet();
  const [name, setName] = useState('Ada');

  return (
    <ScrollView contentContainerStyle={[styles.container, { paddingTop: insets.top + 24 }]}>
      <Text style={styles.title}>Hello, Mobile!</Text>
      <Text style={styles.subtitle}>
        End-to-end wiring: typed nav + React Query (query + mutation) + @template/types
      </Text>

      {/* Query — runs on mount */}
      {ping.isLoading && <ActivityIndicator />}
      {ping.isError && <Text style={styles.error}>API unreachable. Is the backend running?</Text>}
      {ping.data && (
        <Text style={styles.body}>
          API up — last ping <Text style={styles.code}>{ping.data.ts}</Text>
        </Text>
      )}

      {/* Mutation — submitting a name to greet */}
      <View style={styles.form}>
        <TextInput
          value={name}
          onChangeText={setName}
          placeholder="Your name"
          autoCapitalize="words"
          style={styles.input}
        />
        <Pressable
          style={({ pressed }) => [
            styles.button,
            pressed && styles.buttonPressed,
            (greet.isPending || name.trim().length === 0) && styles.buttonDisabled,
          ]}
          disabled={greet.isPending || name.trim().length === 0}
          onPress={() => greet.mutate({ name: name.trim() })}
          accessibilityRole="button"
        >
          <Text style={styles.buttonText}>
            {greet.isPending ? 'Greeting…' : `Greet ${name || '…'}`}
          </Text>
        </Pressable>

        {greet.isError && (
          <Text style={styles.error}>Greet failed: {(greet.error as Error).message}</Text>
        )}
        {greet.data && (
          <View style={styles.result}>
            <Text style={styles.greeting}>{greet.data.greeting}</Text>
            <UserCard user={greet.data.user} />
          </View>
        )}
      </View>

      <View style={styles.action}>
        <Pressable
          style={({ pressed }) => [styles.linkButton, pressed && styles.buttonPressed]}
          onPress={() => navigation.navigate('Details', { name: name.trim() || 'Ada' })}
          accessibilityRole="button"
        >
          <Text style={styles.linkButtonText}>View details →</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 24,
    paddingBottom: 24,
    gap: 20,
    flexGrow: 1,
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
  body: {
    fontSize: 14,
    color: '#08060d',
    textAlign: 'center',
  },
  error: {
    fontSize: 14,
    color: '#b91c1c',
    textAlign: 'center',
  },
  code: {
    fontFamily: 'Menlo',
    fontSize: 12,
  },
  form: {
    gap: 12,
  },
  input: {
    borderWidth: 1,
    borderColor: '#e5e4e7',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
  },
  button: {
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 8,
    backgroundColor: '#08060d',
    alignItems: 'center',
  },
  buttonPressed: {
    opacity: 0.85,
  },
  buttonDisabled: {
    backgroundColor: '#9ca3af',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '500',
  },
  result: {
    gap: 12,
  },
  greeting: {
    fontSize: 18,
    fontWeight: '500',
    textAlign: 'center',
  },
  action: {
    alignSelf: 'stretch',
  },
  linkButton: {
    paddingVertical: 12,
    alignItems: 'center',
  },
  linkButtonText: {
    color: '#08060d',
    fontSize: 16,
    fontWeight: '500',
  },
});
```

> **Safe-area rule.** Every screen respects safe-area insets. Either wrap content in a `View` with `paddingTop: insets.top` (as above), or use the `<SafeAreaView>` component from `react-native-safe-area-context` (not the deprecated one in `react-native`). Without this, content is obscured by the iPhone notch.

> **Typed navigation rule.** Always use `useNavigation<NativeStackNavigationProp<RootStackParamList>>()` (with the generic) and `useRoute<RouteProp<RootStackParamList, 'X'>>()` for the route name `X`. **Never plain `useNavigation()` without the generic** — that returns `any`, and `navigation.navigate(...)` calls become silently unchecked.

### `src/features/hello/screens/DetailsScreen.tsx`

Demonstrates typed `useRoute` for route params.

```tsx
import { type RouteProp, useRoute } from '@react-navigation/native';
import { StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import type { RootStackParamList } from '../../../navigation/types';

export function DetailsScreen() {
  const insets = useSafeAreaInsets();
  // Typed params — `route.params.name` is `string`, not `any`.
  const route = useRoute<RouteProp<RootStackParamList, 'Details'>>();

  return (
    <View style={[styles.container, { paddingTop: insets.top + 24 }]}>
      <Text style={styles.title}>Hello, {route.params.name}!</Text>
      <Text style={styles.subtitle}>route.params is fully typed.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 24,
    gap: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 28,
    fontWeight: '600',
  },
  subtitle: {
    fontSize: 14,
    color: '#6b6375',
  },
});
```

### `src/features/hello/index.ts` — public surface

```ts
export { useGreet } from './api/use-greet';
export { useHelloPing } from './api/use-hello-ping';
export { DetailsScreen } from './screens/DetailsScreen';
export { HelloScreen } from './screens/HelloScreen';

export type { GreetRequest, GreetResponse, HelloPing } from './types/hello-state';
```

Other features (and the navigator) import only from `'../features/hello'` — never reach into `screens/`, `components/`, etc. directly.

## 15. `apps/<app-name>/CLAUDE.md`

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

## 16. `app.json`

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
    "plugins": ["@react-native-firebase/app", "@react-native-firebase/crashlytics"]
  }
}
```

> The `bundleIdentifier` (iOS) and `package` (Android) are **per-app** and must be globally unique. Reverse-DNS your org. Android packages don't allow hyphens — use underscores.

## 17. README and Firebase setup

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

| Command          | What it does                 |
| ---------------- | ---------------------------- |
| `pnpm start`     | Expo dev server with QR code |
| `pnpm ios`       | Open in iOS simulator        |
| `pnpm android`   | Open on Android device/emu   |
| `pnpm lint`      | ESLint                       |
| `pnpm typecheck` | `tsc --noEmit`               |

## Firebase setup (per-app, **not** template-level)

Firebase requires per-project credentials. The template doesn't ship working Firebase — each app does this once during onboarding.

1. **Create a Firebase project** for this app (or use an existing one) at <https://console.firebase.google.com>.
2. **Register the iOS app** with bundle id matching `app.json#expo.ios.bundleIdentifier`. Download `GoogleService-Info.plist` and place it at `apps/<app-name>/GoogleService-Info.plist`.
3. **Register the Android app** with package name matching `app.json#expo.android.package`. Download `google-services.json` and place it at `apps/<app-name>/google-services.json`.
4. **Reference the files** in `app.json`:

   ```jsonc
   {
     "expo": {
       "ios": { "googleServicesFile": "./GoogleService-Info.plist" },
       "android": { "googleServicesFile": "./google-services.json" },
     },
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

## 18. `.env.example`

```bash
# Backend API base URL (no trailing slash). Includes /api/v1.
EXPO_PUBLIC_API_URL=http://localhost:3000/api/v1
```

> Only env vars prefixed with `EXPO_PUBLIC_` are visible to the JS bundle at runtime. Anything else stays in the build environment. **Don't put secrets in `.env`** — the bundle ships to user devices and is trivially extractable.

## 19. Source maps and Crashlytics

Mobile production builds upload **source maps** to Crashlytics so crash stacks symbolicate back to original TypeScript. This is automated:

- **CI handles it** — the source-map upload runs as part of the EAS production build pipeline. Source maps **never** ship inside the app binary.
- **Set up in Week 4** of project onboarding. For the template, no action needed.
- See [`docs/deployment.md`](./deployment.md#source-maps-and-crashlytics-mobile) for the full flow.

## 20. Verification

```bash
# 1. Install
pnpm install

# 2. Start the backend in another terminal (so the Hello screen has something to ping)
pnpm --filter @<org>/<backend-name> dev

# 3. Start the Expo dev server
pnpm --filter @<org>/<app-name> start
```

Then either press `i`/`a` for a simulator, or scan the QR in **Expo Go** on a physical device. Verify:

- ✅ App opens to the **Hello** screen with the title visible **below** the status bar / notch (safe-area applied)
- ✅ "API up — last ping ..." text appears (React Query hit `/api/v1/hello` successfully)
- ✅ Typing a name + tapping **Greet** posts to `/api/v1/hello` and renders the greeting + the returned `User`
- ✅ The disabled state on the Greet button works while the mutation is pending and when the input is empty
- ✅ Tapping **View details** navigates to the Details screen and renders "Hello, <name>!"
- ✅ Going back lands on Hello with state preserved
- ✅ Forcing a render error in any component falls through to the **Try again** screen (the error boundary), not the red dev overlay
- ✅ No red error overlay otherwise; Metro logs are clean

If the backend is offline, you should see the "API unreachable" message instead of a crash — the error path is also part of the verification.

Then the lint/typecheck sweep:

```bash
pnpm turbo lint typecheck --filter=@<org>/<app-name>
```

Both tasks must pass with **zero warnings**. **Don't commit until they do.**

> **`pnpm turbo build`** is intentionally not run here — Expo apps are "built" via `eas build` (cloud) or `expo prebuild` + `xcodebuild` / `gradlew`, not via a local turbo task.

---

## Troubleshooting

### "Module not found" / "Unable to resolve module" errors that persist after the Metro config

If symptoms persist after step 4, the most reliable escape hatch is to flip pnpm's linker mode for this app only. Add `apps/<app-name>/.npmrc`:

```ini
node-linker=hoisted
```

Then re-install from the repo root:

```bash
pnpm install
```

This trades pnpm's strict isolation for that app — deps land in a flat `node_modules` instead of pnpm's symlink tree, which Metro and many React Native native modules expect. The whole monorepo's other apps and packages keep their isolated layout.

### Metro cache hangs onto stale state

```bash
pnpm --filter @<org>/<app-name> start --clear
```

The `--clear` flag wipes Metro's transformation cache. Use this whenever you change `metro.config.js`, switch branches with deep changes, or see imports that should resolve but don't.

### iOS pod install after adding native deps

If you've added a native module (Firebase, camera, anything with native code) and built a dev client, you need to install CocoaPods after the JS install:

```bash
cd apps/<app-name>/ios
pod install
cd -
```

Required after:

- Adding any `@react-native-firebase/*` package
- Adding any package whose README says "iOS pod install required"
- Bumping the Expo SDK major version

If you skip `pod install`, the iOS build fails with a confusing "framework not found" error.

### App crashes on launch with `import '@react-native-firebase/...'`

You're trying to use Firebase under **Expo Go**. Firebase has native code that Expo Go does not bundle. You must either:

1. Build a dev client (see Firebase setup in the README), and run on the dev client instead of Expo Go, or
2. Remove the Firebase imports until you've built a dev client.

### React Native version pinned to 0.76 — can I bump?

Only when Expo bumps. Each Expo SDK version dictates a specific RN version pair. Bumping RN out of the Expo SDK's tested matrix breaks everything from Metro to native modules. Wait for the next Expo SDK release, follow its upgrade guide, and update both at once.

---

## Conventions cheat sheet

Pin this somewhere visible:

- ✅ Feature-based folder structure — **`screens/`, not `pages/`**
- ✅ Coupling rule — keep code inside the feature until **2+ features** need it
- ✅ Domain types from `@template/types` — **never redefine** `User`, `Order`, etc.
- ✅ Styles via **`StyleSheet.create()`** — no inline `style={{...}}`, no styling libs
- ✅ All API calls through `src/lib/api-client.ts` + React Query hook in `features/<x>/api/` — `useQuery` for reads, `useMutation` for writes; **no raw `fetch()` in screens**
- ✅ Top-level `<ErrorBoundary>` (from `react-native-error-boundary`) wraps the app — render errors fall through, not the red dev overlay
- ✅ **Relative imports throughout** — no `@/*` aliases (Metro doesn't read tsconfig paths)
- ✅ Every screen uses **`useSafeAreaInsets`** (or `<SafeAreaView>`) — no notch overlap
- ✅ Typed navigation: **`useNavigation<NativeStackNavigationProp<RootStackParamList>>()`** + **`useRoute<RouteProp<RootStackParamList, 'X'>>()`** — never the bare hooks
- ✅ Every route registered in `RootNavigator` is also typed in `src/navigation/types.ts`
- ✅ No new `.js` files in `src/` — ESLint blocks it
- ✅ **Don't import `@react-native-firebase/*`** in template / Expo-Go code paths — needs a dev-client build first
- ✅ pnpm symlinks need `unstable_enableSymlinks: true` in `metro.config.js`
- ✅ Don't ship source maps **inside** the app binary — upload to Crashlytics in CI
