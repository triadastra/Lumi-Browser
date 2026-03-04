#!/bin/bash
# create-dmg.sh - Create a distributable DMG for Lumi Browser
# Usage: ./scripts/create-dmg.sh <app-path> <output-dmg> <app-name> <version>
#
# This script creates a beautiful DMG with:
# - The app icon
# - A link to /Applications
# - Custom background (optional)
# - Proper window size and icon positions

set -euo pipefail

APP_PATH="${1:-build/LumiBrowser.app}"
OUTPUT_DMG="${2:-build/LumiBrowser.dmg}"
APP_NAME="${3:-LumiBrowser}"
VERSION="${4:-1.0.0}"
VOLUME_NAME="${APP_NAME} ${VERSION}"

# Staging directory
STAGING_DIR=$(mktemp -d)
trap "rm -rf '$STAGING_DIR'" EXIT

echo "▸ Staging DMG contents..."
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -sf /Applications "$STAGING_DIR/Applications"

# Create a temporary writable DMG
TEMP_DMG=$(mktemp -t lumi-temp.XXXXXX).dmg
trap "rm -rf '$STAGING_DIR' '$TEMP_DMG'" EXIT

echo "▸ Creating writable DMG..."
hdiutil create \
    -srcfolder "$STAGING_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,b=16" \
    -format UDRW \
    -size 200m \
    "$TEMP_DMG"

# Mount the writable DMG
echo "▸ Mounting DMG for customization..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

# Wait for mount
sleep 2

# Set custom window appearance via AppleScript
echo "▸ Customizing DMG window..."
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 760, 460}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set position of item "${APP_NAME}.app" of container window to {160, 180}
        set position of item "Applications" of container window to {400, 180}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

# Ensure changes are flushed
sync
sleep 1

# Unmount
echo "▸ Unmounting..."
hdiutil detach "$DEVICE"

# Convert to compressed read-only DMG
echo "▸ Compressing DMG..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$OUTPUT_DMG"

# Get final size
SIZE=$(du -sh "$OUTPUT_DMG" | cut -f1)
echo "✓ DMG created: $OUTPUT_DMG ($SIZE)"
