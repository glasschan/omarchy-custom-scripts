#!/bin/bash

# setup-distrobox.sh
# 安裝 Distrobox + DistroShelf，設定 alias
# Category: 容器工具
# Description: 安裝 Distrobox + DistroShelf

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

BASHRC="$HOME/.bashrc"

# 檢查 alias 是否存在
check_alias() {
    grep -q "alias de='distrobox enter'" "$BASHRC" 2>/dev/null
}

# 安裝 distrobox
setup_distrobox() {
    info "檢查 distrobox..."
    install_package "distrobox"
}

# 安裝 distroshelf
setup_distroshelf() {
    info "檢查 distroshelf..."

    # 優先嘗試安裝穩定版
    if install_package "distroshelf"; then
        return 0
    fi

    # 如果穩定版失敗，嘗試 git 版
    warn "穩定版安裝失敗，嘗試安裝 git 版..."
    install_package "distroshelf-git"
}

# 設定 alias
setup_alias() {
    info "檢查 alias..."

    if check_alias; then
        info "alias 'de' 已設定，跳過"
        return 0
    fi

    info "加入 alias 'de' 到 $BASHRC..."

    # 確保 .bashrc 存在
    if [[ ! -f "$BASHRC" ]]; then
        touch "$BASHRC"
    fi

    # 加入 alias
    cat >> "$BASHRC" << 'EOF'

# Distrobox alias
alias de='distrobox enter'
EOF

    detail "已加入 alias: de='distrobox enter'"
    info "Alias 設定完成"
    info "請執行 'source ~/.bashrc' 或重新登入以生效"
}

# 移除 alias
remove_alias() {
    info "移除 alias..."
    if [[ -f "$BASHRC" ]]; then
        # 移除 distrobox alias 行
        sed -i '/# Distrobox alias/d' "$BASHRC"
        sed -i "/alias de='distrobox enter'/d" "$BASHRC"
        info "Alias 已移除"
    fi
}

# 移除 distroshelf
remove_distroshelf() {
    info "移除 distroshelf..."
    if check_package "distroshelf"; then
        sudo pacman -R --noconfirm distroshelf 2>/dev/null || true
    fi
    if check_package "distroshelf-git"; then
        sudo pacman -R --noconfirm distroshelf-git 2>/dev/null || true
    fi
    info "distroshelf 已移除"
}

# 移除 distrobox
remove_distrobox() {
    info "移除 distrobox..."
    if check_package "distrobox"; then
        sudo pacman -R --noconfirm distrobox 2>/dev/null || true
    fi
    info "distrobox 已移除"
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}Distrobox 狀態:${NC}"

    if check_package "distrobox"; then
        echo -e "  ${GREEN}✓${NC} distrobox 已安裝"
    else
        echo -e "  ${RED}✗${NC} distrobox 未安裝"
    fi

    if check_package "distroshelf" || check_package "distroshelf-git"; then
        echo -e "  ${GREEN}✓${NC} distroshelf 已安裝"
    else
        echo -e "  ${RED}✗${NC} distroshelf 未安裝"
    fi

    if check_alias; then
        echo -e "  ${GREEN}✓${NC} alias 'de' 已設定"
    else
        echo -e "  ${YELLOW}!${NC} alias 'de' 未設定"
    fi
}

# 安裝模式
install() {
    info "開始安裝 Distrobox + DistroShelf..."

    setup_distrobox
    setup_distroshelf
    setup_alias

    info ""
    info "安裝完成！"
    info ""
    info "使用方法:"
    info "  - distrobox: 命令行管理容器"
    info "  - distroshelf: 圖形介面管理容器"
    info "  - de <container-name>: 快速進入容器"
    info ""
    info "請執行: source ~/.bashrc"
}

# 解除安裝模式
uninstall() {
    info "開始移除 Distrobox + DistroShelf..."

    remove_alias
    remove_distroshelf
    remove_distrobox

    info "Distrobox + DistroShelf 已移除！"
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝 Distrobox + DistroShelf (預設)"
    echo "  -u, --uninstall   移除 Distrobox + DistroShelf"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 安裝"
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
