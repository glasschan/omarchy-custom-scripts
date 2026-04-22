#!/bin/bash

# setup-all.sh
# 主程式：設定所有 macOS 風格設定

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

# 檢查 script 是否存在
check_script() {
    [[ -f "$SCRIPT_DIR/$1" ]]
}

# 執行 script
run_script() {
    local script="$1"
    local mode="${2:-}"
    
    if ! check_script "$script"; then
        error "找不到 script: $script"
        return 1
    fi
    
    info "執行 $script..."
    bash "$SCRIPT_DIR/$script" $mode
}

# 顯示選單
show_menu() {
    header "Glass Omarchy 自訂工具箱"
    echo -e ""
    echo -e "\033[1;34m▼ 安裝設定\033[0m"
    echo -e "  \033[0;32m1\033[0m. 安裝所有設定 (字體 + 輸入法 + macOS 輸入 + Distrobox)"
    echo -e "  \033[0;32m2\033[0m. 安裝字體設定"
    echo -e "  \033[0;32m3\033[0m. 安裝輸入法設定 (fcitx5-rime + 快速倉頡)"
    echo -e "  \033[0;32m4\033[0m. 安裝 macOS 風格輸入設定"
    echo -e "  \033[0;32m5\033[0m. 安裝 Distrobox + DistroShelf"
    echo -e "  \033[0;32m6\033[0m. 交換內建鍵盤 Super/Alt (Optional)"
    echo -e ""
    echo -e "\033[1;34m▼ 還原與其他\033[0m"
    echo -e "  \033[0;32m7\033[0m. 還原所有設定"
    echo -e "  \033[0;32m8\033[0m. 還原字體設定"
    echo -e "  \033[0;32m9\033[0m. 還原輸入法設定"
    echo -e "  \033[0;32m10\033[0m. 還原 macOS 輸入設定"
    echo -e "  \033[0;32m11\033[0m. 還原鍵盤 Swap 設定"
    echo -e "  \033[0;32m12\033[0m. 還原 Distrobox 設定"
    echo -e "  \033[0;32m13\033[0m. 顯示設定狀態"
    echo -e "  \033[0;32m0\033[0m. 離開"
    echo -e ""
}

# 安裝所有設定
install_all() {
    header "安裝所有設定"
    
    run_script "setup-fonts.sh" "-i"
    echo ""
    
    run_script "setup-input.sh" "-i"
    echo ""
    
    run_script "setup-macos-input.sh" "-i"
    echo ""
    
    run_script "setup-distrobox.sh" "-i"
    echo ""
    
    header "所有設定安裝完成！"
    echo ""
    echo "請重新登入以確保所有設定生效。"
}

# 還原所有設定
uninstall_all() {
    header "還原所有設定"
    
    read -p "確定要還原所有設定嗎？ (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "取消還原"
        return 0
    fi
    
    run_script "setup-macos-input.sh" "-u"
    echo ""
    
    run_script "setup-input.sh" "-u"
    echo ""
    
    run_script "setup-distrobox.sh" "-u"
    echo ""
    
    run_script "setup-fonts.sh" "-u"
    echo ""
    
    header "所有設定已還原！"
}

# 顯示設定狀態
show_status() {
    header "設定狀態"

    echo ""
    echo -e "${CYAN}字體設定:${NC}"
    if fc-list | grep -qi "MiSans" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} MiSans 字體已安裝"
    else
        echo -e "  ${RED}✗${NC} MiSans 字體未安裝"
    fi

    local current_font
    current_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || echo "未設定")
    echo -e "  目前字體: $current_font"

    echo ""
    echo -e "${CYAN}Chromium 設定:${NC}"
    if [[ -f "$HOME/.config/chromium-flags.conf" ]]; then
        if grep -q "force-device-scale-factor=1" "$HOME/.config/chromium-flags.conf"; then
            echo -e "  ${GREEN}✓${NC} Scale factor 已設為 1"
        else
            echo -e "  ${YELLOW}!${NC} Scale factor 未設定為 1"
        fi
    else
        echo -e "  ${RED}✗${NC} Chromium flags 檔案不存在"
    fi

    echo ""
    echo -e "${CYAN}輸入法設定:${NC}"
    if pacman -Q fcitx5-rime &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} fcitx5-rime 已安裝"
    else
        echo -e "  ${RED}✗${NC} fcitx5-rime 未安裝"
    fi

    if [[ -f "$HOME/.local/share/fcitx5/rime/scj6.schema.yaml" ]]; then
        echo -e "  ${GREEN}✓${NC} rime-scj 已安裝"
    else
        echo -e "  ${RED}✗${NC} rime-scj 未安裝"
    fi

    if [[ -f "$HOME/.local/share/fcitx5/rime/default.custom.yaml" ]]; then
        echo -e "  ${GREEN}✓${NC} default.custom.yaml 已設定"
    else
        echo -e "  ${RED}✗${NC} default.custom.yaml 未設定"
    fi

    if [[ -f "$HOME/.local/share/fcitx5/rime/scj6.custom.yaml" ]]; then
        if grep -q "reset: 1" "$HOME/.local/share/fcitx5/rime/scj6.custom.yaml"; then
            echo -e "  ${GREEN}✓${NC} scj6 預設英文模式已設定"
        else
            echo -e "  ${YELLOW}!${NC} scj6 預設英文模式未設定"
        fi
    else
        echo -e "  ${RED}✗${NC} scj6.custom.yaml 不存在"
    fi

    echo ""
    echo -e "${CYAN}macOS 輸入設定:${NC}"
    if [[ -f "$HOME/.config/hypr/input.conf" ]]; then
        if grep -q "repeat_rate = 60" "$HOME/.config/hypr/input.conf"; then
            echo -e "  ${GREEN}✓${NC} macOS 風格輸入已設定"
        else
            echo -e "  ${YELLOW}!${NC} macOS 風格輸入未設定"
        fi
    else
        echo -e "  ${RED}✗${NC} input.conf 不存在"
    fi

    if grep -q "altwin:swap_alt_win" "$HOME/.config/hypr/input.conf" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} 鍵盤 Swap 已設定"
    fi

    echo ""
    echo -e "${CYAN}Distrobox 設定:${NC}"
    if pacman -Q distrobox &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} distrobox 已安裝"
    else
        echo -e "  ${RED}✗${NC} distrobox 未安裝"
    fi

    if pacman -Q distroshelf &>/dev/null || pacman -Q distroshelf-git &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} distroshelf 已安裝"
    else
        echo -e "  ${RED}✗${NC} distroshelf 未安裝"
    fi

    if grep -q "alias de='distrobox enter'" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} alias 'de' 已設定"
    else
        echo -e "  ${RED}✗${NC} alias 'de' 未設定"
    fi

    echo ""
}

# 互動模式
interactive_mode() {
    while true; do
        show_menu
        read -p "請選擇 [0-13]: " choice
        
        case "$choice" in
            1)
                install_all
                read -p "按 Enter 繼續..."
                ;;
            2)
                run_script "setup-fonts.sh" "-i"
                read -p "按 Enter 繼續..."
                ;;
            3)
                run_script "setup-input.sh" "-i"
                read -p "按 Enter 繼續..."
                ;;
            4)
                run_script "setup-macos-input.sh" "-i"
                read -p "按 Enter 繼續..."
                ;;
            5)
                run_script "setup-distrobox.sh" "-i"
                read -p "按 Enter 繼續..."
                ;;
            6)
                run_script "setup-keyboard-swap.sh" "-i"
                read -p "按 Enter 繼續..."
                ;;
            7)
                uninstall_all
                read -p "按 Enter 繼續..."
                ;;
            8)
                run_script "setup-fonts.sh" "-u"
                read -p "按 Enter 繼續..."
                ;;
            9)
                run_script "setup-input.sh" "-u"
                read -p "按 Enter 繼續..."
                ;;
            10)
                run_script "setup-macos-input.sh" "-u"
                read -p "按 Enter 繼續..."
                ;;
            11)
                run_script "setup-keyboard-swap.sh" "-u"
                read -p "按 Enter 繼續..."
                ;;
            12)
                run_script "setup-distrobox.sh" "-u"
                read -p "按 Enter 繼續..."
                ;;
            13)
                show_status
                read -p "按 Enter 繼續..."
                ;;
            0)
                info "再見！"
                exit 0
                ;;
            *)
                error "無效選項: $choice"
                sleep 1
                ;;
        esac
        
        echo ""
    done
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝所有設定 (預設)"
    echo "  -u, --uninstall   還原所有設定"
    echo "  -s, --status      顯示設定狀態"
    echo "  -m, --menu        互動選單模式"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 安裝所有設定"
    echo "  $SCRIPT_NAME -u           # 還原所有設定"
    echo "  $SCRIPT_NAME -m           # 互動選單模式"
}

# 主程式
main() {
    case "${1:-}" in
        -u|--uninstall)
            uninstall_all
            ;;
        -s|--status)
            show_status
            ;;
        -m|--menu)
            interactive_mode
            ;;
        -h|--help)
            usage
            ;;
        -i|--install|"")
            install_all
            ;;
        *)
            error "未知選項: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
