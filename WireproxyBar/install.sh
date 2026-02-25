#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.sammers.wireproxybar.plist"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"

echo "==> Step 1: Building app..."
bash "${SCRIPT_DIR}/build.sh"

echo ""
echo "==> Step 2: Installing LaunchAgent (start at login)..."
mkdir -p "${LAUNCH_AGENTS_DIR}"
cp "${SCRIPT_DIR}/${PLIST_NAME}" "${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"

# Unload first in case it was already loaded
launchctl unload "${LAUNCH_AGENTS_DIR}/${PLIST_NAME}" 2>/dev/null || true
launchctl load "${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"

echo ""
echo "==> Done!"
echo ""
echo "  App:          /Applications/WireproxyBar.app"
echo "  LaunchAgent:  ${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"
echo "  Logs:         /tmp/wireproxy.log"
echo ""
echo "WireproxyBar is now running and will start automatically at login."
echo "Look for 'VPN ●' in your menu bar."
