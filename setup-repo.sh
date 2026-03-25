#!/bin/bash

set -euo pipefail

REPO_NAME="systemd-ageless"
REPO_SIGLEVEL="Optional TrustAll"
REPO_SERVER="https://jarmoco.github.io/systemd-ageless-archpkg/pkg"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root.${NC}"
    echo "Usage: curl -sSL https://jarmoco.github.io/systemd-ageless-archpkg/setup-repo.sh | sudo bash"
    exit 1
fi

PACMAN_CONF="/etc/pacman.conf"

if ! [ -f "$PACMAN_CONF" ]; then
    echo -e "${RED}Error: $PACMAN_CONF not found.${NC}"
    exit 1
fi

# Extract the repo block for an existing installation.
# We match from the [systemd-ageless] header to the next blank line or end of file.
extract_repo_block() {
    sed -n "/^\[$REPO_NAME\]/,/^$/p" "$PACMAN_CONF"
}

verify_repo_block() {
    local block="$1"
    local ok=true

    local current_siglevel
    current_siglevel=$(echo "$block" | grep -i "^SigLevel\s*=" | sed 's/^SigLevel\s*=\s*//')
    if [ "$current_siglevel" != "$REPO_SIGLEVEL" ]; then
        echo -e "${YELLOW}  SigLevel mismatch: expected '$REPO_SIGLEVEL', found '$current_siglevel'${NC}"
        ok=false
    fi

    local current_server
    current_server=$(echo "$block" | grep -i "^Server\s*=" | sed 's/^Server\s*=\s*//')
    if [ "$current_server" != "$REPO_SERVER" ]; then
        echo -e "${YELLOW}  Server mismatch: expected '$REPO_SERVER', found '$current_server'${NC}"
        ok=false
    fi

    if $ok; then
        return 0
    else
        return 1
    fi
}

if grep -q "^\[$REPO_NAME\]" "$PACMAN_CONF"; then
    block=$(extract_repo_block)
    echo -e "${GREEN}Repository [$REPO_NAME] already present in $PACMAN_CONF.${NC}"
    if verify_repo_block "$block"; then
        echo -e "${GREEN}SigLevel and Server values are correct. Nothing to do.${NC}"
        exit 0
    else
        echo -e "${RED}The existing configuration has incorrect values.${NC}"
        echo "Fix them manually or remove the [$REPO_NAME] block and re-run this script."
        exit 1
    fi
fi

insert_line=$(grep -n "^\[core\]" "$PACMAN_CONF" | head -1 | cut -d: -f1)

if [ -n "$insert_line" ]; then
    echo -e "${YELLOW}Adding [$REPO_NAME] to $PACMAN_CONF (before [core])...${NC}"
    tmpfile=$(mktemp)
    printf "[%s]\nSigLevel = %s\nServer = %s\n\n" \
        "$REPO_NAME" "$REPO_SIGLEVEL" "$REPO_SERVER" > "$tmpfile"
    sed -i "$((insert_line-1))r $tmpfile" "$PACMAN_CONF"
    rm -f "$tmpfile"
else
    echo -e "${YELLOW}Adding [$REPO_NAME] to $PACMAN_CONF (appending at end)...${NC}"
    printf "\n[%s]\nSigLevel = %s\nServer = %s\n" \
        "$REPO_NAME" "$REPO_SIGLEVEL" "$REPO_SERVER" >> "$PACMAN_CONF"
fi

echo -e "${GREEN}Repository added successfully.${NC}"
echo
echo "Next steps:"
echo "  sudo pacman -Syu"
echo "  reboot"
