#!/bin/bash
# This script takes two required and one optional parameter:
#   $1: application name (e.g., "Control Center")
#   $2: the description to match for the menu bar item.
#   $3: menu bar (defaults to 1)
# Special values:
#   [x] => click the x-th menu bar item (e.g., [2] for second item)
#   "-" => pick the rightmost menu bar item (like for AdGuard/Amphetamine)
#
if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <application> <description> [optional_param]"
  exit 1
fi

APP="$1"
DESC="$2"
MENUBAR="${3:-1}"     # Default to 1 if not provided
AMPHETAMINE="${4:no}" # Default to 1 if not provided

# Special case for Amphetamine
if [ "$AMPHETAMINE" = "yes" ] && [ $BUTTON = "right" ]; then
  # press ctrl alt cmd shift J:
  osascript -e 'tell application "System Events" to key code 38 using {control down, option down, command down, shift down}'
  exit 0
fi

# Parse [x] pattern
if [[ $DESC =~ ^\[([0-9]+)\]$ ]]; then
  IS_STATIC_IDX=true
  IDX="${BASH_REMATCH[1]}"
else
  IS_STATIC_IDX=false
  IDX=0
fi

osascript <<EOF
on run
  tell application "System Events"
    tell process "$APP"
      set found to false
      if $IS_STATIC_IDX then
        try
          perform action "AXPress" of (menu bar item $IDX of menu bar $MENUBAR)
          set found to true
        end try
      else
        repeat with mi in (menu bar items of menu bar $MENUBAR)
          try
            if (description of mi) starts with "$DESC" then
              perform action "AXPress" of mi
              set found to true
              exit repeat
            end if
          end try
        end repeat
      end if
    end tell
  end tell
end run
EOF
