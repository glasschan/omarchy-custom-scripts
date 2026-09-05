# Glass Omarchy 自訂工具箱

> 個人 Hyprland + Omarchy 環境自訂腳本

這組腳本用於自動化設定我的個人 Linux 環境。基於 [Omarchy](https://omarchy.org/) + Hyprland，主題是「把 macOS 的操作手感移植到 Arch Linux」。

**分支對應 Omarchy 版本：**

- `master` — **Omarchy v4**（Hyprland Lua 設定：`~/.config/hypr/*.lua`，fcitx5 由 systemd 監管）
- `v3` — Omarchy v3（舊版 `.conf` 設定檔；v4 機器請勿使用）

## 設計理念

- **個人用途**：不是通用的安裝腳本，是為了自己每次重灌後能快速恢復工作環境
- **自動化**：所有設定都透過 script 完成，不依賴 GUI 工具或互動精靈
- **可重複**：可以隨時還原/重新安裝，不會汙染系統
- **不重寫 Omarchy 範本**：v4 的 `input.lua` / `bindings.lua` 以 marker 區塊附加，保留範本註解與 Omarchy 預設

## 功能總覽

| 分類 | 腳本 | 功能 |
| ------ | ------ | ------ |
| **系統設定** | `setup-fonts.sh` | 字體 + Chromium scale 修復 |
| **輸入法** | `setup-input.sh` | fcitx5-rime + 快速倉頡 |
| **鍵盤** | `setup-macos-input.sh` | 鍵盤/觸控板 macOS 行為 |
| **快捷鍵** | `setup-keybindings.sh` | 剪貼簿管理員快捷鍵 |
| **容器工具** | `setup-distrobox.sh` | Distrobox + DistroShelf + `de` alias |
| **修復工具** | `fix-spotify-scale.sh` | Spotify 1080p 縮放修復 |

> v3 專屬腳本 `setup-keyboard-swap.sh` 與 `setup-gaming.sh` 已在 v4 移除（Hyprland 改用 Lua 設定後不再適用），保留在 `v3` branch。

## 快速開始

```bash
# 🌟 安裝精靈（推薦）— 互動式 checkbox 選單,勾選要安裝的項目
./install-wizard.sh

# 非互動:直接安裝指定編號
./install-wizard.sh 1 3 4

# 一鍵安裝全部
./install-wizard.sh all

# 互動選單（含還原/狀態檢查）
./setup-all.sh

# 一鍵安裝所有
./setup-all.sh -i

# 檢查所有設定狀態
./setup-all.sh -s

# 單獨執行特定腳本
./setup-fonts.sh -i     # 安裝
./setup-fonts.sh -u     # 還原
./setup-fonts.sh -s     # 檢查狀態
```

### install-wizard.sh — 安裝精靈（懶人包）

互動式 TUI 精靈,適合不熟悉命令列的中文用戶。流程:

1. 先問**裝置類型**（筆電/桌面）,只顯示適用的選項
2. 上下箭嘴移動游標,`Space` 切換勾選,`Enter` 進入下一步
3. 選擇「字體」會進入字體子選單（MiSans / OPPO Sans）
4. 選擇「輸入法」會進入輸入法子選單（快速倉頡/倉頡五代/速成/注音/拼音/粵拼/嘸蝦米）
5. 確認後依序執行所選 setup 腳本

快捷鍵: `A` 全部選 ／ `N` 取消全部 ／ `Q` 離開
也可用參數指定:`./install-wizard.sh 2 5` 或 `./install-wizard.sh all`
用 `./install-wizard.sh --list` 查看所有可安裝項目與編號。

## 各腳本說明

### setup-fonts.sh — 字體與顯示

**目標：** 安裝中文字體，避免顯示缺字

- **MiSans**（預設）：小米出品,現代幾何感,支援繁中/簡中
- **OPPO Sans**：OPPO 出品,閱讀舒適
- `--fonts` 可只裝指定款式,例如:`./setup-fonts.sh --fonts misans`
- 安裝字體後不會改動系統 GTK 預設字體（Omarchy 以自訂字體作系統預設）
- **Chromium scale**：設定為 1,避免 HiDPI 下 Chromium 再縮放造成 UI 過大

### setup-input.sh — 輸入法

**目標：** 在 Wayland 環境下使用順手的中文輸入法

- **fcitx5 + rime**
  - 為何：Wayland 原生支援，rime 詞庫可同步、彈性高
- **多種輸入方案（可選）**
  - 快速倉頡 (scj6)、倉頡五代 (cangjie5)、速成 (quick5)、注音 (bopomofo)、朙月拼音 (luna_pinyin)、粵拼 (jyutping)、嘸蝦米 (boshiamy)
  - 用 `--schemas` 指定，例如 `./setup-input.sh --schemas scj6,bopomofo`（不傳則裝預設快速倉頡）
- **快速倉頡** 支援三代＋五代碼，啟動預設英文模式
- **F4 切換輸入法方案**、**右 Shift 切換中英文**
- **自動部署**：執行後自動重啟 fcitx5 並等待部署完成

**v4 注意事項**：

- fcitx5 由 systemd user service `omarchy-fcitx5.service` 監管，重啟一律透過 `systemctl --user restart`
- IM 環境變數已是 Omarchy v4 預設，腳本無需設定
- 腳本會檢查並修復 fcitx5 `profile`
- 切換 trigger：`Ctrl+Space`

**直接寫入 fcitx5 profile 設定檔**：不透過 GUI 精靈，避免卡住 script

### setup-keyboard.sh / setup-macos-touchpad.sh — 輸入體驗

**目標：** 把 macOS 的鍵盤/觸控板操作手感移植到 Hyprland

| 腳本 | 設定 | 裝置 |
| ------ | ----- | ------ |
| `setup-keyboard.sh` | kb_options `compose:caps`、repeat_rate 60、repeat_delay 200、numlock | 兩者 |
| `setup-macos-touchpad.sh` | natural_scroll、tap_to_click、clickfinger、scroll_factor | 筆電 |

説明：v4 預設 `kb_options` 有 `shift:both_capslock_cancel` 會干擾 rime 右 Shift 切中英文，故還原成 `compose:caps`。

### setup-distrobox.sh — 容器環境

**目標：** 在主系統內隔離其他發行版，卻仍能整合使用

- **Distrobox**
  - 為什麼：輕量、shared home、支援 Wayland socket 共享，直接用主系統的字體/主題
- **DistroShelf**
  - 為什麼：圖形化管理容器內安裝的 GUI 程式
- **`de` alias**
  - 為什麼：`de ubuntu` 比 `distrobox enter ubuntu` 少打很多字

### setup-keybindings.sh — 剪貼簿快捷鍵

**目標：** 剪貼簿管理員的自訂快捷鍵

| 快捷鍵 | 功能 |
| -------- | ------ |
| `Ctrl+\`` | 開啟剪貼簿管理員 |

**v4 實作方式**：以 marker 區塊附加到 `~/.config/hypr/bindings.lua`（`o.bind()` Lua API）。

- **剪貼簿管理員**：Ctrl+\` 開啟 Omarchy v4 內建剪貼簿（`omarchy-shell shell toggle omarchy.clipboard`），另有預設快捷鍵 `Super+Ctrl+V`。v3 的 walker + elephant 自動貼上組合已淘汰
- 截圖/錄影/OCR/取色快捷鍵已於 2026-09 移除 — 由自製 OmaSwiss plugin（`glasschan.oma-swiss`）嘅 Quick capture 取代

## 支援的作業系統

- Omarchy Linux v4（Arch-based）— `master` branch；v3 請用 `v3` branch
- Hyprland (Wayland，Lua 設定)
- 需要有 `yay` 或 `paru`（AUR 助手） 或 `sudo` 可用

## 檔案結構

```
.
├── lib/
│   ├── common.sh                    # 共用函式庫（顏色、紀錄函數、套件管理等）
│   ├── discovery.sh                 # 腳本探索邏輯（setup-all 與 wizard 共用）
│   └── AGENTS.md                    # DOX 子文件：lib 契約
├── AGENTS.md                        # DOX 根文件：專案契約與索引
├── install-wizard.sh                # 安裝精靈（互動 checkbox 選單，懶人包）
├── setup-all.sh                     # 主程式，自動探索所有腳本 + 互動選單
├── setup-fonts.sh                   # 字體設定
├── setup-input.sh                   # 輸入法設定
├── setup-macos-input.sh             # 鍵盤/觸控板設定
├── setup-keybindings.sh             # 剪貼簿快捷鍵
├── setup-distrobox.sh               # Distrobox 容器工具
├── fix-spotify-scale.sh             # Spotify 1080p 縮放修復
└── test-idempotency.sh              # 冪等性測試工具
```

## 開發者說明

### 標準 CLI 介面

所有腳本都支援一致的命令列參數：

| 參數 | 功能 |
| ------ | ------ |
| `-i`, `--install` | 安裝/套用設定 |
| `-u`, `--uninstall` | 還原設定 |
| `-s`, `--status` | 顯示目前狀態 |
| `-h`, `--help` | 顯示說明 |

### 新增腳本 QA 檢查清單 ✅

新增任何會修改設定檔的腳本之前，請務必先通過這份清單：

- [ ] **冪等性測試**: 連續執行 `-i` 兩次，確認第二次執行後設定檔內容完全不變
- [ ] **sed 安全性**: 所有 `sed` 取代字串中的 `&` 都必須跳脫為 `\&`
- [ ] **grep 安全性**: 所有包含 `\s` 的 grep 都必須使用 `-E` flag
- [ ] **grep 安全性**: pattern 以 `-` 開頭（如 `-- BEGIN ...` marker）必須加 `--` 分隔符
- [ ] **狀態檢查**: `-s` 參數能正確判斷是否已安裝
- [ ] **移除功能**: `-u` 能完全清理所有新增的內容
- [ ] **無重複**: 連續執行兩次不會在設定檔中產生重複行

---

### 新增腳本

只要在開頭加上 metadata 註解，就會自動出現在 `setup-all.sh` 選單中：

```bash
#!/bin/bash

# my-new-script.sh
# 我的新腳本功能說明
# Category: 系統設定
# Description: 腳本功能描述（會顯示在選單中）

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 載入共用函式庫
source "$SCRIPT_DIR/lib/common.sh"

# 實作標準函數
install() { info "安裝中..." }
uninstall() { info "還原中..." }
show_status() { info "顯示狀態..." }

# 主程式
main() {
    case "${1:-}" in
        -u|--uninstall) uninstall ;;
        -s|--status) show_status ;;
        -h|--help) usage ;;
        -i|--install|"") install ;;
    esac
}

main "$@"
```

### 冪等性測試 (`test-idempotency.sh`)

自動驗證所有腳本的冪等性，確保執行兩次後設定檔內容完全相同：

```bash
# 測試所有腳本
./test-idempotency.sh

# 測試單一腳本
./test-idempotency.sh setup-keybindings.sh
```

**為什麼需要？** 這個專案的核心設計原則是「可重複執行」，但 bash 腳本很容易因為 `sed` 的 `&` 展開、`echo >>` 累加寫入、TOML section 解析等問題，導致每次執行都改變設定檔內容。這些 bug 不會立刻出錯，但會讓設定檔指數級膨脹或損壞（例如之前剪貼簿 `command` 欄位每次執行都重複堆疊的問題）。這個測試確保每次修改腳本後，不會意外引入堆疊 bug。

### 共用函式 (`lib/common.sh`)

- **記錄函數**：`info()`, `warn()`, `error()`, `detail()`, `header()` - 自動套用顏色
- **套件管理**：`check_package()`, `install_package()` - 自動偵測 paru/yay/sudo
- **工具函數**：`config_contains()`, `ensure_dir()`, `create_backup()`

## ⚠️ 已知陷阱與最佳實務 (Bash Pitfalls)

### `sed` 中的 `&` 是特殊字元，不是字面 ampersand

**曾造成的 bug**: `setup-keybindings.sh` 剪貼簿設定指數級腐敗

```bash
# ❌ 錯誤寫法 - 會造成指數級堆疊腐敗！
sed -i 's/^command=.*$/command = "wl-copy && sleep 0.2"/' file

# ✅ 正確寫法
sed -i 's/^command=.*$/command = "wl-copy \&\& sleep 0.2"/' file
```

**為什麼**: 在 `sed` 的取代字串中，`&` 代表「整個比對到的內容」，不是字面的 `&`。每次執行都會把舊內容塞進新字串中，指數級膨脹。

---

### `grep \s` 需要 `-E` flag 才可靠

```bash
# ❌ 不可靠 - 基本 POSIX grep 不支援 \s
grep -q '^command\s*=' file

# ✅ 正確寫法
grep -Eq '^command\s*=' file
```

---

### `grep` pattern 以 `-` 開頭會被當成選項

**曾造成的 bug**: v4 marker 區塊偵測永遠失敗，每次執行都重複附加區塊

```bash
# ❌ 錯誤 - "-- BEGIN ..." 被當成 grep 的長選項，exit 2（ugrep 同樣）
grep -qF "-- BEGIN macOS input settings" file

# ✅ 正確 - 用 -- 分隔符明確結束選項解析
grep -qF -- "-- BEGIN macOS input settings" file
```

**為什麼**: Lua 註解 marker 以 `--` 開頭，正好是長選項前綴。grep 回傳 2（錯誤）而非 0/1，「已安裝」檢查永遠不成立，`cat >>` 累加寫入就會重複堆疊。

---

### 冪等性 (Idempotency) 檢查清單

任何會修改設定檔的腳本，**跑兩次應該得到完全相同的結果**：

| ✅ 正確做法 | ❌ 錯誤做法 |
| ------------- | ------------- |
| 先檢查是否已存在 → 才修改 | 永遠直接 append (`>>`) 不檢查 |
| `cat > file` (覆蓋寫入) | `cat >> file` (累加寫入) |
| `sed -i 's/old/new/'` 有 guard check | 裸 `sed -i` 不檢查 |
| 修改後 `cat` 內容驗證 | 修改後就不管了 |

---

### Hyprland v4 Lua 設定驗證流程

```bash
# 1. 套用腳本後驗證 Lua 設定無錯
hyprctl reload && hyprctl configerrors   # 應無輸出

# 2. 確認快捷鍵已註冊
omarchy menu keybindings --print | grep -i "screenshot"

# 3. 確認選項生效（讀 runtime 值而非檔案）
hyprctl getoption input:repeat_rate
hyprctl getoption decoration:rounding

# 4. 驗證腳本冪等性
cd ~/omarchy-custom-scripts
./setup-macos-input.sh -i   # 第一次
./setup-macos-input.sh -i   # 第二次 → 設定檔內容必須完全相同
```

## 授權

MIT License
