#!/usr/bin/env bash
set -euo pipefail

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

branch_is_open() {
    local branch_name="$1"
    but status --json | jq -e --arg branch_name "$branch_name" '
        .stacks[]? | .branches[]? | select(.name == $branch_name)
    ' >/dev/null
}

create_pr_with_ai_fallback() {
    local branch_name="$1"
    local pr_message_file
    local ai_stderr_file
    local ai_output
    local ai_error

    pr_message_file="$(mktemp)"
    ai_stderr_file="$(mktemp)"

    if ai_output="$(but branch show "$branch_name" --ai 2>"$ai_stderr_file")"; then
        # Drop leading blank lines so the PR body starts with meaningful content.
        ai_output="$(printf '%s\n' "$ai_output" | sed '/./,$!d')"
        if [[ -n "${ai_output//[[:space:]]/}" ]]; then
            {
                printf 'AI summary for %s\n\n' "$branch_name"
                printf '%s\n' "$ai_output"
            } >"$pr_message_file"

            but pr new "$branch_name" -F "$pr_message_file"
            rm -f "$pr_message_file" "$ai_stderr_file"
            return
        fi
    fi

    ai_error="$(tr '\n' ' ' <"$ai_stderr_file" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    if [[ -n "$ai_error" ]]; then
        echo "AI summary unavailable for $branch_name: $ai_error" >&2
    else
        echo "AI summary unavailable for $branch_name; falling back to default PR content." >&2
    fi

    rm -f "$pr_message_file" "$ai_stderr_file"
    but pr new "$branch_name" -t
}

main() {
    require_command but
    require_command jq

    mapfile -t open_branches < <(but status --json | jq -r '.stacks[]? | .branches[]? | .name')

    if [[ "${#open_branches[@]}" -eq 0 ]]; then
        echo "No open GitButler virtual branches found."
        exit 0
    fi

    local total="${#open_branches[@]}"
    local index=0
    local branch_name

    for branch_name in "${open_branches[@]}"; do
        index=$((index + 1))
        echo ""
        echo "[$index/$total] Processing branch: $branch_name"

        if ! branch_is_open "$branch_name"; then
            echo "Skipping $branch_name because it is no longer open."
            continue
        fi

        echo "  1/4 Force push"
        but push "$branch_name" --with-force

        echo "  2/4 Create PR (AI summary, fallback to default)"
        create_pr_with_ai_fallback "$branch_name"

        if ! branch_is_open "$branch_name"; then
            echo "Skipping merge/pull for $branch_name because it is no longer open."
            continue
        fi

        echo "  3/4 Merge"
        but merge "$branch_name"

        # `but merge` already updates branches, but we run an explicit pull per request.
        echo "  4/4 Pull"
        but pull
    done
}

main "$@"
