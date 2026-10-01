---
name: noninteractive-apple-signing
description: Use when Apple build or release automation needs a macOS signing keychain. Do not use for App Store metadata or review work that does not build or sign.
---

Use a dedicated signing keychain without changing keychain access for other apps.

Before an Apple build, archive, export, or upload:

1. Require an explicit existing signing keychain and password. Resolve its real path. Reject the default keychain, personal `login` keychains including renamed copies, and system keychains before unlocking or changing permissions. Missing configuration is fatal.
2. Never change the user's default keychain or keychain search list, even temporarily. `security list-keychains -d user -s` changes shared state for every app and concurrent build. Cleanup cannot make this safe. Never lock, reset, rename, delete, or change the password of a personal keychain.
3. Unlock only the configured signing keychain, with a bounded timeout. Find the required identity explicitly in that keychain. Select its certificate hash and pass `--keychain` to `codesign`. Preserve the normal search list for certificate-chain lookup.
4. For Xcode, pass that identity through `CODE_SIGN_IDENTITY` and the keychain through `OTHER_CODE_SIGN_FLAGS`. Use invocation-scoped build settings or a temporary `XCODE_XCCONFIG_FILE`, preserving existing overrides. Expo wrappers must propagate these settings to their `xcodebuild` subprocess. Never solve identity selection by hiding other keychains.
5. Codesign and verify a throwaway binary with the selected identity and keychain before version changes, dependency installs, prebuild, archive, or export. Bound the probe so an authorization dialog cannot leave it waiting for a person. A failed probe stops the workflow.
6. Do not run `set-key-partition-list` on every build. Use it only when provisioning or repairing the explicitly authorized dedicated signing keychain, scoped to the required signing keys. Never run it without a keychain argument or against a personal or system keychain. Do not clear existing access permissions to silence an error.
7. If an authorization or password dialog appears, cancel the operation and fail preflight. Never tell the user to approve it or enter a password. Missing certificate-chain material or unavailable credentials requires a specific diagnosis, not changes to personal keychains.

For an isolated clone, reference a stable signing keychain outside the repository through explicit environment variables. Copy only named environment files. Validate signing configuration, App Store Connect key paths, and provisioning profiles before changing version or build state. Do not copy personal keychains or depend on ignored `build/` contents.
