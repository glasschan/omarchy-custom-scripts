#!/bin/bash

# setup-macos-input.sh
# 設定 macOS 風格輸入體驗 (Omarchy v4 Lua 設定)
# 以 marker 區塊附加到 ~/.config/hypr/input.lua，唔會重寫整個檔案
# Category: 鍵盤
# Description: macOS 風格鍵盤/觸控板設定

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

INPUT_LUA="$HOME/.config/hypr/input.lua"

BEGIN_MARKER="-- BEGIN macOS input settings (setup-macos-input.sh)"
END_MARKER="-- END macOS input settings (setup-macos-input.sh)"

# 檢查是否已設定 macOS 風格
check_macos_input() {
    [[ -f "$INPUT_LUA" ]] && grep -qF -- "$BEGIN_MARKER" "$INPUT_LUA"
}

# 移除舊區塊（區塊永遠附加在檔尾：由 BEGIN 行起刪到 EOF，
# 連同前方附加嘅空行一齊清走，還原後與安裝前 byte-identical）
strip_block() {
    local first_line
    first_line=$(grep -n -F -- "$BEGIN_MARKER" "$INPUT_LUA" | cut -d: -f1 | head -1)
    [[ -z "$first_line" ]] && return 0

    local cut_line=$first_line
    if (( cut_line > 1 )) && [[ -z "$(sed -n "$((cut_line - 1))p" "$INPUT_LUA")" ]]; then
        cut_line=$((cut_line - 1))
    fi
    sed -i "${cut_line},\$d" "$INPUT_LUA"
}

# 設定 macOS 風格輸入
setup_macos_input() {
    info "檢查 macOS 風格輸入設定..."

    # -f/--force: 跳過存在性檢查，強制重新套用（用於腳本更新後重寫區塊）
    local force=false
    [[ "$1" == "-f" || "$1" == "--force" ]] && force=true

    if ! $force && check_macos_input; then
        info "macOS 風格輸入已設定，跳過"
        return 0
    fi

    info "設定 macOS 風格輸入..."
    mkdir -p "$(dirname "$INPUT_LUA")"
    create_backup "$INPUT_LUA"

    # -f 時先移除舊區塊再重加
    strip_block

    cat >> "$INPUT_LUA" << 'EOF'

-- BEGIN macOS input settings (setup-macos-input.sh)
-- macOS 風格鍵盤/觸控板設定。
-- kb_options 覆蓋 v4 預設：v4 新加 shift:both_capslock_cancel 會令 rime
-- 「單獨撳右 Shift 切中英文」失效（XKB 層干擾 alone-Shift 偵測），
-- v3 用 compose:caps 冇問題，故還原 v3 值。
-- (v4 預設 terminal 捲動規則已含 Alacritty|kitty|foot 1.5 / ghostty 0.2，
--  無需在此重複設定)。
hl.config({
  input = {
    -- 還原 v3 鍵盤選項：移除 v4 嘅 shift:both_capslock_cancel（會破壞 rime 右 Shift 切換）
    kb_options = "compose:caps",

    -- macOS-like keyboard repeat settings
    repeat_rate = 60,
    repeat_delay = 200,

    -- macOS-like mouse settings
    natural_scroll = true,

    -- Start with numlock on by default
    numlock_by_default = true,

    touchpad = {
      -- macOS-like touchpad settings
      natural_scroll = true,
      tap_to_click = true,
      clickfinger_behavior = true,
      disable_while_typing = true,
      scroll_factor = 0.7,
    },
  },
})
-- END macOS input settings (setup-macos-input.sh)
EOF

    detail "input.lua 區塊已加入:"
    sed -n "/^$BEGIN_MARKER$/,/^$END_MARKER$/p" "$INPUT_LUA" | sed 's/^/  /'

    info "macOS 風格輸入設定完成"

    # Hyprland 會自動重新載入 Lua 設定；明確 reload 確保生效
    if command -v hyprctl >/dev/null 2>&1; then
        info "重新載入 Hyprland 設定..."
        hyprctl reload &>/dev/null && info "Hyprland 設定已重新載入" || warn "無法重新載入 Hyprland，請重新登入"
    fi
}

# 還原原始設定
reset_input() {
    info "還原輸入設定..."

    if [[ ! -f "$INPUT_LUA" ]]; then
        warn "找不到 $INPUT_LUA"
        return 0
    fi

    if ! check_macos_input; then
        info "沒有找到 macOS 風格設定，跳過"
        return 0
    fi

    strip_block

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload &>/dev/null && info "Hyprland 設定已重新載入" || warn "無法重新載入 Hyprland"
    fi

    info "已還原（input.lua 回復 Omarchy v4 範本 + 預設）"
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}macOS 風格輸入設定狀態:${NC}"

    if check_macos_input; then
        echo -e "  ${GREEN}✓${NC} macOS 風格輸入已設定"
        local rate=$(hyprctl getoption input:repeat_rate 2>/dev/null | awk '/^int:/{print $2}')
        local natural=$(hyprctl getoption input:natural_scroll 2>/dev/null | awk '/^bool:/{print $2}')
        echo -e "  ${CYAN}ℹ${NC}  目前 repeat_rate: $rate / natural_scroll: $natural"
    else
        echo -e "  ${YELLOW}!${NC} macOS 風格輸入未設定"
    fi
}

# 安裝模式
install() {
    info "開始設定 macOS 風格輸入..."
    setup_macos_input "$1"
    info "macOS 風格輸入設定完成！"
    info ""
    info "設定內容:"
    info "  - kb_options: compose:caps (移除 v4 shift:capslock_cancel，保留 rime 右 Shift 切換)"
    info "  - 鍵盤重複率: 60 (更快)"
    info "  - 重複延遲: 200ms (更短)"
    info "  - 自然捲動: 開啟 (mouse + touchpad)"
    info "  - 輕觸點擊: 開啟"
    info "  - 兩指右鍵: 開啟"
    info "  - 打字時停用觸控板: 開啟"
    info "  - 捲動速度: 0.7 (更快)"
}

# 解除安裝模式
uninstall() {
    info "開始還原輸入設定..."
    reset_input
    info "輸入設定已還原！"
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定 macOS 風格輸入 (預設)"
    echo "  -f, --force       強制重新套用（跳過重複檢查，重寫區塊）"
    echo "  -u, --uninstall   還原輸入設定"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定 macOS 風格輸入"
    echo "  $SCRIPT_NAME -s           # 顯示狀態"
}

# 主程式
main() {
    case "${1:-}" in
        -u|--uninstall)
            uninstall
            ;;
        -s|--status)
            show_status
            ;;
        -h|--help)
            usage
            ;;
        -f|--force)
            install --force
            ;;
        -i|--install|"")
            install
            ;;
        *)
            error "未知選項: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
