---
name: noninteractive-apple-signing
description: Use when Apple build or release automation needs a macOS signing keychain. Do not use for App Store metadata or review work that does not build or sign.
version: 1.0.0
---

Codex broke release autonomy by copying env files without the signing keychain, swallowing `security set-key-partition-list` failure, and starting Xcode without a codesign probe.

Before any Apple build, archive, export, or upload:

1. Require explicit keychain path and password variables. Never guess paths or passwords and never fall back to the login keychain.
2. Verify the configured keychain exists. Missing configuration or files are fatal.
3. Unlock the keychain and run `security set-key-partition-list -S apple-tool:,apple:,codesign:`. Any failure is fatal.
4. Save the user keychain search list, restrict it to the configured signing keychain plus explicitly named keychains needed for certificate-chain validation, and restore it on success, failure, interruption, and shell exit. Never inherit the ambient list.
5. Codesign and verify a throwaway binary with the selected identity and `--keychain` before version changes, dependency installs, prebuild, archive, or export.
6. If any authorization or password dialog appears, the run failed. Stop or cancel the process and dismiss the dialog when safe. Never tell the user to approve it or enter a password.

For an isolated clone, use a canonical path outside `/tmp`. Reference a stable keychain outside every repository and clone through explicit environment variables. Copy only named environment files and validate the signing keychain path, password variable, App Store Connect key path, and required provisioning profiles before changing version or build state. Never depend on ignored `build/` contents or ambient macOS keychain search state.
