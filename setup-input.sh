#!/bin/bash

# setup-input.sh
# 設定 fcitx5-rime + 快速倉頡輸入法
# Omarchy v4：fcitx5 由 systemd user service (omarchy-fcitx5.service) 監管，
# 環境變數 (QT_IM_MODULE 等) 已是 Omarchy 預設，此腳本只需管理 rime 設定檔
# Category: 輸入法
# Description: 安裝 Fcitx5 + 快速倉頡
# Device: both

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

RIME_DIR="$HOME/.local/share/fcitx5/rime"
FCITX5_PROFILE="$HOME/.config/fcitx5/profile"

# 可選 RIME 輸入方案: id -> GitHub repo
# scj6 快速倉頡（三代+五代碼兼收）; cangjie5 倉頡五代;
# quick5 速成; bopomofo 注音; luna_pinyin 朙月拼音;
# jyutping 粵拼; boshiamy 嘸蝦米
declare -A SCHEMA_REPOS=(
    [scj6]="rime/rime-scj"
    [cangjie5]="rime/rime-cangjie"
    [quick5]="rime/rime-quick"
    [bopomofo]="rime/rime-bopomofo"
    [luna_pinyin]="rime/rime-pinyin"
    [jyutping]="rime/rime-jyutping"
    [boshiamy]="yorkxin/rime-boshiamy"
)

# 記錄已安裝 / 由本 script 管理嘅 schema (uninstall 時用)
CHOSEN_SCHEMAS_FILE="$RIME_DIR/.omarchy-schemas"

# 中英切換用邊邊 Shift (left|right, 預設 right)
SHIFT_SIDE="right"
parse_shift_arg() {
    local val="${1:-right}"
    case "$val" in
        left) SHIFT_SIDE="left" ;;
        right) SHIFT_SIDE="right" ;;
        *) warn "忽略無效 shift 值: $val (可用: left, right)" ;;
    esac
}

# 抽傳入嘅 schema 列表(逗號或空格分隔),放入 $SCHEMAS 全域 array
SCHEMAS=()
parse_schemas_arg() {
    local raw="$1"
    local normalized
    normalized=$(echo "$raw" | tr ',' ' ')
    local id
    for id in $normalized; do
        if [[ -n "${SCHEMA_REPOS[$id]:-}" ]]; then
            SCHEMAS+=("$id")
        else
            warn "忽略未知輸入方案: $id"
        fi
    done
}

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

# 檢查 default.custom.yaml 是否包含全部指定 schemas + 指定 shift side
check_default_custom() {
    local schemas=("$@")
    [[ ${#schemas[@]} -eq 0 ]] && schemas=(scj6)
    [[ -f "$RIME_DIR/default.custom.yaml" ]] || return 1
    grep -q "switcher" "$RIME_DIR/default.custom.yaml" || return 1
    grep -q "ascii_composer" "$RIME_DIR/default.custom.yaml" || return 1
    # 中英切換 shift side
    local expect_l expect_r
    if [[ "$SHIFT_SIDE" == "left" ]]; then
        expect_l="commit_code"; expect_r="noop"
    else
        expect_l="noop"; expect_r="commit_code"
    fi
    grep -q "Shift_L: $expect_l" "$RIME_DIR/default.custom.yaml" || return 1
    grep -q "Shift_R: $expect_r" "$RIME_DIR/default.custom.yaml" || return 1
    local s
    for s in "${schemas[@]}"; do
        grep -q "schema: $s" "$RIME_DIR/default.custom.yaml" || return 1
    done
    return 0
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
    local fcitx5_config="$HOME/.config/fcitx5/config"
    sed -i '/^\[Hotkey\/AltTriggerKeys\]$/,/^\[/{/^0=Shift_L$/d}' "$fcitx5_config"

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

# 安裝一個 RIME 方案 (repo 由 SCHEMA_REPOS 提供)
install_schema() {
    local id="$1"
    local repo="${SCHEMA_REPOS[$id]}"

    if [[ -f "$RIME_DIR/$id.schema.yaml" ]]; then
        info "$id 已安裝，跳過"
        return 0
    fi

    info "下載並安裝 $id ($repo)..."
    mkdir -p "$RIME_DIR"

    local temp_dir
    temp_dir=$(mktemp -d)
    git clone --depth 1 "https://github.com/$repo.git" "$temp_dir"

    # 大多 repo 嘅 schema/dict 喺 root;fallback 搵一層
    cp "$temp_dir"/*.yaml "$RIME_DIR/" 2>/dev/null || true
    if ! [[ -f "$RIME_DIR/$id.schema.yaml" ]]; then
        find "$temp_dir" -maxdepth 1 -name "*.schema.yaml" -exec cp {} "$RIME_DIR/" \;
        find "$temp_dir" -maxdepth 1 -name "*.dict.yaml" -exec cp {} "$RIME_DIR/" \;
    fi
    rm -rf "$temp_dir"

    if [[ -f "$RIME_DIR/$id.schema.yaml" ]]; then
        # 記錄由本 script 管理 (uninstall 時清走)
        if ! grep -q "^$id$" "$CHOSEN_SCHEMAS_FILE" 2>/dev/null; then
            echo "$id" >> "$CHOSEN_SCHEMAS_FILE"
        fi
        info "$id 安裝完成"
        return 0
    fi

    warn "$id 安裝失敗: $RIME_DIR/$id.schema.yaml 不存在"
    return 1
}

# 移除單一 scheme 嘅檔案 (schema + dict,唔郁 custom yaml)
remove_schema() {
    local id="$1"
    [[ -d "$RIME_DIR" ]] || return 0
    rm -f "$RIME_DIR/${id}".schema.yaml "$RIME_DIR/${id}".dict.yaml \
          "$RIME_DIR/${id}".*.dict.yaml 2>/dev/null || true
}

# 移除所有本 script 管理嘅 schema (uninstall 用)
remove_all_schemas() {
    if [[ ! -f "$CHOSEN_SCHEMAS_FILE" ]]; then
        warn "搵唔到已安裝記錄 ($CHOSEN_SCHEMAS_FILE),跳過移除 schema"
        return 0
    fi
    local id
    while read -r id; do
        [[ -n "$id" ]] || continue
        info "移除 schema: $id..."
        rm -f "$RIME_DIR/$id".*
    done < "$CHOSEN_SCHEMAS_FILE"
    rm -f "$CHOSEN_SCHEMAS_FILE"
    info "schema 移除完成"
}

# 安裝 rime-scj (見 $SCHEMAS)
setup_rime_scj() {
    install_schema scj6
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

    cat > "$RIME_DIR/scj6.custom.yaml" << 'EOF'
patch:
  switches:
    - name: ascii_mode
      reset: 1
      states: [ 中文, 西文 ]
EOF

    detail "scj6.custom.yaml 內容:"
    cat "$RIME_DIR/scj6.custom.yaml" | sed 's/^/  /'

    info "scj6.custom.yaml 建立完成"
}

# 移除 scj6.custom.yaml
remove_scj6_custom() {
    info "移除 scj6.custom.yaml..."
    rm -f "$RIME_DIR/scj6.custom.yaml"
    info "scj6.custom.yaml 已移除"
}

# 設定 default.custom.yaml
setup_default_custom() {
    local schemas=("$@")
    [[ ${#schemas[@]} -eq 0 ]] && schemas=(scj6)

    if check_default_custom "${schemas[@]}"; then
        info "default.custom.yaml 已設定，跳過"
        return 0
    fi

    info "建立 default.custom.yaml (中英切換: ${SHIFT_SIDE} Shift)..."
    mkdir -p "$RIME_DIR"

    local shift_l shift_r
    if [[ "$SHIFT_SIDE" == "left" ]]; then
        shift_l="commit_code"
        shift_r="noop"
    else
        shift_l="noop"
        shift_r="commit_code"
    fi

    {
        echo "patch:"
        echo "  schema_list:"
        local s
        for s in "${schemas[@]}"; do
            echo "    - schema: $s"
        done
        cat <<EOF
  menu:
    page_size: 5
  switcher:
    hotkeys:
      - F4
  ascii_composer:
    switch_key:
      Shift_L: $shift_l
      Shift_R: $shift_r
      Control_L: noop
      Control_R: noop
      Caps_Lock: noop
      Eisu_toggle: noop
EOF
    } > "$RIME_DIR/default.custom.yaml"

    detail "default.custom.yaml 內容:"
    cat "$RIME_DIR/default.custom.yaml" | sed 's/^/  /'

    info "default.custom.yaml 建立完成"
}

# 移除 default.custom.yaml
remove_default_custom() {
    info "移除 default.custom.yaml..."
    rm -f "$RIME_DIR/default.custom.yaml"
    info "default.custom.yaml 已移除"
}

# 檢查 fcitx5 profile 是否含 rime（v4 升級後 profile 曾損毀導致無法切換中文）
check_fcitx5_profile() {
    if [[ -f "$FCITX5_PROFILE" ]]; then
        grep -q "Name=rime" "$FCITX5_PROFILE" && \
        grep -q "DefaultIM=rime" "$FCITX5_PROFILE"
    else
        return 1
    fi
}

# 修復 fcitx5 profile（寫入 canonical 結構；fcitx5 之後可能自行改寫，屬正常）
setup_fcitx5_profile() {
    info "檢查 fcitx5 profile..."

    if check_fcitx5_profile; then
        info "fcitx5 profile 結構正確，跳過"
        return 0
    fi

    info "修復 fcitx5 profile（keyboard-us + rime）..."
    mkdir -p "$(dirname "$FCITX5_PROFILE")"
    create_backup "$FCITX5_PROFILE"

    cat > "$FCITX5_PROFILE" << 'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=rime

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=rime
# Layout
Layout=

[GroupOrder]
0=Default
EOF

    info "fcitx5 profile 已修復"
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

    # 等任一已啟用方案嘅 build 產物出現(唔硬編碼 scj6 — 純選其他方案時會誤報超時)
    local probes=("${SCHEMAS[@]}")
    [[ ${#probes[@]} -eq 0 ]] && probes=(scj6)

    info "等待部署完成..."
    local count s
    while (( count < 10 )); do
        for s in "${probes[@]}"; do
            if [[ -f "$RIME_DIR/build/$s.schema.yaml" ]]; then
                info "Rime 部署完成 ($s)"
                return 0
            fi
        done
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
        echo -e "  ${GREEN}✓${NC} fcitx5 profile 已設定 rime"
    else
        echo -e "  ${RED}✗${NC} fcitx5 profile 缺少 rime"
    fi
}

# 安裝模式
install() {
    info "開始設定 fcitx5-rime 輸入法..."

    local need_redeploy=false
    local need_fcitx5_restart=false

    # 冇指定 --schemas 時,預設只啟用快速倉頡
    if [[ ${#SCHEMAS[@]} -eq 0 ]]; then
        SCHEMAS=(scj6)
    fi

    if ! check_package "fcitx5-rime"; then
        setup_fcitx5_rime
        need_redeploy=true
    fi

    if ! check_package "fcitx5-config-qt"; then
        setup_fcitx5_config
    fi

    local s
    local installed_schemas=()
    for s in "${SCHEMAS[@]}"; do
        if install_schema "$s"; then
            installed_schemas+=("$s")
            need_redeploy=true
        else
            warn "$s 安裝失敗,唔加入方案列表"
        fi
    done
    SCHEMAS=("${installed_schemas[@]}")

    # scj6 獨特:啟動時預設英文模式
    if [[ " ${SCHEMAS[*]} " == *" scj6 "* ]] && ! check_scj6_custom; then
        setup_scj6_custom
        need_redeploy=true
    fi

    if ! check_default_custom "${SCHEMAS[@]}"; then
        setup_default_custom "${SCHEMAS[@]}"
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
    info "已啟用方案: ${SCHEMAS[*]}"
    info "快捷鍵："
    info "  - F4: 切換輸入法方案"
    info "  - 右 Shift: 切換中英文"
    info "  - 左 Shift: 不會觸發中英文切換"
}

# 解除安裝模式
uninstall() {
    info "開始還原 fcitx5-rime 設定..."

    remove_all_schemas
    remove_scj6_custom
    remove_default_custom

    info "fcitx5-rime 設定已還原！"
    info "注意: fcitx5-rime 套件未被移除，如需移除請手動執行:"
    info "  sudo pacman -R fcitx5-rime fcitx5-config-qt"
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定輸入法 (預設)"
    echo "  -u, --uninstall   還原輸入法設定"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo "  --schemas <list>  指定要安裝嘅 RIME 方案,逗號或空格分隔"
    echo "  --shift <side>    中英切換用邊隻 Shift (left|right, 預設 right)"
    echo ""
    echo "可用方案:"
    echo "  scj6        快速倉頡 (預設, 三代+五代)"
    echo "  cangjie5    倉頡五代"
    echo "  quick5      速成"
    echo "  bopomofo    注音"
    echo "  luna_pinyin 朙月拼音"
    echo "  jyutping    粵拼"
    echo "  boshiamy    嘸蝦米"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME                              # 全部預設 (快速倉頡, 右 Shift 切中英)"
    echo "  $SCRIPT_NAME --schemas scj6,quick5     # 安裝快速倉頡 + 速成"
    echo "  $SCRIPT_NAME --shift left              # 左 Shift 切中英"
    echo "  $SCRIPT_NAME -s                        # 顯示狀態"
}

# 主程式
# 參數可組合 (例: --schemas scj6,quick5 --shift left),逐個解析後一次過 install
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--uninstall)
                uninstall
                return 0
                ;;
            -s|--status)
                show_status
                return 0
                ;;
            -h|--help)
                usage
                return 0
                ;;
            --schemas)
                if [[ -z "${2:-}" ]]; then
                    error "--schemas 需要參數 (scj6, cangjie5, quick5, bopomofo, luna_pinyin, jyutping, boshiamy)"
                fi
                parse_schemas_arg "$2"
                shift 2
                ;;
            --shift)
                if [[ -z "${2:-}" ]]; then
                    error "--shift 需要參數 (left, right)"
                fi
                parse_shift_arg "$2"
                shift 2
                ;;
            -i|--install|"")
                shift
                ;;
            *)
                error "未知選項: $1"
                ;;
        esac
    done
    install
}

main "$@"
