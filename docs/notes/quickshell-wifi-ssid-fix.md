# Quickshell Wi-Fi SSID Display Fix

## Issue

After installing HANCORE quickshell dots with:

```bash
curl -fsSL https://raw.githubusercontent.com/HANCORE-linux/quickshell-dots/main/install.sh | bash -s V1
```

The Wi-Fi SSID displayed as:

```text
Mario\xe2\x80\x99s RG Home
```

Expected display:

```text
Mario's RG Home
```

## Cause

`iw dev wlan0 link` outputs the SSID with literal escaped UTF-8 bytes:

```text
SSID: Mario\xe2\x80\x99s RG Home
```

The Quickshell bar was reading that string directly without decoding the `\x..` byte escapes.

## Files patched

```text
/home/glasschan/.config/quickshell/bar/modules/NetworkWidget.qml
/home/glasschan/.config/quickshell/bar/panels/NetworkPanel.qml
```

## Fix applied

After extracting `SSID` from `iw`, decode byte escapes and normalize the curly apostrophe to a straight apostrophe:

```bash
SSID=$(printf '%b' "$SSID" | sed "s/’/'/g")
```

Inserted after the existing SSID extraction line in both files.

## Verification command

```bash
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'); LINK=$(iw dev "$IFACE" link 2>/dev/null); SSID=$(printf '%s\n' "$LINK" | sed -n 's/^\s*SSID: //p' | head -1); SSID=$(printf '%b' "$SSID" | sed "s/’/'/g"); printf '%s\n' "$SSID"
```

Expected output:

```text
Mario's RG Home
```

## Quickshell restart warning

Do not start Quickshell manually if it is already running, or two top bars will appear.

Check running instances first:

```bash
quickshell list --all
pgrep -a quickshell
```

If duplicate instances exist, kill only the newer duplicate process:

```bash
kill <duplicate-pid>
```

To validate config without leaving another bar running:

```bash
timeout 5s quickshell --path /home/glasschan/.config/quickshell/bar
```
