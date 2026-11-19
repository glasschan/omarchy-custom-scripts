#!/bin/bash

# lint.sh
# 專案 lint 入口：語法、shellcheck（規則見 .shellcheckrc）、以及幾條由
# 實機踩過嘅坑變成嘅結構規則。CI 同本機跑同一個檔案，唔會兩邊唔同。
# Category: Main
# Description: Lint all scripts (syntax + shellcheck + project rules)

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

ERRORS=0

# lint.sh 自己唔喺 menu；加 metadata 會令 setup-all.sh 當佢係設定腳本。
# Hidden 唔夠，# Category 都唔應該有，所以刻意唔寫。

# usage
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $SCRIPT_NAME [--strict]"
    echo ""
    echo "  --strict   shellcheck 未安裝時視為失敗（CI 預設）"
    exit 0
fi

fail() {
    echo "  ✗ $1"
    ERRORS=$((ERRORS + 1))
}

pass() {
    echo "  ✓ $1"
}

section() {
    echo ""
    echo "== $1"
}

# 活躍腳本（repo 根目錄；archive/ 唔受呢啲結構規則管）
active_scripts() {
    local f
    for f in setup-*.sh fix-*.sh; do
        [[ -f "$f" ]] && printf '%s\n' "$f"
    done
}

# ========================================
# 1. 語法
# ========================================
section "bash -n"
for f in *.sh lib/*.sh archive/*.sh; do
    [[ -f "$f" ]] || continue
    if bash -n "$f" 2>/tmp/opencode-lint-syntax.$$; then
        continue
    fi
    fail "語法錯誤: $f"
    sed 's/^/    /' /tmp/opencode-lint-syntax.$$ || true
done
rm -f /tmp/opencode-lint-syntax.$$
(( ERRORS == 0 )) && pass "全部腳本語法正確"

# ========================================
# 2. shellcheck（規則集中喺 .shellcheckrc）
# ========================================
section "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck --format=gcc ./*.sh ./lib/*.sh; then
        pass "shellcheck 無問題"
    else
        fail "shellcheck 有問題（規則見 .shellcheckrc）"
    fi
elif $STRICT; then
    fail "shellcheck 未安裝，--strict 唔准跳過（CI 會裝）"
else
    echo "  ! shellcheck 未安裝，略過；--strict 模式下會當失敗"
    echo "    安裝：sudo pacman -S shellcheck  或  bash lint.sh --strict"
fi

# ========================================
# 3. 結構規則：由實機踩過嘅坑寫成
# ========================================

# R1 marker 區塊要成對。教訓：-u 只靠 BEGIN marker 斬到檔尾，會食咗
#    用戶喺區塊之後加嘅設定。凡是 strip_block 都要傳 END marker，
#    所以 2 個參數嘅呼叫一律失敗（就算個檔案冇定義 END_MARKER）。
section "R1 marker 區塊有界刪除"
R1=0
for f in $(active_scripts); do
    while IFS= read -r line; do
        # 註解行唔算
        [[ "$line" =~ ^[0-9]+:[[:space:]]*# ]] && continue
        # 只認真正嘅呼叫；定義行／用法註解唔算
        [[ "$line" =~ strip_block[[:space:]] ]] || continue
        if [[ "$line" == *"END_MARKER"* ]]; then
            continue
        fi
        fail "$f 嘅 strip_block 冇傳 END_MARKER: $line"
        R1=$((R1 + 1))
    done < <(grep -n "strip_block" "$f")
done
(( R1 == 0 )) && pass "所有 strip_block 都係有界刪除"

# R2 唔准再用 create_backup。教訓：.bak.<timestamp> 每次 -i 都多一個，
#    而且 -u 根本唔用佢；備份只准 ~/.local/state/ 嘅 snapshot。
section "R2 唔准 ad-hoc 備份"
R2=0
for f in $(active_scripts); do
    if grep -n "create_backup" "$f" >/dev/null 2>&1; then
        fail "$f 仍然用 create_backup（改用 snapshot_original）"
        R2=$((R2 + 1))
    fi
done
(( R2 == 0 )) && pass "冇腳本用 create_backup"

# R3 冪等性測試要覆蓋所有會被 menu 發現嘅腳本。教訓：新腳本漏咗登記
#    SCRIPT_CONFIG_MAP，測試仍然全綠，等於冇測。Hidden 判斷要同
#    setup-all.sh is_script_hidden 一致（yes/true/1，大小寫不拘）。
section "R3 冪等性測試覆蓋"
missing=0
map_scripts=$(sed -nE 's/^[[:space:]]*"(setup-[^|"]+|fix-[^|"]+)\|.*/\1/p' test-idempotency.sh)
for f in $(active_scripts); do
    [[ "$f" == "setup-all.sh" ]] && continue
    grep -q "^# Category:" "$f" || continue
    grep -q "^# Description:" "$f" || continue
    hidden=$(sed -nE 's/^# Hidden:[[:space:]]*(.*)$/\1/p' "$f" | head -1)
    [[ "$hidden" =~ ^[Yy]es$ || "$hidden" =~ ^[Tt]rue$ || "$hidden" == "1" ]] && continue
    if ! printf '%s\n' "$map_scripts" | grep -qxF -- "$f"; then
        fail "$f 未登記喺 SCRIPT_CONFIG_MAP"
        missing=$((missing + 1))
    fi
done
(( missing == 0 )) && pass "SCRIPT_CONFIG_MAP 覆蓋所有可發現腳本"

# R4 每個腳本都要有 -i/-u/-s/-h 四個選項。教訓：setup-all.sh 靠 -h 入面
#    嘅 "-s, --status" 決定要唔要跑狀態，漏咗會被靜靜雞跳過；
#    -i/-u 係每個 setup/fix 腳本嘅基本安裝／還原介面。
section "R4 標準 CLI 介面"
R4=0
for f in $(active_scripts); do
    usage_text=$(bash "$f" -h 2>/dev/null || true)
    for opt in "-i, --install" "-u, --uninstall" "-s, --status" "-h, --help"; do
        if ! printf '%s\n' "$usage_text" | grep -qF -- "$opt"; then
            fail "$f 嘅 usage() 冇 \"$opt\" 行"
            R4=$((R4 + 1))
        fi
    done
done
(( R4 == 0 )) && pass "全部腳本都有 -i／-u／-s／-h"

# R5 fcitx5 profile 唔准再加入 keyboard-* 輸入法。教訓：english 做獨立
#    輸入法只係多咗一個切換位，英文應該經 rime 嘅 ascii_mode 打。
section "R5 fcitx5 profile 唔含 keyboard-*"
R5=0
for f in $(active_scripts); do
    grep -q "FCITX5_PROFILE" "$f" || continue
    while IFS= read -r line; do
        [[ "$line" =~ ^[0-9]+:[[:space:]]*# ]] && continue
        fail "$f 會寫入 keyboard-* 輸入法: $line"
        R5=$((R5 + 1))
    done < <(grep -nE 'Name=keyboard(-|\b)' "$f")
done
(( R5 == 0 )) && pass "冇腳本寫入 keyboard-* 輸入法"

# R6 SCRIPT_CONFIG_MAP 唔可以有過期登記。教訓：腳本歸檔到 archive/ 之後
#    仍然留喺 map，會令 test-idempotency.sh 搵唔到檔案而失敗，或者
#    靜靜雞測試緊一個唔存在嘅腳本。每個登記嘅腳本都必須存在於 repo 根目錄。
section "R6 SCRIPT_CONFIG_MAP 冇過期登記"
R6=0
while IFS= read -r script; do
    [[ -z "$script" ]] && continue
    if [[ ! -f "$script" ]]; then
        fail "SCRIPT_CONFIG_MAP 登記咗唔存在嘅腳本: $script"
        R6=$((R6 + 1))
    fi
done < <(sed -nE 's/^[[:space:]]*"(setup-[^|"]+|fix-[^|"]+)\|.*/\1/p' test-idempotency.sh)
(( R6 == 0 )) && pass "SCRIPT_CONFIG_MAP 全部指向現存腳本"

# ========================================
# 結果
# ========================================
echo ""
if (( ERRORS > 0 )); then
    echo "lint 失敗：$ERRORS 項"
    exit 1
fi
echo "lint 全部通過"
exit 0
