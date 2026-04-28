#!/bin/bash

# setup-looknfeel.sh
# Hyprland 視覺與動畫設定
# - 漸層邊框 (橘紅色)
# - 圓角視窗
# - 視窗陰影 + 毛玻璃
# - 流暢動畫曲線
# Category: 系統設定
# Description: Hyprland Look & Feel (圓角、陰影、動畫、漸層邊框)

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 載入共用函式庫
source "$SCRIPT_DIR/lib/common.sh"

# 設定檔路徑
HYPR_LOOKNFEEL="$HOME/.config/hypr/looknfeel.conf"

# 檢查設定檔是否存在
check_config_exists() {
    if [ ! -f "$HYPR_LOOKNFEEL" ]; then
        error "找不到 $HYPR_LOOKNFEEL"
        exit 1
    fi
}

# 檢查是否已安裝
is_installed() {
    grep -q "Custom looknfeel settings by setup-looknfeel.sh" "$HYPR_LOOKNFEEL"
}

# 安裝設定
install() {
    info "開始設定 Hyprland Look & Feel..."

    check_config_exists

    if is_installed; then
        warn "Look & Feel 設定似乎已經套用，跳過重複設定"
        return
    fi

    # 備份原始設定
    create_backup "$HYPR_LOOKNFEEL"

    # 寫入自訂 Look & Feel 設定
cat > "$HYPR_LOOKNFEEL" << 'EOF'
# Custom looknfeel settings by setup-looknfeel.sh

# ── Colors ──────────────────────────────────────────
$activeBorderColor = rgba(f38d70ee) rgba(fd6883ee) 45deg
$inactiveBorderColor = rgba(595959aa)

# ── General ─────────────────────────────────────────
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2

    col.active_border = $activeBorderColor
    col.inactive_border = $inactiveBorderColor

    resize_on_border = true
    allow_tearing = false
    layout = dwindle
}

# ── Decoration ──────────────────────────────────────
decoration {
    rounding = 10

    dim_inactive = true
    dim_strength = 0.25

    shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
    }

    blur {
        enabled = true
        size = 3
        passes = 3
        special = true
        brightness = 0.60
        contrast = 0.75
    }
}

# ── Animations ──────────────────────────────────────
animations {
    enabled = yes

    bezier = easeOutQuint,0.23,1,0.32,1
    bezier = easeInOutCubic,0.65,0.05,0.36,1
    bezier = linear,0,0,1,1
    bezier = almostLinear,0.5,0.5,0.75,1.0
    bezier = quick,0.15,0,0.1,1

    animation = global, 1, 8, default
    animation = border, 1, 5.39, easeOutQuint
    animation = windows, 1, 5, easeOutQuint
    animation = windowsIn, 1, 3.5, easeOutQuint, popin 87%
    animation = windowsOut, 1, 1.49, linear, popin 87%
    animation = fadeIn, 1, 1.73, almostLinear
    animation = fadeOut, 1, 1.46, almostLinear
    animation = fade, 1, 3.03, quick
    animation = layers, 1, 3.81, easeOutQuint
    animation = layersIn, 1, 4, easeOutQuint, fade
    animation = layersOut, 1, 1.5, linear, fade
    animation = fadeLayersIn, 1, 1.79, almostLinear
    animation = fadeLayersOut, 1, 1.39, almostLinear
    animation = workspaces, 0, 0, ease
    animation = specialWorkspace, 1, 3, easeOutQuint, slidevert
}

# ── Layout ──────────────────────────────────────────
# layout {
#     # Avoid overly wide single-window layouts on wide screens
#     # single_window_aspect_ratio = 4 3
# }
EOF

    info "Look & Feel 設定已套用至 $HYPR_LOOKNFEEL"
    info "Hyprland 會自動重新載入設定"

    echo
    info "=============================="
    info "設定完成!"
    info "=============================="
    echo
    echo "套用的設定："
    echo "  🎨 漸層邊框 (橘紅色)"
    echo "  🪟 視窗圓角 (10px)"
    echo "  💫 毛玻璃效果 (強化版)"
    echo "  🌑 未聚焦視窗暗化"
    echo "  ✨ 流暢動畫曲線"
    echo "  🖱️  邊框拖曳調整大小"
    echo
}

# 還原設定
uninstall() {
    info "還原 Look & Feel 設定..."

    if [ ! -f "$HYPR_LOOKNFEEL" ]; then
        warn "找不到 $HYPR_LOOKNFEEL"
        return 0
    fi

    # 移除我們的自訂設定 (透過 marker 判斷)
    if is_installed; then
        # 從 Omarchy 預設複製回來
        OARCHY_DEFAULT="$HOME/.local/share/omarchy/default/hypr/looknfeel.conf"
        if [ -f "$OARCHY_DEFAULT" ]; then
            cp "$OARCHY_DEFAULT" "$HYPR_LOOKNFEEL"
            info "已從 Omarchy 預設還原 looknfeel.conf"
        else
            warn "找不到 Omarchy 預設設定，手動還原可能需要"
        fi
    else
        info "沒有找到自訂 Look & Feel 設定，跳過"
    fi

    echo
    info "還原完成！"
    echo
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}Look & Feel 設定狀態:${NC}"

    if [[ -f "$HYPR_LOOKNFEEL" ]]; then
        if is_installed; then
            echo -e "  ${GREEN}✓${NC} 自訂 Look & Feel 已套用"
        else
            echo -e "  ${YELLOW}!${NC} 使用 Omarchy 預設 Look & Feel"
        fi

        # 顯示目前的圓角設定
        local ROUNDING=$(grep -E '^[[:space:]]*rounding' "$HYPR_LOOKNFEEL" | head -1 | tr -d ' ' | cut -d'=' -f2)
        local BORDER_RESIZE=$(grep -E 'resize_on_border' "$HYPR_LOOKNFEEL" | head -1 | tr -d ' ' | cut -d'=' -f2)
        echo -e "  ${CYAN}ℹ${NC}  圓角大小: $ROUNDING px"
        echo -e "  ${CYAN}ℹ${NC}  邊框調整大小: $BORDER_RESIZE"
    else
        echo -e "  ${RED}✗${NC} looknfeel.conf 不存在"
    fi
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/套用設定 (預設)"
    echo "  -u, --uninstall   還原設定 (回復 Omarchy 預設)"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
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
