#!/bin/bash

# setup-macos-input.sh
# 設定 macOS 風格輸入體驗
# Category: 鍵盤
# Description: macOS 風格鍵盤/觸控板設定

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

INPUT_CONF="$HOME/.config/hypr/input.conf"

# 檢查是否已設定 macOS 風格
check_macos_input() {
    if [[ ! -f "$INPUT_CONF" ]]; then
        return 1
    fi
    
    grep -q "repeat_rate = 60" "$INPUT_CONF" && \
    grep -q "natural_scroll = true" "$INPUT_CONF" && \
    grep -q "tap-to-click = true" "$INPUT_CONF"
}

# 備份原始設定
backup_input() {
    local backup_file="$INPUT_CONF.bak.$(date +%s)"
    if [[ -f "$INPUT_CONF" ]]; then
        cp "$INPUT_CONF" "$backup_file"
        detail "已備份原始設定: $backup_file"
    fi
}

# 設定 macOS 風格輸入
setup_macos_input() {
    info "檢查 macOS 風格輸入設定..."
    
    if check_macos_input; then
        info "macOS 風格輸入已設定，跳過"
        return 0
    fi
    
    info "設定 macOS 風格輸入..."
    backup_input
    
    mkdir -p "$(dirname "$INPUT_CONF")"
    
    cat > "$INPUT_CONF" << 'EOF'
# Control your input devices
# See https://wiki.hypr.land/Configuring/Variables/#input
input {
  # Use multiple keyboard layouts and switch between them with Left Alt + Right Alt
  # kb_layout = us,dk,eu

  # Use a specific keyboard variant if needed (e.g. intl for international keyboards)
  # kb_variant = intl

  kb_layout = us
  kb_options = compose:caps # ,grp:alts_toggle

  # macOS-like keyboard repeat settings
  repeat_rate = 60
  repeat_delay = 200

  # macOS-like mouse settings
  natural_scroll = true

  # Start with numlock on by default
  numlock_by_default = true

  # Increase sensitivity for mouse/trackpad (default: 0)
  # sensitivity = 0.35

  # Turn off mouse acceleration (default: false)
  # force_no_accel = true

  touchpad {
    # macOS-like touchpad settings
    natural_scroll = true
    tap-to-click = true
    clickfinger_behavior = true
    disable_while_typing = true
    scroll_factor = 0.7

    # Left-click-and-drag with three fingers
    # drag_3fg = 1
  }
}

# Scroll nicely in the terminal
windowrule = match:class (Alacritty|kitty), scroll_touchpad 1.5
windowrule = match:class com.mitchellh.ghostty, scroll_touchpad 0.2

# Enable touchpad gestures for changing workspaces
# See https://wiki.hyprland.org/Configuring/Gestures/
# gesture = 3, horizontal, workspace

# Enable touchpad gestures for moving focus (helpful on scrolling layout)
# gesture = 3, left,  dispatcher, movefocus, l
# gesture = 3, right, dispatcher, movefocus, r
EOF
    
    detail "input.conf 內容:"
    cat "$INPUT_CONF" | sed 's/^/  /'
    
    info "macOS 風格輸入設定完成"
    
    # 嘗試重新載入 Hyprland
    if command -v hyprctl >/dev/null 2>&1; then
        info "重新載入 Hyprland 設定..."
        hyprctl reload &>/dev/null && info "Hyprland 設定已重新載入" || warn "無法重新載入 Hyprland，請重新登入"
    fi
}

# 還原原始設定
reset_input() {
    info "還原輸入設定..."
    
    # 尋找最新的備份
    local latest_backup
    latest_backup=$(ls -t "$HOME/.config/hypr/input.conf.bak."* 2>/dev/null | head -1)
    
    if [[ -n "$latest_backup" ]]; then
        cp "$latest_backup" "$INPUT_CONF"
        info "已還原為備份: $latest_backup"
    else
        warn "找不到備份檔案，無法還原"
        return 1
    fi
    
    # 嘗試重新載入 Hyprland
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload &>/dev/null && info "Hyprland 設定已重新載入" || warn "無法重新載入 Hyprland"
    fi
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}macOS 風格輸入設定狀態:${NC}"

    if check_macos_input; then
        echo -e "  ${GREEN}✓${NC} macOS 風格輸入已設定"
    else
        echo -e "  ${YELLOW}!${NC} macOS 風格輸入未設定"
    fi

    if [[ -f "$HOME/.config/hypr/input.conf.bak" ]]; then
        echo -e "  ${GREEN}✓${NC} 存在備份檔案"
    fi
}

# 安裝模式
install() {
    info "開始設定 macOS 風格輸入..."
    setup_macos_input
    info "macOS 風格輸入設定完成！"
    info ""
    info "設定內容:"
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
