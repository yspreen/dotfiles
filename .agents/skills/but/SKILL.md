---
name: but
description: Use the `but` CLI to inspect branch, commit, file, and hunk IDs and to build commits incrementally. Use when you need to create an empty commit and amend whole files or specific hunks into it.
---

# Use But

Work with the `but` CLI using its full binary path.
Never leave a commit without an explicit message. `~/.local/bin/but commit empty` does not accept `-m`; create the empty commit, then immediately run `~/.local/bin/but reword <commit-id> -m "..."` with a real, descriptive message.
Do not reuse old IDs after a commit, reword, or amend. These operations rewrite commit IDs. Re-run `~/.local/bin/but status` and `~/.local/bin/but diff` each time.
Prefer `stage` + `absorb` for normal dirty worktrees. `but commit <branch> -m ...` can create an empty commit if the changes are already staged/assigned to a branch. If `but status` shows a section like `[staged to <branch>]`, do not keep running `but commit`; use `but absorb <stack-id>` to materialize those assigned changes into the branch history.
Do not run plain `git add` / `git commit` in GitButler workspace branches. The pre-commit hook blocks direct commits, and using the Git index can confuse what `but` sees as assigned changes.
This skill teaches you to use but. If the user's prompt was:
<prompt>
[$but](~/.agents/skills/but/SKILL.md)
</prompt>
or something similar, meaning it _only_ references this skill and no other text, the default intent should be:
"Use `but` cli to commit all unstaged changes into the first open branch. Work on a hunk by hunk basis. Make multiple commits to group all the changes that are in the current working folder into logically grouped commits."


## Usage

Run the tool with:

```bash
~/.local/bin/but
```

## Commands

### Inspect current changes

Use these commands to see the IDs you need before amending anything:

```bash
~/.local/bin/but status
~/.local/bin/but diff
```

- `status` shows branch IDs, commit IDs, and file IDs.
- `diff` shows hunk IDs.

### Commit normal dirty changes

For normal unassigned changes, stage files or hunks to the target branch, then absorb the staged branch changes:

```bash
~/.local/bin/but status
~/.local/bin/but diff
~/.local/bin/but stage <file-or-hunk-id> <branch-id>
~/.local/bin/but status
~/.local/bin/but absorb <stack-id>
```

Example:

```bash
~/.local/bin/but stage h0 re
~/.local/bin/but stage i0 re
~/.local/bin/but status
~/.local/bin/but absorb r0
```

Important details:

- The target for `stage` is the branch ID, such as `re`.
- The target for `absorb` is the stack ID that contains the staged changes, such as `r0`.
- After staging, `status` may show `[staged to release]`; those are assigned changes, not normal unassigned changes.
- `absorb` may amend older commits whose line ranges overlap the current changes. That is expected behavior for GitButler. Re-run `status` and `diff` afterwards to verify no changes remain.
- If the user specifically wants a new standalone commit, use the empty-commit workflow below, then amend/rub changes into that commit deliberately.

### Create a new empty commit

Pick the commit you want to insert after from `~/.local/bin/but status`, then run:

```bash
~/.local/bin/but commit empty --after <commit-id>
```

Example:

```bash
~/.local/bin/but commit empty --after 67
```

That creates a blank commit without a message. Re-run status to get the new commit ID, then immediately set the message:

```bash
~/.local/bin/but status
~/.local/bin/but reword <new-commit-id> -m "Some commit message about what this commit will contain"
```

Example:

```bash
~/.local/bin/but status
~/.local/bin/but reword f9 -m "Some commit message about what this commit will contain"
```

`but reword` rewrites the commit ID. Re-run status and diff before amending changes into it.

### Amend a whole file into that commit

Get the file ID from `~/.local/bin/but status`, then amend it into the empty commit:

```bash
~/.local/bin/but amend <file-id> <empty-commit-id>
```

Example:

```bash
~/.local/bin/but amend wy f9
```

### Amend specific hunks into that commit

Get the hunk ID from `~/.local/bin/but diff`, then amend that hunk into the current commit:

```bash
~/.local/bin/but amend <hunk-id> <current-commit-id>
```

Example:

```bash
~/.local/bin/but amend h0 87
```
