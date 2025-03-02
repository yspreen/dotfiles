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
