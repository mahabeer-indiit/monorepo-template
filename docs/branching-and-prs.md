# Branching and PRs

## Long-lived branches

| Branch | Purpose                  | Auto-deploys to |
| ------ | ------------------------ | --------------- |
| `main` | Production               | prod            |
| `dev`  | Staging / integration    | staging         |

Never commit directly to `main` or `dev`. Both are protected.

## Feature branches

Branch off **`dev`**. Always.

```bash
git checkout dev && git pull
git checkout -b feat/<scope>/<short-description>
```

### Naming convention

`<type>/<scope>/<kebab-summary>`

- **type** — one of: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`
- **scope** — the app or package: `web`, `mobile`, `api`, `ui`, `types`, etc.
- **summary** — 2–5 words, kebab-case

Examples:

```
feat/web/login-page
fix/api/jwt-refresh-race
chore/mobile/upgrade-expo-52
refactor/ui/button-variants
```

## PR target rules

| PR source         | Target | Reviewers           |
| ----------------- | ------ | ------------------- |
| Feature branch    | `dev`  | 1 peer minimum      |
| `dev`             | `main` | 1 peer + tech lead  |
| Hotfix branch     | `main` | tech lead, then back-merge to `dev` same day |

Hotfix branches are the **only** exception to "branch off dev." Use `hotfix/<scope>/<summary>` and target `main` directly.

## Merge strategy

- **Squash-merge by default.** PR title becomes the squash commit message — write it as a Conventional Commit (see [commit-conventions.md](./commit-conventions.md)).
- **Rebase-merge** allowed for PRs that are already a clean, intentional commit series (rare).
- **Never merge-commit.** No "Merge branch 'dev' into ..." noise in history.

## Branch protection expectations

`main` and `dev` enforce:

- ✅ PR required (no direct pushes)
- ✅ At least 1 approving review
- ✅ All status checks pass (`build`, `lint`, `typecheck`, `test`)
- ✅ Branch up-to-date with target before merge
- ✅ Conversations resolved
- ✅ Linear history (no merge commits)
- ✅ Force-pushes blocked
- ✅ Deletions blocked

Admins do not bypass these rules. If a check is wrong, fix the check.
