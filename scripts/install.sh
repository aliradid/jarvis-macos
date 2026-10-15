#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "         Installing Jarvis for macOS      "
echo "=========================================="

REPO="aliradid/jarvis-macos"
LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
  LATEST_TAG="v1.0.2"
fi

DMG_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/Jarvis.dmg"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "--> Downloading Jarvis (${LATEST_TAG})..."
curl -fL "$DMG_URL" -o "$TEMP_DIR/Jarvis.dmg"

echo "--> Mounting disk image..."
MOUNT_DIR=$(mktemp -d)
hdiutil attach "$TEMP_DIR/Jarvis.dmg" -nobrowse -mountpoint "$MOUNT_DIR" -quiet

echo "--> Installing Jarvis.app into /Applications..."
rm -rf /Applications/Jarvis.app
cp -R "$MOUNT_DIR/Jarvis.app" /Applications/

hdiutil detach "$MOUNT_DIR" -quiet
rm -rf "$MOUNT_DIR"

echo ""
echo "Jarvis has been successfully installed to /Applications/Jarvis.app!"
echo "You can launch it anytime by opening Spotlight (Cmd+Space) and typing 'Jarvis',"
echo "or run: open /Applications/Jarvis.app"
