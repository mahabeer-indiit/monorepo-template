# Testing

We write **tests as specs first, code second**. The flow:

1. Author writes a `.md` spec describing the behavior
2. Claude generates a `.spec.ts` Playwright test from the spec via the Playwright MCP server
3. **Both files are committed** in the same PR as the feature
4. CI runs the `.spec.ts` on every PR

## The `.md` spec

Lives next to the feature, named `<thing>.spec.md`:

```
src/features/auth/login.spec.md
src/features/checkout/coupon-redemption.spec.md
```

Format — bullet-style, no prose paragraphs:

```markdown
# Login spec

## Setup

- User exists with email `qa@example.com`, password `correct-horse`

## Happy path

- Visit `/login`
- Fill email, fill password, click "Sign in"
- Redirected to `/dashboard`
- Header shows user's email

## Wrong password

- Visit `/login`
- Fill email, fill wrong password, click "Sign in"
- Stays on `/login`
- Inline error: "Invalid credentials"
- No request to `/dashboard`

## Empty fields

- Visit `/login`
- Click "Sign in" without filling fields
- Both fields show "Required"
- "Sign in" button stays enabled (no client-side block)
```

The spec is the **contract**. Reviewers approve specs the same way they approve API contracts.

## Generating the `.spec.ts`

Inside Claude Code:

```
/test src/features/auth/login.spec.md
```

The `/test` skill drives the Playwright MCP server: it opens the dev server in a real browser, walks each scenario, generates idiomatic Playwright code, and writes `login.spec.ts` next to the `.md`. Review the generated test the same way you'd review human-written code — locator brittleness, missing assertions, hardcoded waits.

If the generated test doesn't match the spec, **fix the test, not the spec**. The spec is canonical.

## What gets committed

```
src/features/auth/
├── login.spec.md     ← contract, never deleted
├── login.spec.ts     ← runs in CI
└── pages/LoginPage.tsx
```

Both `.md` and `.spec.ts` ship together in the same PR as the feature implementation. Spec-only or test-only PRs are rejected — they drift.

## CI

Only `.spec.ts` runs in CI (Playwright). The `.md` files are documentation; they're checked for existence by a lint rule on every page-level component but are not parsed.

```yaml
# .github/workflows/test.yml — sketch
- run: pnpm turbo test --filter='[origin/dev]'
- run: pnpm exec playwright test
```

## When to skip Playwright

Unit tests (pure functions, hooks, reducers) live next to their source as `<thing>.test.ts` and run via Vitest. Use Playwright for **anything that crosses a boundary** — the DOM, the network, navigation, persistence. If in doubt, use Playwright.
