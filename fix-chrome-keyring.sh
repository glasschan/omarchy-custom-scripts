#!/bin/bash

# fix-chrome-keyring.sh
# Fix Chrome-based apps constantly asking for keyring password on Hyprland/Omarchy

set -e

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

detail() {
    echo -e "${BLUE}[DETAIL]${NC} $1"
}

header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# 安裝/修復 keyring
install_fix() {
    header "Fixing Chrome keyring prompts"
    
    # Backup existing keyring
    local BACKUP_DIR="$HOME/.local/share/keyrings.bak.$(date +%s)"
    info "Backing up current keyring to $BACKUP_DIR..."
    
    if [[ -d "$HOME/.local/share/keyrings" ]]; then
        cp -r "$HOME/.local/share/keyrings" "$BACKUP_DIR"
        detail "Backup created successfully"
    else
        warn "No existing keyring directory found, creating new..."
        mkdir -p "$HOME/.local/share/keyrings"
    fi
    
    echo ""
    
    # Recreate default keyring without password
    info "Recreating unencrypted default keyring..."
    
    KEYRING_DIR="$HOME/.local/share/keyrings"
    KEYRING_FILE="$KEYRING_DIR/Default_keyring.keyring"
    DEFAULT_FILE="$KEYRING_DIR/default"
    
    cat << EOF > "$DEFAULT_FILE"
Default_keyring
EOF

cat << 'EOF' > "$KEYRING_FILE"
[keyring]
display-name=Default keyring
ctime=1776930000
mtime=0
lock-on-idle=false
lock-after=false
EOF

    chmod 700 "$KEYRING_DIR"
    chmod 600 "$KEYRING_FILE"
    chmod 644 "$DEFAULT_FILE"
    
    # Remove extra keyring files
    rm -f "$KEYRING_DIR"/Default_keyring_*.keyring
    
    detail "Default keyring created successfully"
    detail "- No password required"
    detail "- Lock-on-idle: false"
    detail "- Lock-after: false"
    
    echo ""
    info "Fix complete!"
    echo ""
    echo "You need to logout and login back (or reboot) for changes to take effect."
    echo "After reboot, Chrome apps should no longer ask for keyring password."
}

# 還原修復
uninstall_fix() {
    header "Restoring from fix"
    
    read -p "This will remove the current keyring. Do you have a backup? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled"
        return 0
    fi
    
    info "Removing current unencrypted keyring..."
    rm -f "$HOME/.local/share/keyrings/Default_keyring.keyring"
    rm -f "$HOME/.local/share/keyrings/default"
    
    info "Done. You can restore from your backup manually."
    echo "You need to logout and login back for changes to take effect."
}

# 顯示狀態
show_status() {
    header "Keyring status"
    
    echo ""
    echo -e "${CYAN}Default keyring:${NC}"
    if [[ -f "$HOME/.local/share/keyrings/Default_keyring.keyring" ]]; then
        if grep -q "lock-on-idle=false" "$HOME/.local/share/keyrings/Default_keyring.keyring" && \
           grep -q "lock-after=false" "$HOME/.local/share/keyrings/Default_keyring.keyring"; then
            echo -e "  ${GREEN}✓${NC} Default keyring is correctly configured"
            echo -e "  ${GREEN}✓${NC} Lock-on-idle: false"
            echo -e "  ${GREEN}✓${NC} Lock-after: false"
        else
            echo -e "  ${YELLOW}!${NC} Default keyring exists but settings are incorrect"
        fi
        
        # Check for extra keyrings
        local EXTRA_COUNT=$(ls -1 "$HOME/.local/share/keyrings/Default_keyring_"*.keyring 2>/dev/null | wc -l)
        if [[ "$EXTRA_COUNT" -gt 0 ]]; then
            echo -e "  ${YELLOW}!${NC} Found $EXTRA_COUNT extra keyring files"
        else
            echo -e "  ${GREEN}✓${NC} No extra keyring files"
        fi
    else
        echo -e "  ${RED}✗${NC} Default keyring doesn't exist"
    fi
    
    echo ""
    echo -e "${CYAN}gnome-keyring service:${NC}"
    if systemctl --user is-active gnome-keyring-daemon.service &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} gnome-keyring-daemon is active"
    else
        echo -e "  ${RED}✗${NC} gnome-keyring-daemon is not active"
    fi
    
    echo ""
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     Apply fix for Chrome keyring prompts (default)"
    echo "  -u, --uninstall   Remove the fix"
    echo "  -s, --status      Show current keyring status"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # Apply the fix"
    echo "  $SCRIPT_NAME -s           # Show status"
}

# 主程式
main() {
    case "${1:-}" in
        -u|--uninstall)
            uninstall_fix
            ;;
        -s|--status)
            show_status
            ;;
        -h|--help)
            usage
            ;;
        -i|--install|"")
            install_fix
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
