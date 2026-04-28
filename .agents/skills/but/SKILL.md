---
name: but
description: Use the `but` CLI to inspect branch, commit, file, and hunk IDs and to build commits incrementally. Use when you need to create an empty commit and amend whole files or specific hunks into it.
---

# Use But

Work with the `but` CLI using its full binary path.
Do not reuse old IDs after a commit or amend. Re-run `~/.local/bin/but status` and `~/.local/bin/but diff` each time.
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

### Create a new empty commit

Pick the commit you want to insert after from `~/.local/bin/but status`, then run:

```bash
~/.local/bin/but commit empty --after <commit-id>
```

Example:

```bash
~/.local/bin/but commit empty --after 67
```

That creates a blank commit with no message. In `/tmp/but`, this produced a new empty commit `f9`.

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
