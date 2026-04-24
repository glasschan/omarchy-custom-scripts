#!/bin/bash
#
# common.sh - Shared helper functions for omarchy-custom-scripts
#
# This library eliminates code duplication across all setup scripts.
# All scripts source this file for logging, package management, and
# common utilities.

# Exit on error by default
set -e

# ========================================
# Color definitions
# ========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ========================================
# Logging functions
# ========================================

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

detail() {
    echo -e "${BLUE}[DETAIL]${NC} $1"
}

header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# ========================================
# Package management
# ========================================

check_package() {
    pacman -Q "$1" &>/dev/null
}

install_package() {
    local pkg="$1"
    if check_package "$pkg"; then
        info "$pkg 已安裝，跳過"
        return 0
    fi

    info "正在安裝 $pkg..."
    if command -v paru &>/dev/null; then
        paru -S --noconfirm "$pkg"
    elif command -v yay &>/dev/null; then
        yay -S --noconfirm "$pkg"
    else
        sudo pacman -S --noconfirm "$pkg"
    fi
}

# ========================================
# Common utilities
# ========================================

confirm() {
    read -p "$1 (y/N): " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]]
}

config_contains() {
    local file="$1"
    local pattern="$2"
    [[ -f "$file" ]] && grep -q "$pattern" "$file"
}

ensure_dir() {
    mkdir -p "$(dirname "$1")"
}

create_backup() {
    local file="$1"
    local backup_file="${file}.bak.$(date +%s)"
    if [[ -f "$file" ]]; then
        cp "$file" "$backup_file"
        detail "已備份原始設定: $backup_file"
    fi
}

# Standard usage template (scripts can append their own examples)
usage_template() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTION]

Options:
  -i, --install     安裝/設定 (預設)
  -u, --uninstall   還原設定
  -s, --status      顯示目前狀態
  -h, --help        顯示此說明

Examples:
  $SCRIPT_NAME              # 安裝/設定
  $SCRIPT_NAME -u           # 還原設定
  $SCRIPT_NAME -s           # 檢查狀態
EOF
}
