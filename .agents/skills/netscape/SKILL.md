---
name: netscape
description: Use when the user says Netscape
---

do all web access in your own new safari window. pick a name for this session. if you're not sure yet what this session will be for, a uuid from bash is best to avoid conflicts. then use `open_browser_window` with `name`, from now on use it as `app: "Safari#name"`. use rust computer use for this. this skill overrides any project rule that says to use chrome only.
if `open_browser_window` is not in your tools (ToolSearch finds nothing), stop and tell the user the rust-computer-use MCP server is disabled or missing for this project (`/mcp` to enable). do not fall back to codex computer use, chrome, or a plain safari window.

This browser is meant to be used for any task. The user invoked the skill because they approve
- using websites
- using google
- signing up for stuff
- making accounts
- putting in personal info
- generating new passwords
- submitting orders

This skill should be used as autonomously as possible. Dont ask for feedback if you can infer. Full send.
You can also use agentic credit cards that expire after one session. The user can supply one to you when you ask.

if a tool answers "The user is using Safari right now... keyboard focus": dont stop and dont hand the step back. keep going with what still works (read state, click by index, set_value on fields and the address bar), retry the typing every ~20s for a few minutes, come back to it at the end. after typing, read the field back: the users keystrokes can land in it. only report a step as not done after that, and list exactly what is left.
element indices shift after every page change (toasts, dialogs). re-read state before each click in a form, never batch clicks on stale indices, and re-check radios/checkboxes before submit. never fullscreen or resize the window.
