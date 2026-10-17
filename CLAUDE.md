# CLAUDE.md

Every repo rule lives in `AGENTS.md`, imported here so there is exactly one copy to keep current:

@AGENTS.md

Everything below is Claude-Code-specific mechanics that other agents have no use for.

## Setup gate — rename before any work

This template ships under the `@template/` npm scope. A real project must be rebranded to its own
org scope before any feature work, so apps never ship as `@template/...`.
[`scripts/check-template-rename.sh`](./scripts/check-template-rename.sh) runs on three events,
with the event passed as `$1`:

| Event | Mode | What it does |
| --- | --- | --- |
| `SessionStart` | `session-start` | Injects the repo state into context before the user types. This is the only channel that survives a slash command — `UserPromptSubmit` does not fire for those. |
| `UserPromptSubmit` | `prompt` | Injects `additionalContext` so **Claude answers in its own voice**: "rename first". It does **not** block. |
| `PreToolUse` (`Edit\|Write\|MultiEdit\|NotebookEdit`) | `pre-write` | The hard stop: `permissionDecision: "deny"`, so no file is modified. Fires only on writes, never on reads. |

**Why it no longer uses `decision: "block"` on the prompt.** The previous version emitted
`{"decision":"block","systemMessage":"…"}` and cloners reported seeing nothing at all. Two separate
faults, both verified against the installed 2.1.220 binary:

1. **`systemMessage` is discarded whenever the same hook output also blocks.** Claude Code
   aggregates hook results in a fixed order — `blockingError` is yielded before `systemMessage` —
   and the `UserPromptSubmit` consumer returns on the first `blockingError`, closing the generator
   before the `systemMessage` yield is reached. The long, helpful text went into the one field a
   blocking hook throws away. `reason` *is* rendered, but only a terse one-liner lived there.
   (The old comment claiming exit-2 stderr "is not reliably surfaced" was also wrong for this build.)
2. **Even a correct `reason` is client-rendered**, and that line has been reported missing in the
   VS Code/Cursor extension and the Windows desktop app. Worse, a hard block means no model turn
   runs at all, so Claude can never explain anything itself.

An assistant message has neither dependency: it renders on every surface, platform and client.
So the prompt path now injects context and lets Claude speak; enforcement moved to `PreToolUse`,
where a denial cannot be silent because the model is told why and relays it.

**Known limits.** Hooks do not run at all until the workspace-trust prompt is accepted, and that
dialog swallows the first keystrokes — which is itself a likely cause of the original "nothing
happened" reports. On Windows the gate needs `bash` on PATH; without it the hook fails to spawn and
is silently absent rather than merely quiet. Both are documented in the README, which needs no hook.

**To clear the gate:**

```bash
./scripts/rename.sh <your-org>      # macOS / Linux / Git Bash / WSL
bash scripts/rename.sh <your-org>   # Windows PowerShell / CMD (runs through Git Bash)
```

**Working on the template itself?** Use the gitignored marker
[`.claude/allow-template-scope`](./.claude/allow-template-scope) or `ALLOW_TEMPLATE_SCOPE=1`. Both
are local-only, so clones never inherit them.

> The gate is rename-proof: the script never stores the literal `@template/` token as one string,
> so `scripts/rename.sh`'s find+sed cannot rewrite the guard and silently disable it.


## Permission rules, and where they actually apply

- Deny rules are committed in `.claude/settings.json` at the repo root **and in every workspace
  package**, because project settings are read from the directory Claude was started in with no
  parent-directory lookup. A package without its own copy runs with no deny rules at all.
- `pnpm agents:sync` writes the copies; `pnpm agents:check` fails CI when one is missing or has
  drifted. Run `agents:sync` and commit the result whenever a package is added or a rule changes.
- Only `Edit(<glob>)` and `Read(<glob>)` path rules are consulted. `Write(...)`, `MultiEdit(...)`,
  `NotebookEdit(...)` and `Glob(...)` path rules validate clean, raise no warning, and are never
  enforced — CI greps for them. `Edit()` already covers Write, MultiEdit and NotebookEdit.
- Deny rules do not stop a subprocess: `Bash(node -e …)`, `sed -i` or a heredoc can still write a
  denied path, and `Bash()` rules match command prefixes, not intent. They are guardrails against
  honest accident, not a security boundary — see `AGENTS.md` §8.
- An invalid settings file is *skipped*, not fatal, and under `claude -p` it is ignored with no
  dialog. Run `claude doctor` after editing a settings file: it names the file and the dropped rule.
  CI also parses every copy as JSON for this reason.

## Local-only overrides

`.claude/settings.local.json` is gitignored and *does* resolve from the git root, so it reaches every
subdirectory. Use it for personal conveniences (extra allow rules, env vars). Never put a team
convention there — nobody else gets it.

## Conventions and decisions

`AGENTS.md` imports `docs/decisions/INDEX.md`, so the one-line rationale for each standing rule is
already in context. Adding or changing a convention means adding a line there in the same PR; use
`docs/decisions/TEMPLATE.md` when a decision needs a long-form record.
