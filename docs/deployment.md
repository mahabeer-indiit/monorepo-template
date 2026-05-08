# Deployment

Production runs **only built artifacts**. Source code, dev servers, and tooling never touch a production host.

## Frontend (web)

- **Build:** `pnpm turbo build --filter=web` produces `apps/web/dist/`
- **Serve:** nginx serves the `dist/` folder as static files, with SPA fallback to `index.html`
- **CDN:** `dist/assets/*` are content-hashed — set `Cache-Control: public, max-age=31536000, immutable`
- **HTML:** `index.html` is small and changes per deploy — set `Cache-Control: no-cache`

```nginx
# /etc/nginx/sites-available/web
root /var/www/web/dist;
location / {
  try_files $uri /index.html;
}
location /assets/ {
  expires 1y;
  add_header Cache-Control "public, immutable";
}
```

**Never** point nginx at `apps/web/src/`, run `vite dev` in production, or expose `node_modules`.

## Backend (api)

- **Build:** `pnpm turbo build --filter=api` produces `apps/api/dist/`
- **Run:** PM2 runs `node dist/index.js` (or whatever the build entry is) — never `tsx src/index.ts` or `nodemon`
- **Process count:** PM2 cluster mode, instances = `max` (one per CPU core)

```js
// ecosystem.config.cjs
module.exports = {
  apps: [
    {
      name: 'api',
      script: 'dist/index.js',
      cwd: '/var/www/api',
      instances: 'max',
      exec_mode: 'cluster',
      env: { NODE_ENV: 'production' },
    },
  ],
};
```

**Never** run `tsx`, `ts-node`, `nodemon`, or `pnpm dev` on a production host. Those exist for local iteration only.

## Source maps and Crashlytics (mobile)

For mobile (React Native + Expo), CI uploads source maps to Crashlytics during the release build so production crashes symbolicate back to original TypeScript:

- iOS: source maps generated during `eas build --profile production`, uploaded via the Crashlytics Fastlane plugin in the post-build step
- Android: same flow via Gradle's Crashlytics plugin

Source maps are **never bundled into the shipped app** — they live on Crashlytics' servers and are looked up by upload UUID. Verify the UUID matches the binary version after every release.

## Why this matters

Serving source in production:

- Leaks proprietary code and dependency surface
- Skips minification → 5–10× larger payloads
- Skips tree-shaking → ships dead code
- Skips type-stripping → slower parse and runtime
- Means `node_modules` ends up on the host (huge attack surface)

The build step is the contract between dev convenience and prod safety. Don't blur it.
