#!/bin/zsh

source ~/.zshrc

# Get script directory
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR/.." || exit 1

# Check if password file exists, create if not
if [ ! -f .ssh_pw ]; then
    uuidgen >.ssh_pw
fi

PASSWORD=$(cat .ssh_pw)

# Compress and encrypt .ssh directory
tar -czf - .ssh .aws .doppler | gpg --batch --yes --symmetric --passphrase "$PASSWORD" -o .ssh_enc

echo "SSH directory encrypted to .ssh_enc using password from .ssh_pw"
