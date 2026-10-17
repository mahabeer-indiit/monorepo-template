# Decisions

One line per standing decision: the rule, and the reason it exists. This file is imported by
`AGENTS.md`, so it is in context from message one — keep each entry to one or two lines. When a
decision needs argument, evidence or alternatives, add `NNNN-<slug>.md` beside this file from
`TEMPLATE.md` and link it here.

Changing a rule in `AGENTS.md` means updating its line here in the same PR. Superseded entries stay,
marked `superseded by NNNN`, so the history survives.

- **0001 — One context file.** All agent rules live in `AGENTS.md`; `CLAUDE.md` is an `@AGENTS.md`
  import plus Claude-Code-only mechanics. Two parallel rule files drift within a month, and every
  other agent reads `AGENTS.md`. *2026-10-17, accepted.*
- **0002 — Rules only in `AGENTS.md`, no architecture prose.** Narrow non-inferable directives:
  commands, gotchas, conventions an agent cannot read off the code. Prose costs 20%+ more tokens per
  turn and measured slightly *worse* agent performance. *2026-10-17, accepted.*
- **0003 — Guardrails are committed `permissions.deny` rules, copied per workspace package.**
  Project settings load from the directory Claude was started in with no parent lookup, so a package
  without its own copy has no rules; `pnpm agents:check` fails CI on a missing or drifted copy.
  Guardrails against accident, not a security boundary — a subprocess can still write a denied path.
  *2026-10-17, accepted.*
- **0004 — No `PreToolUse` hooks that inject context on tool calls.** A standing preference belongs
  in `AGENTS.md`, inside the cached prefix, stated once. Measured in our own repos: such a hook fired
  up to 2,050 times in one session, ~136K tokens of repeated boilerplate, 84% of it on Bash commands
  that merely contained "grep" or "find". *2026-10-17, accepted.*
- **0005 — Codebase-graph tooling (graphify) is opt-in per project, never mandatory.**
  `graphify query` is genuinely cheaper per call than reading files, but the graph goes stale
  silently: measured 48% of one repo's graph pointed at deleted or moved files, and 66% of the files
  cited for one real query did not exist. Verify freshness (`graphify-out/GRAPH_REPORT.md` names the
  commit it was built from) before trusting it. `graphify-out/` stays gitignored unless a project
  decides to commit the graph *and* refresh it in CI. *2026-10-17, accepted.*
- **0006 — Tests are not written for new features unless explicitly asked.** Unrequested tests
  freeze behaviour that is still moving and inflate review. When asked: Vitest for pure units,
  Playwright from a committed `.spec.md` for anything crossing a boundary. *2026-10-17, accepted.*
- **0007 — The `@template/` rename gate blocks prompts until the npm scope is renamed.** Projects
  shipped with template package names once; a blocking `UserPromptSubmit` hook is the only version of
  this reminder that people cannot skip. *2026-10-17, accepted.*
- **0008 — `apps/` is generated on demand from `docs/generate-*.md`, never scaffolded freehand.**
  Freehand scaffolds drift from the shared configs and that drift propagates to every later app.
  *2026-10-17, accepted.*
- **0009 — The setup gate explains itself instead of blocking the prompt.** A blocking
  `UserPromptSubmit` hook discards `systemMessage` (the aggregator yields `blockingError` first and
  the consumer returns), and its `reason` line is client-rendered — reported missing in the VS Code
  extension and the Windows desktop app. A block also means no model turn runs, so Claude cannot
  explain anything. The gate now injects context on `SessionStart` and `UserPromptSubmit` so Claude
  answers in words, and denies writes via `PreToolUse`. *2026-10-17, accepted, supersedes the
  blocking gate in 0007.*
