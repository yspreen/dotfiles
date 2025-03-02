#!/bin/bash

set -e

# print "WARNING" in dark yellow
echo -e "\033[33;1m⚠️ ======== *** WARNING *** ======== ⚠️\033[0m"

echo "We are about to replace your entire system configuration. This will install nix and overwrite your nix installation. This script will override all home directory configuration files. We will also uninstall all home brew packages. You probably don't want to run these commands if your name is not Nick. To familiarize yourself more with what will be installed please check https://github.com/yspreen/dotfiles"

# print "WARNING" in dark yellow
echo -e "\033[33;1m⚠️ ======== *** WARNING *** ======== ⚠️\033[0m"

echo

# Insert confirmation prompt before running any commands
read -p "Are you sure you want to run these commands? (y/N): " answer
if [[ $answer != "y" && $answer != "Y" ]]; then
    echo "Aborted"
    exit 1
fi

cd ~
sh <(curl -L https://nixos.org/nix/install)
nix-shell -p git --run 'git clone https://github.com/yspreen/dotfiles.git dotfiles'
~/dotfiles/scripts/decrypt-ssh.sh
nix run nix-darwin --extra-experimental-features 'nix-command flakes' -- switch --impure --flake ~/dotfiles/nix#spreen
