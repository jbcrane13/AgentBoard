#!/bin/bash
#
# Install the AgentBoard Companion as a per-user LaunchAgent on this machine.
# Runs from inside an unpacked agentboard-companion bundle; needs no Xcode,
# toolchain, or repo checkout.
#
# A LaunchAgent (not a LaunchDaemon) on purpose: the companion discovers the
# user's tmux sessions and reads ~/.hermes, so it must run as the logged-in
# user, in their session — not as root.
#
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/Library/Application Support/AgentBoardCompanion"
LOG_DIR="$HOME/Library/Logs/AgentBoardCompanion"
LABEL="com.agentboard.companion"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CONFIG="$HOME/.agentboard-companion/config.json"

if [[ ! -x "$BUNDLE_DIR/bin/AgentBoardCompanion" ]]; then
    echo "error: run this from inside the unpacked agentboard-companion bundle" >&2
    exit 1
fi

echo "==> Stopping any running companion"
launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true

echo "==> Installing to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$(dirname "$PLIST")"
rm -rf "$INSTALL_DIR/bin" "$INSTALL_DIR/Frameworks"
cp -R "$BUNDLE_DIR/bin" "$BUNDLE_DIR/Frameworks" "$INSTALL_DIR/"

# tmux lives in Homebrew's prefix, which a LaunchAgent does not inherit.
cat >"$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/bin/AgentBoardCompanion</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/companion.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/companion.err.log</string>
</dict>
</plist>
PLIST_EOF

echo "==> Loading LaunchAgent"
launchctl bootstrap "gui/$UID" "$PLIST"
launchctl enable "gui/$UID/$LABEL"

echo "==> Waiting for the companion to come up"
for _ in $(seq 1 20); do
    if [[ -f "$CONFIG" ]]; then
        break
    fi
    sleep 0.5
done

if [[ ! -f "$CONFIG" ]]; then
    echo "error: companion did not create $CONFIG — check $LOG_DIR/companion.err.log" >&2
    exit 1
fi

PORT="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("port",8742))' "$CONFIG")"
TOKEN="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("bearerToken") or "")' "$CONFIG")"

# Prefer the Tailscale address when present — that is how a remote AgentBoard
# will actually reach this machine.
HOST_ADDR="$(/usr/bin/env tailscale ip -4 2>/dev/null | head -1 || true)"
if [[ -z "$HOST_ADDR" ]]; then
    HOST_ADDR="$(scutil --get LocalHostName 2>/dev/null).local"
fi

echo
echo "AgentBoard Companion installed and running."
echo
echo "  Companion URL:    http://$HOST_ADDR:$PORT"
echo "  Companion Token:  $TOKEN"
echo
echo "Paste both into AgentBoard -> Settings -> Companion Service, then Save and Refresh."
echo
echo "  Logs:    $LOG_DIR/companion.{out,err}.log"
echo "  Stop:    launchctl bootout gui/$UID/$LABEL"
echo "  Start:   launchctl bootstrap gui/$UID $PLIST"
