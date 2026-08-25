#!/usr/bin/env bash
# Notification hook — fires when Claude Code sends a notification
# Cross-platform: macOS uses osascript; Windows/WSL uses PowerShell; else prints only.

# Read notification JSON from stdin
INPUT=$(cat)

# Extract message — try jq first, fall back to grep
if command -v jq &>/dev/null; then
  MESSAGE=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)
fi
if [ -z "$MESSAGE" ]; then
  MESSAGE=$(echo "$INPUT" | grep -oE '"message":"[^"]*"' | sed 's/"message":"//;s/"//')
fi
if [ -z "$MESSAGE" ]; then
  MESSAGE="Claude Code needs your attention"
fi

MESSAGE_SAFE=$(echo "$MESSAGE" | head -c 200)

case "$(uname -s)" in
  Darwin)
    # macOS native notification; escape double quotes and backslashes for AppleScript
    OSA_MSG=$(echo "$MESSAGE_SAFE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    osascript -e "display notification \"$OSA_MSG\" with title \"Claude Code\"" 2>/dev/null
    ;;
  *)
    if command -v powershell.exe &>/dev/null; then
      # Windows balloon tip (works on Windows 10/11 without extra modules)
      PS_MSG=$(echo "$MESSAGE_SAFE" | sed "s/'/''/g")
      powershell.exe -NonInteractive -WindowStyle Hidden -Command "
        Add-Type -AssemblyName System.Windows.Forms
        \$notify = New-Object System.Windows.Forms.NotifyIcon
        \$notify.Icon = [System.Drawing.SystemIcons]::Information
        \$notify.BalloonTipTitle = 'Claude Code'
        \$notify.BalloonTipText = '$PS_MSG'
        \$notify.Visible = \$true
        \$notify.ShowBalloonTip(5000)
        Start-Sleep -Seconds 6
        \$notify.Dispose()
      " 2>/dev/null &
    fi
    ;;
esac

echo "Notification: $MESSAGE_SAFE"
