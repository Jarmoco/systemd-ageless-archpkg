#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/pkg"
REPO_NAME="systemd-ageless"
CHROOT_DIR="/var/lib/archbuild/extra-x86_64"
ASSUME_YES=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -y, --yes    Assume yes to all prompts"
    echo "  -h, --help   Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

confirm() {
    local prompt="$1"
    if [ "$ASSUME_YES" -eq 1 ]; then
        return 0
    fi
    read -p "$prompt [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        return 1
    fi
    return 0
}

echo -e "${GREEN}systemd-ageless build & setup script${NC}"
echo "======================================"
echo

check_deps() {
    local missing_cmds=()
    local required_packages=()

    if ! command -v makechrootpkg >/dev/null 2>&1; then
        missing_cmds+=("makechrootpkg")
        required_packages+=("devtools")
    fi

    if ! command -v namcap >/dev/null 2>&1; then
        missing_cmds+=("namcap")
        required_packages+=("namcap")
    fi

    if [ ${#required_packages[@]} -gt 0 ]; then
        echo -e "${YELLOW}[Deps] Installing required tools...${NC}"
        echo "  Missing: ${missing_cmds[*]}"
        echo "  Installing: ${required_packages[*]}"
        echo
        sudo pacman -S --needed "${required_packages[@]}"
        echo -e "${GREEN}[Deps] Tools installed${NC}"
    fi
}

clear_bad_cache() {
    echo -e "${YELLOW}[Cache] Checking for corrupted packages in cache...${NC}"
    
    local cache_dir="/var/cache/pacman/pkg"
    local bad_patterns=("systemd-260" "systemd-libs-260")
    local found_bad=0
    
    for pattern in "${bad_patterns[@]}"; do
        for file in "$cache_dir"/${pattern}*.pkg.tar.zst; do
            if [ -f "$file" ]; then
                echo "  Removing corrupted cache: $(basename "$file")"
                sudo rm -f "$file"
                found_bad=1
            fi
        done
    done
    
    if [ "$found_bad" -eq 1 ]; then
        echo -e "${GREEN}[Cache] Corrupted packages removed${NC}"
        echo "  Refreshing pacman databases..."
        sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true
    fi
    
    echo -e "${GREEN}[Cache] Done${NC}"
}

handle_existing_systemd() {
    if pacman -Qs "^systemd$" >/dev/null 2>&1; then
        echo -e "${YELLOW}[Info] Official systemd is currently installed${NC}"
        echo
        echo "The fork will replace it via conflicts/replaces."
        echo "After running 'pacman -Syu', pacman will prompt to replace the packages."
        echo
        if ! confirm "Continue building?"; then
            exit 0
        fi
    fi
}

ensure_chroot() {
    local root="$CHROOT_DIR/root"

    if [ ! -d "$root" ]; then
        echo "  Creating chroot..."
        sudo mkdir -p "$CHROOT_DIR"
        sudo mkarchroot "$root" base-devel
    fi

    if [ ! -f "$root/etc/makepkg.conf" ]; then
        echo -e "${YELLOW}  Root chroot incomplete, rebuilding...${NC}"
        sudo rm -rf "$root"
        sudo mkdir -p "$CHROOT_DIR"
        sudo mkarchroot "$root" base-devel
    fi
}

build_package() {
    echo -e "${YELLOW}[Build] Building package in clean chroot...${NC}"
    echo

    ensure_chroot

    if ! makechrootpkg -c -r "$CHROOT_DIR" -- --skippgpcheck; then
        echo -e "${RED}[Error] Build failed!${NC}"
        exit 1
    fi

    echo
    echo -e "${GREEN}[Build] Package built successfully${NC}"
}

run_namcap() {
    echo -e "${YELLOW}[Check] Running namcap...${NC}"
    echo

    echo "--- PKGBUILD checks ---"
    namcap PKGBUILD || true
    echo

    echo "--- Package checks ---"
    for pkg in *.pkg.tar.zst; do
        echo "Checking $pkg:"
        namcap "$pkg" || true
        echo
    done

    echo -e "${GREEN}  Namcap checks complete${NC}"
}

update_srcinfo() {
    echo -e "${YELLOW}[Info] Updating .SRCINFO...${NC}"
    makepkg --printsrcinfo > "$SCRIPT_DIR/.SRCINFO"
    echo -e "${GREEN}  .SRCINFO updated${NC}"
}

setup_pkg_dir() {
    echo -e "${YELLOW}[Setup] Setting up package directory...${NC}"

    mkdir -p "$PKG_DIR"

    local pkg_count
    pkg_count=$(ls -1 *.pkg.tar.zst 2>/dev/null | wc -l)
    if [ "$pkg_count" -eq 0 ]; then
        echo -e "${RED}[Error] No package files found!${NC}"
        exit 1
    fi

    echo -e "${GREEN}  Found $pkg_count package(s)${NC}"
}

cleanup_old_packages() {
    echo -e "${YELLOW}[Cleanup] Removing old packages...${NC}"

    local after_count
    cp -f *.pkg.tar.zst "$PKG_DIR/"
    after_count=$(ls -1 "$PKG_DIR"/*.pkg.tar.zst 2>/dev/null | wc -l)

    echo -e "${GREEN}  Cleaned up, $after_count package(s) in directory${NC}"
}

cleanup_build_artifacts() {
    echo -e "${YELLOW}[Cleanup] Removing build artifacts from working directory...${NC}"

    rm -f *.pkg.tar.zst *.log

    echo -e "${GREEN}  Build artifacts cleaned${NC}"
}

update_repo() {
    echo -e "${YELLOW}[Repo] Updating repository database...${NC}"

    (
        cd "$PKG_DIR"
        repo-add "$REPO_NAME.db.tar.zst" *.pkg.tar.zst

        # Ensure database files are actual copies (not symlinks) for file:// repos
        rm -f "$REPO_NAME.db" "$REPO_NAME.files"
        cp "$REPO_NAME.db.tar.zst" "$REPO_NAME.db"
        cp "$REPO_NAME.files.tar.zst" "$REPO_NAME.files"
    )

    echo -e "${GREEN}  Repository updated${NC}"
}

print_summary() {
    echo
    echo -e "${GREEN}======================================"
    echo -e "Done!${NC}"
    echo
    echo "To install the package, run:"
    echo -e "  ${BLUE}sudo pacman -Syu${NC}"
    echo
    echo "This will:"
    echo "  1. Replace official systemd with your fork"
    echo "  2. Add systemd-ageless to your repos"
    echo
    echo "Package files location: $PKG_DIR"
}

add_pacman_repo() {
    if grep -q "^\[$REPO_NAME\]" /etc/pacman.conf 2>/dev/null; then
        echo -e "${GREEN}[Config] Repository already configured${NC}"
        return 0
    fi

    echo -e "${YELLOW}[Config] Adding repository to pacman.conf...${NC}"
    echo

    # Insert repo BEFORE [core] for priority
    local repo_config="
[$REPO_NAME]
SigLevel = Optional TrustAll
Server = http://localhost:8181
"

    # Find line number of [core] section
    local insert_line
    insert_line=$(grep -n "^\[core\]" /etc/pacman.conf | head -1 | cut -d: -f1)

    if [ -n "$insert_line" ]; then
        # Insert before first repo section
        sudo awk -v line="$insert_line" -v repo="$repo_config" '
            NR == line { print repo }
            { print }
        ' /etc/pacman.conf | sudo tee /etc/pacman.conf.tmp > /dev/null && sudo mv /etc/pacman.conf.tmp /etc/pacman.conf
    else
        # No repo found, append at end
        echo "$repo_config" | sudo tee -a /etc/pacman.conf > /dev/null
    fi

    echo -e "${GREEN}  Repository added (before [core])${NC}"
}

check_deps
handle_existing_systemd
clear_bad_cache
build_package
run_namcap
update_srcinfo
setup_pkg_dir
cleanup_old_packages
cleanup_build_artifacts
update_repo
add_pacman_repo
print_summary
