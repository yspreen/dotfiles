---
name: asc-testflight-release
description: Use when asked to release, publish, upload, or ship a new TestFlight build of a native Xcode project, or upload anything to ASC. Not for submitting an already-uploaded build to review; use asc-start-review for that.
---

# ASC TestFlight Release

Archive, export, and upload an iOS build to TestFlight with `asc`. Run from the directory holding the `.xcodeproj`/`.xcworkspace`.

## Facts

Resolve from the project and ASC before changing anything. Never guess.

- `APP_ID`: `asc apps list --output json` matched by bundle ID.
- Project/workspace, scheme, `Release` configuration, team ID (`DEVELOPMENT_TEAM`), bundle IDs of app and extensions.
- TestFlight group: `asc testflight groups list --app "$APP_ID" --output json`. Ask the user if there are several and none is obvious.
- `VERSION`: current marketing version from the project.

## Preconditions

1. Upload is outward-facing. Require an explicit request.
2. `git status --short --branch`. Don't overwrite or discard unrelated changes.
3. `asc` reads the repo's `.asc/config.json` with `ASC_BYPASS_KEYCHAIN=1` (see `noninteractive-apple-signing`). Check with `asc apps view --id "$APP_ID"`. Never `asc auth status`/`login`, which read the keychain.
4. Inspect the scheme's archive pre/post-actions in `xcshareddata/xcschemes/*.xcscheme` (e.g. `agvtool bump`). Don't run Archive just to inspect settings, because post-actions can mutate source.
5. Signing: cloud signing per `noninteractive-apple-signing`. There is no local signing identity or keychain. If the project has a `release.sh`, use it; pacey, remy, lovetalk and bunny-stamps all sign this way through `scripts/ios-cloud-signing.sh`. Otherwise source that file from one of them for steps 3 and 4.
6. If `xcodebuild` reports Command Line Tools, set `DEVELOPER_DIR=/Applications/Xcode-*.app/Contents/Developer` for the invocation.

## 1. Next build number

```sh
asc builds next-build-number --app "$APP_ID" --version "$VERSION" --platform IOS
```

Use `nextBuildNumber` as `BUILD`. Before upload, read `CFBundleVersion` from the exported IPA and pass that as `--build-number`; a mismatch fails with 90345. Don't reuse the latest processed number.

## 2. Set build number

```sh
agvtool new-version -all "$BUILD"
```

Verify the intended files changed (app, extensions, test Info.plists). Spurious `agvtool` warnings such as `Cannot find ".../YES"` are fine if the files are right.

## 3. Archive (unsigned, then ad-hoc)

```sh
xcodebuild archive -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Release \
  -archivePath "/tmp/${SCHEME}-${VERSION}-${BUILD}.xcarchive" -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGNING_ALLOWED=NO
source scripts/ios-cloud-signing.sh
load_asc_key .asc/config.json
adhoc_sign_archive "$PROJECT" "/tmp/${SCHEME}-${VERSION}-${BUILD}.xcarchive/Products/Applications/${SCHEME}.app"
```

Use `-project` instead of `-workspace` without CocoaPods/SPM workspaces. Require `** ARCHIVE SUCCEEDED **` and that the archive exists. A post-action bump means the archive has `BUILD` while source now has `BUILD + 1`.

## 4. Export IPA (cloud signing)

```sh
cloud_export "/tmp/${SCHEME}-${VERSION}-${BUILD}.xcarchive" "/tmp/${SCHEME}-${VERSION}-${BUILD}-export" \
  app-store-connect export "$TEAM_ID"
```

Require `** EXPORT SUCCEEDED **` and matching bundle ID, version, build. Never add archive, IPA, or plist to git.

## 5. Upload and distribute

```sh
asc publish testflight --app "$APP_ID" --ipa "/tmp/${SCHEME}-${VERSION}-${BUILD}-export/${SCHEME}.ipa" \
  --version "$VERSION" --build-number "$BUILD" --group "$GROUP" --wait --notify
```

Success: `"uploaded": true`, `"processingState": "VALID"`, expected version/build. For an internal group that already receives all builds, "assignment skipped" and `"notified": false` are both success.

## 6. Prepare next source build

```sh
agvtool new-version -all "$((BUILD + 1))"
git status --short && git diff --check
```

Normalize all version files to `BUILD + 1` even if a post-action already bumped. Only build-number files should change.

## 7. Commit

Only after upload is `VALID`. Stage only the build-number files:

```sh
git commit -m "chore: bump build number to $((BUILD + 1))" \
  -m "Build ${BUILD} was uploaded to TestFlight; prepare source for next archive."
```

Don't push unless asked.

## Failure handling

- Next-build query fails: stop before touching the project.
- Archive fails: don't export or upload. Report the decisive error. Revert build-number changes only with approval if unrelated work exists.
- Export fails: keep archive, don't upload.
- Upload commits but processing fails: report build ID and error; don't claim success.

## Final report

Marketing version and build, ASC build ID, processing state, TestFlight group result, next source build and commit hash, whether anything was pushed.
