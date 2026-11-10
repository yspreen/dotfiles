#!/bin/bash
# Git pre-commit hook (installed by decrypt-ssh.sh).
cd "$(git rev-parse --show-toplevel)" || exit 1

grep -v '^#' scripts/copied-files.txt | while read -r live repo; do
    mkdir -p "$(dirname "$repo")" && cp "$HOME/$live" "$repo" 2>/dev/null && git add "$repo" 2>/dev/null
done

# Claude's user MCP servers live in ~/.claude.json (otherwise runtime state). Env may hold tokens, so keep them encrypted.
jq '.mcpServers' ~/.claude.json >secrets/claude-mcp-servers.json 2>/dev/null

scripts/encrypt-ssh.sh
git status --porcelain | grep -q .ssh_enc && git add .ssh_enc
exit 0
