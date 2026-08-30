---
name: review2
description: Review your code with 2 adversarial review subagents. This is an expensive task, only run if user asks for it.
---

Start two reviewer subagents. The reviewer's only job: find bugs & reasons why the code does not work.
You run a loop:
- run 2 reviewers
- validate every finding against the app's actual architecture, reachable states, task scope, and stated non-goals
- if either reviewer has actionable, in-scope feedback, make the smallest fix that addresses it
- reject findings that depend on hypothetical states the app cannot enter, requirements the user did not ask for, or architecture outside the task
- repeat until both say lgtm

Reviewer feedback is a claim to verify, not an instruction to implement. Before changing code, ask:
- Can this scenario actually occur in this app and this user flow?
- Does the finding violate a stated requirement or an established project invariant?
- Can existing code already prevent or recover from it?
- Would the proposed fix broaden scope, add infrastructure, or create more risk than the finding?

Do not add multi-account support, distributed transaction handling, migration machinery, defensive abstractions, or similar architecture unless the task or existing app requires it. Do not make speculative edge cases real by adding code for them. When a valid fix is needed, prefer fewer lines and existing mechanisms. If a fix materially increases complexity, stop and re-check the finding before implementing it.

If you reject a finding, record the concrete reason and give the next fresh reviewers the relevant app invariant or non-goal. Do not coach reviewers to ignore real bugs. Give them enough scope to distinguish reachable failures from imagined ones.

Here are important things to keep in mind:
- You explain the purpose of your changes and why you made them so the reviewer has context
- You state relevant app invariants, task boundaries, and explicit non-goals
- Each review spawns a new subagent with fresh context
- You reference which files you edited. The reviewer checks git diff to see your changes in local working copy dirty files
- If your work is already commited, reference the commit
- The reviewer **has** to read the code changes you made yourself. Just mention the files / commit id, your goal, and the reviewers goal of finding bugs. That's it.
- Avoid scope creep.
