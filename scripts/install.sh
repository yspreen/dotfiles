#!/bin/bash

set -e

cd ~
sh <(curl -L https://nixos.org/nix/install)
nix-shell -p git --run 'git clone https://github.com/yspreen/dotfiles.git dotfiles'
nix run nix-darwin --extra-experimental-features 'nix-command flakes' -- switch --flake ~/dotfiles/nix#spreen
