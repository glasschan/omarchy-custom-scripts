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
# 安裝時記錄 flags 原狀嘅快照目錄（lib/common.sh snapshot_original 系列據此還原）
STATE_DIR="$HOME/.local/state/omarchy-custom-scripts/fix-spotify-scale"

# Non-destructive contract (-i/-u are a strict pair):
# -i: only guarantee the flag line exists; every other line is preserved
#     verbatim; the pre-install file (or its absence) is snapshotted to
#     STATE_DIR first — but only when -i actually modifies something
# -u: restore the snapshot and remove STATE_DIR; with no snapshot, -i never
#     touched the file (any flag present was already there), so -u leaves it
#     byte-identical untouched
# Never touches /usr/share/omarchy/.

install_fix() {
    header "Fixing Spotify scaling"

    if [[ -f "$FLAGS_FILE" ]] && grep -qxF -- "$EXPECTED_FLAG" "$FLAGS_FILE"; then
        info "Spotify scale fix already applied, skipping"
        return 0
    fi

    mkdir -p "$(dirname "$FLAGS_FILE")"
    snapshot_original "$STATE_DIR" "$FLAGS_FILE" flags

    if [[ -f "$FLAGS_FILE" ]]; then
        # Terminate a missing final newline so the flag lands on its own line
        # and existing flags stay byte-identical
        [[ -n "$(tail -c 1 "$FLAGS_FILE")" ]] && echo "" >> "$FLAGS_FILE"
        echo "$EXPECTED_FLAG" >> "$FLAGS_FILE"
        detail "Appended $EXPECTED_FLAG (existing flags preserved)"
    else
        echo "$EXPECTED_FLAG" > "$FLAGS_FILE"
        detail "Set $EXPECTED_FLAG"
    fi

    echo ""
    info "Fix complete!"
    echo "Restart Spotify for changes to take effect."
}

uninstall_fix() {
    header "Restoring Spotify scaling"

    # True pair with -i: no snapshot means -i made no change (the flag, if
    # present, predates this script), so -u must not remove anything
    if [[ ! -d "$STATE_DIR" ]]; then
        info "No install-time snapshot; $FLAGS_FILE was not modified by this script — leaving it untouched"
        return 0
    fi

    restore_original "$STATE_DIR" "$FLAGS_FILE" flags
    cleanup_state_dir "$STATE_DIR"

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

    if [[ -d "$STATE_DIR" ]]; then
        echo -e "  ${YELLOW}!${NC} 有安裝時快照待還原（spotify-flags.conf 原狀），執行 -u 還原"
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
