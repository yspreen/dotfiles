---
name: simslim
description: use when doing anything with an ios simulator unless the user says no slimsim or not slim or anything like that
---

# simslim (also called "slimsim")

`simslim` (installed with `brew install mobai-app/tap/simslim`, source github.com/MobAI-App/simslim) turns off the ~175 background daemons an iOS simulator starts and does not need. One simulator drops from about 4 GB and 258 processes to about 0.9 GB and 70. Use a slim simulator for every simulator task unless the user says not to.

## Before you use a simulator

1. `simslim list` shows every simulator with its state, e.g. `booted · 0/173 slim` (stock) or `173/173 slim`.
2. If the simulator you will use is not slim, slim it first. Pass the UDID, never `booted`.
   - Shut down, or yours alone: `simslim on <udid>` (persists the settings and reboots it slim; `--preserve-boot-state` leaves a shut-down one shut down).
   - Booted and in use by you, reboot unwanted: `simslim on <udid> --no-reboot`.
   - Booted and possibly in use by another agent: do not touch it. A reboot kills their app and Maestro run. Use or create another simulator, or ask.
3. `simslim on` is idempotent: running it again only applies what is missing.

## Keep what the task needs

Slimming turns features off on purpose. Name what you need:

| Task | Command |
|---|---|
| Home screen widgets, Live Activities | `simslim on <udid> --except widgets --keep com.apple.linkd` (without linkd, widget buttons do nothing) |
| StoreKit, in-app purchase, App Store, remote push | `--except store` |
| Universal links, associated domains | `--except web` |
| iCloud, Apple Account, iCloud Keychain, Sign in with Apple | `--except icloud` |
| Photos picker, photo library | `--except photos` |
| Contacts, Calendar, Reminders pickers | `--except pim` |
| Spotlight, Settings search, Files Recents | `--except search` |
| HealthKit, HomeKit | `--except health` |
| One daemon only (e.g. push) | `--keep com.apple.apsd` |

Several: `--except widgets,store`. `simslim profiles` lists all categories, `simslim profiles <id>` the daemons in one.

Need a feature for a while on a slim, booted simulator, without a reboot:
`simslim enable <udid> icloud,photos`, later `simslim disable <udid> icloud,photos`.

Check that the features a test needs work: `simslim doctor <udid> --requires push,storekit,universal-links` (exit code non-zero if one is broken; `simslim doctor --list` for the ids).

## When something looks broken

If a system feature fails on a slim simulator (a picker stays empty, a widget never updates, a purchase sheet does not appear, a link does not open the app), suspect slimming first: `simslim doctor`, then `simslim enable` the category and try again, before changing app code. To rule it out fully: `simslim off <udid>` puts the simulator back to stock with a reboot.

## Other commands

- `simslim status <udid>`: which managed daemons are disabled (not a process count).
- `simslim measure <udid>`: real memory of a booted simulator. `simslim top`: live view of all.
- `simslim boot <udid>` / `simslim shutdown <udid>`: boot and wait for services, shut down.
- `simslim clone <udid> <name>`: copy a simulator (do this before risky changes).
- `simslim watch`: slims every simulator as it boots, until Ctrl-C. Useful for xcodebuild parallel-testing clones.
- `--profile file.json` instead of `--except`/`--keep` for a repeatable setup: `{"name":"dev","except":["widgets"],"keep":[]}`.
- `simslim erase`, `simslim delete`, `simslim disk-clean` destroy data: only when the user asked.

Slow machine and `context deadline exceeded`: add `--boot-timeout 15m`.

A slim simulator still counts toward the machine's limit on booted simulators and native builds; project rules about how many agents may run simulators stay in force.
