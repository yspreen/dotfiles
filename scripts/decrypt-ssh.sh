#!/bin/bash

gpg() {
    nix-shell -p gnupg --run "gpg $(printf '%q ' "$@")"
}

# Get script directory
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR/.." || exit 1

# Setup pre-commit hook
HOOKS_DIR=.git/hooks
mkdir -p "$HOOKS_DIR"
printf '#!/bin/bash\nexec "$(git rev-parse --show-toplevel)/scripts/pre-commit.sh"\n' >"$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

# Skip if all managed secret files/directories already exist
managed_items=(.ssh .aws .doppler .npmrc .gnupg scriptswithsecrets secrets .sentryclirc .appstoreconnect)
missing_items=()
for item in "${managed_items[@]}"; do
    if [ ! -e "$item" ]; then
        missing_items+=("$item")
    fi
done

if [ ${#missing_items[@]} -eq 0 ]; then
    echo "All managed secret files/directories already exist, skipping decryption"
    exit 0
fi

# Get password from file or prompt
if [ -f .ssh_pw ]; then
    PASSWORD=$(cat .ssh_pw)
else
    echo "No .ssh_pw found. Please enter the decryption password:"
    read -r PASSWORD
fi

# Check if encrypted file exists
if [ ! -f .ssh_enc ]; then
    echo "Error: .ssh_enc not found"
    exit 1
fi

# Decrypt and extract
gpg --batch --yes --decrypt --passphrase "$PASSWORD" .ssh_enc | tar xzf -


echo "Managed secret files/directories decrypted successfully"
