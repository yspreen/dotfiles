#!/bin/zsh

source ~/.zshrc

cd ~/dotfiles

# Check if password file exists, create if not
if [ ! -f .ssh_pw ]; then
    uuidgen >.ssh_pw
fi

PASSWORD=$(cat .ssh_pw)

# Compress and encrypt .ssh directory
tar -czf - .ssh .aws .doppler .npmrc .gnupg scriptswithsecrets | gpg --batch --yes --symmetric --passphrase "$PASSWORD" -o .ssh_enc

echo "SSH directory encrypted to .ssh_enc using password from .ssh_pw"
