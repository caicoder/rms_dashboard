#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Change directory to the project root (where this script is located's parent)
cd "$(dirname "$0")/.."

echo "--------------------------------------------------------"
echo "  RMS Dashboard DMG Packaging Script"
echo "--------------------------------------------------------"

# 1. Self-healing background image copying (copy from IDE brain directory if needed)
if [ ! -f "macos/dmg_background.png" ]; then
  BRAIN_IMG="/Users/huaxizhineng/.gemini/antigravity-ide/brain/64358f93-79a5-47fd-a7c6-67dcf2909a30/dmg_background_1782350811774.png"
  if [ -f "$BRAIN_IMG" ]; then
    echo "Copying generated background image into macos/dmg_background.png..."
    cp "$BRAIN_IMG" "macos/dmg_background.png"
  else
    echo "Warning: Background image not found at $BRAIN_IMG. A generic background will be used."
  fi
fi

# 2. Build the release macOS app using the existing Flutter SDK version
echo "Building Flutter macOS application in release mode..."
flutter build macos --release

APP_PATH="build/macos/Build/Products/Release/rms_dashboard.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: Release build failed or app bundle not found at $APP_PATH"
  exit 1
fi

echo "Build succeeded. Preparing DMG packaging..."

# 3. Setup temporary folder
STAGING_DIR="build/dmg_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy the app to the staging folder
echo "Copying application bundle..."
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create symlink to Applications
echo "Creating Applications folder symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

# Copy background image if exists
if [ -f "macos/dmg_background.png" ]; then
  echo "Setting up custom installer background image..."
  mkdir -p "$STAGING_DIR/.background"
  cp "macos/dmg_background.png" "$STAGING_DIR/.background/background.png"
  HAS_BACKGROUND=true
else
  HAS_BACKGROUND=false
fi

# Clean up any existing temporary/final DMG files
rm -f build/temp.dmg
rm -f rms_dashboard.dmg

# 4. Create temporary read-write DMG
echo "Creating temporary read-write disk image..."
hdiutil create -srcfolder "$STAGING_DIR" -volname "RMS Dashboard" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW build/temp.dmg

# 5. Mount the disk image and get device node
echo "Mounting temporary disk image..."
device=$(hdiutil attach -readwrite -noverify build/temp.dmg | grep '^/dev/' | head -n 1 | awk '{print $1}')
sleep 3

# 6. Apply styling using AppleScript via osascript
echo "Styling DMG folder view using AppleScript..."

if [ "$HAS_BACKGROUND" = true ]; then
  # AppleScript to set custom background, icon positions, and windows size
  osascript <<EOF
  tell application "Finder"
    tell disk "RMS Dashboard"
      open
      set current view of container window to icon view
      set statusbar visible of container window to false
      set toolbar visible of container window to false
      
      # Set window size and position (bounds: {left, top, right, bottom})
      # 600x600 size: 400 + 600 = 1000, 100 + 600 = 700
      set the bounds of container window to {400, 100, 1000, 700}
      
      # Configure view settings
      set theViewOptions to icon view options of container window
      set icon size of theViewOptions to 100
      try
        set arrangement of theViewOptions to not arranged
      end try
      try
        set label position of theViewOptions to bottom
      end try
      
      # Set custom background image
      try
        set background picture of theViewOptions to file ".background:background.png"
      end try
      
      # Position the icons on the background placeholders
      # Left placeholder: {160, 320}
      # Right placeholder: {440, 320}
      set position of item "rms_dashboard.app" to {160, 320}
      set position of item "Applications" to {440, 320}
      
      update without registering applications
      delay 3
      close
    end tell
  end tell
EOF
else
  # Default basic styling if no background image is present
  osascript <<EOF
  tell application "Finder"
    tell disk "RMS Dashboard"
      open
      set current view of container window to icon view
      set the bounds of container window to {400, 100, 1000, 500}
      set theViewOptions to icon view options of container window
      set icon size of theViewOptions to 100
      try
        set arrangement of theViewOptions to not arranged
      end try
      set position of item "rms_dashboard.app" to {150, 200}
      set position of item "Applications" to {450, 200}
      update without registering applications
      delay 3
      close
    end tell
  end tell
EOF
fi

# Sync filesystem changes
sync
sleep 2

# 7. Unmount the disk image
echo "Unmounting temporary disk image..."
hdiutil detach "$device"
sleep 2

# 8. Convert to compressed, read-only DMG
echo "Converting to final compressed DMG..."
hdiutil convert build/temp.dmg -format UDZO -imagekey zlib-level=9 -o rms_dashboard.dmg

# 9. Clean up temporary files
echo "Cleaning up temporary files..."
rm -rf "$STAGING_DIR"
rm -f build/temp.dmg

echo "--------------------------------------------------------"
echo "  Success! Your installer is ready at:"
echo "  $(pwd)/rms_dashboard.dmg"
echo "--------------------------------------------------------"
