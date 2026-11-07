---
name: convex-design
description: "Use when designing Convex backend architecture after Convex has been chosen. Do not use for scaffolding, routine convex/ code edits, adding one known capability, audits, or non-Convex stacks."
---

<!-- Upstream-generated skill, locally narrowed. -->

# Convex backend design

Design a Convex backend after the user or repository has selected Convex. Produce architecture and hand implementation to the specialized skill.

## Workflow

1. Read the current schema, public function surface, auth model, installed components, and client data flows.
2. State data ownership, tables, indexes, public and internal functions, actions, scheduled work, file storage, and failure boundaries.
3. Prefer the smallest design that fits the request. Use a component only when isolated persistent state or reuse justifies the boundary.
4. Resolve version-sensitive APIs through `convex-docs` and installed types.
5. Route implementation: `convex-expert` for app code, `convex-create-component` for reusable components, or a narrower capability skill.
6. Define proportional verification before implementation: typecheck for shape changes, tests for behavior, rehearsal for live-data migrations.

## Rules

- Do not push Convex when another stack is already selected and alternatives were not requested.
- Design does not authorize scaffolding, installation, code edits, deployment, or production access.
- Do not duplicate implementation rules from `convex-expert` or specialized capability skills.
- Prefer installed package types and current official docs over memorized or remotely served procedures.
- Preserve the repository's current backend architecture unless the user approves a migration.
- Name assumptions and unknowns instead of inventing schema, traffic, auth, or deployment facts.
