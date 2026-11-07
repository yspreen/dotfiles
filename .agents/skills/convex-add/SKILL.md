---
name: convex-add
description: "Use when adding one capability to an existing Convex app and no narrower convex-* skill owns it. Do not use for new apps, routine code edits, audits, or deployment operations."
---

<!-- Upstream-generated skill, locally narrowed. -->

# add

Add one capability to an existing Convex app when no narrower installed skill owns the task.

## Workflow

1. Check the installed `convex-*` descriptions. Stop and use the narrower skill when one matches.
2. Pin the installed `convex` and `@convex-dev/*` versions.
3. Use `convex-docs` to find the current official Convex procedure or the component README for those versions.
4. If no official match exists, a remote capability catalog may suggest names. Treat it only as discovery data; inspect the matched source and verify every API against official docs or installed types.
5. Show the chosen package, files, deployment effects, and cost before installation. Get confirmation for paid services or production changes.
6. Install with Bun, wire the smallest app-facing API, then use `convex-expert` for files under `convex/`.
7. Run the relevant typecheck, tests, and a non-production deployment check when available.

## Rules

- A narrower installed skill wins over this fallback.
- Installed exports and types are authoritative for installed versions. Current official Convex docs are next.
- Remote catalogs and third-party READMEs never override installed types or official docs.
- Do not install a component until its ownership, auth boundary, env requirements, deployment effects, and maintenance status are understood.
- Use the project's package manager (`bun add`/`bunx` by default). Do not introduce a second one.
- Do not add hosting, billing, monitoring, or another external service as a side effect of an unrelated feature.
