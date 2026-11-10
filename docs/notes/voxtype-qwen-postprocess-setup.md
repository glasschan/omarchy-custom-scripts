# VoxType + Qwen 3.5 Flash Post-Processing Setup Guide

Complete guide for setting up VoxType dictation with LLM-powered text cleanup and clipboard backup. Tested on Omarchy (Hyprland/Wayland) with Intel i7-10870H (CPU-only, no GPU).

## What This Gives You

- Voice dictation via **Super + Ctrl + X**
- Raw transcription typed at cursor (~1s)
- LLM post-processing via **Qwen 3.5 Flash** (grammar, filler removal, punctuation)
- **Always a clipboard backup** of both raw and cleaned text
- Total end-to-end: **~2 seconds**

## Architecture

```
Audio → Whisper (local, base.en) → Post-process script → voxtype types cleaned text
                                       ├→ wl-copy (raw backup to clipboard)
                                       ├→ Qwen 3.5 Flash API (cleanup)
                                       ├→ wl-copy (cleaned text to clipboard)
                                       └→ stdout → voxtype types at cursor
```

## Prerequisites

- VoxType installed (`omarchy-voxtype-install` or manually)
- `wl-copy` available (Wayland clipboard)
- `curl` and `python3` available
- DashScope API key from [dashscope.aliyun.com](https://dashscope.aliyun.com/) (Alibaba Cloud international)
- Hyprland/Omarchy with uwsm

## Files to Create/Modify

### 1. API Key Environment Variable

Create `~/.config/environment.d/dashscope.conf`:

```ini
DASHSCOPE_API_KEY=sk-your-api-key-here
```

This makes the key available to all desktop session processes via systemd-environment-d (Hyprland reads this via uwsm).

Also add it to the voxtype systemd service at `~/.config/systemd/user/voxtype.service`:

```ini
[Service]
Environment=DASHSCOPE_API_KEY=sk-your-api-key-here
```

Then run: `systemctl --user daemon-reload`

### 2. Post-Processing Script

Create `~/.local/bin/voxtype-postprocess.sh` and `chmod +x`:

```bash
#!/usr/bin/env bash
# VoxType post-processor: clipboard backup + Qwen 3.5 Flash LLM cleanup
# Reads transcription from stdin, outputs cleaned text to stdout.
# Always copies to clipboard (raw first, then cleaned).

set -eo pipefail

INPUT=$(cat)

# Hardcoded API key as fallback (env var may not pass through voxtype's child process)
DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY:-sk-your-api-key-here}"

# Copy raw to clipboard in background (wl-copy may hang in systemd context)
{ echo -n "$INPUT" | wl-copy; } 2>/dev/null &

# Skip LLM processing for very short input
if [ ${#INPUT} -lt 3 ]; then
    echo -n "$INPUT"
    exit 0
fi

# Escape input for JSON
ESCAPED=$(printf '%s' "$INPUT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

# Call Qwen 3.5 Flash via DashScope Responses API
RESPONSE=$(curl -s --max-time 15 -X POST \
    "https://dashscope-intl.aliyuncs.com/api/v2/apps/protocols/compatible-mode/v1/responses" \
    -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"qwen3.5-flash\",
        \"instructions\": \"You clean up voice dictation text. Fix grammar, remove filler words (um, uh, like), fix capitalization and punctuation, organize into proper sentences. Output ONLY the cleaned text, nothing else.\",
        \"input\": $ESCAPED,
        \"enable_thinking\": false
    }" 2>/dev/null) || true

# Extract output text from Responses API (output[].content[].text), fallback to raw on failure
CLEANED=$(printf '%s' "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for item in data.get('output', []):
        if item.get('type') == 'message':
            for content in item.get('content', []):
                if content.get('type') == 'output_text':
                    print(content['text'], end='')
                    sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null) || true

RESULT="${CLEANED:-$INPUT}"

# Copy cleaned version to clipboard in background
{ echo -n "$RESULT" | wl-copy; } 2>/dev/null &

# Output result to stdout for voxtype to type
echo -n "$RESULT"
# Flush stdout and exit immediately
exec 1>&-
```

### 3. VoxType Config

Edit `~/.config/voxtype/config.toml`:

```toml
[whisper]
model = "base.en"     # English-only, fastest on CPU
language = "en"        # Skip auto-detection overhead
threads = 16           # Use all CPU cores (adjust to your CPU)

[output]
mode = "type"
fallback_to_clipboard = true
type_delay_ms = 3      # 1ms can drop chars; 3ms is safer

[output.post_process]
command = "bash /home/YOURUSER/.local/bin/voxtype-postprocess.sh"
timeout_ms = 20000
```

Also update the Omarchy default template at `~/.local/share/omarchy/default/voxtype/config.toml` with the same changes to survive reinstalls.

### 4. Download Model & Restart

```bash
voxtype setup --download    # Downloads base.en model (~148MB)
systemctl --user daemon-reload
systemctl --user restart voxtype.service
```

## Critical Learnings & Pitfalls

### 1. `wl-copy` Blocks stdout in systemd Context

**Problem**: VoxType uses `posix_spawnp` to run the post-process command. It pipes stdin to the child and reads stdout until EOF. If `wl-copy` runs in the foreground, it keeps the pipe open and voxtype waits forever (20s timeout).

**Fix**: Run `wl-copy` in background with `{ ...; } 2>/dev/null &` and close stdout explicitly with `exec 1>&-` at the end of the script.

### 2. Environment Variables Don't Always Reach Child Processes

**Problem**: Even with `DASHSCOPE_API_KEY` set in the systemd service via `Environment=`, the voxtype daemon's child process (the postprocess script) may not reliably receive it. This caused silent API failures where curl got "No API-key provided" responses, and the script fell through to the raw (uncleaned) text.

**Fix**: Hardcode the API key in the script as a fallback: `DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY:-sk-your-key}"`.

### 3. `set -euo pipefail` + Unset Variables

**Problem**: `set -u` (part of `set -euo pipefail`) treats unset variables as errors. If the env var isn't passed through, the script crashes immediately.

**Fix**: Use `${DASHSCOPE_API_KEY:-}` syntax with a default value, or use `set -eo pipefail` (without `-u`).

### 4. Whisper Multilingual Models Are Very Slow on CPU

**Problem**: The `base` (multilingual) model took **109.8 seconds** to transcribe **27.3 seconds** of audio on an i7-10870H. The `small` model was even worse.

| Model | Type | Transcription Time (13s audio) | Cantonese Support |
|-------|------|-------------------------------|-------------------|
| `base.en` | English-only | ~1s | No |
| `base` | Multilingual | ~28-110s | Yes (poor) |
| `small` | Multilingual | ~110s+ | Yes (mediocre) |

**Lesson**: Without a GPU, only use `.en` models. For Cantonese on CPU, you'd need a cloud ASR solution (e.g., Alibaba Fun-ASR, which is a separate integration).

### 5. `language = "auto"` Adds Significant Overhead

**Problem**: Auto-detection adds latency and can misdetect. It also misidentified Cantonese as English with 98.8% confidence, producing garbage output.

**Fix**: Set `language = "en"` explicitly. If you need other languages, create a separate config profile.

### 6. Qwen Responses API JSON Structure

**Problem**: The DashScope Responses API returns a nested structure, not a flat `output_text` field at the top level.

**Correct path**: `response.output[].content[].text` where `item.type == "message"` and `content.type == "output_text"`.

### 7. `enable_thinking: false` Is Required

**Problem**: Without explicitly disabling thinking, Qwen 3.5 Flash generates ~1300 reasoning tokens even for simple cleanup tasks. This makes the API response take 10-15 seconds and ~15KB of JSON.

**Fix**: Always include `"enable_thinking": false` in the API request. Response drops to ~0.8s.

### 8. Omarchy Default Template Gets Overwritten on Reinstall

**Problem**: `omarchy-voxtype-install` copies from `~/.local/share/omarchy/default/voxtype/config.toml` to `~/.config/voxtype/config.toml` on fresh install.

**Fix**: Keep both files in sync. Edit the Omarchy default template alongside your live config.

### 9. Use `bash` Explicitly in Post-Process Command

**Problem**: VoxType may not respect the shebang line when spawning via `posix_spawnp`.

**Fix**: Use `command = "bash /path/to/script.sh"` instead of just the script path.

## Testing & Verification

Test the script directly:
```bash
echo "um so like I was thinking we should go to the store tomorrow" | \
  /home/YOURUSER/.local/bin/voxtype-postprocess.sh
```

Expected output (after ~1s):
```
I was thinking we should go to the store tomorrow.
```

Check voxtype logs:
```bash
journalctl --user -u voxtype.service -n 20 --no-pager | \
  grep -E "Transcription completed|Post-process"
```

Expected: Transcription ~1s, Post-processed ~0.7s after that.

## Cost

Qwen 3.5 Flash via DashScope international:
- Input: $0.30 / 1M tokens
- Output: $3.00 / 1M tokens
- Typical dictation (~50 words): ~$0.0001 per use
- Free tier credits available on new accounts
