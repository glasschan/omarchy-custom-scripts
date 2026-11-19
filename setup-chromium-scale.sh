#!/bin/bash

# setup-chromium-scale.sh
# 設定 Chromium / Electron scale factor（1）
# Category: 系統設定
# Description: 設定 Chromium / Electron scale factor（1）

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
# shellcheck disable=SC1091  # lint 會連同 lib/*.sh 一齊檢查；單檔跑時係假警報
source "$SCRIPT_DIR/lib/common.sh"

CHROMIUM_FLAGS="$HOME/.config/chromium-flags.conf"
STATE_DIR="$HOME/.local/state/omarchy-custom-scripts/setup-chromium-scale"
SCALE_FLAG="--force-device-scale-factor=1"

# 檢查 scale factor 是否已設為 1。用 -x 全行精確比對，1.25 唔算已裝。
check_chromium_scale() {
    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        grep -qxF -- "$SCALE_FLAG" "$CHROMIUM_FLAGS"
    else
        return 1
    fi
}

# 設定 Chromium scale factor
setup_chromium() {
    info "檢查 Chromium 設定..."

    if check_chromium_scale; then
        info "Chromium scale factor 已設定為 1，跳過"
        return 0
    fi

    info "設定 Chromium scale factor 為 1..."

    # 只在真係有改動時快照。-i/-u 嚴格成對，見 AGENTS.md。
    snapshot_original "$STATE_DIR" "$CHROMIUM_FLAGS" chromium-flags

    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        if grep -qE -- "^[[:space:]]*--force-device-scale-factor=" "$CHROMIUM_FLAGS"; then
            # 有舊值，例如 1.25：就地改成 1，其他 flags 逐字保留
            sed -i 's/^[[:space:]]*--force-device-scale-factor=.*/--force-device-scale-factor=1/' "$CHROMIUM_FLAGS"
            info "已將現有 scale flag 改成 $SCALE_FLAG"
        else
            # 只 append 一行。先補回結尾換行，免得黏住上一個 flag。
            [[ -n "$(tail -c 1 "$CHROMIUM_FLAGS")" ]] && echo "" >> "$CHROMIUM_FLAGS"
            echo "$SCALE_FLAG" >> "$CHROMIUM_FLAGS"
            info "已附加 $SCALE_FLAG"
        fi
    else
        mkdir -p "$(dirname "$CHROMIUM_FLAGS")"
        cat > "$CHROMIUM_FLAGS" << 'EOF'
--ozone-platform=wayland
--force-device-scale-factor=1
--ozone-platform-hint=wayland
--enable-features=TouchpadOverscrollHistoryNavigation
EOF
        info "已建立 $CHROMIUM_FLAGS 同寫入預設 flags"
    fi

    detail "Chromium flags 檔案: $CHROMIUM_FLAGS"
    detail "內容:"
    sed 's/^/  /' "$CHROMIUM_FLAGS"
    info "Chromium 設定完成"
}

# 還原 Chromium。由快照還原原狀，原本冇檔就刪走。
reset_chromium() {
    info "還原 Chromium 設定..."
    restore_original "$STATE_DIR" "$CHROMIUM_FLAGS" chromium-flags
    cleanup_state_dir "$STATE_DIR"
    info "Chromium 設定已還原"
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}Chromium 設定:${NC}"
    if [[ -f "$CHROMIUM_FLAGS" ]]; then
        if check_chromium_scale; then
            echo -e "  ${GREEN}✓${NC} Scale factor 已設為 1"
        else
            echo -e "  ${YELLOW}!${NC} Scale factor 未設定為 1"
        fi
    else
        echo -e "  ${RED}✗${NC} Chromium flags 檔案不存在"
    fi
}

# 安裝模式
install() {
    info "開始設定 Chromium scale factor..."
    setup_chromium
}

# 解除安裝模式
uninstall() {
    info "開始還原 Chromium 設定..."
    reset_chromium
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     設定 Chromium / Electron scale factor 為 1（預設）"
    echo "  -u, --uninstall   還原安裝前嘅 chromium-flags.conf"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "寫入 $CHROMIUM_FLAGS，其他 flags 保留。"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定 scale factor (預設)"
    echo "  $SCRIPT_NAME -s           # 顯示狀態"
    echo "  $SCRIPT_NAME -u           # 還原原狀"
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
            ;;
    esac
}

main "$@"
