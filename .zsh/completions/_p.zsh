#compdef p

_p() {
    local projects_dir="$HOME/Documents/proj"
    local input cur prefix base_path

    # The argument being completed
    input=$words[CURRENT]

    if [[ "$input" == *"/"* ]]; then
        # If there’s at least one slash, separate the prefix (everything before the last slash)
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
        if [[ "$dname" == "$cur"* ]]; then
            completions+=("${prefix}${dname}")
        fi
    done

    # Use compadd with a trailing slash (-S "/") so that the completed directory gets a slash
    if ((${#completions})); then
        compadd -S "/" -- $completions
    fi
}

if [ "$funcstack[1]" = "_p" ]; then
    _p "$@"
else
    compdef _p p
fi
