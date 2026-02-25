#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="WireproxyBar"
APP_BUNDLE="/Applications/${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"

echo "==> Building ${APP_NAME}..."

# Create bundle structure
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Use the Xcode-bundled compiler explicitly (avoids standalone toolchain conflicts)
XCODE_SWIFTC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SDK="$(xcrun --show-sdk-path)"

"${XCODE_SWIFTC}" \
    "${SCRIPT_DIR}/Sources/main.swift" \
    -sdk "${SDK}" \
    -target arm64-apple-macosx15.0 \
    -o "${MACOS_DIR}/${APP_NAME}" \
    -framework AppKit \
    -framework Foundation

# Copy Info.plist
cp "${SCRIPT_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

echo "==> Built: ${APP_BUNDLE}"
echo ""
echo "Run install.sh to set up login item, or open ${APP_BUNDLE} manually."
