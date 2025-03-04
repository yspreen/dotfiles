#!/bin/bash
set -e

username=$(whoami)
export HOME=/Users/${username}

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
    cp -f "$file" "$HOME/$file"
    echo "$file -> $HOME/$file"
done
echo "Finished copying files to home directory."
cd ..

# Create temporary plist files for each setting
cat >/tmp/AppleCurrentKeyboardLayoutInputSourceID.txt <<EOF
"org.sil.ukelele.keyboardlayout..u.s.qwerty+umlaut"
EOF

cat >/tmp/AppleDictationAutoEnable.txt <<EOF
1
EOF

cat >/tmp/AppleEnabledInputSources.plist <<EOF
(
    {
        "Bundle ID" = "com.apple.CharacterPaletteIM";
        "InputSourceKind" = "Non Keyboard Input Method";
    },
    {
        "Bundle ID" = "com.apple.inputmethod.ironwood";
        "InputSourceKind" = "Non Keyboard Input Method";
    },
    {
        "Bundle ID" = "com.apple.PressAndHold";
        "InputSourceKind" = "Non Keyboard Input Method";
    },
    {
        "InputSourceKind" = "Keyboard Layout";
        "KeyboardLayout ID" = 0;
        "KeyboardLayout Name" = "U.S.";
    }
)
EOF

cat >/tmp/AppleFnUsageType.txt <<EOF
2
EOF

cat >/tmp/AppleInputSourceHistory.plist <<EOF
(
    {
        "InputSourceKind" = "Keyboard Layout";
        "KeyboardLayout ID" = -26430;
        "KeyboardLayout Name" = "U.S. qwerty + umlaut";
    },
    {
        "InputSourceKind" = "Keyboard Layout";
        "KeyboardLayout ID" = 0;
        "KeyboardLayout Name" = "U.S.";
    }
)
EOF

cat >/tmp/AppleSelectedInputSources.plist <<EOF
(
    {
        "Bundle ID" = "com.apple.PressAndHold";
        "InputSourceKind" = "Non Keyboard Input Method";
    },
    {
        "InputSourceKind" = "Keyboard Layout";
        "KeyboardLayout ID" = -26430;
        "KeyboardLayout Name" = "U.S. qwerty + umlaut";
    }
)
EOF

# Apply all settings
defaults write com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID "$(cat /tmp/AppleCurrentKeyboardLayoutInputSourceID.txt)"
defaults write com.apple.HIToolbox AppleDictationAutoEnable "$(cat /tmp/AppleDictationAutoEnable.txt)"
defaults write com.apple.HIToolbox AppleEnabledInputSources -array "$(cat /tmp/AppleEnabledInputSources.plist)"
defaults write com.apple.HIToolbox AppleFnUsageType "$(cat /tmp/AppleFnUsageType.txt)"
defaults write com.apple.HIToolbox AppleInputSourceHistory -array "$(cat /tmp/AppleInputSourceHistory.plist)"
defaults write com.apple.HIToolbox AppleSelectedInputSources -array "$(cat /tmp/AppleSelectedInputSources.plist)"

# Clean up temporary files
rm /tmp/AppleCurrentKeyboardLayoutInputSourceID.txt
rm /tmp/AppleDictationAutoEnable.txt
rm /tmp/AppleEnabledInputSources.plist
rm /tmp/AppleFnUsageType.txt
rm /tmp/AppleInputSourceHistory.plist
rm /tmp/AppleSelectedInputSources.plist
