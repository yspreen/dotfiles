---
name: convex-env
description: "Manage Convex deployment env. Not client or local env."
---

<!-- GENERATED from convex-agents content/capabilities/env.json — do not edit by hand. -->

# Manage env vars + secrets

Store secrets as Convex deployment env vars (bunx convex env set), read them with process.env in actions, never commit them.

## Workflow

1. `bunx convex env set KEY value` (per deployment).
2. Read via process.env.KEY inside actions (not queries/mutations).
3. Never hardcode or commit secrets; add to .env.local only for local.
4. Confirm with `bunx convex env list --names-only` (lists names without printing values).

## Rules

- Secrets live in Convex env vars, never in code or git.
- process.env only in actions ('use node' if needed), not queries/mutations.
- Different deployments need their own values.
- Never print secret values into the conversation.
