#!/bin/bash
set -e

username=$1
export HOME=/Users/${username}

stow() {
    nix-shell -p stow --run "stow --adopt ."
}

fix_xcode_headers() {
    # for each Xcode.app in /Applications, like Xcode.app, Xcode-beta.app, etc.:
    while read -r xcode; do
        echo "Updating file header for $xcode (this will take a while)"

        # find all files that have the header:
        grep -rl '//___FILEHEADER___' "$xcode" | while read -r file; do
            # if the file is a symlink, skip it:
            if [ -L "$file" ]; then
                continue
            fi

            # if the file is a directory, skip it:
            if [ -d "$file" ]; then
                continue
            fi

            sudo sed -i '' 's|//___FILEHEADER___|___FILEHEADER___|' "$file"
        done
    done < <(find /Applications -maxdepth 1 -iname 'xcode*' | grep -iv xcodes | sort)
}

install_xcode() {
    latest="$(/opt/homebrew/bin/xcodes list | grep -iv beta | grep -iv candidate | grep -Eo '^[^ ]+' | tail -1)"
    /opt/homebrew/bin/xcodes install "$latest"
    /opt/homebrew/bin/xcodes select "$latest"
    fix_xcode_headers

    # find first Xcode*.app in /Applications and link it to /Applications/Xcode.app:
    sudo rm -rf /Applications/Xcode.app 2>/dev/null || true
    first_xcode=$(find /Applications -maxdepth 1 -iname 'Xcode*.app' | sort | head -n 1)
    sudo ln -s "$first_xcode" /Applications/Xcode.app
}

echo "#!/bin/bash" >/opt/homebrew/bin/aws
echo "" >/opt/homebrew/bin/aws
echo 'nix-shell -p awscli2 --run "aws $(printf '\''%q '\'' "$@")"' >/opt/homebrew/bin/aws
chmod +x /opt/homebrew/bin/aws

sudotouchid() {
    # check if already added:
    sudo grep -q "pam_tid.so" /etc/pam.d/sudo && return

    c="$(cat /etc/pam.d/sudo)"
    n="$(echo "$c" | wc -l)"
    echo "$c" | head -1 >.sudo.tmp
    echo 'auth sufficient pam_tid.so' >>.sudo.tmp
    echo "$c" | tail "-$((n - 1))" >>.sudo.tmp
    sudo mv .sudo.tmp /etc/pam.d/sudo
}

sudotouchid

/bin/launchctl load -w /Library/LaunchAgents/homebrew.mxcl.sketchybar.plist 2>/dev/null

./decrypt-ssh.sh && cd .. && stow

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

sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

mkdir -p /opt/homebrew/bin
echo 'nix-shell -p gh --run "gh $(printf "%q " "$@")"' >/opt/homebrew/bin/gh
echo 'nix-shell -p ncdu --run "ncdu $(printf "%q " "$@")"' >/opt/homebrew/bin/ncdu
echo 'nix-shell -p doppler --run "doppler $(printf "%q " "$@")"' >/opt/homebrew/bin/doppler
echo 'nix-shell -p xcodes --run "xcodes $(printf "%q " "$@")"' >/opt/homebrew/bin/xcodes
echo 'nix-shell -p tree --run "tree $(printf "%q " "$@")"' >/opt/homebrew/bin/tree
echo 'nix-shell -p terraform --run "terraform $(printf "%q " "$@")"' >/opt/homebrew/bin/terraform
echo 'nix-shell -p mosh --run "mosh $(printf "%q " "$@")"' >/opt/homebrew/bin/mosh
echo 'nix-shell -p nginx --run "nginx $(printf "%q " "$@")"' >/opt/homebrew/bin/nginx
echo 'nix-shell -p neofetch --run "neofetch $(printf "%q " "$@")"' >/opt/homebrew/bin/neofetch
echo 'nix-shell -p xcbeautify --run "xcbeautify $*"' >/opt/homebrew/bin/xcbeautify
echo '
#!/bin/bash
OLD_WORKING_DIR=$(pwd)
cd ~/dotfiles/scripts/mcp-sentry
pnpm install >/dev/null 2>&1
pnpm --silent run latest-issue "$@" --cwd="$OLD_WORKING_DIR"
cd "$OLD_WORKING_DIR"' >/opt/homebrew/bin/sentry-latest

echo '#!/bin/bash
raw_flyctl() {
  nix-shell -p flyctl --run "flyctl $(printf "%q " "$@")"
}

# find nearest .fly_token in parent directories
find_fly_token() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.fly_token" ]]; then
            echo "$dir/.fly_token"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

if token_file=$(find_fly_token); then
  token=$(cat "$token_file")
  raw_flyctl --access-token "$token" "$@"
else
  raw_flyctl "$@"
fi
' >/opt/homebrew/bin/flyctl
echo '#!/bin/bash
flyctl "$@"' >/opt/homebrew/bin/fly
chmod +x /opt/homebrew/bin/* 2>/dev/null || true

[ $(find /Applications -maxdepth 1 -iname 'xcode*' | wc -l) -gt 0 ] || install_xcode
which xcodebuild || xcode-select --install

[ -d ~/Applications/Gmail.app ] || unzip -q ~/dotfiles/other/Gmail.zip -d ~/Applications
