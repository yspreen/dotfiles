---
name: asc-summary
description: Quick-reference guide for all ASC skills with pitfalls, correct commands, and skill routing. Read this FIRST before any App Store Connect task.
---

# ASC Summary — Skill Index & Pitfall Guide

Read this skill FIRST before performing any App Store Connect task. It tells you which skill to invoke and warns about common mistakes.

## Before You Start

Run `brew upgrade rudrankriyam/tap/asc` once at the beginning of any ASC session to ensure the CLI is up to date. This avoids "Update available" warnings cluttering output and ensures you have the latest commands and flags.

## Golden Rules

1. **Never guess flags.** If you're unsure whether a flag exists, run `asc <command> --help` first. Do NOT invent flags like `--build` on commands that don't support them.
2. **Never make parallel calls that depend on each other.** If call B uses output from call A, run them sequentially.
3. **Most `list` commands require `--app`.** Always pass `--app "APP_ID"` (or set `ASC_APP_ID`) for `builds list`, `versions list`, `beta-groups list`, etc.
4. **Use `asc submit create` to attach a build and submit in one step.** There is no `--build` flag on `asc versions update`. To attach a build separately (without submitting), use `asc versions attach-build`.
5. **Localizations have no inline `update` subcommand.** To update fields like `whatsNew`, either use the download/edit/upload workflow or `asc app-info set`.

## Skill Router — Which Skill to Use

| Task | Skill |
|------|-------|
| Find an app/build/version/group ID | **asc-id-resolver** |
| Understand CLI flags, output formats, auth | **asc-cli-usage** |
| Build, archive, export an IPA or PKG | **asc-xcode-build** |
| Set up bundle IDs, certs, provisioning profiles | **asc-signing-setup** |
| Upload a build, distribute to TestFlight or App Store | **asc-release-flow** |
| Track build processing, find latest build, expire old builds | **asc-build-lifecycle** |
| Manage TestFlight groups, testers, What to Test notes | **asc-testflight-orchestration** |
| Update App Store metadata (description, What's New, keywords) | **asc-metadata-sync** |
| Preflight and submit a build for App Store review | **asc-submission-health** |
| Notarize a macOS app for distribution outside the App Store | **asc-notarization** |
| Set per-territory or PPP-based pricing | **asc-ppp-pricing** |
| Look up the vendor number | **asc-vendor-number** |

## Common Workflows & Correct Commands

### Submit a new version for App Store review

This is the most common task. The correct sequence is:

```bash
# 1. Resolve IDs (asc-id-resolver)
asc apps list --output table                            # find APP_ID
asc builds list --app "APP_ID" --limit 5 --output table # find BUILD_ID
asc versions list --app "APP_ID" --output table         # check existing versions

# 2. Create version if needed
asc versions create --app "APP_ID" --version "1.0.2" --platform IOS

# 3. Update What's New (asc-metadata-sync)
#    Option A: download/edit/upload
asc localizations download --version "VERSION_ID" --path /tmp/localizations
#    Edit the .strings file to add/update "whatsNew" key
asc localizations upload --version "VERSION_ID" --path /tmp/localizations
#    Option B: quick set (if available)
asc app-info set --app "APP_ID" --locale "en-US" --whats-new "Bug fixes and improvements"

# 4. Update or clear reviewer notes (asc-submission-health)
asc review details-for-version --version-id "VERSION_ID"  # check current notes
asc review details-update --id "DETAIL_ID" --notes ""      # clear notes

# 5. Submit with build attached (asc-submission-health)
asc submit create --app "APP_ID" --version-id "VERSION_ID" --build "BUILD_ID" --confirm

# 6. Verify
asc review submissions-get --id "SUBMISSION_ID" --output json --pretty
```

### Resubmit after rejection

```bash
# Cancel existing submission first
asc review submissions-cancel --id "SUBMISSION_ID" --confirm
# Then create a new submission
asc submit create --app "APP_ID" --version-id "VERSION_ID" --build "BUILD_ID" --confirm
```

### Attach build WITHOUT submitting

```bash
asc versions attach-build --version-id "VERSION_ID" --build "BUILD_ID"
```

## Pitfalls & Fixes

### 1. `asc versions update --build` does not exist
`asc versions update` only supports `--copyright`, `--release-type`, `--earliest-release-date`, and `--version`. To attach a build, use either:
- `asc versions attach-build --version-id "VERSION_ID" --build "BUILD_ID"` (attach only)
- `asc submit create ... --build "BUILD_ID"` (attach + submit in one step)

### 2. `asc builds list` without `--app` fails
Every build command that lists or queries requires `--app "APP_ID"`. There is no global build list.

### 3. `asc builds assign` does not exist
There is no `assign` subcommand on `builds`. Build attachment is done via `asc versions attach-build` or `asc submit create --build`.

### 4. No `asc localizations update` subcommand
To update localization fields (description, whatsNew, keywords, etc.):
- **Bulk:** `asc localizations download` → edit `.strings` file → `asc localizations upload`
- **Quick:** `asc app-info set --app "APP_ID" --locale "en-US" --whats-new "..."`
- The `.strings` format uses `"key" = "value";` — add a `"whatsNew"` key to set release notes.

### 5. Reviewer notes carry over between versions
When you create a new version, the reviewer notes from the previous version are copied. Always check and clear them if they are no longer relevant:
```bash
asc review details-for-version --version-id "VERSION_ID"
asc review details-update --id "DETAIL_ID" --notes ""
```

### 6. Parallel tool calls with dependencies cause cascading failures
If call A fails and call B depends on A's result, B will also fail. Sequence dependent calls. Only parallelize truly independent operations (e.g., fetching localizations and review details for an already-known version ID).

### 7. `asc versions list` may not show all states
By default it returns versions in common states. Use `--state PREPARE_FOR_SUBMISSION` to find draft versions, or omit `--state` to get all.

### 8. Forgetting to invoke the metadata-sync skill
When updating What's New, description, or any localization, invoke **asc-metadata-sync** — it documents the download/edit/upload workflow and the `.strings` file format. Don't try to guess the update mechanism.

## Quick Reference: Key Commands

| Action | Command |
|--------|---------|
| List apps | `asc apps list --output table` |
| List builds | `asc builds list --app "APP_ID" --limit 5 --output table` |
| Latest build | `asc builds latest --app "APP_ID"` |
| Build details | `asc builds info --build "BUILD_ID"` |
| List versions | `asc versions list --app "APP_ID" --output table` |
| Create version | `asc versions create --app "APP_ID" --version "X.Y.Z" --platform IOS` |
| Attach build | `asc versions attach-build --version-id "VERSION_ID" --build "BUILD_ID"` |
| Update copyright | `asc versions update --version-id "VERSION_ID" --copyright "2026 Company"` |
| Download localizations | `asc localizations download --version "VERSION_ID" --path ./loc` |
| Upload localizations | `asc localizations upload --version "VERSION_ID" --path ./loc` |
| Get review details | `asc review details-for-version --version-id "VERSION_ID"` |
| Clear reviewer notes | `asc review details-update --id "DETAIL_ID" --notes ""` |
| Submit for review | `asc submit create --app "APP_ID" --version-id "VERSION_ID" --build "BUILD_ID" --confirm` |
| Check submission status | `asc review submissions-get --id "SUBMISSION_ID" --output json --pretty` |
| Cancel submission | `asc review submissions-cancel --id "SUBMISSION_ID" --confirm` |
