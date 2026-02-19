#!/usr/bin/env bash
set -euo pipefail

PR_JSON_SCHEMA='{"type":"object","properties":{"title":{"type":"string"},"body":{"type":"string"}},"required":["title","body"],"additionalProperties":false}'
GH_MERGE_AVAILABLE=0

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

normalize_pr_json() {
    jq -c '{
        title: (.title | gsub("^\\s+|\\s+$"; "")),
        body: (.body | gsub("^\\s+|\\s+$"; ""))
    }'
}

validate_pr_json_shape() {
    jq -e '
        type == "object" and
        (.title | type == "string") and
        (.body | type == "string") and
        (.title | gsub("^\\s+|\\s+$"; "") | length >= 10) and
        (.title | length <= 120) and
        (.body | gsub("^\\s+|\\s+$"; "") | length >= 40)
    ' >/dev/null
}

validate_pr_json_quality() {
    jq -e '
        (.title | ascii_downcase) as $title |
        (.body | ascii_downcase) as $body |
        (.title | gsub("^\\s+|\\s+$"; "") | length >= 12) and
        (.body | gsub("^\\s+|\\s+$"; "") | length >= 60) and
        ($title | test("ready to help|awaiting instructions|test title|untitled|placeholder"; "i") | not) and
        ($body | test("ready to help|awaiting instructions|i can.t|i cannot|unable to|error:"; "i") | not)
    ' >/dev/null
}

extract_json_line() {
    local raw_text="$1"
    printf '%s\n' "$raw_text" | sed -n 's/^[[:space:]]*//;s/[[:space:]]*$//;/^{.*}$/p' | tail -n 1
}

build_pr_prompt() {
    local branch_name="$1"
    local branch_details="$2"
    cat <<EOF
Write a GitHub pull request title and description for branch "$branch_name".

Return exactly one JSON object on a single line in this format:
{"title":"...","body":"..."}

Rules:
- No Markdown code fences.
- Use only keys "title" and "body".
- Title should be imperative and specific (10-80 chars).
- Body should be concise and technical with bullet points and no placeholders.
- Do not mention AI, model output, or the prompt.

Branch details:
$branch_details
EOF
}

default_pr_json_for_branch() {
    local branch_name="$1"
    local branch_details="$2"
    local default_title
    local default_body

    default_title="$(printf '%s' "$branch_name" | tr '-' ' ')"
    default_body="$(printf '%s\n' "$branch_details" | sed -n 's/^[[:xdigit:]]\{7\}[[:space:]]\+/- /p' | head -n 5)"
    if [[ -z "${default_body//[[:space:]]/}" ]]; then
        default_body="- Updates from branch $branch_name"
    fi

    jq -nc \
        --arg title "$default_title" \
        --arg body "$default_body" \
        '{title: $title, body: $body}'
}

generate_pr_json_with_claude() {
    local prompt_text="$1"
    local raw_output
    local structured_output

    command -v claude >/dev/null 2>&1 || return 1

    set +e
    raw_output="$(claude -p "$prompt_text" --output-format json --json-schema "$PR_JSON_SCHEMA" 2>/dev/null)"
    local status=$?
    set -e
    [[ $status -eq 0 ]] || return 1

    structured_output="$(printf '%s\n' "$raw_output" | jq -cr '.structured_output // empty' 2>/dev/null || true)"
    [[ -n "$structured_output" ]] || return 1
    printf '%s\n' "$structured_output"
}

generate_pr_json_with_codex() {
    local prompt_text="$1"
    local schema_file
    local message_file
    local stdout_file
    local stderr_file
    local raw_output

    command -v codex >/dev/null 2>&1 || return 1

    schema_file="$(mktemp)"
    message_file="$(mktemp)"
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"

    printf '%s\n' "$PR_JSON_SCHEMA" >"$schema_file"

    set +e
    printf '%s\n' "$prompt_text" | codex exec - --output-schema "$schema_file" --output-last-message "$message_file" >"$stdout_file" 2>"$stderr_file"
    local status=$?
    set -e

    if [[ $status -ne 0 ]]; then
        rm -f "$schema_file" "$message_file" "$stdout_file" "$stderr_file"
        return 1
    fi

    raw_output="$(cat "$message_file" 2>/dev/null || true)"
    if [[ -z "${raw_output//[[:space:]]/}" ]]; then
        raw_output="$(cat "$stdout_file" 2>/dev/null || true)"
    fi

    rm -f "$schema_file" "$message_file" "$stdout_file" "$stderr_file"
    [[ -n "${raw_output//[[:space:]]/}" ]] || return 1

    printf '%s\n' "$(extract_json_line "$raw_output")"
}

generate_pr_json_for_branch() {
    local branch_name="$1"
    local branch_details="$2"
    local prompt_text
    local pr_json

    prompt_text="$(build_pr_prompt "$branch_name" "$branch_details")"

    pr_json="$(generate_pr_json_with_claude "$prompt_text" || true)"
    if [[ -n "${pr_json//[[:space:]]/}" ]] &&
        printf '%s\n' "$pr_json" | validate_pr_json_shape &&
        printf '%s\n' "$pr_json" | validate_pr_json_quality; then
        printf '%s\n' "$pr_json" | normalize_pr_json
        return
    fi

    pr_json="$(generate_pr_json_with_codex "$prompt_text" || true)"
    if [[ -n "${pr_json//[[:space:]]/}" ]] &&
        printf '%s\n' "$pr_json" | validate_pr_json_shape; then
        printf '%s\n' "$pr_json" | normalize_pr_json
        return
    fi

    default_pr_json_for_branch "$branch_name" "$branch_details" | normalize_pr_json
}

find_open_pr_number_for_branch() {
    local branch_name="$1"
    gh pr list --state open --head "$branch_name" --json number --limit 1 | jq -r '.[0].number // empty'
}

create_or_get_pr_number() {
    local branch_name="$1"
    local existing_pr_number
    local branch_details
    local pr_json
    local pr_message_file
    local title
    local body

    existing_pr_number="$(find_open_pr_number_for_branch "$branch_name")"
    if [[ -n "$existing_pr_number" ]]; then
        printf '%s\n' "$existing_pr_number"
        return
    fi

    branch_details="$(but branch show "$branch_name" -f 2>/dev/null || but branch show "$branch_name" 2>/dev/null || printf 'No branch details available.\n')"
    pr_json="$(generate_pr_json_for_branch "$branch_name" "$branch_details")"
    title="$(printf '%s\n' "$pr_json" | jq -r '.title')"
    body="$(printf '%s\n' "$pr_json" | jq -r '.body')"

    pr_message_file="$(mktemp)"
    {
        printf '%s\n\n' "$title"
        printf '%s\n' "$body"
    } >"$pr_message_file"

    but pr new "$branch_name" -F "$pr_message_file"
    rm -f "$pr_message_file"

    existing_pr_number="$(find_open_pr_number_for_branch "$branch_name")"
    if [[ -z "$existing_pr_number" ]]; then
        echo "Failed to discover PR number after creating PR for $branch_name" >&2
        exit 1
    fi

    printf '%s\n' "$existing_pr_number"
}

merge_pr_number() {
    local pr_number="$1"

    if [[ "$GH_MERGE_AVAILABLE" -eq 1 ]]; then
        gh merge -m "$pr_number"
        return
    fi

    gh pr merge "$pr_number" --merge
}

main() {
    require_command but
    require_command jq
    require_command gh

    if gh merge --help >/dev/null 2>&1; then
        GH_MERGE_AVAILABLE=1
    fi

    mapfile -t open_branches < <(but status --json | jq -r '.stacks[]? | .branches[]? | [.name, (.commits | length)] | @tsv')

    if [[ "${#open_branches[@]}" -eq 0 ]]; then
        echo "No open GitButler virtual branches found."
        exit 0
    fi

    local total="${#open_branches[@]}"
    local index=0
    local branch_name
    local commit_count
    local branch_row
    local pr_number

    for branch_row in "${open_branches[@]}"; do
        index=$((index + 1))
        branch_name="${branch_row%%$'\t'*}"
        commit_count="${branch_row#*$'\t'}"
        echo ""
        echo "[$index/$total] Processing branch: $branch_name"

        if [[ "$commit_count" -eq 0 ]]; then
            echo "Skipping $branch_name because it has no commits."
            continue
        fi

        if ! branch_is_open "$branch_name"; then
            echo "Skipping $branch_name because it is no longer open."
            continue
        fi

        echo "  1/4 Force push"
        but push "$branch_name" --with-force

        echo "  2/4 Create or reuse PR (Claude -> Codex -> default)"
        pr_number="$(create_or_get_pr_number "$branch_name")"
        echo "  Using PR #$pr_number"

        if ! branch_is_open "$branch_name"; then
            echo "Skipping merge/pull for $branch_name because it is no longer open."
            continue
        fi

        echo "  3/4 Merge PR"
        merge_pr_number "$pr_number"

        echo "  4/4 Pull"
        but pull
    done
}

main "$@"
