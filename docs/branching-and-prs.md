# Branching and PRs

## Long-lived branches

| Branch | Purpose               | Auto-deploys to |
| ------ | --------------------- | --------------- |
| `main` | Production            | prod            |
| `dev`  | Staging / integration | staging         |

Never commit directly to `main` or `dev`. Both are protected.

## Feature branches

Branch off **`dev`**. Always.

```bash
git checkout dev && git pull
git checkout -b <type>/<ticket>-<short-desc>
# e.g. git checkout -b feat/PROJ-123-add-login
```

### Naming convention

`<type>/<ticket>-<short-desc>` — for example, `feat/PROJ-123-add-login`.

- **type** — one of: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `perf`, `build`, `ci` (matches Conventional Commits)
- **ticket** — your project's ticket identifier (e.g. `PROJ-123`)
- **short-desc** — 2–5 words, kebab-case

Examples:

```
feat/PROJ-123-add-login
fix/PROJ-456-cart-duplicate-on-rapid-click
chore/PROJ-789-bump-react-query
docs/PROJ-321-update-readme
```

## PR target rules

| PR source      | Target | Reviewers                                    |
| -------------- | ------ | -------------------------------------------- |
| Feature branch | `dev`  | 1 peer minimum                               |
| `dev`          | `main` | 1 peer + tech lead                           |
| Hotfix branch  | `main` | tech lead, then back-merge to `dev` same day |

Hotfix branches are the **only** exception to "branch off dev." Use `hotfix/<ticket>-<short-desc>` and target `main` directly.

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
