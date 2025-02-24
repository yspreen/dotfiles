#compdef p

_p() {
    local projects_dir="$HOME/Documents/proj"
    local cur="${words[CURRENT]}"
    local parts=(${(s:/:)cur})
    local base_path="$projects_dir"
    
    # If there's a partial path, use it as base
    if [[ ${#parts} -gt 1 ]]; then
        base_path="$projects_dir/${(j:/:)parts[1,-2]}"
        cur="${parts[-1]}"
    fi
    
    # Generate completions
    local -a completions
    completions=($(find "$base_path" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
    
    _describe 'projects' completions
}

if [ "$funcstack[1]" = "_p" ]; then
    _p "$@"
else
    compdef _p p
fi