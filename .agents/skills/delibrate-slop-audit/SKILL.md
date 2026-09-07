---
name: delibrate-slop-audit
description: Use this skill only when the user asks you to use it. Never else.
---

I want you to do a thorough slop audit of this codebase. Look for:
- dead code
- useless tests, checking if things have been removed, or any other test that is just not bringing value
- unnecessary function stubs and wrappers
- TypeScript that looks like it was written by a Python dev
- all the different types of patterns and messy code that can slowly sneak into a codebase with a lot of agents
Be thorough in your investigation. Use Fable 5.1 for all subagents that you spin up during the investigation and come back to me with a thorough report of the different types of slop you find and where they are, and what your proposal will be to fix them
