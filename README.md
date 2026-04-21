# Omarchy macOS-like Custom Scripts

這是一組為 [Omarchy](https://omarchy.org/) Linux 系統設計的 macOS 風格自定義腳本。

## 功能

- **字體設定**: 自動設定 MiSans 字體、Chromium scale factor
- **輸入法設定**: 安裝 fcitx5-rime + 快速倉頡 (rime-scj)
- **macOS 輸入體驗**: 鍵盤重複率、自然捲動、輕觸點擊等
- **Distrobox**: 安裝 distrobox + DistroShelf GUI，設定 `de` alias

## 安裝

```bash
# 克隆倉庫
git clone https://github.com/glasschan/omarchy-custom-scripts.git
cd omarchy-custom-scripts

# 執行主程式
./setup-all.sh -m
```

## 使用方法

### 主程式 (setup-all.sh)

```bash
./setup-all.sh -m    # 互動選單模式
./setup-all.sh       # 一鍵安裝所有設定
./setup-all.sh -u    # 一鍵還原所有設定
./setup-all.sh -s    # 檢查設定狀態
```

### 單獨執行

```bash
./setup-fonts.sh        # 字體設定
./setup-input.sh        # 輸入法設定
./setup-macos-input.sh  # macOS 輸入體驗
./setup-distrobox.sh    # Distrobox + DistroShelf
```

## 功能詳情

### setup-fonts.sh
- 檢查並設定 GTK 字體為 MiSans 10
- 設定 Chromium scale factor 為 1
- 支援還原功能

### setup-input.sh
- 安裝 fcitx5-rime、fcitx5-config-qt
- 安裝快速倉頡輸入法 (rime-scj)
- 設定預設英文模式
- 方案選單: F4
- 中英切換: 右 Shift
- 支援還原功能

### setup-macos-input.sh
- 鍵盤重複率: 60 (更快)
- 重複延遲: 200ms (更短)
- 自然捲動 (mouse + touchpad)
- 輕觸點擊
- 兩指右鍵
- 打字時停用觸控板
- 支援還原功能

### setup-distrobox.sh
- 安裝 distrobox (容器管理)
- 安裝 distroshelf (GTK4 GUI 管理介面)
- 設定 `de` alias (`de <container>` = `distrobox enter <container>`)
- 支援還原功能

## 系統需求

- Omarchy Linux (Arch-based)
- Hyprland
- fcitx5

## 授權

MIT License
