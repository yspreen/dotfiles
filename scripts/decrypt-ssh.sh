#!/bin/bash

gpg() {
    nix-shell -p gnupg --run "gpg $(printf '%q ' "$@")"
}

# Get script directory
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR/.." || exit 1

# Skip if .ssh already exists
if [ -d .ssh ]; then
    echo ".ssh directory already exists, skipping decryption"
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

# Setup pre-commit hook
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"
PRE_COMMIT="$HOOKS_DIR/pre-commit"

mkdir -p "$HOOKS_DIR"
cat >"$PRE_COMMIT" <<'EOL'
#!/bin/bash

DOTFILES_ROOT="$(git rev-parse --show-toplevel)"
"$DOTFILES_ROOT/scripts/encrypt-ssh.sh"

# Add the encrypted file to the commit if it changed
if git status --porcelain | grep -q ".ssh_enc"; then
    git add .ssh_enc
fi
EOL

chmod +x "$PRE_COMMIT"

echo "SSH directory decrypted successfully"
echo "Pre-commit hook installed"
