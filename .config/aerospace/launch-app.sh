#!/bin/bash

# Usage: launch-app.sh <workspace_letter> <app_name>
# Example: launch-app.sh A Safari

workspace_letter="$1"
app_name="$2"
full_screen="$3"
aerospace_bin="/usr/local/bin/aerospace"

if [ -z "$workspace_letter" ] || [ -z "$app_name" ]; then
    echo "Usage: $0 <workspace_letter> <app_name>"
    echo "Example: $0 A Safari"
    exit 1
fi

focused_workspace=$("$aerospace_bin" list-workspaces --focused)
"$aerospace_bin" workspace "$workspace_letter"

window_count=$("$aerospace_bin" list-windows --workspace "$workspace_letter" --count)
if [ "$focused_workspace" = "$workspace_letter" ] || [ "$window_count" -eq 0 ]; then
    open -a "$app_name"

    if [ "$full_screen" = "f" ]; then
        for _ in {1..30}; do
            window_count=$("$aerospace_bin" list-windows --workspace "$workspace_letter" --count)
            [ "$window_count" -gt 0 ] && break
            sleep 0.1
        done
    fi
fi

[ "$full_screen" = "f" ] && "$aerospace_bin" fullscreen
