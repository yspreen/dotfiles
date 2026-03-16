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

run_with_timeout() {
    local timeout_seconds="$1"
    shift

    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -le 0 ]]; then
        "$@"
        return $?
    fi

    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$timeout_seconds" "$@"
        return $?
    fi

    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_seconds" "$@"
        return $?
    fi

    if command -v perl >/dev/null 2>&1; then
        perl -e 'my $t=shift @ARGV; $SIG{ALRM}=sub{exit 124}; alarm($t); exec @ARGV; exit 127;' "$timeout_seconds" "$@"
        return $?
    fi

    "$@"
}

branch_is_open() {
    local branch_name="$1"
    but status --json | jq -e --arg branch_name "$branch_name" '
        .stacks[]? | .branches[]? | select(.name == $branch_name)
    ' >/dev/null
}

remove_virtual_branch() {
    local branch_name="$1"
    if ! branch_is_open "$branch_name"; then
        return 0
    fi
    echo "  Removing virtual branch: $branch_name"
    but unapply "$branch_name" --force 2>/dev/null || true
    git branch -D "$branch_name" 2>/dev/null || true
}

branch_json_for_name() {
    local branch_name="$1"
    but status --json | jq -c --arg branch_name "$branch_name" '
        first(.stacks[]? | .branches[]? | select(.name == $branch_name)) // empty
    '
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
    local timeout_seconds="${BUTMERGE_CLAUDE_TIMEOUT_SECONDS:-45}"
    local raw_output
    local structured_output

    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -le 0 ]]; then
        timeout_seconds=45
    fi

    if [[ "${BUTMERGE_SKIP_CLAUDE:-0}" == "1" ]]; then
        return 1
    fi

    command -v claude >/dev/null 2>&1 || return 1

    set +e
    raw_output="$(run_with_timeout "$timeout_seconds" claude -p "$prompt_text" --output-format json --json-schema "$PR_JSON_SCHEMA" 2>/dev/null)"
    local status=$?
    set -e
    if [[ $status -eq 124 ]]; then
        echo "  [claude] Timed out after ${timeout_seconds}s; continuing with fallback." >&2
        return 1
    fi
    [[ $status -eq 0 ]] || return 1

    structured_output="$(printf '%s\n' "$raw_output" | jq -cr '.structured_output // empty' 2>/dev/null || true)"
    [[ -n "$structured_output" ]] || return 1
    printf '%s\n' "$structured_output"
}

generate_pr_json_with_codex() {
    local prompt_text="$1"
    local timeout_seconds="${BUTMERGE_CODEX_TIMEOUT_SECONDS:-90}"
    local schema_file
    local message_file
    local stdout_file
    local stderr_file
    local raw_output

    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -le 0 ]]; then
        timeout_seconds=90
    fi

    command -v codex >/dev/null 2>&1 || return 1

    schema_file="$(mktemp)"
    message_file="$(mktemp)"
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"

    printf '%s\n' "$PR_JSON_SCHEMA" >"$schema_file"

    set +e
    printf '%s\n' "$prompt_text" | run_with_timeout "$timeout_seconds" codex exec -c 'model_reasoning_effort="medium"' - --output-schema "$schema_file" --output-last-message "$message_file" >"$stdout_file" 2>"$stderr_file"
    local status=$?
    set -e

    if [[ $status -eq 124 ]]; then
        rm -f "$schema_file" "$message_file" "$stdout_file" "$stderr_file"
        echo "  [codex] Timed out after ${timeout_seconds}s; continuing with fallback." >&2
        return 1
    fi

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

    if [[ "${BUTMERGE_SKIP_CLAUDE:-0}" == "1" ]]; then
        echo "  [$branch_name] PR text: skipping Claude (BUTMERGE_SKIP_CLAUDE=1)." >&2
        pr_json=""
    else
        echo "  [$branch_name] PR text: trying Claude..." >&2
        pr_json="$(generate_pr_json_with_claude "$prompt_text" || true)"
    fi
    if [[ -n "${pr_json//[[:space:]]/}" ]] &&
        printf '%s\n' "$pr_json" | validate_pr_json_shape &&
        printf '%s\n' "$pr_json" | validate_pr_json_quality; then
        echo "  [$branch_name] PR text: using Claude output." >&2
        printf '%s\n' "$pr_json" | normalize_pr_json
        return
    fi

    echo "  [$branch_name] PR text: Claude unavailable/skipped/invalid; trying Codex (medium reasoning)..." >&2
    pr_json="$(generate_pr_json_with_codex "$prompt_text" || true)"
    if [[ -n "${pr_json//[[:space:]]/}" ]] &&
        printf '%s\n' "$pr_json" | validate_pr_json_shape &&
        printf '%s\n' "$pr_json" | validate_pr_json_quality; then
        echo "  [$branch_name] PR text: using Codex output." >&2
        printf '%s\n' "$pr_json" | normalize_pr_json
        return
    fi

    echo "  [$branch_name] PR text: using deterministic fallback." >&2
    default_pr_json_for_branch "$branch_name" "$branch_details" | normalize_pr_json
}

single_commit_pr_json_for_branch() {
    local branch_name="$1"
    local branch_json
    local commit_count

    branch_json="$(branch_json_for_name "$branch_name")"
    [[ -n "${branch_json//[[:space:]]/}" ]] || return 1

    commit_count="$(printf '%s\n' "$branch_json" | jq -r '.commits | length')"
    [[ "$commit_count" -eq 1 ]] || return 1

    printf '%s\n' "$branch_json" | jq -c '
        (.commits[0].message // "" | gsub("\r"; "")) as $message
        | ($message | split("\n")) as $lines
        | {
            title: (($lines[0] // "") | gsub("^\\s+|\\s+$"; "")),
            body: (($lines[1:] | join("\n")) | gsub("^\\s+|\\s+$"; ""))
        }
    '
}

build_branch_details() {
    local branch_name="$1"
    local branch_json
    local commit_lines
    local file_lines
    local commit_count
    local commit_sha
    local raw_files

    branch_json="$(branch_json_for_name "$branch_name")"

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
    local branch_json
    local commit_count=0
    local pr_json
    local title
    local body
    local message
    local pr_create_output

    existing_pr_number="$(find_open_pr_number_for_branch "$branch_name")"
    if [[ -n "$existing_pr_number" ]]; then
        echo "  [$branch_name] Reusing existing PR #$existing_pr_number" >&2
        printf '%s\n' "$existing_pr_number"
        return
    fi

    echo "  [$branch_name] No open PR found; generating PR title/body." >&2
    branch_details="$(build_branch_details "$branch_name")"
    branch_json="$(branch_json_for_name "$branch_name")"
    if [[ -n "${branch_json//[[:space:]]/}" ]]; then
        commit_count="$(printf '%s\n' "$branch_json" | jq -r '.commits | length')"
    fi

    if [[ "$commit_count" -eq 1 ]]; then
        echo "  [$branch_name] Single commit detected; using commit message for PR title/body." >&2
        pr_json="$(single_commit_pr_json_for_branch "$branch_name" || true)"
        if [[ -z "${pr_json//[[:space:]]/}" ]]; then
            echo "  [$branch_name] Could not read single commit message; using deterministic fallback." >&2
            pr_json="$(default_pr_json_for_branch "$branch_name" "$branch_details" | normalize_pr_json)"
        fi
    else
        pr_json="$(generate_pr_json_for_branch "$branch_name" "$branch_details")"
    fi

    if [[ "${BUTMERGE_DEBUG:-0}" == "1" ]]; then
        {
            printf 'DEBUG branch details:\n%s\n' "$branch_details"
            printf 'DEBUG generated pr_json raw:\n%s\n' "$pr_json"
        } >&2
    fi

    pr_json="$(printf '%s\n' "$pr_json" | normalize_pr_json)"
    if [[ "$commit_count" -ne 1 ]] &&
        (! printf '%s\n' "$pr_json" | validate_pr_json_shape || ! printf '%s\n' "$pr_json" | validate_pr_json_quality); then
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

    echo "  [$branch_name] Creating PR..." >&2
    pr_create_output="$(but pr new "$branch_name" -m "$message" 2>&1)"
    printf '%s\n' "$pr_create_output" >&2

    existing_pr_number="$(find_open_pr_number_for_branch "$branch_name")"
    if [[ -z "$existing_pr_number" ]]; then
        existing_pr_number="$(printf '%s\n' "$pr_create_output" | grep -Eo '#[0-9]+' | tail -n 1 | tr -d '#')"
    fi

    # Guard against reused branch names: if the discovered PR is already
    # merged/closed, it's stale.  Fall back to `gh pr create` directly so
    # GitHub is forced to open a brand-new PR.
    if [[ -n "$existing_pr_number" ]]; then
        local pr_state
        pr_state="$(gh pr view "$existing_pr_number" --json state --jq '.state' 2>/dev/null || true)"
        if [[ "$pr_state" != "OPEN" ]]; then
            echo "  [$branch_name] PR #$existing_pr_number is $pr_state (stale); creating fresh PR via gh." >&2
            existing_pr_number="$(gh pr create --head "$branch_name" --base main --title "$title" --body "$body" 2>&1 | grep -Eo '[0-9]+$' || true)"
        fi
    fi

    if [[ -z "$existing_pr_number" ]]; then
        echo "Failed to discover PR number after creating PR for $branch_name" >&2
        exit 1
    fi

    echo "  [$branch_name] Created PR #$existing_pr_number" >&2
    printf '%s\n' "$existing_pr_number"
}

merge_pr_number() {
    local pr_number="$1"
    local pr_state

    # Pre-check: skip if the PR is not open (e.g. stale reused branch name).
    pr_state="$(gh pr view "$pr_number" --json state --jq '.state' 2>/dev/null || true)"
    if [[ "$pr_state" != "OPEN" ]]; then
        echo "  PR #$pr_number is $pr_state — skipping merge." >&2
        return 1
    fi

    if [[ "$GH_MERGE_AVAILABLE" -eq 1 ]]; then
        gh merge -m "$pr_number"
        return
    fi

    gh pr merge "$pr_number" --merge
}

ensure_worktree_clean_for_merge() {
    local unassigned_count
    unassigned_count="$(but status --json | jq -r '.unassignedChanges | length')"

    if [[ "$unassigned_count" -gt 0 ]]; then
        echo "Cannot continue: worktree has uncommitted changes."
        echo "Please commit or stash local changes before running butmerge."
        return 1
    fi
}

pull_if_needed_or_fail() {
    local context="$1"
    local pull_check_json
    local upstream_count
    local has_worktree_conflicts

    if ! pull_check_json="$(but pull --check --json)"; then
        echo "Failed to run pull pre-check ($context)." >&2
        return 1
    fi

    upstream_count="$(printf '%s\n' "$pull_check_json" | jq -r '.upstreamCommits.count // 0')"
    has_worktree_conflicts="$(printf '%s\n' "$pull_check_json" | jq -r '.hasWorktreeConflicts // false')"

    if [[ "$has_worktree_conflicts" == "true" ]]; then
        echo "Cannot continue: pull is blocked by worktree conflicts ($context)." >&2
        return 1
    fi

    if [[ "$upstream_count" -eq 0 ]]; then
        return 0
    fi

    echo "  Pulling $upstream_count upstream commit(s) ($context)..."
    if ! but pull --json --status-after >/dev/null; then
        echo "Pull command failed ($context)." >&2
        return 1
    fi

    if ! pull_check_json="$(but pull --check --json)"; then
        echo "Failed to run post-pull check ($context)." >&2
        return 1
    fi

    upstream_count="$(printf '%s\n' "$pull_check_json" | jq -r '.upstreamCommits.count // 0')"
    has_worktree_conflicts="$(printf '%s\n' "$pull_check_json" | jq -r '.hasWorktreeConflicts // false')"

    if [[ "$has_worktree_conflicts" == "true" || "$upstream_count" -gt 0 ]]; then
        echo "Pull did not fully integrate local branches ($context)." >&2
        return 1
    fi
}

push_and_create_pr_parallel() {
    local branch_name="$1"
    local pr_out_file
    local push_pid
    local pr_pid
    local push_status=0
    local pr_status=0
    local pr_number

    pr_out_file="$(mktemp)"

    but push "$branch_name" --with-force &
    push_pid=$!

    create_or_get_pr_number "$branch_name" >"$pr_out_file" &
    pr_pid=$!

    wait "$push_pid" || push_status=$?
    wait "$pr_pid" || pr_status=$?

    if [[ $push_status -ne 0 ]]; then
        rm -f "$pr_out_file"
        return "$push_status"
    fi

    if [[ $pr_status -ne 0 ]]; then
        echo "  [$branch_name] PR creation failed before push finished; retrying now that push is complete."
        create_or_get_pr_number "$branch_name" >"$pr_out_file"
    fi

    pr_number="$(tr -d '\r' <"$pr_out_file" | tail -n 1)"

    rm -f "$pr_out_file"

    if [[ -z "${pr_number//[[:space:]]/}" ]]; then
        echo "Failed to discover PR number for $branch_name" >&2
        return 1
    fi

    printf '%s\n' "$pr_number"
}

main() {
    require_command but
    require_command jq
    require_command gh

    if gh merge --help >/dev/null 2>&1; then
        GH_MERGE_AVAILABLE=1
    fi

    local -a open_branches=()
    while IFS= read -r branch_row; do
        open_branches+=("$branch_row")
    done < <(but status --json | jq -r '.stacks[]? | .branches[]? | [.name, (.commits | length)] | @tsv')

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
    local prep_total=0
    local merge_index=0
    local prep_index=0
    local prep_out_file

    local -a eligible_branches=()
    local -a prep_pids=()
    local -a prep_output_files=()
    local -a prepared_pr_numbers=()

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

        eligible_branches+=("$branch_name")
    done

    prep_total="${#eligible_branches[@]}"
    if [[ "$prep_total" -eq 0 ]]; then
        echo "No eligible open branches with commits to process."
        exit 0
    fi

    echo ""
    echo "Preparing $prep_total branches in parallel (initial push + PR creation)..."
    for branch_name in "${eligible_branches[@]}"; do
        prep_index=$((prep_index + 1))
        echo ""
        echo "[prep $prep_index/$prep_total] Processing branch: $branch_name"
        echo "  1/5 Force push (parallel with PR creation)"
        echo "  2/5 Create or reuse PR (single-commit message, else Claude -> Codex medium -> default)"

        prep_out_file="$(mktemp)"
        prep_output_files+=("$prep_out_file")
        push_and_create_pr_parallel "$branch_name" >"$prep_out_file" &
        prep_pids+=("$!")
    done

    echo ""
    echo "Waiting for parallel preparation to complete..."
    for prep_index in "${!eligible_branches[@]}"; do
        branch_name="${eligible_branches[$prep_index]}"
        prep_out_file="${prep_output_files[$prep_index]}"

        if wait "${prep_pids[$prep_index]}"; then
            pr_number="$(tr -d '\r' <"$prep_out_file" | tail -n 1)"
            if [[ -n "${pr_number//[[:space:]]/}" ]]; then
                prepared_pr_numbers+=("$pr_number")
                echo "[prep $((prep_index + 1))/$prep_total] Ready: $branch_name -> PR #$pr_number"
            else
                prepared_pr_numbers+=("")
                echo "[prep $((prep_index + 1))/$prep_total] Failed: $branch_name (no PR number)"
            fi
        else
            prepared_pr_numbers+=("")
            echo "[prep $((prep_index + 1))/$prep_total] Failed: $branch_name"
        fi

        rm -f "$prep_out_file"
    done

    echo ""
    echo "Merging branches in sequence (force push -> merge -> pull)..."

    if ! ensure_worktree_clean_for_merge; then
        exit 1
    fi

    if ! pull_if_needed_or_fail "before merge phase"; then
        exit 1
    fi

    for prep_index in "${!eligible_branches[@]}"; do
        merge_index=$((merge_index + 1))
        branch_name="${eligible_branches[$prep_index]}"
        pr_number="${prepared_pr_numbers[$prep_index]}"

        echo ""
        echo "[merge $merge_index/$prep_total] Processing branch: $branch_name"
        if [[ -z "${pr_number//[[:space:]]/}" ]]; then
            echo "Skipping $branch_name because preparation failed."
            continue
        fi

        echo "  Using PR #$pr_number"
        if ! branch_is_open "$branch_name"; then
            echo "Skipping merge/pull for $branch_name because it is no longer open."
            continue
        fi

        echo "  3/5 Force push before merge"
        but push "$branch_name" --with-force

        echo "  4/5 Merge PR"
        if ! merge_pr_number "$pr_number"; then
            echo "  Merge skipped for $branch_name; cleaning up virtual branch."
            remove_virtual_branch "$branch_name"
            continue
        fi

        # Remove the branch from GitButler before pulling so that `but pull`
        # doesn't encounter multiple integrated virtual branches at once
        # (which triggers a "Chosen resolutions do not match" error).
        remove_virtual_branch "$branch_name"

        echo "  5/5 Pull"
        if ! pull_if_needed_or_fail "after merging $branch_name"; then
            exit 1
        fi
    done
}

main "$@"
