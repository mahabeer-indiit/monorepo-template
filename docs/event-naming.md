# Event naming

> **Status: placeholder.** To be defined in **Week 5**, when mobile analytics rolls out.

## What this doc will cover

- Event name format (`snake_case` vs `camelCase`, namespacing by feature)
- Required vs optional properties on every event
- User identity / session correlation rules
- PII handling and what must never enter event payloads
- Web ↔ mobile event parity (same event for the same user action across platforms)
- Where event definitions live in the repo (likely `packages/analytics`)
- Validation: typed event registry to prevent typos at call site

## Why we're waiting

Naming a taxonomy before there are real screens to instrument tends to produce events that don't match what product asks about later. Wait until the mobile app has at least the auth and onboarding flows shipped, then design the schema around the actual questions stakeholders are asking.

In the meantime, **do not add ad-hoc analytics calls.** If you genuinely need to track something pre-Week-5, raise it in `#mobile-eng` first and we'll add a temporary `track()` shim with explicit TODOs.

## Owners

- Schema: TBD (will be assigned at Week 5 kickoff)
- Implementation: mobile + web feature owners follow the schema
