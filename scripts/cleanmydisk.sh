#!/bin/bash
# cleanmydisk: delete regenerable caches, build output, temp files, old release builds and simulators.
# Everything here comes back on demand (package installs, builds, simulator downloads). Run: cleanmydisk [-n]
#   -n  dry run: list what would be deleted, delete nothing.
set -u
DRY=0; [ "${1:-}" = "-n" ] && DRY=1
P=~/Documents/proj
TMP=$(getconf DARWIN_USER_TEMP_DIR); CACHE=$(getconf DARWIN_USER_CACHE_DIR)
avail() { df -k /System/Volumes/Data | awk 'NR==2{print $4}'; }
start=$(avail)

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
del() {  # delete each existing path, printing its size
  for p in "$@"; do
    [ -e "$p" ] || continue
    printf '  %6s  %s\n' "$(du -sh "$p" 2>/dev/null | cut -f1)" "${p/#$HOME/~}"
    [ $DRY = 1 ] || { chmod -R u+w "$p" 2>/dev/null; rm -rf "$p"; }
  done
}
older() { find "$@" -print0 2>/dev/null | while IFS= read -r -d '' p; do del "$p"; done; }  # del every find match
running() { pgrep -fq "$1"; }

say "Chrome temp copies (left behind when Chrome is killed)"
X="${TMP}../X/com.google.Chrome.code_sign_clone"
inuse=$(lsof +D "$X" 2>/dev/null | grep -o 'code_sign_clone\.[A-Za-z0-9]*' | sort -u)
find "$X" -mindepth 1 -maxdepth 1 -mmin +60 2>/dev/null | while read -r c; do
  grep -qx "$(basename "$c")" <<<"$inuse" || del "$c"; done

say "Package manager caches"
running GradleDaemon && { echo "  stopping idle Gradle daemons"; [ $DRY = 1 ] || pkill -f GradleDaemon; }
del ~/.gradle/caches ~/.gradle/daemon ~/.bun/install/cache ~/Library/pnpm/store ~/.npm/_cacache ~/.npm/_npx \
    ~/Library/Caches/CocoaPods ~/Library/Caches/Yarn ~/Library/Caches/pnpm ~/Library/Caches/ReactNative \
    ~/Library/Caches/dotslash ~/Library/Caches/sentry-react-native ~/.cache/nodejs-compile-cache ~/.cache/uv \
    ~/.expo/android-apk-cache ~/Library/Developer/Xcode/DerivedData ~/Library/Developer/Xcode/Archives "${CACHE}clang"

say "Crash symbolication cache (rebuilt on demand; needs sudo)"
C=/System/Library/Caches/com.apple.coresymbolicationd/data
printf '  %6s  %s\n' "$(sudo du -sh "$C" 2>/dev/null | cut -f1)" "$C"
[ $DRY = 1 ] || { sudo rm -f "$C"; sudo killall coresymbolicationd 2>/dev/null; }

say "Cloud drives to online-only (files stay in the cloud, download again when opened)"
command -v evict-cloud >/dev/null || swiftc -O -o ~/.local/bin/evict-cloud "$(dirname "$(readlink -f "$0")")/evict-cloud.swift"
for d in ~/Library/CloudStorage/*/; do
  [ -d "$d" ] || continue
  echo "  $(du -sh "$d" | cut -f1) on disk  ${d/#$HOME/~}"
  [ $DRY = 1 ] || echo "  $(evict-cloud "$d")"
done

say "App caches (only for apps that aren't running)"
running Spotify.app || del ~/Library/Caches/com.spotify.client
running CapCut.app || del ~/Movies/CapCut/User\ Data/Cache

say "Temp files older than 3 days"
older "$TMP" -mindepth 1 -maxdepth 1 \( -name 'maestro_*' -o -name 'bunx-*' \) -mtime +3
older /private/tmp/claude-501 -mindepth 2 -maxdepth 2 -mtime +3
older ~/.maestro/tests -mindepth 1 -maxdepth 1 -mtime +3
older ~/.Trash -mindepth 1 -maxdepth 1

say "Build output in projects and agent clones (untouched for 2+ days, not tracked in git)"
# Never descend into .git (its objects/xx dirs look like build dirs) or media. Prune every match before the
# age test, so a fresh node_modules is skipped whole instead of having its nested folders deleted.
# Agent clones in ~/.cache keep DerivedData in a top-level "dd" folder.
find "$P" ~/.cache -maxdepth 6 \( -name .git -o -path "$P/media" \) -prune -o -type d \( -name node_modules -o -name Pods \
  -o -name build -o -name .gradle -o -name .cxx -o -name target -o -name DerivedData -o -name .next -o -name .expo \
  -o -path "$HOME/.cache/*/dd" \) -prune -mtime +2 -print 2>/dev/null | while read -r d; do
  [ -n "$(git -C "$(dirname "$d")" ls-files -- "$(basename "$d")" 2>/dev/null | head -1)" ] || del "$d"
done

say "Old release builds (pacey-ota keeps its newest .aab and .xcarchive)"
A=~/.config/pacey-ota/native-artifacts
for ext in aab xcarchive; do
  ls -td "$A"/*."$ext" 2>/dev/null | tail -n +2 | while read -r f; do del "$f" "$f.json"; done
done
older "$A" -mindepth 1 -maxdepth 1 -name 'diagnostic-candidates-*'
older "$P" ~/.cache ~/Downloads \( -name '*.aab' -o -name '*.ipa' -o -name '*.xcarchive' \) -mtime +7 -prune

say "iOS simulators (keeps only the newest runtime)"
if xcrun simctl list devices 2>/dev/null | grep -q Booted; then echo "  skipped: a simulator is booted"
else
  xcrun simctl list devices -j | jq -r '.devices[][] | "\(.udid) \(.name)"' | while read -r id name; do
    echo "  delete sim $name"; [ $DRY = 1 ] || xcrun simctl delete "$id"; done
  xcrun simctl runtime list -j | jq -r 'to_entries | sort_by(.value.version | split(".") | map(tonumber)) | .[:-1][] | "\(.key) \(.value.version)"' |
    while read -r id v; do echo "  delete runtime iOS $v"; [ $DRY = 1 ] || xcrun simctl runtime delete "$id"; done
fi

say "Android emulators and old SDK versions"
if running qemu-system; then echo "  skipped: an emulator is running"
else
  S=~/Library/Android/sdk
  del ~/.android/avd/* "$S"/system-images/*
  for d in build-tools platforms ndk cmake; do
    ls "$S/$d" 2>/dev/null | sort -V | sed '$d' | while read -r v; do del "$S/$d/$v"; done
  done
fi

say "Repack big git repos"
for g in "$P"/*/.git; do
  [ "$(du -sk "$g" | cut -f1)" -gt 1048576 ] || continue
  echo "  git gc ${g/#$HOME/~} ($(du -sh "$g" | cut -f1))"; [ $DRY = 1 ] || git -C "${g%/.git}" gc --quiet
done

freed=$(( ($(avail) - start) / 1048576 ))
say "Done. Freed ${freed}G, $(df -h /System/Volumes/Data | awk 'NR==2{print $4}') free."
