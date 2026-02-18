---
name: butler-flow
description: "End-to-end feature workflow: ask for feature, create branch, plan, implement with surgical commits — all through the but CLI. Use when starting any new feature or bug fix."
---

# Butler Flow

Orchestrates a complete feature branch lifecycle using GitButler (`but`) for all version control.

## Prerequisites

Invoke the `gitbutler` skill FIRST to load the full `but` CLI reference. Use it as your source of truth for command syntax and flags throughout this flow.

**PARALLEL AGENTS: Many agents may be running simultaneously on different GitButler branches. Always ignore changes, hunks, and files that are not yours. Only commit, amend, or act on changes from YOUR plan.**

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

**Multiple agents run in parallel on different branches. Always ignore changes that
are not yours. Only touch hunks whose diff content matches work from THIS plan.**

**NEVER unapply, remove, or disable another branch.** Other agents are actively
working on those branches. Unapplying a branch will destroy their work. If a
conflict blocks your commit, escalate to the user — do NOT try to unapply anything.

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

**Step 4 — If still stuck after unassign:** Stop and ask the user for help. NEVER
unapply or disable another branch — other agents are working on them. NEVER loop
more than 3 total attempts per commit.

### After EVERY commit — verify completeness

Check the `--status-after` output for uncommitted changes in files you edited.
**Ignore any changes that are not from YOUR plan** — other agents may be working in
parallel. If YOUR changes remain:

- Commit them with a follow-up `but commit`.
- If hunks won't commit, try `but amend <hunk-id> <commit-id> --json --status-after`.
  **`but amend` takes ONE hunk ID at a time.** The commit ID changes after each amend,
  so read `new_commit_id` from the result and use it for the next.
- NEVER retry more than twice. If stuck, stop and ask the user for help.

---

## Context

<describe the problem/feature, root cause if applicable, relevant file paths>

## Commit 1: <imperative description>

### Files
- `path/to/file.ts` — <what changes>

### Changes
<detailed description of code changes>

### After implementing
1. Run the repo-appropriate formatter/linter command(s) if configured (for example: `xcrun swift-format format --in-place --recursive --configuration .swift-format .` for Swift repos, or `bunx eslint .` for JS/TS repos) — must pass
2. Follow the "How to commit" steps above
3. Commit message: `"<message>"`

## Commit 2: <imperative description>

... (repeat for each commit)

## Final Steps

1. Run the repo-appropriate formatter/linter command(s) one final time (if configured)
2. Report: branch name, each commit (hash + message)
```

Every plan you write MUST include the full "Version Control Rules" section verbatim. Do not abbreviate it, do not say "see the gitbutler skill," do not assume the executing agent knows how `but` works. The plan is the only document the agent will have.

Wait for user approval before implementing.

## Step 5 — Implement

Execute the approved plan. Follow each commit boundary exactly. Use the `but` commands as written in the plan.

## Reminders

- The `gitbutler` skill is your reference during planning. But the PLAN must be self-contained.
- Read-only `git` commands (`git log`, `git blame`) are fine.
- If `but` fails unexpectedly, run `but skill check` to verify CLI version.
