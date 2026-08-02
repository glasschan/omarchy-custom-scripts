#!/bin/bash

# setup-foot.sh
# 設定 foot 終端機貼上/複製快捷鍵
# - clipboard-paste: Shift+Insert + Ctrl+Shift+V
# - clipboard-copy: Control+Insert
# Category: 快捷鍵
# Description: foot 終端機貼上/複製快捷鍵

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

FOOT_CONF="$HOME/.config/foot/foot.ini"

# 檢查是否已設定
check_foot_configured() {
	[[ -f "$FOOT_CONF" ]] && grep -q "^clipboard-paste=.*Control+Shift+v" "$FOOT_CONF"
}

# 設定單一 keybinding（若已存在則取代，否則插入 [key-bindings] section）
set_binding() {
	local key="$1" value="$2"

	if grep -q "^$key=" "$FOOT_CONF"; then
		sed -i "s|^$key=.*|$key=$value|" "$FOOT_CONF"
	elif grep -q "^\[key-bindings\]" "$FOOT_CONF"; then
		sed -i "/^\[key-bindings\]/a $key=$value" "$FOOT_CONF"
	else
		cat >>"$FOOT_CONF" <<EOF

[key-bindings]
$key=$value
EOF
	fi
}

install() {
	info "設定 foot 快捷鍵..."

	mkdir -p "$HOME/.config/foot"

	if [[ ! -f "$FOOT_CONF" ]]; then
		info "建立新的 foot.ini..."
		cat >"$FOOT_CONF" <<'EOF'
[key-bindings]
clipboard-copy=Control+Insert
clipboard-paste=Shift+Insert Control+Shift+v
EOF
	else
		set_binding "clipboard-copy" "Control+Insert"
		set_binding "clipboard-paste" "Shift+Insert Control+Shift+v"
	fi

	detail "clipboard-paste: $(grep '^clipboard-paste=' "$FOOT_CONF")"
	detail "clipboard-copy:  $(grep '^clipboard-copy=' "$FOOT_CONF")"
	info "完成！開新 foot 視窗生效（每個視窗啟動時讀 config）"
}

uninstall() {
	info "移除 foot 快捷鍵設定..."

	if [[ ! -f "$FOOT_CONF" ]]; then
		warn "foot.ini 不存在"
		return 0
	fi

	if ! check_foot_configured; then
		info "foot 快捷鍵設定不存在，跳過"
		return 0
	fi

	sed -i '/^clipboard-paste=/d;/^clipboard-copy=/d' "$FOOT_CONF"
	sed -i '/^\[key-bindings\]$/{N;/^\[key-bindings\]\n$/d}' "$FOOT_CONF"

	info "已移除（foot 回復預設：Ctrl+Shift+C 複製 / Ctrl+Shift+V 貼上）"
}

# 顯示狀態
show_status() {
	echo -e "${CYAN}foot 快捷鍵設定狀態:${NC}"

	if check_foot_configured; then
		echo -e "  ${GREEN}✓${NC} foot 快捷鍵已設定"
		grep '^clipboard-' "$FOOT_CONF" | sed 's/^/    /'
	else
		echo -e "  ${YELLOW}!${NC} foot 快捷鍵未設定"
	fi
}

usage() {
	echo "Usage: $SCRIPT_NAME [OPTION]"
	echo ""
	echo "Options:"
	echo "  -i, --install     安裝 foot 快捷鍵設定 (預設)"
	echo "  -u, --uninstall   移除 foot 快捷鍵設定"
	echo "  -s, --status      顯示目前狀態"
	echo "  -h, --help        顯示此說明"
}

main() {
	case "${1:-}" in
	-u | --uninstall)
		uninstall
		;;
	-s | --status)
		show_status
		;;
	-h | --help)
		usage
		;;
	-i | --install | "")
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
