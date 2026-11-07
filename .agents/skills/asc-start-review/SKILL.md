---
name: asc-start-review
description: Submit an already-uploaded iOS and/or Android build for store review with asc and gpd. Use when asked to send build X for review, submit an App Store/Play release, or start App Review. Not for building, signing, or uploading builds; use asc-testflight-release for that.
---

# Start Store Review

Goal: an existing uploaded build becomes a production review submission. Use `asc` (Apple) and `gpd` (Google). Chrome only when the CLI/API blocks. Run from repo root.

A request like "send build 244 for review" authorizes submission to every store the app ships on. Without an explicit request to submit, stop after dry-runs.

## Facts

Resolve before mutating anything. Never guess.

- `APP_ID`: App Store Connect app ID. Check project docs/config, else `asc apps list --output json` matched by bundle ID.
- `PACKAGE`: Play package name (usually equals bundle ID). Skip Android if the app has no Android build.
- `BUILD`: requested build number. If none given, use newest `VALID` iOS build by `uploadedDate`.
- `VERSION`: marketing version from the build, not local config.
- Release notes: checked-in store files if the repo has them (e.g. `intl/store/{apple,google}/<locale>/whatsnew.txt`), else release output/changelog, else ask the user. Preserve user wording.

Read project docs (`AGENTS.md`, `ASO.md`, etc.) before store-copy work.

## 1. Preconditions

```sh
git status --short --branch   # workflow should not change repo files
asc apps view --id "$APP_ID" --output json  # repo .asc/config.json, ASC_BYPASS_KEYCHAIN=1; never asc auth status
gpd auth status
asc builds info --app "$APP_ID" --build-number "$BUILD" --platform IOS --output json
asc builds pre-release-version view --build-id "$BUILD_ID" --output json
gpd publish builds list --package "$PACKAGE" --type bundle --output json
gpd publish status --package "$PACKAGE" --output json
```

No `BUILD` given: `asc builds list --app "$APP_ID" --platform IOS --processing-state VALID --exclude-expired --sort=-uploadedDate --limit 10 --output json`.

`asc builds info` puts the build number in `.data.attributes.version`; marketing version comes from `pre-release-version view`. Require Apple build `VALID` (recheck while `PROCESSING`; stop on `FAILED`/`INVALID`). Require the same Android version code in `.data.builds`. If it is already completed on `production`, don't resubmit Android. If either store lacks the build, stop before mutating either store.

## 2. Inspect active review state

```sh
asc review status --app "$APP_ID" --output json
```

Never cancel or replace an existing submission without explicit approval. If the requested version is already waiting for review or later, verify its build and treat iOS as submitted. On Play, never remove retained version codes, halt a rollout, or cancel an in-progress review.

## 3. Prepare iOS version

```sh
asc versions list --app "$APP_ID" --version "$VERSION" --platform IOS --output json
```

Reuse it in `PREPARE_FOR_SUBMISSION`. If absent, copy metadata from the latest `READY_FOR_SALE` version, excluding stale notes:

```sh
asc versions list --app "$APP_ID" --platform IOS --paginate --output json
asc versions create --app "$APP_ID" --version "$VERSION" --platform IOS --release-type AFTER_APPROVAL \
  --copy-metadata-from "$PREVIOUS_VERSION" --exclude-fields whatsNew --output json
asc versions list --app "$APP_ID" --version "$VERSION" --platform IOS --output json
```

Don't trust the create output shape. Re-query, record `VERSION_ID`, and require `PREPARE_FOR_SUBMISSION`.

Set What's New on every localization the version has, never just one:

```sh
asc localizations list --version "$VERSION_ID" --output json
asc localizations update --version "$VERSION_ID" --locale "$ASC_LOCALE" --whats-new "$NOTES" --output json
```

Map ASC locales (`en-US`, `ar-SA`, `zh-Hans`...) to repo folders explicitly. Re-list and require exact text matches.

## 4. Screenshot parity

Do this before dry-run. ASC returns `wouldSubmit: true` while screenshots are still uploading, and screenshots still processing block the real submission.

For the latest `READY_FOR_SALE` version and for `VERSION_ID`, list localizations (`--paginate`), then `asc screenshots list --version-localization "$LOC_ID" --output json` for each. Count `.sets[].screenshots` per locale and `screenshotDisplayType`.

Require:
- Same locale set and same count per locale/display type as the approved version.
- Every new screenshot `assetDeliveryState.state == COMPLETE` with positive `imageAsset` width/height.

Print a table (locale, display type, approved, new, incomplete). If anything mismatches, poll every 30–60s. Proceed only after two consecutive passes. If the release intentionally changes screenshots, confirm with the user and use their counts as the baseline.

## 5. Dry-run

```sh
asc review submit --app "$APP_ID" --version-id "$VERSION_ID" --build-id "$BUILD_ID" --dry-run --output json
```

Require `wouldSubmit: true` with correct build/version. If blocked: `asc validate --app "$APP_ID" --version-id "$VERSION_ID" --platform IOS --output json`. Fix only metadata clearly covered by the request. Stop for user input on policy, legal, pricing, age rating, screenshots, review contact, data safety, countries, or release strategy.

Android notes file must be a locale map, not an array: `{"en-US":"...","de-DE":"..."}`. Include every Play listing locale.

```sh
gpd publish release --package "$PACKAGE" --track production --name "$BUILD ($VERSION)" --status completed \
  --version-codes "$BUILD" --release-notes-file "$NOTES_FILE" --dry-run --output json
```

Prefer creating the production release directly so notes are explicit. Use `gpd publish promote --from-track internal --to-track production --percentage 100` only if release creation can't reuse the artifact.

## 6. Submit (once each)

```sh
asc review submit --app "$APP_ID" --version-id "$VERSION_ID" --build-id "$BUILD_ID" --confirm --output json
gpd publish release --package "$PACKAGE" --track production --name "$BUILD ($VERSION)" --status completed \
  --version-codes "$BUILD" --release-notes-file "$NOTES_FILE" --wait --wait-timeout 30m --output json
```

Record the submission ID. Never retry a mutation blindly; read status first. If an existing Play review blocks commit, use `--in-progress-review-behaviour CANCEL_IN_PROGRESS_AND_SUBMIT` only with explicit approval.

## 7. Verify

```sh
asc review status --app "$APP_ID" --output json
asc versions list --app "$APP_ID" --version "$VERSION" --platform IOS --output json
asc localizations list --version "$VERSION_ID" --output json
gpd publish status --package "$PACKAGE" --track production --output json
gpd release-mgmt notes --package "$PACKAGE" --action get --track production --version-code "$BUILD" --output json
```

iOS success: intended build attached, version `WAITING_FOR_REVIEW` or later, submission ID matches, notes match. Android success: production holds the version code in an accepted state (completed or in review) and all notes match. If submission returned an ID but verification fails, report the ID and observed state; don't claim success.

## Chrome fallback

Only for CLI capability/auth failures. Use the existing signed-in Chrome session.
- App Store Connect: My Apps → app → iOS App → version. Select exact build, verify every What's New locale, add for review, submit.
- Play Console: app → Release → Production. Create release from the exact uploaded version code, enter every locale's notes, start full rollout / send for review.
Never re-upload a build. Re-open state afterwards and confirm the exact build.

## Final report

Build number and marketing version, iOS build ID and submission ID, final iOS state, final Android state and verified locales, exact notes, repo files changed (normally none). Distinguish uploaded, submitted, in review, released.
