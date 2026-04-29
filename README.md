# Glass Omarchy 自訂工具箱

> 個人 Hyprland + Omarchy 環境自訂腳本

這組腳本用於自動化設定我的個人 Linux 環境。基於 [Omarchy](https://omarchy.org/) + Hyprland，主題是「把 macOS 的操作手感移植到 Arch Linux」。

## 設計理念

- **個人用途**：不是通用的安裝腳本，是為了自己每次重灌後能快速恢復工作環境
- **自動化**：所有設定都透過 script 完成，不依賴 GUI 工具或互動精靈
- **可重複**：可以隨時還原/重新安裝，不會汙染系統

## 功能總覽

| 分類 | 腳本 | 功能 |
|------|------|------|
| **系統設定** | `setup-fonts.sh` | 字體 + Chromium scale 修復 |
| **輸入法** | `setup-input.sh` | fcitx5-rime + 快速倉頡 |
| **鍵盤** | `setup-macos-input.sh` | 鍵盤/觸控板 macOS 行為 |
| **鍵盤** | `setup-keyboard-swap.sh` | 交換內建鍵盤 Super/Alt (Optional) |
| **快捷鍵** | `setup-keybindings.sh` | 截圖、錄影、剪貼簿自動貼上 |
| **遊戲相容** | `setup-gaming.sh` | gamescope + 遊戲環境變數 + 視窗規則 |
| **容器工具** | `setup-distrobox.sh` | Distrobox + DistroShelf + `de` alias |
| **修復工具** | `fix-chrome-keyring.sh` | 修復 Chrome keyring 密碼彈窗 |
| **相容包裝** | `setup-rime-scj.sh` | [舊版] 字體 + 輸入法組合（已拆分） |

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

**直接寫入 fcitx5 profile 設定檔**：不透過 GUI 精靈，避免卡住 script

### setup-macos-input.sh — 輸入體驗

**目標：** 把 macOS 的鍵盤/觸控板操作手感移植到 Hyprland

| 設定 | 值 | 為什麼 |
|------|-----|--------|
| repeat_rate | 60 | Arch 預設 25 太慢，macOS 約 60 |
| repeat_delay | 200ms | 比預設 660ms 短，更快開始重複 |
| natural_scroll | true | macOS muscle memory |
| tap-to-click | true | macOS trackpad 習慣 |
| scroll_factor | 0.7 | 滾輪速度更快 |

### setup-distrobox.sh — 容器環境

**目標：** 在主系統內隔離其他發行版，卻仍能整合使用

- **Distrobox**
  - 為什麼：輕量、shared home、支援 Wayland socket 共享，直接用主系統的字體/主題
- **DistroShelf**
  - 為什麼：圖形化管理容器內安裝的 GUI 程式
- **`de` alias**
  - 為什麼：`de ubuntu` 比 `distrobox enter ubuntu` 少打很多字

### setup-keyboard-swap.sh — 鍵盤按鍵交換 (Optional)

**目標：** 將 Laptop 內建鍵盤的 Super 和 Alt 交換，適合外接鍵盤用 Mac 配置的使用者

- **交換時機**：需要外接鍵盤使用 Mac 配置（Cmd=Alt, Alt=Super）但又不想要打擾內建鍵盤
- **實作方式**：透過 Hyprland 的 per-device XKB options，只針對內建鍵盤應用 `altwin:swap_alt_win`
- **互動式選單**：執行時會顯示所有偵測到的鍵盤，讓使用者選擇要套用的鍵盤（內建鍵盤會被自動標記）
- **Swap 效果**：
  - Alt 鍵 → 變成 Super 鍵（可拉視窗選單、Super+數字切換workspace）
  - Super 鍵 → 變成 Alt 鍵（可當 Ctrl+Alt+T 之類的組合鍵）

### setup-keybindings.sh — 快捷鍵設定

**目標：** 截圖、螢幕錄影、剪貼簿的自訂快捷鍵

| 快捷鍵 | 功能 |
|--------|------|
| `Alt+Shift+Q` | 區域截圖 |
| `Alt+Shift+E` | 視窗截圖 |
| `Alt+Shift+F` | 全螢幕截圖 |
| `Alt+Shift+R` | 螢幕錄影 |
| `Alt+Shift+A` | 顏色選擇器 |
| `Ctrl+\`` | 開啟剪貼簿管理員 |

- **自動貼上**：選取剪貼項目後自動複製並貼上（透過 `hyprctl dispatch sendshortcut`）
- **Pin 功能**：重要項目可固定在列表頂部

### setup-gaming.sh — 遊戲相容性

**目標：** 解決 Wayland 環境下 Unity/SDL 遊戲的常見問題

- **gamescope**：微合成器，把遊戲包在獨立的 Wayland 視窗中
- **SDL_VIDEODRIVER=x11**：強制 SDL 遊戲使用 XWayland
- **自訂視窗規則**：針對特定遊戲的 float/center 規則
- **Steam 啟動選項範本**：`gamescope -W 1920 -H 1080 -f -- %command%`

### fix-chrome-keyring.sh — Chrome Keyring 修復

**目標：** 解決 Chrome/Chromium 每次啟動都詢問 keyring 密碼的問題

- 建立未加密的預設 keyring
- 移除多餘的 keyring 檔案
- 需要重新登入才能生效

## 支援的作業系統

- Omarchy Linux (Arch-based)
- Hyprland (Wayland)
- 需要有 `yay` 或 `paru`（AUR 助手） 或 `sudo` 可用

## 檔案結構

```
.
├── lib/
│   └── common.sh            # 共用函式庫（顏色、紀錄函數、套件管理等）
├── setup-all.sh             # 主程式，自動探索所有腳本 + 互動選單
├── setup-fonts.sh           # 字體設定
├── setup-input.sh           # 輸入法設定
├── setup-macos-input.sh    # 鍵盤/觸控板設定
├── setup-keyboard-swap.sh   # 交換內建鍵盤 Super/Alt
├── setup-keybindings.sh     # 截圖/錄影/剪貼簿快捷鍵
├── setup-gaming.sh          # 遊戲相容性設定
├── setup-distrobox.sh       # Distrobox 容器工具
├── fix-chrome-keyring.sh    # Chrome keyring 密碼彈窗修復
└── setup-rime-scj.sh        # [舊版] 相容包裝
```

## 開發者說明

### 標準 CLI 介面

所有腳本都支援一致的命令列參數：

| 參數 | 功能 |
|------|------|
| `-i`, `--install` | 安裝/套用設定 |
| `-u`, `--uninstall` | 還原設定 |
| `-s`, `--status` | 顯示目前狀態 |
| `-h`, `--help` | 顯示說明 |

### 新增腳本 QA 檢查清單 ✅

新增任何會修改設定檔的腳本之前，請務必先通過這份清單：

- [ ] **冪等性測試**: 連續執行 `-i` 兩次，確認第二次執行後設定檔內容完全不變
- [ ] **sed 安全性**: 所有 `sed` 取代字串中的 `&` 都必須跳脫為 `\&`
- [ ] **grep 安全性**: 所有包含 `\s` 的 grep 都必須使用 `-E` flag
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

### 冪等性 (Idempotency) 檢查清單

任何會修改設定檔的腳本，**跑兩次應該得到完全相同的結果**：

| ✅ 正確做法 | ❌ 錯誤做法 |
|-------------|-------------|
| 先檢查是否已存在 → 才修改 | 永遠直接 append (`>>`) 不檢查 |
| `cat > file` (覆蓋寫入) | `cat >> file` (累加寫入) |
| `sed -i 's/old/new/'` 有 guard check | 裸 `sed -i` 不檢查 |
| 修改後 `cat` 內容驗證 | 修改後就不管了 |

---

### 剪貼簿設定除錯流程

```bash
# 1. 檢查設定檔是否正常
grep '^command' ~/.config/elephant/clipboard.toml
# 應顯示: command = 'wl-copy && hyprctl dispatch sendshortcut "SHIFT, Insert,"'

# 2. 確認服務執行中
pgrep -a elephant && pgrep -a walker

# 3. 有問題就重啟
systemctl --user restart elephant

# 4. 驗證腳本冪等性
cd ~/omarchy-custom-scripts
./setup-keybindings.sh -i   # 第一次
./setup-keybindings.sh -i   # 第二次 → 設定檔內容必須完全相同
```

## 授權

MIT License