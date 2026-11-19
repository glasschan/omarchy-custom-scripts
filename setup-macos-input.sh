#!/bin/bash

# setup-macos-input.sh
# 設定鍵盤 / 觸控板微調 (Omarchy v4 Lua 設定)
# 以 marker 區塊附加到 ~/.config/hypr/input.lua，唔會重寫整個檔案
# Category: 鍵盤
# Description: 鍵盤 / 觸控板微調設定

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
# shellcheck disable=SC1091  # lint 會連同 lib/*.sh 一齊檢查；單檔跑時係假警報
source "$SCRIPT_DIR/lib/common.sh"

INPUT_LUA="$HOME/.config/hypr/input.lua"
STATE_DIR="$HOME/.local/state/omarchy-custom-scripts/setup-macos-input"
LUA_SNAPSHOT_NAME="input-lua"

BEGIN_MARKER="-- BEGIN macOS input settings (setup-macos-input.sh)"
END_MARKER="-- END macOS input settings (setup-macos-input.sh)"

# 檢查是否已設定鍵盤 / 觸控板微調
check_macos_input() {
    [[ -f "$INPUT_LUA" ]] && grep -qF -- "$BEGIN_MARKER" "$INPUT_LUA"
}

# reload 後檢查 configerrors，並列出實際生效值（唔使靠估）
reload_and_verify() {
    local errors
    errors=$(hyprctl configerrors 2>/dev/null)
    if [[ -n "$errors" ]]; then
        warn "Hyprland 設定有錯誤:"
        printf '%s\n' "$errors" | sed 's/^/  /'
    else
        detail "hyprctl configerrors: 無錯誤"
    fi

    local key value
    info "實際生效值:"
    for key in \
        input:kb_options input:repeat_rate input:repeat_delay \
        input:natural_scroll input:numlock_by_default \
        input:touchpad:natural_scroll input:touchpad:tap_to_click \
        input:touchpad:clickfinger_behavior input:touchpad:disable_while_typing \
        input:touchpad:scroll_factor; do
        value=$(hyprctl getoption "$key" 2>/dev/null | head -1 | awk '{sub(/^[a-z]+:[[:space:]]*/, ""); print}')
        [[ -n "$value" ]] && printf '  %-42s %s\n' "$key" "$value"
    done
}

# 移除舊區塊：共用 lib/common.sh 嘅 strip_block（檔案路徑 + marker 由參數傳入）

# 設定鍵盤 / 觸控板微調
setup_macos_input() {
    info "檢查鍵盤 / 觸控板設定..."

    # -f/--force: 跳過存在性檢查，強制重新套用（用於腳本更新後重寫區塊）
    local force=false
    [[ "$1" == "-f" || "$1" == "--force" ]] && force=true

    if ! $force && check_macos_input; then
        info "鍵盤 / 觸控板設定已套用，跳過"
        return 0
    fi

    info "設定鍵盤 / 觸控板..."
    mkdir -p "$(dirname "$INPUT_LUA")"
    [[ -f "$INPUT_LUA" ]] || warn "找不到 $INPUT_LUA（似乎唔係 Omarchy v4），會建立新檔"

    # 第一次改動之前記錄原狀（absent marker 表示原本冇呢個檔），供 -u 判斷
    snapshot_original "$STATE_DIR" "$INPUT_LUA" "$LUA_SNAPSHOT_NAME"

    # -f 時先移除舊區塊再重加（有界刪除，唔會掂 END 之後嘅內容）
    strip_block "$INPUT_LUA" "$BEGIN_MARKER" "$END_MARKER" || \
        warn "找不到結束標記，已刪至檔尾；請檢查 $INPUT_LUA"

    cat >> "$INPUT_LUA" << 'EOF'

-- BEGIN macOS input settings (setup-macos-input.sh)
-- 鍵盤 / 觸控板微調。
-- kb_options 覆蓋 v4 預設：v4 新加 shift:both_capslock_cancel 會令 rime
-- 「單獨撳右 Shift 切中英文」失效（XKB 層干擾 alone-Shift 偵測），
-- v3 用 compose:caps 冇問題，故還原 v3 值。
-- (v4 預設 terminal 捲動規則已含 Alacritty|kitty|foot 1.5 / ghostty 0.2，
--  無需在此重複設定)。
hl.config({
  input = {
    -- 還原 v3 鍵盤選項：移除 v4 嘅 shift:both_capslock_cancel（會破壞 rime 右 Shift 切換）
    kb_options = "compose:caps",

    -- 鍵盤重複速度
    repeat_rate = 60,
    repeat_delay = 200,

    -- 滑鼠設定
    natural_scroll = true,

    -- 登入時 NumLock 預設開啟
    numlock_by_default = true,

    touchpad = {
      -- 觸控板設定
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

    info "鍵盤 / 觸控板設定完成"

    # Hyprland 會自動重新載入 Lua 設定；明確 reload 確保生效
    if command -v hyprctl >/dev/null 2>&1; then
        info "重新載入 Hyprland 設定..."
        if hyprctl reload &>/dev/null; then
            info "Hyprland 設定已重新載入"
        else
            warn "無法重新載入 Hyprland，請重新登入"
        fi
        reload_and_verify
    fi
}

# 還原原始設定
reset_input() {
    info "還原輸入設定..."

    if [[ ! -f "$INPUT_LUA" ]]; then
        warn "找不到 $INPUT_LUA"
        cleanup_state_dir "$STATE_DIR"
        return 0
    fi

    if ! check_macos_input; then
        info "沒有找到鍵盤 / 觸控板設定區塊，跳過"
        cleanup_state_dir "$STATE_DIR"
        return 0
    fi

    strip_block "$INPUT_LUA" "$BEGIN_MARKER" "$END_MARKER" || \
        warn "找不到結束標記，已刪至檔尾；請檢查 $INPUT_LUA"

    # 只有原本就冇呢個檔（.absent 快照）才用 restore_original 刪返個空殼；
    # 原本已存在（真快照）就唔可以複製返舊內容，否則會蓋掉 -i 之後嘅用戶修改。
    if [[ -f "$STATE_DIR/$LUA_SNAPSHOT_NAME.absent" ]]; then
        restore_original "$STATE_DIR" "$INPUT_LUA" "$LUA_SNAPSHOT_NAME"
        info "已還原（input.lua 原本不存在，已移除，不留空殼）"
    else
        info "已還原（input.lua 回復安裝前內容，區塊後嘅設定原封不動）"
    fi
    cleanup_state_dir "$STATE_DIR"

    if command -v hyprctl >/dev/null 2>&1; then
        if hyprctl reload &>/dev/null; then
            info "Hyprland 設定已重新載入"
        else
            warn "無法重新載入 Hyprland"
        fi
    fi
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}鍵盤 / 觸控板設定狀態:${NC}"

    if check_macos_input; then
        echo -e "  ${GREEN}✓${NC} 鍵盤 / 觸控板設定已套用"
        local rate natural
        rate=$(hyprctl getoption input:repeat_rate 2>/dev/null | awk '/^int:/{print $2}')
        natural=$(hyprctl getoption input:natural_scroll 2>/dev/null | awk '/^bool:/{print $2}')
        echo -e "  ${CYAN}ℹ${NC}  目前 repeat_rate: $rate / natural_scroll: $natural"
    else
        echo -e "  ${YELLOW}!${NC} 鍵盤 / 觸控板設定未套用"
    fi
}

# 安裝模式
install() {
    info "開始設定鍵盤 / 觸控板..."
    setup_macos_input "$1"
    info "鍵盤 / 觸控板設定完成！"
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
    echo "  -i, --install     安裝/設定鍵盤 / 觸控板 (預設)"
    echo "  -f, --force       強制重新套用（跳過重複檢查，重寫區塊）"
    echo "  -u, --uninstall   還原輸入設定"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定鍵盤 / 觸控板"
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
            ;;
    esac
}

main "$@"
