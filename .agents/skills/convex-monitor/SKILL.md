---
name: convex-monitor
description: "Wait for next Convex error/request. Not log queries or capture setup."
---

<!-- GENERATED from convex-agents content/capabilities/monitor.json — do not edit by hand. -->

# Watch for the next thing to react to

Block on the next typed event instead of polling. Races local error logs, deployment subscriptions, and Sentinel prod-error rows; returns the first to fire (or a quiet heartbeat).

## Workflow

1. Call `wait_for_event` with {project_dir, event_kinds, timeout_ms}.
2. On kind=convex_error/next_error: decode and fix it. On kind=prod_error: triage (see sentinel) and fix. On kind=feature_request: build it. On kind=quiet: loop.
3. Where a harness has no blocking MCP (e.g. Copilot cloud), the pack runs a poll loop with the SAME event contract — same behavior, different mechanism.

## Rules

- Prefer the blocking tool; fall back to a poll loop only where blocking MCP is weak.
- The event schema is fixed and versioned — the same trigger yields the same typed event.
- Prod events (kind=prod_error) require a deployed cloud app plus Sentinel.
