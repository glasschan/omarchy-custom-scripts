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
- **不重寫 Omarchy 範本**：v4 的 `input.lua` / `looknfeel.lua` / `bindings.lua` 以 marker 區塊附加，保留範本註解與 Omarchy 預設

## 功能總覽

| 分類 | 腳本 | 功能 |
| ------ | ------ | ------ |
| **系統設定** | `setup-fonts.sh` | 字體 + Chromium scale 修復 |
| **系統設定** | `setup-looknfeel.sh` | Hyprland Look & Feel（圓角、陰影、動畫、白色邊框） |
| **輸入法** | `setup-input.sh` | fcitx5-rime + 快速倉頡 |
| **鍵盤** | `setup-macos-input.sh` | 鍵盤/觸控板 macOS 行為 |
| **快捷鍵** | `setup-keybindings.sh` | 截圖、錄影、OCR、剪貼簿快捷鍵 |
| **快捷鍵** | `setup-foot.sh` | foot 終端機貼上/複製快捷鍵 |
| **容器工具** | `setup-distrobox.sh` | Distrobox + DistroShelf + `de` alias |
| **修復工具** | `fix-chrome-keyring.sh` | Chrome keyring 密碼彈窗修復 |
| **修復工具** | `fix-spotify-scale.sh` | Spotify 1080p 縮放修復 |
| **相容包裝** | `setup-rime-scj.sh` | [舊版] 字體 + 輸入法組合（已拆分） |

> v3 專屬腳本 `setup-keyboard-swap.sh` 與 `setup-gaming.sh` 已在 v4 移除（Hyprland 改用 Lua 設定後不再適用），保留在 `v3` branch。

## 快速開始

```bash
# 互動選單（預設）
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

## 各腳本說明

### setup-fonts.sh — 字體與顯示

**目標：** 統一顯示環境，避免 HiDPI UI 過大的問題

- **GTK 字體**：MiSans 10
  - 為什麼：支援 CJK、個人覺得耐看
- **Chromium scale**：設定為 1
  - 為什麼：Hyprland 已經處理 HiDPI，Chromium 再縮放會造成 UI 過大

### setup-looknfeel.sh — Hyprland 視覺與動畫

**目標：** macOS 風格 Look & Feel（覆蓋 Omarchy 預設：彩色邊框、0 圓角、無陰影、極慢動畫）

- **近乎透明嘅白色邊框**：1px hairline（macOS 冇彩色邊框，焦點靠陰影區分）
- **視窗圓角**：10px
- **陰影 & 毛玻璃**：柔和陰影 + 明亮 vibrancy blur（macOS 風格）
- **快速彈簧動畫**：macSpring ~300ms（Omarchy 預設 3-4 秒太慢）
- **無視窗暗化**：`dim_inactive` 關閉（個人偏好 — 滑鼠 focus 轉移時視窗唔變暗）
- **邊框拖曳調整大小**：`resize_on_border = true`
- **`-f/--force`**：強制重新套用（還原被手動修改嘅設定）

**v4 實作方式**：以 `-- BEGIN/END macOS looknfeel settings` marker 區塊附加到 `~/.config/hypr/looknfeel.lua`（`hl.config` / `hl.curve` / `hl.animation` Lua API），唔會重寫 Omarchy 範本；`-u` 移除區塊即回復預設。

### setup-input.sh — 輸入法

**目標：** 在 Wayland 環境下使用順手的中文輸入法

- **fcitx5 + rime**
  - 為什麼：Wayland 原生支援，rime 詞庫可同步、彈性高
- **快速倉頡 (scj6)**
  - 為什麼：比傳統倉頡學習成本低，重碼率低，適合日常使用
- **啟動時預設英文模式**
  - 為什麼：多數時候在打程式或英文，預設英文減少切換次數
- **F4 切換輸入法方案**（scj6 ↔ 倉頡五代）
- **右 Shift 切換中英文**
- **自動部署**：執行後會自動重啟 fcitx5 並等待部署完成（最長 10 秒）

**v4 注意事項**：

- fcitx5 由 systemd user service `omarchy-fcitx5.service` 監管，重啟一律透過 `systemctl --user restart`（不再 `killall` 手動啟動）
- IM 環境變數（`QT_IM_MODULE` 等）已是 Omarchy v4 預設，腳本無需設定
- 腳本會檢查並修復 fcitx5 `profile`（v4 升級後 profile 曾損毀導致無法切換中文）
- 切換輸入法主要 trigger：`Ctrl+Space`（注意 `Super+Space` 在 v4 被 Omarchy menu 佔用）

**直接寫入 fcitx5 profile 設定檔**：不透過 GUI 精靈，避免卡住 script

### setup-macos-input.sh — 輸入體驗

**目標：** 把 macOS 的鍵盤/觸控板操作手感移植到 Hyprland

| 設定 | 值 | 為什麼 |
| ------ | ----- | -------- |
| kb_options | `compose:caps` | 還原 v3 值——v4 預設加咗 `shift:both_capslock_cancel`，會令 rime「單獨撳右 Shift 切中英文」失效 |
| repeat_rate | 60 | Arch 預設 25 太慢，macOS 約 60 |
| repeat_delay | 200ms | 比預設 660ms 短，更快開始重複 |
| natural_scroll | true | macOS muscle memory |
| tap_to_click | true | macOS trackpad 習慣 |
| scroll_factor | 0.7 | 滾輪速度更快 |

**v4 實作方式**：以 marker 區塊附加到 `~/.config/hypr/input.lua`（`hl.config({ input = ... })`）；terminal 捲動規則 v4 預設已含（Alacritty/kitty/foot 1.5、ghostty 0.2），無需重複。

### setup-distrobox.sh — 容器環境

**目標：** 在主系統內隔離其他發行版，卻仍能整合使用

- **Distrobox**
  - 為什麼：輕量、shared home、支援 Wayland socket 共享，直接用主系統的字體/主題
- **DistroShelf**
  - 為什麼：圖形化管理容器內安裝的 GUI 程式
- **`de` alias**
  - 為什麼：`de ubuntu` 比 `distrobox enter ubuntu` 少打很多字

### setup-keybindings.sh — 快捷鍵設定

**目標：** 截圖、螢幕錄影、OCR、剪貼簿的自訂快捷鍵

| 快捷鍵 | 功能 |
| -------- | ------ |
| `Alt+Shift+Q` | 區域截圖 |
| `Alt+Shift+E` | 視窗截圖 |
| `Alt+Shift+F` | 全螢幕截圖 |
| `Alt+Shift+R` | 螢幕錄影 |
| `Alt+Shift+Ctrl+R` | 螢幕錄影（含攝影機） |
| `Alt+Shift+A` | 顏色選擇器 |
| `Alt+Shift+O` | OCR 文字辨識（中英混合） |
| `Ctrl+\`` | 開啟剪貼簿管理員 |

**v4 實作方式**：以 marker 區塊附加到 `~/.config/hypr/bindings.lua`（`o.bind()` Lua API）。

- **剪貼簿管理員**：Ctrl+\` 開啟 Omarchy v4 內建剪貼簿（`omarchy-shell shell toggle omarchy.clipboard`），另有預設快捷鍵 `Super+Ctrl+V`。v3 的 walker + elephant 自動貼上組合已淘汰
- **OCR**：使用 `omarchy-capture-text`（v3 的 `-extraction` 後綴指令已改名），以 `OMARCHY_OCR_LANGS=eng+chi_tra` 支援中英混合

### setup-foot.sh — foot 終端機快捷鍵

**目標：** 設定 foot 終端機的貼上/複製快捷鍵（foot 預設的 `Ctrl+Shift+V` 會被自訂 `clipboard-paste` 取代，需要一併保留）

- **貼上**：`Shift+Insert` + `Ctrl+Shift+V`
- **複製**：`Control+Insert`
- 修改 `~/.config/foot/foot.ini` 的 `[key-bindings]` section，開新視窗生效

### fix-chrome-keyring.sh — Chrome Keyring 修復

**目標：** 解決 Chrome/Chromium 每次啟動都詢問 keyring 密碼的問題

- 建立未加密的預設 keyring
- 移除多餘的 keyring 檔案
- 需要重新登入才能生效

## 支援的作業系統

- Omarchy Linux v4（Arch-based）— `master` branch；v3 請用 `v3` branch
- Hyprland (Wayland，Lua 設定)
- 需要有 `yay` 或 `paru`（AUR 助手） 或 `sudo` 可用

## 檔案結構

```
.
├── lib/
│   ├── common.sh                    # 共用函式庫（顏色、紀錄函數、套件管理等）
│   └── AGENTS.md                    # DOX 子文件：lib 契約
├── AGENTS.md                        # DOX 根文件：專案契約與索引
├── setup-all.sh                     # 主程式，自動探索所有腳本 + 互動選單
├── setup-fonts.sh                   # 字體設定
├── setup-input.sh                   # 輸入法設定
├── setup-macos-input.sh             # 鍵盤/觸控板設定
├── setup-keybindings.sh             # 截圖/錄影/OCR/剪貼簿快捷鍵
├── setup-foot.sh                    # foot 終端機貼上/複製快捷鍵
├── setup-distrobox.sh               # Distrobox 容器工具
├── fix-chrome-keyring.sh            # Chrome keyring 密碼彈窗修復
├── fix-spotify-scale.sh             # Spotify 1080p 縮放修復
├── test-idempotency.sh              # 冪等性測試工具
└── setup-rime-scj.sh                # [舊版] 相容包裝
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
