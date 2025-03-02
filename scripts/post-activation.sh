#!/bin/bash

/bin/launchctl load -w /Library/LaunchAgents/homebrew.mxcl.sketchybar.plist 2>/dev/null

./scripts/decrypt-ssh.sh && stow --adopt .

install_oh_my_zsh() {
    cp ../.zshrc my.zshrc
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    mv my.zshrc ../.zshrc
}

[ -d /Users/${username}/.oh-my-zsh ] || install_oh_my_zsh

[ -d /Users/${username}/.oh-my-zsh/themes/powerlevel10k ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /Users/${username}/.oh-my-zsh/themes/powerlevel10k
