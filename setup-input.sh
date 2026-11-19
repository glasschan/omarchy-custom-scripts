#!/bin/bash

# setup-input.sh
# 設定 fcitx5-rime + 快速倉頡輸入法
# Omarchy v4：fcitx5 由 systemd user service (omarchy-fcitx5.service) 監管，
# 環境變數 (QT_IM_MODULE 等) 已是 Omarchy 預設，此腳本只需管理 rime 設定檔
# Category: 輸入法
# Description: 安裝 Fcitx5 + 快速倉頡

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
# shellcheck disable=SC1091  # 單檔檢查時見唔到 ./lib/common.sh；lint.sh 會連埋 lib/*.sh 一齊掃
source "$SCRIPT_DIR/lib/common.sh"

RIME_DIR="$HOME/.local/share/fcitx5/rime"
FCITX5_PROFILE="$HOME/.config/fcitx5/profile"
FCITX5_CONFIG="$HOME/.config/fcitx5/config"
# 安裝時記錄 profile/config 原狀嘅快照目錄（lib/common.sh snapshot_original 系列
# 據此還原；-u 還原後會移除）
STATE_DIR="$HOME/.local/state/omarchy-custom-scripts/setup-input"
# setup_rime_scj 只記錄「安裝前唔存在、由 -i 複製入去」嘅 yaml 檔名（append-only）；
# remove_rime_scj 只會按呢份記錄移除，唔會掂 scj6.userdb/build/sync 等用戶資料
RIME_FILES_RECORD="$STATE_DIR/installed-rime-files"

# 檢查 rime-scj 是否安裝
check_rime_scj() {
    [[ -f "$RIME_DIR/scj6.schema.yaml" ]]
}

# 檢查 scj6.custom.yaml
check_scj6_custom() {
    if [[ -f "$RIME_DIR/scj6.custom.yaml" ]]; then
        grep -q "ascii_mode" "$RIME_DIR/scj6.custom.yaml" && \
        grep -q "reset: 1" "$RIME_DIR/scj6.custom.yaml"
    else
        return 1
    fi
}

# 檢查 default.custom.yaml
check_default_custom() {
    if [[ -f "$RIME_DIR/default.custom.yaml" ]]; then
        grep -q "schema: scj6" "$RIME_DIR/default.custom.yaml" && \
        grep -q "schema: cangjie5" "$RIME_DIR/default.custom.yaml" && \
        grep -q "ascii_composer" "$RIME_DIR/default.custom.yaml" && \
        grep -q "switcher" "$RIME_DIR/default.custom.yaml"
    else
        return 1
    fi
}

# 檢查 fcitx5 config 中的 AltTriggerKeys 是否綁定 Shift_L
check_fcitx5_alttrigger() {
    local fcitx5_config="$HOME/.config/fcitx5/config"
    if [[ -f "$fcitx5_config" ]]; then
        grep -A 1 "^\[Hotkey/AltTriggerKeys\]" "$fcitx5_config" 2>/dev/null | grep -q "Shift_L"
    else
        return 1
    fi
}

# 移除 fcitx5 config 中 AltTriggerKeys 的 Shift_L
setup_fcitx5_alttrigger() {
    info "檢查 fcitx5 AltTriggerKeys 設定..."

    if ! check_fcitx5_alttrigger; then
        info "fcitx5 AltTriggerKeys 未綁定 Shift_L，跳過"
        return 0
    fi

    info "移除 fcitx5 AltTriggerKeys 的 Shift_L 綁定..."
    snapshot_original "$STATE_DIR" "$FCITX5_CONFIG" config
    sed -i '/^\[Hotkey\/AltTriggerKeys\]$/,/^\[/{/^0=Shift_L$/d}' "$FCITX5_CONFIG"

    info "fcitx5 AltTriggerKeys Shift_L 已移除"
}

# 安裝 fcitx5-rime
setup_fcitx5_rime() {
    info "檢查 fcitx5-rime..."
    install_package "fcitx5-rime"
}

# 安裝 fcitx5-config-qt
setup_fcitx5_config() {
    info "檢查 fcitx5-config-qt..."
    install_package "fcitx5-config-qt"
}

# 安裝 rime-scj
setup_rime_scj() {
    info "檢查 rime-scj..."

    if check_rime_scj; then
        info "rime-scj 已安裝，跳過"
        return 0
    fi

    info "下載並安裝 rime-scj..."
    mkdir -p "$RIME_DIR"

    local temp_dir
    temp_dir=$(mktemp -d)
    git clone --depth 1 https://github.com/rime/rime-scj.git "$temp_dir"

    # 記錄每個安裝前唔存在嘅 yaml（append-only，重複跑唔會再記錄）
    local src base
    for src in "$temp_dir"/*.yaml; do
        [[ -f "$src" ]] || continue
        base=$(basename "$src")
        [[ -e "$RIME_DIR/$base" ]] && continue
        if [[ -f "$RIME_FILES_RECORD" ]] && grep -qxF -- "$base" "$RIME_FILES_RECORD"; then
            continue
        fi
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$base" >> "$RIME_FILES_RECORD"
    done

    cp "$temp_dir"/*.yaml "$RIME_DIR/"
    rm -rf "$temp_dir"

    detail "已安裝檔案:"
    # shellcheck disable=SC2012  # 檔名固定為 scj6.*，冇空格或特殊字元
    ls -la "$RIME_DIR"/scj6.* | sed 's/^/  /'

    info "rime-scj 安裝完成"
}

# 移除 rime-scj（只移除 -i 新增嘅 yaml，保留 userdb/dict/build/sync 等用戶資料）
remove_rime_scj() {
    info "移除 rime-scj..."

    if [[ ! -f "$RIME_FILES_RECORD" ]]; then
        warn "冇 rime-scj 安裝記錄（$RIME_FILES_RECORD），唔會移除任何檔案"
        return 0
    fi

    local name
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        # 記錄只應有單純檔名；有路徑就跳過，避免 rm 走出 rime 目錄
        [[ "$name" == */* ]] && continue
        if [[ -f "$RIME_DIR/$name" ]]; then
            rm -f -- "$RIME_DIR/$name"
            detail "已移除 $RIME_DIR/$name"
        fi
    done < "$RIME_FILES_RECORD"

    info "rime-scj 已移除"
}

# 設定 scj6.custom.yaml
setup_scj6_custom() {
    info "檢查 scj6.custom.yaml..."

    if check_scj6_custom; then
        info "scj6.custom.yaml 已設定，跳過"
        return 0
    fi

    info "建立 scj6.custom.yaml..."
    mkdir -p "$RIME_DIR"

    # 覆寫前先記錄用戶原有版本（唔存在就留 .absent），-u 先可以原狀還原
    snapshot_original "$STATE_DIR" "$RIME_DIR/scj6.custom.yaml" scj6-custom

    cat > "$RIME_DIR/scj6.custom.yaml" << 'EOF'
patch:
  switches:
    - name: ascii_mode
      reset: 1
      states: [ 中文, 西文 ]
EOF

    detail "scj6.custom.yaml 內容:"
    sed 's/^/  /' "$RIME_DIR/scj6.custom.yaml"

    info "scj6.custom.yaml 建立完成"
}

# 還原 scj6.custom.yaml（-i 有快照就還原原狀；原本唔存在就刪走）
remove_scj6_custom() {
    info "還原 scj6.custom.yaml..."
    restore_original "$STATE_DIR" "$RIME_DIR/scj6.custom.yaml" scj6-custom
    info "scj6.custom.yaml 已還原"
}

# 設定 default.custom.yaml
setup_default_custom() {
    info "檢查 default.custom.yaml..."

    if check_default_custom; then
        info "default.custom.yaml 已設定，跳過"
        return 0
    fi

    info "建立 default.custom.yaml..."
    mkdir -p "$RIME_DIR"

    # 覆寫前先記錄用戶原有版本（唔存在就留 .absent），-u 先可以原狀還原
    snapshot_original "$STATE_DIR" "$RIME_DIR/default.custom.yaml" default-custom

    cat > "$RIME_DIR/default.custom.yaml" << 'EOF'
patch:
  schema_list:
    - schema: scj6
    - schema: cangjie5
    - schema: luna_pinyin
  menu:
    page_size: 5
  switcher:
    hotkeys:
      - F4
  ascii_composer:
    switch_key:
      Shift_L: noop
      Shift_R: commit_code
      Control_L: noop
      Control_R: noop
      Caps_Lock: noop
      Eisu_toggle: noop
EOF

    detail "default.custom.yaml 內容:"
    sed 's/^/  /' "$RIME_DIR/default.custom.yaml"

    info "default.custom.yaml 建立完成"
}

# 還原 default.custom.yaml（-i 有快照就還原原狀；原本唔存在就刪走）
remove_default_custom() {
    info "還原 default.custom.yaml..."
    restore_original "$STATE_DIR" "$RIME_DIR/default.custom.yaml" default-custom
    info "default.custom.yaml 已還原"
}

# 列出 profile 入面 [Groups/0/Items/*] 嘅輸入法名（忽略 group 名）
profile_items() {
    awk '
        /^\[/ { section = $0; next }
        section ~ /^\[Groups\/0\/Items/ && /^Name=/ {
            sub(/^Name=/, ""); print
        }
    ' "$FCITX5_PROFILE"
}

# 檢查 fcitx5 profile：DefaultIM=rime、有 rime、冇 keyboard-*（即係 english 已拎走）。
# fcitx5 執行時會自行重寫檔案（補註解、改次序），所以用語意比對而唔係 byte 比對。
check_fcitx5_profile() {
    [[ -f "$FCITX5_PROFILE" ]] || return 1
    grep -qxF -- "DefaultIM=rime" "$FCITX5_PROFILE" || return 1
    local items
    items=$(profile_items)
    printf '%s\n' "$items" | grep -qxF -- "rime" || return 1
    ! printf '%s\n' "$items" | grep -qE '^keyboard(-|$)'
}

# 寫入 rime-only profile：移除 keyboard-us，保留用戶自己加嘅其他輸入法。
setup_fcitx5_profile() {
    info "檢查 fcitx5 profile..."

    if check_fcitx5_profile; then
        info "fcitx5 profile 已設定（冇 keyboard-us），跳過"
        return 0
    fi

    info "設定 fcitx5 profile（移除 keyboard-us）..."
    mkdir -p "$(dirname "$FCITX5_PROFILE")"
    snapshot_original "$STATE_DIR" "$FCITX5_PROFILE" profile

    # 抽出目前非 keyboard-* 嘅輸入法（連 Layout），rime 排第一
    local -a names=() layouts=()
    local name layout
    while IFS='|' read -r name layout; do
        [[ -z "$name" ]] && continue
        [[ "$name" == rime ]] && continue
        [[ "$name" =~ ^keyboard ]] && continue
        names+=("$name")
        layouts+=("$layout")
    done < <(awk '
        function flush() {
            if (name != "") { print name "|" layout; name = ""; layout = "" }
        }
        /^\[/ { flush(); section = $0; next }
        section ~ /^\[Groups\/0\/Items/ {
            if (/^Name=/) { sub(/^Name=/, ""); name = $0 }
            else if (/^Layout=/) { sub(/^Layout=/, ""); layout = $0 }
        }
        END { flush() }
    ' "$FCITX5_PROFILE")

    {
        echo "[Groups/0]"
        echo "# Group Name"
        echo "Name=Default"
        echo "# Layout"
        echo "Default Layout=us"
        echo "# Default Input Method"
        echo "DefaultIM=rime"
        echo ""
        echo "[Groups/0/Items/0]"
        echo "# Name"
        echo "Name=rime"
        echo "# Layout"
        echo "Layout="
        local i
        for i in "${!names[@]}"; do
            echo ""
            echo "[Groups/0/Items/$((i + 1))]"
            echo "# Name"
            echo "Name=${names[i]}"
            echo "# Layout"
            echo "Layout=${layouts[i]}"
        done
        echo ""
        echo "[GroupOrder]"
        echo "0=Default"
    } > "$FCITX5_PROFILE"

    detail "已移除 keyboard-us；英文照樣經 rime 嘅 ascii_mode 打（右 Shift 切换）"

    # 叫 fcitx5 即刻重讀 profile（實測 fcitx5-remote -r 有效；dbus 只作後備）
    if command -v fcitx5-remote >/dev/null 2>&1 && fcitx5-remote -r 2>/dev/null; then
        detail "fcitx5 已重讀設定"
    elif command -v dbus-send >/dev/null 2>&1; then
        dbus-send --session --dest=org.fcitx.Fcitx5 --type=method_call \
            /controller org.fcitx.Fcitx.Controller1.SetConfig \
            string:fcitx://config/global >/dev/null 2>&1 || true
    fi
}



# 重新啟動 fcitx5（v4 用 systemd service；舊版 fallback 到手動啟動）
restart_fcitx5() {
    if systemctl --user cat omarchy-fcitx5.service &>/dev/null; then
        info "重新啟動 omarchy-fcitx5.service..."
        systemctl --user restart omarchy-fcitx5.service
    else
        if pgrep -x "fcitx5" > /dev/null; then
            info "停止 fcitx5..."
            killall fcitx5 2>/dev/null || true
            sleep 1
        fi
        fcitx5 -d &
        sleep 1
    fi
}

# 重新部署 Rime
redeploy_rime() {
    info "重新部署 Rime..."

    rm -rf "$RIME_DIR/build"

    restart_fcitx5

    info "等待部署完成..."
    local count=0
    while [[ $count -lt 10 ]]; do
        if [[ -d "$RIME_DIR/build" ]] && [[ -f "$RIME_DIR/build/scj6.schema.yaml" ]]; then
            info "Rime 部署完成"
            return 0
        fi
        sleep 1
        ((count++))
    done

    warn "等待 Rime 部署超時，請手動重啟 fcitx5"
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}Fcitx5 Rime 狀態:${NC}"

    if check_package "fcitx5-rime"; then
        echo -e "  ${GREEN}✓${NC} fcitx5-rime 已安裝"
    else
        echo -e "  ${RED}✗${NC} fcitx5-rime 未安裝"
    fi

    if check_package "fcitx5-config-qt"; then
        echo -e "  ${GREEN}✓${NC} fcitx5-config-qt 已安裝"
    else
        echo -e "  ${RED}✗${NC} fcitx5-config-qt 未安裝"
    fi

    if check_rime_scj; then
        echo -e "  ${GREEN}✓${NC} rime-scj 已安裝"
    else
        echo -e "  ${RED}✗${NC} rime-scj 未安裝"
    fi

    if check_scj6_custom; then
        echo -e "  ${GREEN}✓${NC} scj6.custom.yaml 已設定"
    else
        echo -e "  ${RED}✗${NC} scj6.custom.yaml 未設定"
    fi

    if check_default_custom; then
        echo -e "  ${GREEN}✓${NC} default.custom.yaml 已設定"
    else
        echo -e "  ${RED}✗${NC} default.custom.yaml 未設定"
    fi

    if pgrep -x "fcitx5" > /dev/null; then
        echo -e "  ${GREEN}✓${NC} fcitx5 正在執行"
        if command -v fcitx5-remote &>/dev/null; then
            echo -e "  ${CYAN}ℹ${NC}  目前輸入法: $(fcitx5-remote -n 2>/dev/null)"
        fi
    else
        echo -e "  ${YELLOW}!${NC} fcitx5 未執行"
    fi

    if systemctl --user cat omarchy-fcitx5.service &>/dev/null; then
        if systemctl --user is-active omarchy-fcitx5.service &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} omarchy-fcitx5.service 執行中 (Omarchy v4)"
        else
            echo -e "  ${RED}✗${NC} omarchy-fcitx5.service 未執行 (Omarchy v4)"
        fi
    fi

    if check_fcitx5_profile; then
        echo -e "  ${GREEN}✓${NC} fcitx5 profile 已移除 keyboard-us（英文經 rime ascii_mode）"
    else
        local items
        items=$(profile_items 2>/dev/null | paste -sd', ' -)
        echo -e "  ${YELLOW}!${NC} fcitx5 profile 未符合（目前: ${items:-無}），重跑 -i 設定"
    fi

    if [[ -d "$STATE_DIR" ]]; then
        echo -e "  ${YELLOW}!${NC} 有安裝時快照／安裝記錄待還原，執行 -u 還原"
    fi
}

# 安裝模式
install() {
    info "開始設定 fcitx5-rime + 快速倉頡..."

    local need_redeploy=false
    local need_fcitx5_restart=false

    if ! check_package "fcitx5-rime"; then
        setup_fcitx5_rime
        need_redeploy=true
    fi

    if ! check_package "fcitx5-config-qt"; then
        setup_fcitx5_config
    fi

    if ! check_rime_scj; then
        setup_rime_scj
        need_redeploy=true
    fi

    if ! check_scj6_custom; then
        setup_scj6_custom
        need_redeploy=true
    fi

    if ! check_default_custom; then
        setup_default_custom
        need_redeploy=true
    fi

    if check_fcitx5_alttrigger; then
        setup_fcitx5_alttrigger
        need_fcitx5_restart=true
    fi

    if ! check_fcitx5_profile; then
        setup_fcitx5_profile
        need_fcitx5_restart=true
    fi

    if $need_redeploy; then
        redeploy_rime
    elif $need_fcitx5_restart; then
        restart_fcitx5
    else
        info "所有設定已完成，無需重新部署"
    fi

    info ""
    info "設定完成！"
    info "輸入法："
    info "  - profile 已移除 keyboard-us（english 唔再佔一個輸入法位）"
    info "  - 英文照樣打：rime 內建 ascii_mode，右 Shift 即時切換"
    info "快捷鍵："
    info "  - F4: 切換輸入法方案"
    info "  - 右 Shift: 切換中英文"
    info "  - 左 Shift: 不會觸發中英文切換"
    info "  - 快速倉頡 (scj6): 已設定為預設，啟動時為英文模式"
    info "  - 倉頡五代 (cangjie5): 已加入方案列表"
    info "  - 朙月拼音 (luna_pinyin): 已加入方案列表"
    info ""
    info "想用圖形介面改：fcitx5-configtool（或 $SCRIPT_NAME -c）"

    # 只喺互動終端問，install_all／CI 唔會彈窗卡住
    if [[ -t 0 ]] && command -v fcitx5-configtool >/dev/null 2>&1; then
        if confirm "現在打開 fcitx5 設定工具？"; then
            open_config_tool
        fi
    fi
}

# 解除安裝模式
uninstall() {
    info "開始還原 fcitx5-rime 設定..."

    # 先還原安裝時改過嘅 fcitx5 profile/config，以及 rime custom yaml（依安裝時快照）
    restore_original "$STATE_DIR" "$FCITX5_CONFIG" config
    restore_original "$STATE_DIR" "$FCITX5_PROFILE" profile

    remove_scj6_custom
    remove_default_custom
    remove_rime_scj

    # 最後才刪快照目錄，否則上面嘅還原／安裝記錄已經冇咗
    cleanup_state_dir "$STATE_DIR"

    info "fcitx5-rime 設定已還原！"
    info "注意: fcitx5 之後可能自行改寫 profile/config，屬正常，不影響本次還原結果"
    info "注意: fcitx5-rime 套件未被移除，如需移除請手動執行:"
    info "  sudo pacman -R fcitx5-rime fcitx5-config-qt"
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定輸入法 (預設)"
    echo "  -u, --uninstall   還原輸入法設定（含 fcitx5 profile/config 原狀）"
    echo "  -s, --status      顯示目前狀態"
    echo "  -c, --config      開啟 fcitx5 圖形設定工具"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定輸入法"
    echo "  $SCRIPT_NAME -s           # 顯示狀態"
    echo "  $SCRIPT_NAME -c           # 開啟 fcitx5-configtool"
}

# 開啟 fcitx5 圖形設定工具。
# 開喺背景，唔用 exec：install() 之後仍然要正常收尾，setup-all 亦唔會卡住等個窗閂。
open_config_tool() {
    local tool
    for tool in fcitx5-configtool fcitx5-config-qt; do
        if command -v "$tool" >/dev/null 2>&1; then
            info "開啟 $tool..."
            nohup "$tool" >/dev/null 2>&1 &
            disown 2>/dev/null || true
            return 0
        fi
    done
    error "找不到 fcitx5 設定工具，請先安裝 fcitx5-config-qt"
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
        -c|--config)
            open_config_tool
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
