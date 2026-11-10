#!/bin/zsh
# Builds "Pulse Preview" (the widget's views in a window, every state, live animation) and opens it.
#   Tools/preview.sh                    open it
#   Tools/preview.sh --capture <dir>    save every state as PNGs, then quit
set -e
cd "$(dirname "$0")/.."
APP="build/Pulse Preview.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -parse-as-library -D RENDER_HARNESS \
  Shared/SessionStore.swift Widget/SessionPulseWidget.swift Tools/Preview.swift \
  -o "$APP/Contents/MacOS/Pulse Preview"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>xyz.krsatvik.SessionPulse.Preview</string>
  <key>CFBundleName</key><string>Pulse Preview</string>
  <key>CFBundleExecutable</key><string>Pulse Preview</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
cp /Applications/Claude.app/Contents/Resources/electron.icns "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null || true
codesign -s - --force "$APP" >/dev/null 2>&1 || true
if [[ "$1" == "--capture" || "$1" == "--frames" ]]; then
  "$APP/Contents/MacOS/Pulse Preview" "$@"
else
  open "$APP"
fi
