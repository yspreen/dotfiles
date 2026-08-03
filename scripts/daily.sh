#!/bin/bash

exec >/dev/null 2>&1

export HOME=/Users/user
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

state_dir="$HOME/.local/state/daily-updates"
stamp="$state_dir/last-run"
lock="$state_dir/lock"
today=$(/bin/date +%F)

/bin/mkdir -p "$state_dir" || exit 0
[ "$(/bin/cat "$stamp" 2>/dev/null)" = "$today" ] && exit 0
/bin/mkdir "$lock" 2>/dev/null || exit 0
trap '/bin/rmdir "$lock" 2>/dev/null || true' EXIT

# Recheck after acquiring the lock in case another invocation just completed.
[ "$(/bin/cat "$stamp" 2>/dev/null)" = "$today" ] && exit 0

/opt/homebrew/bin/brew upgrade claude-code@latest || true
/usr/bin/curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 /bin/sh || true
/opt/homebrew/bin/brew upgrade cliproxyapi || true

printf '%s\n' "$today" >"$stamp.tmp"
/bin/mv "$stamp.tmp" "$stamp"
