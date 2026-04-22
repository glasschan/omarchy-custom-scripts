# Glass Omarchy 自訂工具箱

> 個人 Hyprland + Omarchy 環境自訂腳本

這組腳本用於自動化設定我的個人 Linux 環境。基於 [Omarchy](https://omarchy.org/) + Hyprland，主題是「把 macOS 的操作手感移植到 Arch Linux」。

## 設計理念

- **個人用途**：不是通用的安裝腳本，是為了自己每次重灌後能快速恢復工作環境
- **自動化**：所有設定都透過 script 完成，不依賴 GUI 工具或互動精靈
- **可重複**：可以隨時還原/重新安裝，不會汙染系統

## 功能總覽

| 腳本 | 功能 |
|------|------|
| `setup-fonts.sh` | 字體 + Chromium scale |
| `setup-input.sh` | fcitx5-rime + 快速倉頡 |
| `setup-macos-input.sh` | 鍵盤/觸控板 macOS 行為 |
| `setup-keyboard-swap.sh` | 交換內建鍵盤 Super/Alt (Optional) |
| `setup-distrobox.sh` | Distrobox + DistroShelf |

## 快速開始

```bash
# 互動選單
./setup-all.sh -m

# 一鍵安裝所有
./setup-all.sh

# 檢查狀態
./setup-all.sh -s
```

## 各腳本說明

### setup-fonts.sh — 字體與顯示

**目標：** 統一顯示環境，避免 HiDPI UI 過大的問題

- **GTK 字體**：MiSans 10
  - 為什麼：支援 CJK、個人覺得耐看
- **Chromium scale**：設定為 1
  - 為什麼：Hyprland 已經处理 HiDPI，Chromium 再縮放會造成 UI 過大

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

## 支援的作業系統

- Omarchy Linux (Arch-based)
- Hyprland (Wayland)
- 需要有 `yay` 或 `paru`（AUR 助手） 或 `sudo` 可用

## 檔案結構

```
.
├── setup-all.sh             # 主程式，選單整合所有腳本
├── setup-fonts.sh           # 字體設定
├── setup-input.sh           # 輸入法設定
├── setup-macos-input.sh    # 鍵盤/觸控板設定
├── setup-keyboard-swap.sh   # 交換內建鍵盤 Super/Alt (Optional)
└── setup-distrobox.sh       # Distrobox 設定
```

## 授權

MIT License