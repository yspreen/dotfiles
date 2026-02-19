---
name: formatter-hook
description: Configure pre-commit formatter/lint hooks to run only on staged files and remain compatible with both plain Git and GitButler-managed hooks. Use when setting up or fixing commit hooks, especially in repos with source hooks in hooks/, runtime hooks in .githooks/, and iOS/Xcode build steps that install hooks.
---

# Formatter Hook Skill

Use this skill to create or repair pre-commit hooks that do not format the entire repo and that run consistently for both `git commit` and `but commit`.

## Repo Learnings (mta)

1. Keep the source hook in `hooks/pre-commit`.
2. Install hooks into `.githooks/` and set `core.hooksPath` to `.githooks`.
3. In this repo, Xcode installs hooks automatically:
- Build phase name: `Install Repo Git Hooks`
- Project file: `ios/NYCSubwayWidget.xcodeproj/project.pbxproj`
- Script invoked: `"${SRCROOT}/scripts/install-git-hooks.sh"`
4. `ios/scripts/install-git-hooks.sh` already handles GitButler takeover:
- If `.githooks/pre-commit` has `GITBUTLER_MANAGED_HOOK_V1`, copy project hook to `.githooks/pre-commit-user`.
- Otherwise copy to `.githooks/pre-commit`.
5. GitButler wrapper hooks call `pre-commit-user` first. Custom project logic must live there when the wrapper exists.

## Non-Negotiable Hook Rules

1. Use POSIX shell (`#!/bin/sh`, `set -eu`).
2. Collect staged files with `git diff --cached --name-only --diff-filter=ACMR`.
3. Filter by file patterns per tool (Swift, TS/JS, etc.).
4. Exit quickly if no relevant staged files exist.
5. Check tool availability only after matching files are found.
6. Run tools only on staged file paths.
7. For auto-fix tools, compare against pre-run backups and fail only when that tool changed files.
8. Print explicit re-stage instructions for both Git and GitButler users.

## Staged-Only Pattern (Reusable)

```sh
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pre-commit.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT INT HUP TERM

# Example: gather staged Swift files.
SWIFT_FILES="$TMP_DIR/swift-files.txt"
git diff --cached --name-only --diff-filter=ACMR -- '*.swift' > "$SWIFT_FILES"
[ -s "$SWIFT_FILES" ] || exit 0

# Back up originals to avoid false positives from unrelated unstaged changes.
BACKUP_MAP="$TMP_DIR/swift-backups.tsv"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  [ -f "$rel" ] || continue
  backup="$(mktemp "${TMP_DIR}/before.XXXXXX")"
  cp "$rel" "$backup"
  printf '%s\t%s\n' "$rel" "$backup" >> "$BACKUP_MAP"
done < "$SWIFT_FILES"
```

## Swift Formatting (swift-format)

Use this for iOS formatting without touching unrelated files:

```sh
# Build arg list safely for POSIX sh.
set --
while IFS="$(printf '\t')" read -r rel backup; do
  set -- "$@" "$rel"
done < "$BACKUP_MAP"

xcrun swift-format format --in-place --configuration .swift-format "$@"

changed=0
while IFS="$(printf '\t')" read -r rel backup; do
  if ! cmp -s "$rel" "$backup"; then
    [ "$changed" -eq 1 ] || echo "swift-format changed staged files. Re-stage and commit again:"
    echo " - $rel"
    changed=1
  fi
done < "$BACKUP_MAP"

if [ "$changed" -eq 1 ]; then
  echo "If using Git: git add <files> && git commit"
  echo "If using GitButler: run your but commit command again"
  exit 1
fi
```

## Swift Lint (iOS)

If SwiftLint is required in your repo:

1. Add config file at repo root: `.swiftlint.yml`.
2. Lint only staged Swift files.
3. Optional: run `swiftlint --fix` per staged file, then strict lint.
4. If `--fix` is enabled, reuse the backup-and-compare loop from the swift-format section and fail with re-stage instructions when files changed.

```sh
SWIFT_FILES="$TMP_DIR/swiftlint-files.txt"
git diff --cached --name-only --diff-filter=ACMR -- '*.swift' > "$SWIFT_FILES"

if [ -s "$SWIFT_FILES" ]; then
  command -v swiftlint >/dev/null 2>&1 || {
    echo "swiftlint is required for staged Swift lint checks."
    exit 1
  }

  # Optional auto-fix pass.
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    swiftlint --fix --config .swiftlint.yml --path "$rel"
  done < "$SWIFT_FILES"

  # Enforced lint pass.
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    swiftlint lint --strict --config .swiftlint.yml --path "$rel"
  done < "$SWIFT_FILES"
fi
```

## ESLint (Web)

For web code (example in `next/`):

1. Gather staged JS/TS files only.
2. Run ESLint from the web workspace (`pnpm -C next exec eslint ...`).
3. Use `--max-warnings=0` to block warning regressions.
4. If using `--fix`, fail and ask for re-stage when fixes were applied.

```sh
WEB_FILES="$TMP_DIR/eslint-files.txt"
git diff --cached --name-only --diff-filter=ACMR -- \
  '*.js' '*.jsx' '*.ts' '*.tsx' '*.mjs' '*.cjs' > "$WEB_FILES"

if [ -s "$WEB_FILES" ]; then
  command -v pnpm >/dev/null 2>&1 || {
    echo "pnpm is required for ESLint hook checks."
    exit 1
  }

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in
      next/*)
        pnpm -C next exec eslint --max-warnings=0 --fix -- "$PWD/$rel"
        ;;
    esac
  done < "$WEB_FILES"
fi
```

If your web workspace is not `next/`, replace the workspace path and file filter.

## Git + GitButler Installation Flow

1. Keep the maintained hook in `hooks/pre-commit`.
2. Ensure installer copies source hook to runtime hooks path and preserves GitButler wrapper behavior.
3. Set hooks path:

```sh
git config core.hooksPath .githooks
```

4. Run installer directly when needed:

```sh
SRCROOT="$PWD/ios" sh ios/scripts/install-git-hooks.sh
```

5. Verify both paths:
- `git commit` runs `.githooks/pre-commit`.
- `but commit` runs GitButler-managed `.githooks/pre-commit`, which invokes `.githooks/pre-commit-user`.

## Verification Checklist

1. Stage one Swift file and one web TS/JS file with known formatting issues.
2. Run `git commit` and confirm only staged files are modified.
3. Re-stage and retry commit.
4. Run `but commit ...` and confirm same behavior.
5. Confirm unrelated repo files are never reformatted by the hook.
