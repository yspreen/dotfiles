---
name: noninteractive-apple-signing
description: Use before any Apple automation that archives, signs, exports, uploads, or calls asc, including App Store review and metadata work, because asc and codesign can read the login keychain and raise password dialogs.
---

Apple automation must never touch the login keychain. A keychain password or authorization dialog is a failed preflight, never a request for the user.

## App Store Connect key

1. Read the key from the repo's `.asc/config.json` (`key_id`, `issuer_id`, `private_key_path`), the same file `asc` reads. `~/.asc/config.json` is the fallback outside a repo.
2. `ASC_BYPASS_KEYCHAIN=1` must be set. It is exported in `~/.zshenv`; scripts export it again. Never run `asc auth login`, `asc auth export-to-config`, or anything else that reads or writes keychain credentials.
3. Pass `realpath` of the key file. `asc` refuses symlinked paths, and `~/.appstoreconnect` is a symlink.
4. A key belongs to one team. Check it with `asc apps view --id APP_ID` before relying on it.

## Signing: cloud signing, no local identity

No local signing identity, so nothing to unlock and no dialog to raise:

1. Archive unsigned: `xcodebuild archive ... DEVELOPMENT_TEAM=TEAM CODE_SIGNING_ALLOWED=NO`.
2. Ad-hoc sign each `.appex`, then the app, with `codesign --force --sign - --entitlements <file>`. Take each target's file from `CODE_SIGN_ENTITLEMENTS` in `xcodebuild -showBuildSettings -json -alltargets`. Without this step the export silently drops push, Sign in with Apple and app groups. Stop if an entitlements file contains `$(...)` variables.
3. Export with `signingStyle` `automatic` and `teamID`, plus `-allowProvisioningUpdates -authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID`. Apple's cloud signing re-signs everything for distribution.

The reference implementation is `scripts/ios-cloud-signing.sh` (`load_asc_key`, `adhoc_sign_archive`, `cloud_export`), shared by pacey, remy, lovetalk and bunny-stamps. Copy it rather than rewriting it.

Before trusting a changed release flow, export to a local `.ipa` without uploading. Then require `codesign --verify --deep --strict` to pass and Apple Distribution on every bundle. Compare each target's entitlements with the last shipped build. The only allowed differences are `aps-environment` production, `get-task-allow` false, and `beta-reports-active`.

## Never

- Never change the default keychain or the keychain search list (`security list-keychains -s`, `default-keychain -s`), even temporarily. `codesign` cannot use an identity from a keychain outside the search list, so a dedicated signing keychain only works by breaking this rule. Don't use one.
- Never lock, unlock, reset, rename, delete, or change the password of a personal keychain. Never run `set-key-partition-list` or export private keys from one.
- Never install a distribution identity in the login keychain. Xcode may sign with it instead of cloud signing.

If cloud signing is unavailable (no API key with access to the team), stop and report it. Don't fall back to a keychain.
