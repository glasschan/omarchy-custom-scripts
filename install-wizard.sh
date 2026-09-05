#!/bin/bash
#
# install-wizard.sh - Omarchy 中文環境安裝精靈
# 互動式 TUI:裝置選擇 → 勾選項目 → 子選項(字體/輸入法)→ 確認安裝。
# 每個項目對應 repo 內一隻 setup 腳本,統一由此精靈驅動,適合中文用戶
# (「懶人包」一鍵安裝)。
#
# 用法:
#   ./install-wizard.sh              互動精靈(預設)
#   ./install-wizard.sh --list       列出所有可安裝項目與編號
#   ./install-wizard.sh 1 3 5        直接安裝指定編號(非互動)
#   ./install-wizard.sh all          安裝全部(字體/輸入法取預設)
#
# 命名刻意避開 setup-*.sh / fix-*.sh,不會被 setup-all.sh discovery 掃進選單。

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/discovery.sh"

# ==========================================================
# 資料
# ==========================================================
FONT_CHOICES=(
    "misans|MiSans 黑體|小米出品,現代幾何感,支援繁中/簡中,個人偏好首選"
    "opposans|OPPO Sans 黑體|OPPO 出品,粗細均勻,閱讀舒適"
)

SCHEMA_CHOICES=(
    "scj6|快速倉頡|倉頡三代+五代碼兼收,香港/廣東最常用,啟動預設英文"
    "cangjie5|倉頡五代|官方五代,香港/台灣通用,支援擴展字"
    "quick5|速成|倉頡簡化版(首尾兩碼),香港常用"
    "bopomofo|注音|台灣標準注音符號輸入"
    "luna_pinyin|朙月拼音|台灣/大陸通用拼音,繁體輸出"
    "jyutping|粵拼|香港粵語拼音輸入"
    "boshiamy|嘸蝦米|台灣字形輸入"
)

DEVICE="both"
ITEMS=()             # script 名稱(顯示順序)
ITEM_CAT=()          # 分類
ITEM_DESC=()         # 描述
SELECTED=()          # 已勾選 index

FONT_SEL=()
SCHEMA_SEL=()
GUI_FONT_SEL=""      # misans|opposans|"" (空=唔設定預設 GUI 字體)

# ================================================================
# TUI 基礎
# ================================================================
clear_screen() { printf "\033[2J\033[H"; }

read_key() {
    local k rest
    IFS= read -rsn1 k
    if [[ "$k" == $'\x1b' ]]; then
        IFS= read -rsn2 rest
        case "$rest" in
            "[A") echo "UP" ;;
            "[B") echo "DOWN" ;;
            *)    echo "ESC" ;;
        esac
    elif [[ "$k" == $'\r' || -z "$k" ]]; then
        # Terminal Enter → \r (CR); 正規化成空字串代表「確定/下一步」
        echo ""
    else
        echo "$k"
    fi
}

# 通用多選子選單: title + entry 陣列(每項 "id|標題|描述")
# 結果寫入指定全域 array 名稱 (例: pick_menu "選擇字體" FONT_SEL "${FONT_CHOICES[@]}")
pick_menu() {
    local title="$1" arr_name="$2"; shift 2
    local -n out="$arr_name"           # nameref
    local -a opts=("$@")
    local n=${#opts[@]}
    local sub_cursor=0

    while true; do
        clear_screen
        header "$title"
        echo ""
        local i
        for ((i=0; i<n; i++)); do
            local id label desc mark x
            IFS='|' read -r id label desc <<< "${opts[$i]}"
            mark=" "
            for x in "${out[@]}"; do [[ "$x" == "$id" ]] && mark="x"; done
            if (( i == sub_cursor )); then
                printf '\033[7m  [%s] %s\033[0m\n' "$mark" "$label"
                printf '\033[7m      %s\033[0m\n' "$desc"
            else
                printf '  [%s] %s\n      %s\n' "$mark" "$label" "$desc"
            fi
        done
        echo ""
        echo "  [↑] 移到  [Space] 切換  [A] 全選  [N] 取消  [Enter] 確定  [Q] 返回"

        local key
        key=$(read_key)
        case "$key" in
            UP)   (( sub_cursor > 0 )) && ((sub_cursor--)) ;;
            DOWN) (( sub_cursor < n-1 )) && ((sub_cursor++)) ;;
            " ")
                IFS='|' read -r id _ <<< "${opts[$sub_cursor]}"
                if [[ " ${out[*]} " == *" $id "* ]]; then
                    local -a nu=()
                    for x in "${out[@]}"; do [[ "$x" != "$id" ]] && nu+=("$x"); done
                    out=("${nu[@]}")
                else
                    out+=("$id")
                fi
                ;;
            a | A)
                out=()
                for ((i=0;i<n;i++)); do IFS='|' read -r id _ <<< "${opts[$i]}"; out+=("$id"); done
                ;;
            n | N)
                out=()
                ;;
            "" | q | Q)
                break
                ;;
        esac
    done
}

# ================================================================
# 集合 helpers
# ================================================================
is_sel() {
    local n="$1" x
    for x in "${SELECTED[@]}"; do [[ "$x" == "$n" ]] && return 0; done
    return 1
}

toggle_sel() {
    local n="$1"
    if is_sel "$n"; then
        local -a nu=()
        local x
        for x in "${SELECTED[@]}"; do [[ "$x" != "$n" ]] && nu+=("$x"); done
        SELECTED=("${nu[@]}")
    else
        SELECTED+=("$n")
    fi
}

# 取得腳本分類(含 fallback)
script_category() {
    get_script_category "$1"
}

# ================================================================
# 主選單渲染
# ================================================================
cursor=0

render_main() {
    clear_screen
    header "Omarchy 中文環境安裝精靈 — $([ "$DEVICE" == laptop ] && echo 筆電 || echo 桌面)"
    echo -e "  ${CYAN}by 玻璃陳 glasschan @ SEAFOODHOLDHAND${NC}"
    echo ""
    echo "  [↑↓] 移動  [Space] 切換  [Enter] 下一步  [A] 全選  [N] 取消  [Q] 離開"
    echo ""

    local n=${#ITEMS[@]}
    local idx=0 last_cat=""
    for ((idx=0; idx<n; idx++)); do
        local cat="${ITEM_CAT[$idx]}"
        if [[ "$cat" != "$last_cat" ]]; then
            echo ""
            echo -e "\033[1;34m▼ $cat\033[0m"
            last_cat="$cat"
        fi
        local mark=" "
        is_sel "$idx" && mark="x"
        if (( idx == cursor )); then
            printf '\033[7m  [%s] %2d. %s\033[0m\n' "$mark" "$((idx+1))" "${ITEM_DESC[$idx]}"
        else
            printf '  [%s] %2d. %s\n' "$mark" "$((idx+1))" "${ITEM_DESC[$idx]}"
        fi
    done
}

# ================================================================
# 主流程
# ================================================================
build_menu() {
    ITEMS=(); ITEM_CAT=(); ITEM_DESC=()
    local cat scripts script dev
    for cat in $(group_scripts_by_category); do
        for script in $(get_scripts_in_category "$cat"); do
            dev=$(get_script_device "$script")
            [[ "$dev" != "both" && "$dev" != "$DEVICE" ]] && continue
            ITEMS+=("$script")
            ITEM_CAT+=("$cat")
            ITEM_DESC+=("$(get_script_description "$script")")
        done
    done
}

ask_device() {
    clear_screen
    header "Omarchy 中文環境安裝精靈"
    echo ""
    echo -e "  ${CYAN}by 玻璃陳 glasschan @ SEAFOODHOLDHAND${NC}"
    echo ""
    echo "  呢部機係邊類型？"
    echo ""
    echo "   1) 筆電 (Laptop)"
    echo "   2) 桌面 (Desktop)"
    echo ""
    read -r -p "  請選擇 [1/2]: " devkey
    case "$devkey" in
        1|l|L|"") DEVICE="laptop" ;;
        *) DEVICE="desktop" ;;
    esac
}

install_selected() {
    local skip_confirm="${1:-}"
    [[ ${#SELECTED[@]} -eq 0 ]] && { warn "尚未選擇任何項目"; return 1; }

    # 確定 summary 需要嘅變數
    local need_font=false need_input=false
    local i
    for i in "${SELECTED[@]}"; do
        case "${ITEMS[$i]}" in
            setup-fonts.sh) need_font=true ;;
            setup-input.sh) need_input=true ;;
        esac
    done

    clear_screen
    header "確認安裝"
    echo "  裝置: $([ "$DEVICE" == "laptop" ] && echo 筆電 || echo 桌面)"
    echo ""
    local idx
    for idx in "${SELECTED[@]}"; do
        echo -e "    ${GREEN}✓${NC} ${ITEM_DESC[$idx]} (${ITEMS[$idx]})"
    done
    $need_font && echo "    字體: ${FONT_SEL[*]:-(預設 MiSans+OPPO Sans)}"
    $need_font && [[ -n "$GUI_FONT_SEL" ]] && echo "    預設中文 GUI 字體: $GUI_FONT_SEL"
    $need_input && echo "    輸入法: ${SCHEMA_SEL[*]:-scj6}"
    echo ""
    if [[ "$skip_confirm" != "--yes" ]]; then
        read -r -p "  確定開始安裝？ [Y/n]: " confirm
        [[ "$confirm" == "n" || "$confirm" == "N" ]] && { info "已取消安裝"; return 1; }
    fi

    echo ""
    header "開始安裝"
    local fail=0
    for idx in "${SELECTED[@]}"; do
        local script="${ITEMS[$idx]}"
        local args="-i"
        case "$script" in
            setup-fonts.sh)
                [[ ${#FONT_SEL[@]} -gt 0 ]] && args="--fonts $(IFS=,; echo "${FONT_SEL[*]}")"
                [[ -n "$GUI_FONT_SEL" ]] && args="$args --gui-font $GUI_FONT_SEL"
                ;;
            setup-input.sh)
                local sel=("${SCHEMA_SEL[@]}")
                [[ ${#sel[@]} -eq 0 ]] && sel=(scj6)
                args="--schemas $(IFS=,; echo "${sel[*]}")"
                ;;
        esac
        echo ""
        info "執行 $script $args ..."
        bash "$SCRIPT_DIR/$script" $args || { warn "$script 安裝失敗,繼續"; fail=1; }
    done
    echo ""
    header "安裝完成"
    echo "  已安裝 ${#SELECTED[@]} 項設定。"
    [[ "$need_input" ]] && echo "  輸入法: F4 切換方案,右 Shift 切中英文。"
    echo "  部分設定需重新登入才生效。"
    echo ""
    return $fail
}

interactive_wizard() {
    cursor=0
    local key
    while true; do
        render_main
        key=$(read_key)
        case "$key" in
            UP)   (( cursor > 0 )) && ((cursor--)) ;;
            DOWN) (( cursor < ${#ITEMS[@]}-1 )) && ((cursor++)) ;;
            " ")  toggle_sel "$cursor" ;;
            a|A)  local i; local -a _all=(); for ((i=0;i<${#ITEMS[@]};i++)); do _all+=("$i"); done; SELECTED=("${_all[@]}") ;;
            n|N)  SELECTED=() ;;
            q|Q)  info "再見！"; exit 0 ;;
            "")
                # Enter: 入子選單(如需要)再安裝
                interactive_submenus
                install_selected
                echo ""
                read -r -p "  按 Enter 返回選單..."
                ;;
        esac
    done
}

# 問用戶要唔要設定預設中文 GUI 字體 (1=唔設定, 2=MiSans, 3=OPPO 推薦)
ask_gui_font() {
    [[ -n "$GUI_FONT_SEL" || ${#FONT_SEL[@]} -eq 0 ]] && return 0
    clear_screen
    header "預設中文 GUI 字體"
    echo ""
    echo "  揀邊款字體做系統預設中文 (GTK + Electron)?"
    echo ""
    echo "   1) 唔設定 (用返 Omarchy 預設)"
    echo "   2) MiSans 黑體"
    echo "   3) OPPO Sans 黑體 (推薦)"
    echo ""
    read -r -p "  請選擇 [1-3, 預設 3]: " gfk
    case "$gfk" in
        1) GUI_FONT_SEL="" ;;
        2) GUI_FONT_SEL="misans" ;;
        *) GUI_FONT_SEL="opposans" ;;
    esac
}

# 係咪有需要揀嘅子項目(字體/輸入法)
interactive_submenus() {
    local need_font=false need_input=false
    local i s
    for i in "${SELECTED[@]}"; do
        s="${ITEMS[$i]}"
        case "$s" in
            setup-fonts.sh) need_font=true ;;
            setup-input.sh) need_input=true ;;
        esac
    done
    if [[ "$need_font" && ${#FONT_SEL[@]} -eq 0 ]]; then
        pick_menu "選擇要安裝的字體" FONT_SEL "${FONT_CHOICES[@]}"
        ask_gui_font
    fi
    [[ "$need_input" && ${#SCHEMA_SEL[@]} -eq 0 ]] && pick_menu "選擇輸入法方案" SCHEMA_SEL "${SCHEMA_CHOICES[@]}"
}

# ================================================================
# 非互動
# ================================================================
list_all() {
    local last_cat="" i
    for ((i=0;i<${#ITEMS[@]};i++)); do
        local cat="${ITEM_CAT[$i]}"
        [[ "$cat" != "$last_cat" ]] && { echo ""; echo "▼ $cat"; last_cat="$cat"; }
        echo "  $((i+1)). ${ITEM_DESC[$i]}"
    done
}

select_argv() {
    local arg idx
    for arg in "$@"; do
        [[ "$arg" == --* ]] && continue
        if [[ "$arg" == "all" ]]; then
            SELECTED=()
            for ((idx=0; idx<${#ITEMS[@]}; idx++)); do SELECTED+=("$idx"); done
            return 0
        fi
        if [[ "$arg" =~ ^[0-9]+$ ]] && (( arg >= 1 && arg <= ${#ITEMS[@]} )); then
            toggle_sel "$((arg-1))"
        else
            error "無效編號: $arg (用 --list 查看)"
        fi
    done
}

usage() {
    cat <<EOF
$SCRIPT_NAME - Omarchy 中文環境安裝精靈

用法:
  $0                互動式精靈(建議)
  $0 --list         列出可用項目與編號
  $0 <編號...>       直接安裝指定編號
  $0 all            安裝全部(字體/輸入法取預設)

互動按鍵:
  ↑/↓              移動游標
  Space            切換勾選
  A                全選
  N                取消全選
  Enter            進入下一步
  Q                離開
EOF
}

main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
        --list)
            DEVICE="both"; build_menu; list_all; exit 0
            ;;
        all)
            DEVICE="both"; build_menu
            select_argv all
            install_selected --yes
            exit $?
            ;;
        "")
            ask_device
            build_menu
            interactive_wizard
            ;;
        *)
            DEVICE="both"
            build_menu
            select_argv "$@"
            install_selected --yes
            exit $?
            ;;
    esac
}

main "$@"