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
- Stage and commit each group in one shell instruction. Never run `git add` and defer `git commit`; another agent may change the shared index between those commands.
- For clean groups of tracked files, use `git commit --only -m "..." -- <paths>`. This selects and commits only those paths.
- For unrelated hunks, use the private-index instruction below with `git add -p`. Do not stage hunks in the shared index.
- For groups containing untracked files, use one shell instruction with a temporary private index. Keep the repository's shared index out of the operation:

```bash
index=$(mktemp)
rm -f "$index"
trap 'rm -f "$index"' EXIT
GIT_INDEX_FILE="$index" git read-tree HEAD && \
GIT_INDEX_FILE="$index" git add -- <paths> && \
GIT_INDEX_FILE="$index" git diff --cached && \
GIT_INDEX_FILE="$index" git commit -m "type: concise description"
```

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
git diff -- <paths>
git commit --only -m "type: concise description" -- <paths>
git status --short
```

For mixed files or untracked files, select, stage, inspect, and commit in one instruction. Use `git add -p <path>` for mixed files. Use `git add -- <paths>` for untracked files:

```bash
index=$(mktemp)
rm -f "$index"
trap 'rm -f "$index"' EXIT
GIT_INDEX_FILE="$index" git read-tree HEAD && \
GIT_INDEX_FILE="$index" git add -p <path> && \
GIT_INDEX_FILE="$index" git diff --cached && \
GIT_INDEX_FILE="$index" git commit -m "type: concise description"
```

Repeat until all intended working-copy changes are committed.
