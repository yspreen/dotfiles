#!/bin/bash
set -e

username=$(whoami)
export HOME=/Users/${username}

install_xcode() {
    latest="$(nix-shell -p xcodes --run "xcodes list" | grep -iv beta | grep -Eo '^[^ ]+' | tail -1)"
    nix-shell -p xcodes --run "xcodes install $latest"
}

find /Applications -maxdepth 1 -iname 'xcode*' >/dev/null || install_xcode
which xcodebuild || xcode-select --install

/bin/launchctl load -w /Library/LaunchAgents/homebrew.mxcl.sketchybar.plist 2>/dev/null

./decrypt-ssh.sh && cd .. && stow --adopt .

install_oh_my_zsh() {
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh ~/.oh-my-zsh
}

[ -d ~/.oh-my-zsh ] || install_oh_my_zsh

[ -d ~/.oh-my-zsh/themes/powerlevel10k ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/themes/powerlevel10k

cd copy
find . -type f | while read file; do
    target_dir="$HOME/$(dirname "$file")"
    mkdir -p "$target_dir"
    diff "$file" "$HOME/$file" >/dev/null 2>&1 ||
        (cp -f "$file" "$HOME/$file" &&
            echo "$file -> $HOME/$file")
done
echo "Finished copying files to home directory."
cd ..

defaults write com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID -string "org.sil.ukelele.keyboardlayout..u.s.qwerty+umlaut"

defaults write com.apple.HIToolbox AppleEnabledInputSources -array \
    '<dict>
        <key>Bundle ID</key>
        <string>com.apple.CharacterPaletteIM</string>
        <key>InputSourceKind</key>
        <string>Non Keyboard Input Method</string>
    </dict>' \
    '<dict>
        <key>Bundle ID</key>
        <string>com.apple.inputmethod.ironwood</string>
        <key>InputSourceKind</key>
        <string>Non Keyboard Input Method</string>
    </dict>' \
    '<dict>
        <key>Bundle ID</key>
        <string>com.apple.PressAndHold</string>
        <key>InputSourceKind</key>
        <string>Non Keyboard Input Method</string>
    </dict>'
# Original U.S. layout commented out
# '<dict>
#     <key>InputSourceKind</key>
#     <string>Keyboard Layout</string>
#     <key>KeyboardLayout ID</key>
#     <integer>0</integer>
#     <key>KeyboardLayout Name</key>
#     <string>U.S.</string>
# </dict>'

defaults write com.apple.HIToolbox AppleInputSourceHistory -array \
    '<dict>
        <key>InputSourceKind</key>
        <string>Keyboard Layout</string>
        <key>KeyboardLayout ID</key>
        <integer>-26430</integer>
        <key>KeyboardLayout Name</key>
        <string>U.S. qwerty + umlaut</string>
    </dict>'
# Original U.S. layout commented out
# '<dict>
#     <key>InputSourceKind</key>
#     <string>Keyboard Layout</string>
#     <key>KeyboardLayout ID</key>
#     <integer>0</integer>
#     <key>KeyboardLayout Name</key>
#     <string>U.S.</string>
# </dict>'

defaults write com.apple.HIToolbox AppleSelectedInputSources -array \
    '<dict>
        <key>InputSourceKind</key>
        <string>Keyboard Layout</string>
        <key>KeyboardLayout ID</key>
        <integer>-26430</integer>
        <key>KeyboardLayout Name</key>
        <string>U.S. qwerty + umlaut</string>
    </dict>'

# Add AppleFnUsageType setting
defaults write com.apple.HIToolbox AppleFnUsageType -int 2
defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 1

# Add com.apple.inputsources configuration
defaults write com.apple.inputsources AppleEnabledThirdPartyInputSources -array \
    '<dict>
        <key>InputSourceKind</key>
        <string>Keyboard Layout</string>
        <key>KeyboardLayout ID</key>
        <integer>-26430</integer>
        <key>KeyboardLayout Name</key>
        <string>U.S. qwerty + umlaut</string>
    </dict>'

# Step 2. Restart SystemUIServer so the changes are picked up.
killall SystemUIServer

/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
killall SystemUIServer
killall -HUP cfprefsd
