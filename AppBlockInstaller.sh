#!/bin/zsh
# blocker_installer.sh
# One-command installer for the Blocker system

set -e

echo "Installing Blocker system..."

sudo mkdir -p /Library/Blocker
sudo mkdir -p /usr/local/bin

sudo tee /Library/Blocker/runner.sh > /dev/null <<'EOF'
#!/bin/zsh
LIST="/Library/Blocker/blocked.txt"
[[ -f "$LIST" ]] || exit 0
while read -r item; do
  [[ -z "$item" ]] && continue
  /usr/bin/pkill -9 -x "$item" 2>/dev/null
done < "$LIST"
EOF
sudo chmod +x /Library/Blocker/runner.sh

sudo tee /Library/LaunchDaemons/com.local.blocker.plist > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.local.blocker</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>/Library/Blocker/runner.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>0</integer>
</dict>
</plist>
EOF

sudo tee /usr/local/bin/block > /dev/null <<'EOF'
#!/bin/zsh
LIST="/Library/Blocker/blocked.txt"
mkdir -p /Library/Blocker
touch "$LIST"
TARGET="$1"
if [[ -z "$TARGET" ]]; then
  echo "Usage:"
  echo "  block /path/to/app-or-binary"
  echo "  block list"
  exit 1
fi
if [[ "$TARGET" == "list" ]]; then
  cat "$LIST"
  exit 0
fi
if [[ ! -e "$TARGET" ]]; then
  echo "Not found: $TARGET"
  exit 1
fi
NAME=$(basename "$TARGET")
NAME="${NAME%.app}"
grep -qx "$NAME" "$LIST" || echo "$NAME" | sudo tee -a "$LIST" > /dev/null
sudo launchctl kickstart -k system/com.local.blocker
echo "Blocked: $NAME"
EOF
sudo chmod +x /usr/local/bin/block

sudo tee /usr/local/bin/unblock > /dev/null <<'EOF'
#!/bin/zsh
LIST="/Library/Blocker/blocked.txt"
NAME="$1"
if [[ -z "$NAME" ]]; then
  echo "Usage: unblock AppName"
  exit 1
fi
sudo sed -i '' "/^${NAME}$/d" "$LIST"
echo "Unblocked: $NAME"
EOF
sudo chmod +x /usr/local/bin/unblock

sudo launchctl bootout system/com.local.blocker 2>/dev/null || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.local.blocker.plist

echo "✅ Blocker system installed successfully!"
echo "Use 'block /path/to/app' to block apps, 'unblock AppName' to unblock, and 'block list' to see blocked apps."
