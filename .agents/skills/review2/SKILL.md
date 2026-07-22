---
name: review2
description: Review your code with 2 adversarial review subagents
---

Start two reviewer subagents. The reviewer's only job: find bugs & reasons why the code does not work.
You run a loop:
- run 2 reviewers
- if either of them has feedback, implement it, fix your code
- repeat until both say lgtm

Here are important things to keep in mind:
- You explain the purpose of your changes and why you made them so the reviewer has context
- Each review spawns a new subagent with fresh context
- You reference which files you edited. The reviewer checks git diff to see your changes in local working copy dirty files
- If your work is already commited, reference the commit
- The reviewer **has** to read the code changes you made yourself. Just mention the files / commit id, your goal, and the reviewers goal of finding bugs. That's it.
