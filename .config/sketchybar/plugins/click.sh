#!/bin/bash
# This script takes two required and one optional parameter:
#   $1: application name (e.g., "Control Center")
#   $2: the description to match for the menu bar item.
#   $3: menu bar (defaults to 1)
# Special values:
#   [x] => click the x-th menu bar item (e.g., [2] for second item)
#   "-" => pick the rightmost menu bar item (like for AdGuard/Amphetamine)
#   "help=text" => match menu item by help text containing "text"
#   "help!=text" => match menu item where help text does not contain "text"
#
if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <application> <description> [menubar_index] [amphetamine]"
  exit 1
fi

APP="$1"
DESC="$2"
MENUBAR="${3:-1}"      # Default to 1 if not provided
AMPHETAMINE="${4:-no}" # Default to no if not provided

# Special case for Amphetamine
if [ "$AMPHETAMINE" = "yes" ] && [ "$BUTTON" = "right" ]; then
  # press ctrl alt cmd shift J:
  osascript -e 'tell application "System Events" to key code 38 using {control down, option down, command down, shift down}'
  exit 0
fi

# Check for special mode patterns
IS_STATIC_IDX=false
IDX=0

# Check for help text pattern
HELP_MODE=""
HELP_VALUE=""

if [[ $DESC =~ ^help=(.+)$ ]]; then
  HELP_MODE="equal"
  HELP_VALUE="${BASH_REMATCH[1]}"
elif [[ $DESC =~ ^help!=(.+)$ ]]; then
  HELP_MODE="notequal"
  HELP_VALUE="${BASH_REMATCH[1]}"
# Parse [x] pattern for static index
elif [[ $DESC =~ ^\[([0-9]+)\]$ ]]; then
  IS_STATIC_IDX=true
  IDX="${BASH_REMATCH[1]}"
fi

# Regular operation mode
osascript <<EOF
on run
  tell application "System Events"
    tell process "$APP"
      set found to false
      
      -- Case 1: Static index mode
      if $IS_STATIC_IDX then
        try
          perform action "AXPress" of (menu bar item $IDX of menu bar $MENUBAR)
          set found to true
        end try
      
      -- Case 2: Help text equal mode
      else if "$HELP_MODE" is "equal" then
        repeat with mi in (menu bar items of menu bar $MENUBAR)
          try
            set helpText to help of mi
            if helpText contains "$HELP_VALUE" then
              perform action "AXPress" of mi
              set found to true
              exit repeat
            end if
          end try
        end repeat
      
      -- Case 3: Help text not equal mode
      else if "$HELP_MODE" is "notequal" then
        repeat with mi in (menu bar items of menu bar $MENUBAR)
          try
            set helpText to help of mi
            if helpText does not contain "$HELP_VALUE" then
              perform action "AXPress" of mi
              set found to true
              exit repeat
            end if
          end try
        end repeat
      
      -- Case 4: Description/name matching (standard mode)
      else
        -- Try by description first
        repeat with mi in (menu bar items of menu bar $MENUBAR)
          try
            if (description of mi) starts with "$DESC" then
              perform action "AXPress" of mi
              set found to true
              exit repeat
            end if
          end try
        end repeat
        
        -- If not found, try by name
        if not found then
          repeat with mi in (menu bar items of menu bar $MENUBAR)
            try
              if (name of mi) starts with "$DESC" then
                perform action "AXPress" of mi
                set found to true
                exit repeat
              end if
            end try
          end repeat
        end if
        
        -- If still not found, try by help text
        if not found then
          repeat with mi in (menu bar items of menu bar $MENUBAR)
            try
              if (help of mi) contains "$DESC" then
                perform action "AXPress" of mi
                set found to true
                exit repeat
              end if
            end try
          end repeat
        end if
      end if
      
      if not found then
        if "$HELP_MODE" is not "" then
          return "Could not find menu item with help text criteria: $DESC"
        else
          return "Could not find menu item with description, name or help: $DESC"
        end if
      else
        return "Successfully clicked menu item: $DESC"
      end if
    end tell
  end tell
end run
EOF
