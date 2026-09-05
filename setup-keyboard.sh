#!/bin/bash

# setup-keyboard.sh
# 設定 macOS 風格鍵盤行為 (Omarchy v4 Lua 設定)
# - kb_options: compose:caps (還原 v3 值,保留 rime 右 Shift 中英切換)
# - repeat_rate: 60 (更快)
# - repeat_delay: 200ms (更快開始重複)
# - numlock_by_default: true
# 以 marker 區塊附加到 ~/.config/hypr/input.lua,唔會重寫整個檔案
# Category: 鍵盤
# Description: macOS 風格鍵盤行為 (重複速率/延遲/caps)
# Device: both

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

INPUT_LUA="$HOME/.config/hypr/input.lua"

BEGIN_MARKER="-- BEGIN macOS keyboard settings (setup-keyboard.sh)"
END_MARKER="-- END macOS keyboard settings (setup-keyboard.sh)"

# 舊版合併 script 嘅 marker (setup-macos-input.sh 已拆分成 keyboard + touchpad)
OLD_BEGIN_MARKER="-- BEGIN macOS input settings (setup-macos-input.sh)"
OLD_END_MARKER="-- END macOS input settings (setup-macos-input.sh)"

check_installed() {
    [[ -f "$INPUT_LUA" ]] && grep -qF -- "$BEGIN_MARKER" "$INPUT_LUA"
}

# 精準刪除由 begin 到 end marker 嘅區塊（連同前面附加嘅空行）,其他區塊不受影響
strip_block_range() {
    local begin_marker="$1" end_marker="$2"
    local begin_line end_line
    begin_line=$(grep -n -F -- "$begin_marker" "$INPUT_LUA" | cut -d: -f1 | head -1)
    [[ -z "$begin_line" ]] && return 0

    end_line=$(grep -n -F -- "$end_marker" "$INPUT_LUA" | cut -d: -f1 | head -1)
    if [[ -z "$end_line" ]]; then
        # 冇 END marker:由 BEGIN 刪到 EOF
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

    info "開始設定 macOS 風格鍵盤行為..."

    if ! $force && check_installed; then
        info "鍵盤設定已存在，跳過（用 -f 強制重新套用）"
        return 0
    fi

    mkdir -p "$(dirname "$INPUT_LUA")"
    create_backup "$INPUT_LUA"

    # 先移除自己嘅舊區塊(冇就係 no-op),確保重套用時唔會疊加
    strip_block_range "$BEGIN_MARKER" "$END_MARKER"

    # 遷移:移除舊 setup-macos-input.sh 合併區塊（鍵盤部分已由此 script 承接）
    if grep -qF -- "$OLD_BEGIN_MARKER" "$INPUT_LUA"; then
        strip_block_range "$OLD_BEGIN_MARKER" "$OLD_END_MARKER"
        warn "已移除舊版 setup-macos-input.sh 區塊（設定已遷移）"
    fi

    cat >>"$INPUT_LUA" <<'EOF'

-- BEGIN macOS keyboard settings (setup-keyboard.sh)
-- macOS 風格鍵盤行為。
-- kb_options 覆蓋 v4 預設：v4 新加 shift:both_capslock_cancel 會令 rime
-- 「單獨撳右 Shift 切中英文」失效（XKB 層干擾 alone-Shift 偵測），
-- v3 用 compose:caps 冇問題，故還原 v3 值。
hl.config({
  input = {
    kb_options = "compose:caps",

    -- macOS-like keyboard repeat settings
    repeat_rate = 60,
    repeat_delay = 200,

    -- Start with numlock on by default
    numlock_by_default = true,
  },
})
-- END macOS keyboard settings (setup-keyboard.sh)
EOF

    info "鍵盤設定已附加至 $INPUT_LUA"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload &>/dev/null && info "Hyprland 設定已重新載入" || warn "無法重新載入 Hyprland，請重新登入"
    fi
}

uninstall() {
    info "還原鍵盤設定..."
    if [[ ! -f "$INPUT_LUA" ]]; then
        warn "找不到 $INPUT_LUA"
        return 0
    fi
    if ! check_installed; then
        info "沒有找到鍵盤設定，跳過"
        return 0
    fi
    strip_block_range "$BEGIN_MARKER" "$END_MARKER"
    # 一併清走舊版 setup-macos-input.sh 殘留區塊(升級後直接 -u 唔會留孤兒)
    strip_block_range "$OLD_BEGIN_MARKER" "$OLD_END_MARKER"
    info "已移除鍵盤設定區塊"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload &>/dev/null || warn "無法重新載入 Hyprland，請重新登入"
    fi
}

show_status() {
    echo -e "${CYAN}macOS 風格鍵盤設定狀態:${NC}"
    if check_installed; then
        echo -e "  ${GREEN}✓${NC} 鍵盤設定已安裝"
        local rate=$(hyprctl getoption input:repeat_rate 2>/dev/null | awk '/^int:/{print $2}')
        echo -e "  ${CYAN}ℹ${NC}  目前 repeat_rate: $rate"
    else
        echo -e "  ${YELLOW}!${NC} 鍵盤設定未安裝"
    fi
}

usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定 macOS 風格鍵盤 (預設)"
    echo "  -f, --force       強制重新套用（跳過存在檢查，重寫區塊）"
    echo "  -u, --uninstall   還原鍵盤設定"
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