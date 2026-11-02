#!/bin/bash
#
# common.sh - Shared helper functions for omarchy-custom-scripts
#
# This library eliminates code duplication across all setup scripts.
# All scripts source this file for logging, package management, and
# common utilities.

# Note: set -e removed from shared library. Sourced by multiple scripts where
# strict error-exit causes surprising failures (e.g., grep returning 1 in guards).
# Individual scripts can add their own error handling as needed.

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

create_backup() {
    local file="$1"
    local backup_file="${file}.bak.$(date +%s)"
    if [[ -f "$file" ]]; then
        cp "$file" "$backup_file"
        detail "已備份原始設定: $backup_file"
    fi
}

# ========================================
# State snapshots
# ========================================

# Record the pre-install original of <file> under <state_dir>/<name>, for -u
# to restore (state_dir is ~/.local/state/omarchy-custom-scripts/<script>).
# Never overwrites an existing snapshot, so repeat -i keeps the true
# pre-install state. A <name>.absent marker records that the file did not exist.
# Usage: snapshot_original <state_dir> <file> <name>
snapshot_original() {
    local state_dir="$1" file="$2" name="$3"
    if [[ -f "$state_dir/$name" || -f "$state_dir/$name.absent" ]]; then
        detail "已有 $name 原狀快照，保留最原始版本"
        return 0
    fi
    mkdir -p "$state_dir"
    if [[ -f "$file" ]]; then
        cp "$file" "$state_dir/$name"
        detail "已記錄 $file 原狀"
    else
        touch "$state_dir/$name.absent"
        detail "已記錄 $file 原本不存在"
    fi
}

# Restore what snapshot_original recorded for <name>. No snapshot means -i
# never modified the file, so this skips (and -u callers may treat "no
# snapshot dir" as "nothing this script added, touch nothing").
# Usage: restore_original <state_dir> <file> <name>
restore_original() {
    local state_dir="$1" file="$2" name="$3"
    if [[ -f "$state_dir/$name" ]]; then
        mkdir -p "$(dirname "$file")"
        cp "$state_dir/$name" "$file"
        info "已還原 $file 原狀"
    elif [[ -f "$state_dir/$name.absent" ]]; then
        rm -f "$file"
        info "已移除 $file（原本不存在，不留空殼）"
    else
        info "$file 安裝時未被修改，跳過還原"
    fi
}

# Remove a snapshot dir once its state has been restored (plus the now-empty
# parent). No-op when the dir is already gone.
# Usage: cleanup_state_dir <state_dir>
cleanup_state_dir() {
    local state_dir="$1"
    if [[ -d "$state_dir" ]]; then
        rm -rf "$state_dir"
        rmdir "$(dirname "$state_dir")" 2>/dev/null || true
    fi
}

# ========================================
# Hyprland Lua marker blocks
# ========================================

# Remove a marker block appended by a setup script (v4 Lua configs).
# Blocks are always appended at end of file: delete from the BEGIN marker line
# to EOF, plus the one preceding blank line, so the file returns byte-identical
# to its pre-install content. No-op when the marker is absent.
# Usage: strip_block <file> <begin_marker>
strip_block() {
    local file="$1" marker="$2"
    local first_line
    first_line=$(grep -n -F -- "$marker" "$file" | cut -d: -f1 | head -1)
    [[ -z "$first_line" ]] && return 0

    local cut_line=$first_line
    if (( cut_line > 1 )) && [[ -z "$(sed -n "$((cut_line - 1))p" "$file")" ]]; then
        cut_line=$((cut_line - 1))
    fi
    sed -i "${cut_line},\$d" "$file"
}
