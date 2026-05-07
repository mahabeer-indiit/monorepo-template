# Commit conventions

We follow [Conventional Commits](https://www.conventionalcommits.org/). The PR squash message is the commit that lands — write the PR title to match this format.

## Format

```
<type>(<scope>): <subject>

<optional body>

<optional footer>
```

- **type** — `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `build`, `ci`, `style`
- **scope** — app or package: `web`, `mobile`, `api`, `ui`, `types`, `config-ts`, etc.
- **subject** — imperative mood, lowercase, no trailing period, ≤72 chars

## Examples

```
feat(web): add login form with email + password
fix(api): prevent duplicate session on parallel refresh
chore(mobile): bump expo to 52.0.11
docs(readme): document monorepo layout
refactor(ui): consolidate button variants into cva
test(api): cover token expiry edge case
perf(web): memoize large product list
```

Breaking changes use `!`:

```
feat(api)!: switch session cookie to SameSite=strict

BREAKING CHANGE: existing mobile clients <1.4.0 will fail to authenticate.
```

## AI-assisted commits

Use Claude Code's `/commit` slash command — it reads the staged diff, writes a Conventional Commit message, and shows it for approval before running `git commit`. Edit the proposed message inline before confirming if scope or subject feels off.

`/commit` will not stage files for you. Stage with `git add -p` (see below) first.

## Grouping rule: 5–8 files per commit

Each commit should be a **reviewable unit** — typically 5–8 files, almost always under 15. If a single change touches 30 files, split it:

- **By layer** — `types` first, then `api`, then `ui` consuming the types
- **By feature** — one feature's changes per commit
- **By concern** — refactor commits separate from behavior changes

Split-up commits make `git bisect` tractable and code review humane. They also unlock partial reverts.

## Selective staging with `git add -p`

Don't `git add .`. Use patch mode:

```bash
git add -p              # walk hunks interactively
# y = stage, n = skip, s = split, e = edit, q = abort
```

This forces you to look at every line you're committing — catches debug `console.log`, stray TODOs, accidental file moves.

## Rebase clean before PR

Before opening a PR, your branch should be a **clean, atomic series of commits** off the latest `dev`:

```bash
git fetch origin
git rebase origin/dev
git rebase -i origin/dev    # squash WIP commits, reorder, reword
```

After rebase: force-push **with lease** (never plain `--force`):

```bash
git push --force-with-lease
```

Goal: each commit on the PR builds, passes tests, and tells one coherent story. Reviewers should be able to read commit-by-commit and follow the reasoning.
