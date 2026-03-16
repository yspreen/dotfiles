---
name: butler-cleanup
description: Create a GitButler safety snapshot and split all current working-directory changes into correct logical branches and commits without editing code. Use when many mixed hunks/files must be bucketed, moved between branches, and committed cleanly.
---

# Butler Cleanup Skill

Use this skill to take a messy GitButler workspace and turn it into clean, logical branches and commits.

This skill is self-contained and does not require other skills.

## Hard Rules

1. Use `but` for all write operations.
2. Never run write-side git commands (`git add`, `git commit`, `git checkout`, `git rebase`, `git stash`, `git merge`, `git cherry-pick`, `git push`).
3. Never edit code/content while cleaning up. Only reassign/stage/commit existing changes.
4. Start with `but status --json`.
5. Create an oplog snapshot before any branch or commit mutation.
6. Add `--json --status-after` to every mutation command.
7. Re-run `but diff --json` after every mutation. Hunk IDs are ephemeral.
8. Resolve branch naming policy before creating any branch, with this precedence: (a) explicit user instruction in the current task, (b) repo-local policy files (for example `AGENTS.md`, `CONTRIBUTING.md`), (c) this skill default.
9. Never invent or auto-apply a branch prefix. If policy says "no prefix", use only the topic slug.
10. If branch naming policies conflict or are ambiguous, stop and ask the user before creating branches.
11. Do not use `but apply` or `but unapply` unless explicitly requested.
12. Keep each commit to one logical change bucket.
13. Before creating any new branch, inspect existing branches and reuse them when bucket topics match.

## Required Command Patterns

- Snapshot:
  `but oplog snapshot -m "<message>" --json --status-after`
- Create branch:
  `but branch new <branch-name> --json --status-after`
- Commit specific hunks:
  `but commit <branch-id-or-name> -m "<message>" --changes <id1>,<id2> --json --status-after`
- Unassign a hunk to the unassigned pool:
  `but rub <hunk-id> zz --json --status-after`
- Verify commit contents:
  `but show <commit-id> --json`

## End-to-End Cleanup Procedure

### 1) Capture Current State

Run:

```bash
but status --json
but diff --json
```

Record:

- Existing branch IDs and names
- Existing commits per branch
- Unassigned files/hunks
- Any already-assigned but uncommitted changes
- Candidate existing branches that can absorb each logical bucket
- Resolved branch naming policy and its source (user instruction vs repo policy vs skill default)

### 2) Create Safety Snapshot

Run:

```bash
but oplog snapshot -m "Pre-cleanup snapshot" --json --status-after
```

Record `snapshot_id` for rollback safety.

### 3) Build Logical Buckets

Group changes by behavior, not by file count.

Use this rubric:

- Same user-visible behavior or bug fix -> same bucket
- Feature logic + direct tests for that logic -> same bucket
- Independent feature exploration/prototype -> separate bucket
- Unrelated UI/logic/test changes -> separate buckets

Prefer splitting too much over mixing unrelated hunks.

### 4) Map Buckets to Branches

For each bucket:

- First attempt to reuse an existing branch if its topic clearly matches. Do this check before creating any new branches.
- Only create a new branch when no existing branch is a good topic match.
- New branch names must follow the resolved policy from Step 1.
- Skill default (only when no higher-priority policy exists): description-only, no prefix, for example `<topic>`.

Branch naming guidance:

- Use 2-5 lowercase hyphenated words.
- Describe intent, not implementation details.
- Do not include prefixes or namespace markers unless explicitly required by resolved policy.
- Examples: `social-proof-rating-gate`, `favorites-tail-routing`.

### 5) Commit Buckets One by One

For each bucket:

1. Refresh hunks:

```bash
but diff --json
```

2. Select only hunk IDs whose diff content belongs to this bucket.
3. Commit only those IDs:

```bash
but commit <target-branch> -m "<message>" --changes <comma-separated-hunk-ids> --json --status-after
```

4. Verify commit:

```bash
but show <returned-commit-id> --json
```

5. Confirm changed files/hunks match intended bucket.

### 6) Handle Common Failures

#### Failure: "assigned to a different stack"

Cause: hunk is currently claimed by another branch.

Fix:

1. Unassign blocked hunk(s):

```bash
but rub <blocked-hunk-id> zz --json --status-after
```

2. Refresh IDs:

```bash
but diff --json
```

3. Retry commit with fresh hunk IDs.

#### Failure: pre-commit hook reformats staged files

Cause: hook changed staged content before commit.

Fix:

1. Refresh IDs:

```bash
but diff --json
```

2. Re-select the same logical bucket hunks.
3. Run the same `but commit ... --changes ...` command again.
4. Do not hand-edit code during cleanup.

#### Failure: commit contains wrong bucket content

Fix:

1. Uncommit that commit:

```bash
but uncommit <commit-id> --json --status-after
```

2. Refresh hunks and recommit with proper `--changes` selection.

### 7) Final Integrity Checks

Run:

```bash
but status --json
```

Confirm:

- `unassignedChanges` is empty (unless intentionally left for follow-up)
- No unexpected leftover assigned changes
- Each branch has a coherent topic
- Each commit message matches its change bucket

### 8) Final Report Format

Report:

1. `snapshot_id`
2. Branch list
3. Commit SHA + message under each branch
4. Any intentionally uncommitted leftovers (if any)

## Troubleshooting (Optional Further Reading)

Use these only when command behavior differs from expectations:

- GitButler CLI docs: `https://docs.gitbutler.com/cli-overview`
- Local CLI help: `but --help`, `but <subcommand> --help`
- Skill/version health: `but skill check`
