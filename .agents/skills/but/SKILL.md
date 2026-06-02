---
name: but
description: Commit all current working-copy changes with plain Git, split into logical commits.
---

# Use But

This skill means: clean up the current Git working copy by committing every intended change into one or more logical commits.

Use plain `git`. Do not use GitButler or the `but` CLI.

Prefer MANY SMALL commits over ONE LARGE commit.

## Default Intent

If the user only invokes this skill, treat it as:

> Review all dirty work in the current repo, split it into coherent groups, and create descriptive Git commits until the working copy is clean.

## Rules

- Inspect before staging: `git status --short`, `git diff`, and `git diff --stat`.
- Preserve user work. Do not discard, reset, checkout, or overwrite changes unless explicitly asked.
- Make multiple commits when the changes represent different concerns.
- Keep each commit internally consistent: related files, tests, docs, migrations, and generated updates belong with the behavior they support.
- Use conventional, descriptive commit messages when possible, such as `fix: ...`, `feat: ...`, `refactor: ...`, `test: ...`, `docs: ...`, or `chore: ...`.
- Stage deliberately. Prefer path-based staging for clean groups and `git add -p` only when a file contains unrelated changes.
- Do not amend, squash, rebase, or rewrite existing commits unless the user explicitly asks.
- If any dirty change is unclear, risky, secret-looking, or unrelated to the apparent task, stop and ask before committing it.
- After committing, verify with `git status --short`. The goal is no remaining intended dirty changes.

## Workflow

```bash
git status --short
git diff --stat
git diff
```

Decide the commit groups. For each group:

```bash
git add <paths>
git diff --cached
git commit -m "type: concise description"
git status --short
```

For mixed files, stage only the relevant hunks:

```bash
git add -p <path>
git diff --cached
git commit -m "type: concise description"
```

Repeat until all intended working-copy changes are committed.
