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

# Non-destructive contract:
# -i: only guarantee the flag line exists; every other line is preserved verbatim
# -u: remove only the flag line; keep the rest (restore from the -i backup if the
#     leftover bytes differ from the pre-install state); delete the file if it
#     becomes empty (it was flag-only). Never touches /usr/share/omarchy/.

# Most recent backup created by create_backup during a previous -i
latest_backup() {
    ls -1t -- "$FLAGS_FILE".bak.* 2>/dev/null | head -1
}

install_fix() {
    header "Fixing Spotify scaling"

    if [[ -f "$FLAGS_FILE" ]] && grep -qxF -- "$EXPECTED_FLAG" "$FLAGS_FILE"; then
        info "Spotify scale fix already applied, skipping"
        return 0
    fi

    mkdir -p "$(dirname "$FLAGS_FILE")"

    if [[ -f "$FLAGS_FILE" ]]; then
        create_backup "$FLAGS_FILE"
        # Terminate a missing final newline so the flag lands on its own line
        # and existing flags stay byte-identical
        [[ -n "$(tail -c 1 "$FLAGS_FILE")" ]] && echo "" >> "$FLAGS_FILE"
        echo "$EXPECTED_FLAG" >> "$FLAGS_FILE"
        detail "Appended $EXPECTED_FLAG (existing flags preserved)"
    else
        echo "$EXPECTED_FLAG" > "$FLAGS_FILE"
        detail "Set --force-device-scale-factor=1"
    fi

    echo ""
    info "Fix complete!"
    echo "Restart Spotify for changes to take effect."
}

uninstall_fix() {
    header "Restoring Spotify scaling"

    if [[ ! -f "$FLAGS_FILE" ]] || ! grep -qxF -- "$EXPECTED_FLAG" "$FLAGS_FILE"; then
        info "Scale flag not found, nothing to remove"
        return 0
    fi

    grep -vxF -- "$EXPECTED_FLAG" "$FLAGS_FILE" > "${FLAGS_FILE}.tmp"
    mv "${FLAGS_FILE}.tmp" "$FLAGS_FILE"

    if [[ ! -s "$FLAGS_FILE" ]]; then
        rm -f "$FLAGS_FILE"
        info "Removed $FLAGS_FILE (contained only the scale flag)"
    else
        local backup
        backup="$(latest_backup)"
        if [[ -n "$backup" ]] && ! cmp -s "$FLAGS_FILE" "$backup"; then
            cp "$backup" "$FLAGS_FILE"
            detail "Restored pre-install flags from $backup"
        else
            info "Removed $EXPECTED_FLAG (other flags preserved)"
        fi
    fi

    echo "Restart Spotify for changes to take effect."
}

show_status() {
    header "Spotify scaling status"

    echo ""
    if [[ -f "$FLAGS_FILE" ]]; then
        if grep -qxF -- "$EXPECTED_FLAG" "$FLAGS_FILE"; then
            echo -e "  ${GREEN}✓${NC} spotify-flags.conf contains $EXPECTED_FLAG"
        else
            echo -e "  ${YELLOW}!${NC} spotify-flags.conf exists but $EXPECTED_FLAG is missing"
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
    echo "Adds --force-device-scale-factor=1 to ~/.config/spotify-flags.conf"
    echo "without touching any other flags in that file."
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
            ;;
    esac
}

main "$@"
