#!/bin/bash

# setup-macos-touchpad.sh
# 設定 macOS 風格觸控板行為 (Omarchy v4 Lua 設定)
# - natural_scroll: true
# - touchpad: tap_to_click, clickfinger_behavior, disable_while_typing, scroll_factor 0.7
# 以 marker 區塊附加到 ~/.config/hypr/input.lua，唔會重寫整個檔案
# Category: 鍵盤
# Description: macOS 風格觸控板設定（筆電限定）
# Device: laptop

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

INPUT_LUA="$HOME/.config/hypr/input.lua"

BEGIN_MARKER="-- BEGIN macOS touchpad settings (setup-macos-touchpad.sh)"
END_MARKER="-- END macOS touchpad settings (setup-macos-touchpad.sh)"

check_installed() {
    [[ -f "$INPUT_LUA" ]] && grep -qF -- "$BEGIN_MARKER" "$INPUT_LUA"
}

strip_block_range() {
    local begin_marker="$1" end_marker="$2"
    local begin_line end_line
    begin_line=$(grep -n -F -- "$begin_marker" "$INPUT_LUA" | cut -d: -f1 | head -1)
    [[ -z "$begin_line" ]] && return 0

    end_line=$(grep -n -F -- "$end_marker" "$INPUT_LUA" | cut -d: -f1 | head -1)
    if [[ -z "$end_line" ]]; then
        end_line=$(wc -l < "$INPUT_LUA")
    fi

    if (( begin_line > 1 )) && [[ -z "$(sed -n "$((begin_line - 1))p" "$INPUT_LUA")" ]]; then
        begin_line=$((begin_line - 1))
    fi
    sed -i "${begin_line},${end_line}d" "$INPUT_LUA"
}

install() {
    # -f/--force: 跳過存在性檢查,強制重新套用(重寫區塊)
    local force=false
    [[ "$1" == "-f" || "$1" == "--force" ]] && force=true

    info "設定 macOS 風格觸控板..."

    if ! $force && check_installed; then
        info "觸控板設定已存在，跳過（用 -f 強制重新套用）"
        return 0
    fi

    mkdir -p "$(dirname "$INPUT_LUA")"
    create_backup "$INPUT_LUA"

    # 先移除自己嘅舊區塊(冇就係 no-op),確保重套用時唔會疊加
    strip_block_range "$BEGIN_MARKER" "$END_MARKER"

    cat >>"$INPUT_LUA" <<'EOF'

-- BEGIN macOS touchpad settings (setup-macos-touchpad.sh)
-- macOS 風格觸控板行為。
hl.config({
  input = {
    natural_scroll = true,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      clickfinger_behavior = true,
      disable_while_typing = true,
      scroll_factor = 0.7,
    },
  },
})
-- END macOS touchpad settings (setup-macos-touchpad.sh)
EOF

    info "觸控板設定已附加至 $INPUT_LUA"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload &>/dev/null && info "Hyprland 設定已重新載入" || warn "無法重新載入 Hyprland，請重新登入"
    fi
}

uninstall() {
    info "還原觸控板設定..."
    if [[ ! -f "$INPUT_LUA" ]]; then
        warn "找不到 $INPUT_LUA"
        return 0
    fi
    if ! check_installed; then
        info "沒有找到觸控板設定，跳過"
        return 0
    fi
    strip_block_range "$BEGIN_MARKER" "$END_MARKER"
    info "已還原觸控板設定"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload &>/dev/null || warn "無法重新載入 Hyprland，請重新登入"
    fi
}

show_status() {
    echo -e "${CYAN}macOS 風格觸控板設定狀態:${NC}"
    if check_installed; then
        echo -e "  ${GREEN}✓${NC} 觸控板設定已安裝"
        local natural=$(hyprctl getoption input:natural_scroll 2>/dev/null | awk '/^bool:/{print $2}')
        echo -e "  ${CYAN}ℹ${NC}  natural_scroll: $natural"
    else
        echo -e "  ${YELLOW}!${NC} 觸控板設定未安裝"
    fi
}

usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定 macOS 觸控板 (預設)"
    echo "  -f, --force       強制重新套用（跳過存在檢查，重寫區塊）"
    echo "  -u, --uninstall   還原觸控板設定"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
}

main() {
    case "${1:-}" in
        -u|--uninstall) uninstall ;;
        -s|--status) show_status ;;
        -h|--help) usage ;;
        -f|--force) install -f ;;
        -i|--install|"") install ;;
        *)
            error "未知選項: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"