#!/bin/bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shim="$repo_root/scripts/gh"
test_root=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/gh-shim-test.XXXXXX")
record_dir="$test_root/record"
fake_gh="$test_root/gh-real"
trap '/bin/rm -rf -- "$test_root"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *) fail "$3" ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) fail "$3" ;;
  esac
}

reset_record() {
  /bin/rm -rf -- "$record_dir"
  /bin/mkdir -p "$record_dir"
}

assert_invoked() {
  [[ -f "$record_dir/count" ]] || fail "$1"
}

assert_not_invoked() {
  [[ ! -f "$record_dir/count" ]] || fail "$1"
}

assert_arg_count() {
  local actual
  actual=$(<"$record_dir/count")
  [[ "$actual" -eq "$1" ]] || fail "$2"
}

assert_arg() {
  local index=$1
  local expected=$2
  local message=$3
  local expected_file="$test_root/expected"

  printf '%s' "$expected" > "$expected_file"
  /usr/bin/cmp -s "$expected_file" "$record_dir/arg.$index" || fail "$message"
}

run_shim() {
  GH_SHIM_REAL_GH="$fake_gh" GH_SHIM_RECORD_DIR="$record_dir" "$shim" "$@"
}

cat > "$fake_gh" <<'EOF'
#!/bin/bash

/bin/mkdir -p "$GH_SHIM_RECORD_DIR"
printf '%s' "$#" > "$GH_SHIM_RECORD_DIR/count"
index=0
for arg in "$@"; do
  printf '%s' "$arg" > "$GH_SHIM_RECORD_DIR/arg.$index"
  index=$((index + 1))
done
printf 'fake gh\n'
exit "${GH_SHIM_FAKE_STATUS:-0}"
EOF
/bin/chmod +x "$fake_gh"

reset_record
output=$(run_shim auth status --user-approved-usage-of-ai-terms)
[[ "$output" == 'fake gh' ]] || fail 'transparent command output changed'
assert_invoked 'transparent command did not reach real gh'
assert_arg_count 2 'approval flag reached transparent real gh invocation'
assert_arg 0 auth 'transparent command name changed'
assert_arg 1 status 'transparent command argument changed'

reset_record
set +e
GH_SHIM_FAKE_STATUS=23 run_shim repo view >/dev/null 2>&1
status=$?
set -e
[[ "$status" -eq 23 ]] || fail 'real gh exit status was not preserved'

safe_body=$'Summary\n\n- keeps spaces, * globs, and "quotes"'
reset_record
run_shim -R owner/repo pr create --title Test --body "$safe_body" >/dev/null
assert_invoked 'safe inline body did not reach real gh'
assert_arg_count 8 'safe inline body argument count changed'
assert_arg 7 "$safe_body" 'safe inline body content changed'

reset_record
run_shim pr -R owner/repo create --body='safe equals body' >/dev/null
assert_invoked 'global option between command path broke detection'
assert_arg 4 '--body=safe equals body' 'equals body form changed'

reset_record
run_shim pr create -b 'safe short body' >/dev/null
assert_arg 3 'safe short body' 'short body value changed'

reset_record
run_shim pr create '-battached body' >/dev/null
assert_arg 2 '-battached body' 'attached short body changed'

reset_record
run_shim pr create --help >/dev/null
assert_invoked 'pr create help was incorrectly blocked'

for blocked_body in 'Claude wrote this' 'cLaUdE-Code' 'CODEX generated' 'preCodexical'; do
  reset_record
  set +e
  blocked_output=$(run_shim pr create --body "$blocked_body" 2>&1)
  blocked_status=$?
  set -e
  [[ "$blocked_status" -eq 1 ]] || fail "prohibited body was not blocked: $blocked_body"
  assert_not_invoked "real gh ran for prohibited body: $blocked_body"
  assert_contains "$blocked_output" '--user-approved-usage-of-ai-terms' 'refusal omitted approval flag'
done

reset_record
set +e
ambiguous_output=$(run_shim pr create --body Claude --title --body=safe 2>&1)
status=$?
set -e
[[ "$status" -eq 1 ]] || fail 'body flag hidden as title value bypassed screening'
assert_not_invoked 'real gh ran after body flag was hidden as title value'

reset_record
set +e
cluster_output=$(run_shim pr create -dbClaude 2>&1)
status=$?
set -e
[[ "$status" -eq 1 ]] || fail 'clustered short body flag bypassed screening'
assert_not_invoked 'real gh ran for prohibited clustered short body'

invalid_utf8_body=$'\xffClaude'
reset_record
set +e
invalid_output=$(run_shim pr create --body "$invalid_utf8_body" 2>&1)
status=$?
set -e
[[ "$status" -eq 1 ]] || fail 'invalid UTF-8 body bypassed screening'
assert_not_invoked 'real gh ran for invalid UTF-8 body containing prohibited term'

expected_refusal="Unfortunately, this repository that we're working with here has a strict policy against advertising coding tools So mentioning \"Claude\" or \"Codex\" is strictly prohibited Please try submitting a new version of this pull request that does not mention \"Claude\" or \"Codex\"
ONLY If you do believe that the functionality that we add in this PR is about codex or claude itself, we might be able to grant an exception. In that case ask the user for resolution If the user approves it manually, you can add this flag: --user-approved-usage-of-ai-terms
This is only an exception for pull requests that are about coding tools themselves, which should be a very very rare edge case. So in 99.9% of cases, please just reword your message to remove the advertisement for the AI coding tool."
reset_record
set +e
actual_refusal=$(run_shim pr create --body Claude 2>&1)
status=$?
set -e
[[ "$status" -eq 1 ]] || fail 'exact refusal case did not fail'
[[ "$actual_refusal" == "$expected_refusal" ]] || fail 'refusal text did not match requested wording'

reset_record
run_shim pr create --body 'Claude and Codex are the subject' --user-approved-usage-of-ai-terms >/dev/null
assert_invoked 'approved prohibited body did not reach real gh'
assert_arg_count 4 'approval flag was forwarded to real gh'
assert_arg 3 'Claude and Codex are the subject' 'approved body changed'

for args in \
  'pr create' \
  'pr create --body-file body.md' \
  'pr create -F body.md' \
  'pr create --fill' \
  'pr create --fill-first' \
  'pr create --editor' \
  'pr create --web' \
  'pr create --template pull_request.md' \
  'pr create --body'; do
  reset_record
  set +e
  blocked_output=$(run_shim $args 2>&1)
  status=$?
  set -e
  [[ "$status" -eq 1 ]] || fail "uninspectable body source was not blocked: $args"
  assert_not_invoked "real gh ran for uninspectable body source: $args"
  assert_contains "$blocked_output" 'requires an inline body via --body' 'uninspectable-body diagnostic was unclear'
done

for args in \
  'pr create --body safe -e' \
  'pr create --body safe -w' \
  'pr create --body safe -f' \
  'pr create --body safe --editor=true' \
  'pr create --body safe --web=true' \
  'pr create --body safe --fill=true' \
  'pr create --body safe --recover recovery.json' \
  'pr create --body safe --recover=recovery.json' \
  'pr create --body safe -dFbody.md'; do
  reset_record
  set +e
  blocked_output=$(run_shim $args 2>&1)
  status=$?
  set -e
  [[ "$status" -eq 1 ]] || fail "body-changing flag bypassed screening: $args"
  assert_not_invoked "real gh ran for body-changing flag: $args"
done

reset_record
run_shim pr create --title 'Claude migration' --body 'ordinary implementation details' >/dev/null
assert_invoked 'term in title incorrectly triggered body policy'

reset_record
run_shim issue create --body 'Claude mention outside pull request creation' >/dev/null
assert_invoked 'term outside pr create incorrectly triggered policy'

reset_record
run_shim pr create --body safe -d=false >/dev/null
assert_invoked 'valid short boolean assignment was incorrectly blocked'

reset_record
set +e
new_output=$(run_shim pr new --body 'Claude mention through built-in alias' 2>&1)
status=$?
set -e
[[ "$status" -eq 1 ]] || fail 'pr new alias bypassed body screening'
assert_not_invoked 'real gh ran for prohibited pr new body'

set +e
missing_output=$(GH_SHIM_REAL_GH="$test_root/missing-gh" "$shim" version 2>&1)
status=$?
set -e
[[ "$status" -eq 1 ]] || fail 'missing real gh launcher did not fail'
assert_contains "$missing_output" 'real GitHub CLI launcher is unavailable' 'missing launcher diagnostic was unclear'

printf 'gh shim tests passed\n'
