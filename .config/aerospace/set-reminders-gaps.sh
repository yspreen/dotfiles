#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

workspace="${1:-}"
reload="${2:-reload}"
config_file="/Users/user/dotfiles/.aerospace.toml"

if [ "$workspace" = "U" ]; then
    inner_horizontal=12
    inner_vertical=12
    outer_bottom=300
    outer_left=463
    outer_right=463
    outer_top=260
else
    inner_horizontal=12
    inner_vertical=12
    outer_bottom=12
    outer_left=12
    outer_right=12
    outer_top=12
fi

desired_gaps="[gaps]
inner.horizontal = $inner_horizontal
inner.vertical = $inner_vertical
outer.bottom = $outer_bottom
outer.left = $outer_left
outer.right = $outer_right
outer.top = $outer_top"

current_gaps=$(perl -0ne 'print $1 if /(\[gaps\]\ninner\.horizontal = \d+\ninner\.vertical = \d+\nouter\.bottom = \d+\nouter\.left = \d+\nouter\.right = \d+\nouter\.top = \d+)/' "$config_file")

if [ "$current_gaps" = "$desired_gaps" ]; then
    exit 0
fi

perl -0pi -e "
s/\\[gaps\\]\\ninner\\.horizontal = \\d+\\ninner\\.vertical = \\d+\\nouter\\.bottom = \\d+\\nouter\\.left = \\d+\\nouter\\.right = \\d+\\nouter\\.top = \\d+/[gaps]\\ninner.horizontal = $inner_horizontal\\ninner.vertical = $inner_vertical\\nouter.bottom = $outer_bottom\\nouter.left = $outer_left\\nouter.right = $outer_right\\nouter.top = $outer_top/
" "$config_file"

if [ "$reload" != "--no-reload" ]; then
    aerospace_bin="${AEROSPACE_BIN:-$(command -v aerospace || true)}"
    if [ -z "$aerospace_bin" ]; then
        for candidate in /opt/homebrew/bin/aerospace /usr/local/bin/aerospace; do
            [ -x "$candidate" ] && aerospace_bin="$candidate" && break
        done
    fi
    [ -n "$aerospace_bin" ] && "$aerospace_bin" reload-config --no-gui
fi
