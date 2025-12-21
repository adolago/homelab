#!/bin/bash
# Setup SOPS with age encryption for homelab secrets
set -e

KEYS_DIR="$HOME/.config/sops/age"
KEYS_FILE="$KEYS_DIR/keys.txt"
SOPS_CONFIG="$(dirname "$0")/../.sops.yaml"

echo "=== SOPS + age Setup for Homelab ==="
echo ""

# Check dependencies
if ! command -v sops &> /dev/null; then
    echo "Installing sops..."
    if command -v paru &> /dev/null; then
        paru -S --noconfirm sops
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm sops
    else
        echo "Please install sops manually"
        exit 1
    fi
fi

if ! command -v age &> /dev/null; then
    echo "Installing age..."
    if command -v paru &> /dev/null; then
        paru -S --noconfirm age
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm age
    else
        echo "Please install age manually"
        exit 1
    fi
fi

# Generate age key if not exists
if [ ! -f "$KEYS_FILE" ]; then
    echo "Generating age key..."
    mkdir -p "$KEYS_DIR"
    age-keygen -o "$KEYS_FILE"
    chmod 600 "$KEYS_FILE"
    echo ""
    echo "Age key generated at: $KEYS_FILE"
else
    echo "Age key already exists at: $KEYS_FILE"
fi

# Extract public key
PUBLIC_KEY=$(grep "public key:" "$KEYS_FILE" | cut -d: -f2 | tr -d ' ')
echo ""
echo "Your age public key:"
echo "  $PUBLIC_KEY"
echo ""

# Update .sops.yaml with the public key
if [ -f "$SOPS_CONFIG" ]; then
    echo "Updating .sops.yaml with your public key..."
    sed -i "s/age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/$PUBLIC_KEY/g" "$SOPS_CONFIG"
    echo "Done!"
else
    echo "Warning: .sops.yaml not found at $SOPS_CONFIG"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Usage:"
echo "  1. Create vault file: cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml"
echo "  2. Encrypt it: sops --encrypt --in-place ansible/group_vars/all/vault.yml"
echo "  3. Edit encrypted: sops ansible/group_vars/all/vault.yml"
echo "  4. Use in playbook: ansible-playbook playbooks/site.yml"
echo ""
echo "SOPS will automatically decrypt when SOPS_AGE_KEY_FILE is set or keys are in $KEYS_DIR"
