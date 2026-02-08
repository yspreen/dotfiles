#!/bin/zsh

source ~/.zshrc

cd ~/dotfiles

# Check if password file exists, create if not
if [ ! -f .ssh_pw ]; then
    uuidgen >.ssh_pw
fi

PASSWORD=$(cat .ssh_pw)

# Build list of items to include only if they exist
items=(.ssh .aws .doppler .npmrc .gnupg scriptswithsecrets .sentryclirc .appstoreconnect)
existing=()
for item in $items; do
    if [ -e "$item" ]; then
        existing+=("$item")
    fi
done

if [ ${#existing[@]} -eq 0 ]; then
    echo "No files or directories to encrypt. None of the following exist: ${items[*]}"
    exit 0
fi

# Compress and encrypt the existing items
if tar -czf - "${existing[@]}" | gpg --batch --yes --symmetric --passphrase "$PASSWORD" -o .ssh_enc; then
    echo "Encrypted: ${existing[*]} -> .ssh_enc using password from .ssh_pw"
else
    echo "Encryption failed" >&2
    exit 1
fi
