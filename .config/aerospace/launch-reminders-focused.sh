#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

workspace_letter="U"
app_name="Reminders"
app_id="com.apple.reminders"
aerospace_bin="${AEROSPACE_BIN:-$(command -v aerospace || true)}"
if [ -z "$aerospace_bin" ]; then
    for candidate in /opt/homebrew/bin/aerospace /usr/local/bin/aerospace; do
        [ -x "$candidate" ] && aerospace_bin="$candidate" && break
    done
fi

[ -n "$aerospace_bin" ] || exit 1

/Users/user/dotfiles/.config/aerospace/set-reminders-gaps.sh "$workspace_letter"

open -g -a "$app_name"

window_id=""
for _ in {1..40}; do
    window_id=$("$aerospace_bin" list-windows --monitor all --app-bundle-id "$app_id" --format '%{window-id}' | head -n 1)
    [ -n "$window_id" ] && break
    sleep 0.1
done

[ -n "$window_id" ] || exit 0

"$aerospace_bin" move-node-to-workspace --window-id "$window_id" "$workspace_letter" || true
"$aerospace_bin" layout --window-id "$window_id" tiles || true
"$aerospace_bin" workspace "$workspace_letter" || true
"$aerospace_bin" focus --window-id "$window_id" || true
osascript -e "tell application \"$app_name\" to activate"
