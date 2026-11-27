---
name: slim-ai-history
description: Shrink Codex and Claude Code chat history (~/.codex, ~/.claude, old CODEX_HOME copies) by stripping base64 images/media and capping tool outputs, keeping every user/assistant message, reasoning and tool call intact and resumable. Never touches threads active in the last 30 days. Use when asked to slim, trim, shrink or clean AI/agent chat history or transcripts, or when ~/.codex or ~/.claude takes too much disk.
---

# Slim AI history

Script: `~/.agents/skills/slim-ai-history/slim.py`

```
python3 -I ~/.agents/skills/slim-ai-history/slim.py --dry-run ~/.codex ~/.claude   # counts only
python3 -I ~/.agents/skills/slim-ai-history/slim.py ~/.codex ~/.claude
```

Any Codex home works (`~/dotfiles/.codex2/.codex`). The script finds Codex rollouts under `sessions/` and `archived_sessions/`, and Claude Code sessions under `projects/<project>/<session>.jsonl` plus `projects/<project>/<session>/` (subagents, tool-results, workflows).

## 30-day rule

Never trim or include anything newer than 30 days. A thread counts as active if any of its files was modified in the last 30 days (`DAYS = 30`). Active threads are skipped entirely, including their subagent and tool-result files. Threads:
- Codex: grouped by the first UUID in the rollout filename, so `rollout-...-<parent>_<child>.jsonl` subagent files stay with their parent.
- Claude Code: `<project>/<session-uuid>` (the main `.jsonl` plus the `<session-uuid>/` folder).

If a file changes while it is being processed, the script skips it.

## What gets removed

- Base64 media is replaced with the text `[image removed]`. That covers `input_image`, Claude `image`/`document` blocks with a base64 `source`, MCP `{type: image, data}`, generated images, and data-URL strings. Block types stay valid for the API (`input_text` / `text`).
- Data URLs embedded inside other text become `data:<mime>;base64,[removed]`.
- Tool output strings over 2,100 chars keep their first 1,500 and last 500 chars, with a `[... N chars of tool output removed ...]` marker. Tool output means anything under `output`, `stdout`, `stderr`, `aggregated_output`, `formatted_output`, `result`, `toolUseResult`, or `tool_result.content`.
- Claude `tool-results/` files: media (png/jpg/pdf...) is deleted and text files are capped like tool output.
- Codex `token_count` events (usage stats only) are dropped.
- Codex `thread_history_1.sqlite`: rows for slimmed threads are deleted, because they store byte offsets into the old rollouts. Codex re-projects them from the files.

## What is kept unchanged

User and assistant messages, reasoning/thinking text, `signature` and `encrypted_content` (needed for resume), tool calls and their arguments, file edits, and system prompts. File mtimes are restored, so T3's import window and recency ordering don't shift.

## Safety

- Every rewritten line is checked: all non-tool, non-media strings must be identical before and after, or the file is left untouched and listed as failed.
- No backups. The user does not want them: slimmed files are replaced in place and the removed media and tool output are gone for good. Never add a backup step.
- Rerunning is safe. Already-slimmed lines come out the same.
- Report MiB before/after per home, and any failed files.
