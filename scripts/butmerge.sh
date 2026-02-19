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
    jq -c '
        . as $root
        | (($root.body | fromjson?) // null) as $parsed
        | {
            title: (
                if ($parsed | type) == "object" and ($parsed | has("title")) and ($parsed | has("body"))
                then $parsed.title
                else $root.title
                end
                | tostring
                | gsub("^\\s+|\\s+$"; "")
            ),
            body: (
                if ($parsed | type) == "object" and ($parsed | has("title")) and ($parsed | has("body"))
                then $parsed.body
                else $root.body
                end
                | tostring
                | gsub("^\\s+|\\s+$"; "")
            )
        }
    '
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
        ($title | test("^pr\\s*(description|json|title)\\b|^untitled$|^update$|^changes?$|ready to help|awaiting instructions|placeholder|test title"; "i") | not) and
        ($body | test("ready to help|awaiting instructions|i can.t|i cannot|unable to|error:"; "i") | not) and
        ($body | test("^\\s*\\{\\s*\"title\"\\s*:\\s*\""; "i") | not) and
        ($body | test("\\\\\"title\\\\\"\\s*:\\s*\\\\\""; "i") | not) and
        ($body | test("(^|\\n)-\\s+"))
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

normalize_commit_subject() {
    local subject="$1"
    local cleaned

    cleaned="$(printf '%s' "$subject" | sed -E 's/^[a-z]+(\([^)]+\))?!?:[[:space:]]*//')"
    cleaned="$(printf '%s' "$cleaned" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//; s/[.]$//')"
    printf '%s' "$cleaned"
}

strip_ansi() {
    sed -E $'s/\x1b\\[[0-9;]*[[:alpha:]]//g'
}

default_pr_json_for_branch() {
    local branch_name="$1"
    local branch_details="$2"
    local clean_details
    local default_title
    local default_body
    local commit_subjects
    local first_subject
    local cleaned_subject
    local file_bullets

    clean_details="$(printf '%s\n' "$branch_details" | strip_ansi)"

    commit_subjects="$(printf '%s\n' "$clean_details" | sed -E -n 's/^[0-9a-fA-F]{7,40}[[:space:]]+//p' | head -n 6)"
    first_subject="$(printf '%s\n' "$commit_subjects" | head -n 1)"
    cleaned_subject="$(normalize_commit_subject "$first_subject")"

    if [[ -n "${cleaned_subject//[[:space:]]/}" && "${#cleaned_subject}" -ge 10 ]]; then
        default_title="$cleaned_subject"
    else
        default_title="$(printf '%s' "$branch_name" | tr '-' ' ')"
    fi

    default_title="$(printf '%s' "$default_title" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    default_title="$(printf '%s' "$default_title" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    if [[ "${#default_title}" -gt 90 ]]; then
        default_title="$(printf '%s' "$default_title" | cut -c1-90 | sed 's/[[:space:]]*$//')"
    fi

    default_body=""
    if [[ -n "${commit_subjects//[[:space:]]/}" ]]; then
        default_body="- Summary of changes:\n"
        while IFS= read -r subject_line; do
            [[ -z "${subject_line//[[:space:]]/}" ]] && continue
            cleaned_subject="$(normalize_commit_subject "$subject_line")"
            if [[ -n "${cleaned_subject//[[:space:]]/}" ]]; then
                default_body+="- ${cleaned_subject}\n"
            fi
        done <<<"$commit_subjects"
    fi

    file_bullets="$(printf '%s\n' "$clean_details" | sed -E -n 's/^[[:space:]]{4,}([^[:space:]][^(]*)[[:space:]]*[(].*$/- \1/p' | sed 's/[[:space:]]*$//' | head -n 6)"
    if [[ -n "${file_bullets//[[:space:]]/}" ]]; then
        default_body+=$'\n- Files touched:\n'
        default_body+="$file_bullets"$'\n'
    fi

    if [[ -z "${default_body//[[:space:]]/}" ]]; then
        default_body="- Summary of changes:\n- Updates from branch $branch_name"
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
        printf '%s\n' "$pr_json" | validate_pr_json_shape &&
        printf '%s\n' "$pr_json" | validate_pr_json_quality; then
        printf '%s\n' "$pr_json" | normalize_pr_json
        return
    fi

    default_pr_json_for_branch "$branch_name" "$branch_details" | normalize_pr_json
}

build_branch_details() {
    local branch_name="$1"
    local branch_json
    local commit_lines
    local file_lines
    local commit_count
    local commit_sha
    local raw_files

    branch_json="$(but status --json | jq -c --arg branch_name "$branch_name" '
        first(.stacks[]? | .branches[]? | select(.name == $branch_name)) // empty
    ')"

    if [[ -z "${branch_json//[[:space:]]/}" ]]; then
        but branch show "$branch_name" -f 2>/dev/null || but branch show "$branch_name" 2>/dev/null || printf 'No branch details available.\n'
        return
    fi

    commit_count="$(printf '%s\n' "$branch_json" | jq -r '.commits | length')"
    commit_lines="$(printf '%s\n' "$branch_json" | jq -r '.commits[]? | "\(.commitId[0:7]) \((.message | split("\n")[0]))"')"

    raw_files=""
    while IFS= read -r commit_sha; do
        [[ -z "${commit_sha//[[:space:]]/}" ]] && continue
        raw_files+=$(git show --pretty='' --name-only "$commit_sha" 2>/dev/null || true)
        raw_files+=$'\n'
    done < <(printf '%s\n' "$branch_json" | jq -r '.commits[]?.commitId')

    file_lines="$(printf '%s\n' "$raw_files" | sed '/^$/d' | sort -u | sed 's#^#    #; s#$# (modified)#')"

    printf 'Branch: %s (%s commits ahead)\n\n' "$branch_name" "$commit_count"
    printf '%s\n' "$commit_lines"
    if [[ -n "${file_lines//[[:space:]]/}" ]]; then
        printf '\n%s\n' "$file_lines"
    fi
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
    local title
    local body
    local message
    local pr_create_output

    existing_pr_number="$(find_open_pr_number_for_branch "$branch_name")"
    if [[ -n "$existing_pr_number" ]]; then
        printf '%s\n' "$existing_pr_number"
        return
    fi

    branch_details="$(build_branch_details "$branch_name")"
    pr_json="$(generate_pr_json_for_branch "$branch_name" "$branch_details")"

    if [[ "${BUTMERGE_DEBUG:-0}" == "1" ]]; then
        {
            printf 'DEBUG branch details:\n%s\n' "$branch_details"
            printf 'DEBUG generated pr_json raw:\n%s\n' "$pr_json"
        } >&2
    fi

    pr_json="$(printf '%s\n' "$pr_json" | normalize_pr_json)"
    if ! printf '%s\n' "$pr_json" | validate_pr_json_shape || ! printf '%s\n' "$pr_json" | validate_pr_json_quality; then
        [[ "${BUTMERGE_DEBUG:-0}" == "1" ]] && printf 'DEBUG generated JSON failed validation, using deterministic fallback.\n' >&2
        pr_json="$(default_pr_json_for_branch "$branch_name" "$branch_details" | normalize_pr_json)"
    fi

    [[ "${BUTMERGE_DEBUG:-0}" == "1" ]] && printf 'DEBUG final pr_json:\n%s\n' "$pr_json" >&2

    title="$(printf '%s\n' "$pr_json" | jq -r '.title')"
    body="$(printf '%s\n' "$pr_json" | jq -r '.body')"

    if [[ -z "${title//[[:space:]]/}" || -z "${body//[[:space:]]/}" ]]; then
        pr_json="$(default_pr_json_for_branch "$branch_name" "$branch_details" | normalize_pr_json)"
        title="$(printf '%s\n' "$pr_json" | jq -r '.title')"
        body="$(printf '%s\n' "$pr_json" | jq -r '.body')"
    fi

    # Keep title single-line and strip control chars to avoid CLI parsing issues.
    title="$(printf '%s' "$title" | tr -d '\000-\010\013\014\016-\037\177' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    body="$(printf '%s' "$body" | tr -d '\000-\010\013\014\016-\037\177')"
    body="${body//$'\r'/}"

    if [[ -z "${title//[[:space:]]/}" ]]; then
        title="$(printf '%s' "$branch_name" | tr '-' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    fi
    if [[ -z "${body//[[:space:]]/}" ]]; then
        body="- Updates from branch $branch_name"
    fi

    message="$(printf '%s\n\n%s' "$title" "$body")"

    if [[ "${BUTMERGE_DEBUG:-0}" == "1" ]]; then
        {
            printf 'DEBUG branch: %s\n' "$branch_name"
            printf 'DEBUG title: %s\n' "$title"
            printf 'DEBUG body:\n%s\n' "$body"
            printf 'DEBUG message preview:\n'
            printf '%s\n' "$message" | sed -n '1,12p'
        } >&2
    fi

    pr_create_output="$(but pr new "$branch_name" -m "$message" 2>&1)"
    printf '%s\n' "$pr_create_output" >&2

    existing_pr_number="$(find_open_pr_number_for_branch "$branch_name")"
    if [[ -z "$existing_pr_number" ]]; then
        existing_pr_number="$(printf '%s\n' "$pr_create_output" | grep -Eo '#[0-9]+' | tail -n 1 | tr -d '#')"
    fi
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
