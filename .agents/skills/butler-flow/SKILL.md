---
name: butler-flow
description: "End-to-end feature workflow: ask for feature, create branch, plan, implement with surgical commits, push, and open PR — all through the but CLI. Use when starting any new feature or bug fix."
---

# Butler Flow

Orchestrates a complete feature branch lifecycle using GitButler (`but`) for all version control.

## Prerequisites

Invoke the `gitbutler` skill FIRST to load the full `but` CLI reference. Use it as your source of truth for command syntax and flags throughout this flow.

## Step 1 — Gather Context

Simply ask the user: **"What do you want to build or fix?"** — one open-ended question, no categories, no multi-select. Let them describe it in their own words. If their description is too vague to plan (e.g. "make it better"), ask ONE follow-up. Otherwise, proceed immediately. Do NOT use AskUserQuestion with predefined options for this step.

## Step 2 — Name the Branch

Generate a kebab-case branch name (2-4 words) from the description. Tell the user. Use theirs if they prefer a different name.

## Step 3 — Create the Branch

```bash
but status --json
but branch new <branch-name>
```

## Step 4 — Enter Plan Mode

Enter plan mode. Write the implementation plan into the plan file.

**CRITICAL: The plan must be fully self-contained.** It will be executed in a clean context where no skills or prior conversation are available. The plan document itself must embed everything the executing agent needs, including the exact `but` commands and the version control workflow.

### Required plan structure

The plan file you write MUST follow this exact structure:

```markdown
# <Feature/Fix Title>

## Branch

Name: `<branch-name>`

## Version Control Rules

All version control uses GitButler CLI (`but`). NEVER use `git add`, `git commit`,
`git push`, `git checkout`, `git rebase`, or `gh pr create`.

### How to commit (graduated escalation)

Other agents may be working in parallel on other GitButler branches. When multiple
branches touch the same file, hunk assignment conflicts can occur. Follow this
escalation sequence — try each step, move to the next only if the previous fails.

**Step 1 — Identify your hunks:**

    but diff --json

Read each hunk's `diff` field. Match hunks against changes from THIS plan. Collect
ONLY the hunk IDs whose diff content matches your work. Ignore other hunks.

**Step 2 — Try committing:**

    but commit "<branch-name>" -c -m "<message>" --changes <hunk-id1>,<hunk-id2> --json --status-after

If this succeeds, you're done with this commit. Check `--status-after` for remaining
changes (see "After EVERY commit" below).

**Step 3 — If "assigned to a different stack" error:**

Some hunks are locked to another branch. Unassign them first:

    but rub <rejected-hunk-id> zz

Repeat for each rejected ID. `but rub` may print `AssignmentRejection` warnings —
**that's normal, ignore the warnings.** It usually still unassigns the hunk.

Then run `but diff --json` again — hunk IDs will have changed. Re-identify your
hunks by reading their diff content, and retry the commit with the new IDs.

**Step 4 — If commit still fails after unassign:**

A specific other branch is blocking. Find which branch by reading the error.
Unapply ONLY that branch, commit, then re-apply it:

    but unapply <conflicting-branch-cliId> --json
    but diff --json
    but commit "<branch-name>" -c -m "<message>" --changes <ids> --json --status-after
    but apply <conflicting-branch-name> --json

**Step 5 — If still stuck:** Stop and ask the user for help. NEVER loop more than
3 total attempts per commit.

### After EVERY commit — verify completeness

Check the `--status-after` output and confirm NO uncommitted changes remain for files
you edited. If changes remain:

- They are YOUR changes. Commit them with a follow-up `but commit`.
- If hunks won't commit, try `but amend <hunk-id> <commit-id> --json --status-after`.
  **`but amend` takes ONE hunk ID at a time.** The commit ID changes after each amend,
  so read `new_commit_id` from the result and use it for the next.
- NEVER retry more than twice. If stuck, stop and ask the user for help.

### How to create PR

`but pr new` automatically pushes the branch before creating the PR. Do NOT run
`but push` separately — it's redundant.

ALWAYS use this exact pattern (substitute your values):

    but pr new "<branch-name>" -m "$(cat <<'EOF'
    <PR title — concise, under 70 chars>

    ## Summary
    <what changed and why>

    ## Test plan
    <how to verify>
    EOF
    )"

- The first line of `-m` becomes the PR title, the rest becomes the description
- The `-m` flag is REQUIRED — Claude cannot open an interactive editor
- Do NOT use `gh pr create` — use `but pr new`

---

## Context

<describe the problem/feature, root cause if applicable, relevant file paths>

## Commit 1: <imperative description>

### Files
- `path/to/file.ts` — <what changes>

### Changes
<detailed description of code changes>

### After implementing
1. Run `bunx eslint .` — must pass
2. Follow the "How to commit" steps above
3. Commit message: `"<message>"`

## Commit 2: <imperative description>

... (repeat for each commit)

## Final Steps

1. Run `bunx eslint .` one final time
2. Create PR with `but pr new` using the pattern in "How to create PR" above (this also pushes automatically)
3. Report: branch name, each commit (hash + message), PR URL
```

Every plan you write MUST include the full "Version Control Rules" section verbatim. Do not abbreviate it, do not say "see the gitbutler skill," do not assume the executing agent knows how `but` works. The plan is the only document the agent will have.

Wait for user approval before implementing.

## Step 5 — Implement

Execute the approved plan. Follow each commit boundary exactly. Use the `but` commands as written in the plan.

## Reminders

- The `gitbutler` skill is your reference during planning. But the PLAN must be self-contained.
- Read-only `git` commands (`git log`, `git blame`) are fine.
- If `but` fails unexpectedly, run `but skill check` to verify CLI version.
