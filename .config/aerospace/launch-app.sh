#!/bin/bash

# Usage: launch-app.sh <workspace_letter> <app_name>
# Example: launch-app.sh A Safari

workspace_letter="$1"
app_name="$2"
full_screen="$3"

if [ -z "$workspace_letter" ] || [ -z "$app_name" ]; then
    echo "Usage: $0 <workspace_letter> <app_name>"
    echo "Example: $0 A Safari"
    exit 1
fi

# Get current workspace
current_workspace=$(aerospace list-workspaces --focused)

if [ "$current_workspace" = "$workspace_letter" ]; then
    # Already on target workspace, launch the app
    open -a "$app_name"
else
    # Switch to target workspace
    aerospace workspace "$workspace_letter"

    # Check if workspace is empty (no windows)
    window_count=$(aerospace list-windows --workspace "$workspace_letter" | wc -l)
    if [ "$window_count" -eq 0 ]; then
        # Workspace is empty, launch the app
        open -a "$app_name"
    fi
fi

sleep 0.1
[ "$full_screen" = "f" ] && aerospace fullscreen