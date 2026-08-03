#!/bin/bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
shim="$repo_root/scripts/git"
test_root=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/git-shim-test.XXXXXX")
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

new_repo() {
  local name=$1
  test_repo="$test_root/$name"
  /bin/mkdir -p "$test_repo"
  "$shim" -C "$test_repo" init -q
  "$shim" -C "$test_repo" config user.name Test
  "$shim" -C "$test_repo" config user.email test@example.com
  printf 'initial\n' > "$test_repo/file"
  "$shim" -C "$test_repo" add file
  "$shim" -C "$test_repo" commit -qm initial
}

commit_message() {
  "$shim" -C "$test_repo" log -1 --format=%B
}

new_repo plain
printf 'plain\n' >> "$test_repo/file"
"$shim" -C "$test_repo" add file
"$shim" -C "$test_repo" commit -qm 'plain commit'
message=$(commit_message)
assert_contains "$message" 'plain commit' 'plain commit message changed'
assert_not_contains "$message" 'Co-Authored-By:' 'plain commit gained co-author trailer'

new_repo anthropic
printf 'anthropic\n' >> "$test_repo/file"
"$shim" -C "$test_repo" add file
"$shim" -C "$test_repo" commit -qm 'strip trailer' -m 'Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>'
message=$(commit_message)
assert_contains "$message" 'strip trailer' 'commit subject disappeared with trailer cleanup'
assert_not_contains "$message" 'anthropic.com' 'Anthropic co-author trailer survived cleanup'

new_repo other-trailer
printf 'other\n' >> "$test_repo/file"
"$shim" -C "$test_repo" add file
"$shim" -C "$test_repo" commit -qm 'keep trailer' -m 'Co-Authored-By: Teammate <teammate@example.com>'
message=$(commit_message)
assert_contains "$message" 'Co-Authored-By: Teammate <teammate@example.com>' 'non-Anthropic trailer was removed'

new_repo poisoned-path
fake_bin="$test_root/fake-bin"
/bin/mkdir -p "$fake_bin"
for tool in grep sed mktemp rm; do
  printf '#!/bin/sh\nexit 99\n' > "$fake_bin/$tool"
  /bin/chmod +x "$fake_bin/$tool"
done
printf 'poisoned\n' >> "$test_repo/file"
"$shim" -C "$test_repo" add file
PATH="$fake_bin:$PATH" "$shim" -C "$test_repo" commit -qm 'poison resistant' -m 'Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>'
message=$(commit_message)
assert_contains "$message" 'poison resistant' 'PATH poisoning broke commit message'
assert_not_contains "$message" 'anthropic.com' 'PATH poisoning bypassed trailer cleanup'

new_repo branch-guard
set +e
blocked_output=$("$shim" -C "$test_repo" branch blocked 2>&1)
blocked_status=$?
set -e
[[ "$blocked_status" -eq 1 ]] || fail 'branch creation was not blocked'
assert_contains "$blocked_output" '--user-asked-for-it' 'branch refusal omitted authorization hint'
if "$shim" -C "$test_repo" show-ref --verify --quiet refs/heads/blocked; then
  fail 'blocked branch was created'
fi
"$shim" -C "$test_repo" branch allowed --user-asked-for-it
"$shim" -C "$test_repo" show-ref --verify --quiet refs/heads/allowed || fail 'authorized branch was not created'

printf 'git shim tests passed\n'
