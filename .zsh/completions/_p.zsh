#compdef p

_p() {
    local projects_dir="$HOME/Documents/proj"
    local input cur prefix base_path

    # The argument being completed
    input=$words[CURRENT]

    if [[ "$input" == *"/"* ]]; then
        # If there's at least one slash, separate the prefix (everything before the last slash)
        # from the current partial directory name.
        prefix="${input%/*}/"
        cur="${input##*/}"
        base_path="$projects_dir/${input%/*}"
    else
        prefix=""
        cur="$input"
        base_path="$projects_dir"
    fi

    # List directories (using /N to avoid errors if no match)
    local -a dirs
    dirs=($base_path/*(/N))

    local -a completions
    for d in $dirs; do
        local dname=${d:t}
        # Make case-insensitive comparison - check if cur is a substring of dname
        if [[ "${(L)dname}" == *"${(L)cur}"* ]]; then
            completions+=("${dname}")
        fi
    done

    # Use compadd with proper options that won't erase input
    if ((${#completions})); then
        # Remove -U and use standard completion
        _wanted dirs expl 'project directory' compadd -S '/' -p "$prefix" -- $completions
    fi
}

if [ "$funcstack[1]" = "_p" ]; then
    _p "$@"
else
    compdef _p p
fi
_p somestringtoinit >/dev/null
