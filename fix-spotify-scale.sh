#!/bin/bash

# fix-spotify-scale.sh
# Fix Spotify scaling too large on 1080p displays (Chromium-based, not affected by GDK_SCALE)
# Category: 修復工具
# Description: Fix Spotify scaling on 1080p displays

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

FLAGS_FILE="$HOME/.config/spotify-flags.conf"
EXPECTED_FLAG="--force-device-scale-factor=1"

install_fix() {
    header "Fixing Spotify scaling"

    if [[ -f "$FLAGS_FILE" ]] && grep -qF "$EXPECTED_FLAG" "$FLAGS_FILE"; then
        info "Spotify scale fix already applied, skipping"
        return 0
    fi

    if [[ -f "$FLAGS_FILE" ]]; then
        create_backup "$FLAGS_FILE"
    fi

    info "Writing $FLAGS_FILE..."
    echo "$EXPECTED_FLAG" > "$FLAGS_FILE"

    detail "Set --force-device-scale-factor=1"
    echo ""
    info "Fix complete!"
    echo "Restart Spotify for changes to take effect."
}

uninstall_fix() {
    header "Restoring Spotify scaling"

    if [[ ! -f "$FLAGS_FILE" ]]; then
        info "No spotify-flags.conf found, nothing to remove"
        return 0
    fi

    create_backup "$FLAGS_FILE"
    rm -f "$FLAGS_FILE"

    info "Removed $FLAGS_FILE"
    echo "Restart Spotify for changes to take effect."
}

show_status() {
    header "Spotify scaling status"

    echo ""
    if [[ -f "$FLAGS_FILE" ]]; then
        if grep -qF "$EXPECTED_FLAG" "$FLAGS_FILE"; then
            echo -e "  ${GREEN}✓${NC} spotify-flags.conf contains $EXPECTED_FLAG"
        else
            echo -e "  ${YELLOW}!${NC} spotify-flags.conf exists but flag is incorrect"
            echo -e "    Current content: $(cat "$FLAGS_FILE")"
        fi
    else
        echo -e "  ${RED}✗${NC} spotify-flags.conf not found (Spotify will auto-detect scale)"
    fi

    if check_package spotify; then
        echo -e "  ${GREEN}✓${NC} Spotify is installed"
    else
        echo -e "  ${YELLOW}!${NC} Spotify is not installed"
    fi

    echo ""
}

usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     Apply Spotify scale fix (default)"
    echo "  -u, --uninstall   Remove the fix"
    echo "  -s, --status      Show current status"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Fixes Spotify appearing too large on 1080p displays."
    echo "Spotify is Chromium-based, so GDK_SCALE has no effect."
    echo "This writes --force-device-scale-factor=1 to ~/.config/spotify-flags.conf"
}

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
