#!/bin/zsh
# Builds "Keep Working Preview" (the widget's views in a window, every state, live animation) and opens it.
#   Tools/preview.sh                    open it
#   Tools/preview.sh --capture <dir>    save every state as PNGs, then quit
set -e
cd "$(dirname "$0")/.."
APP="build/Keep Working Preview.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -parse-as-library -D RENDER_HARNESS \
  Shared/SessionStore.swift Widget/KeepWorkingWidget.swift Widget/ClawdMotion.swift \
  Tools/Preview.swift \
  -o "$APP/Contents/MacOS/Keep Working Preview"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>xyz.krsatvik.KeepWorking.Preview</string>
  <key>CFBundleName</key><string>Keep Working Preview</string>
  <key>CFBundleExecutable</key><string>Keep Working Preview</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
cp /Applications/Claude.app/Contents/Resources/electron.icns "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null || true
codesign -s - --force "$APP" >/dev/null 2>&1 || true
if [[ "$1" == "--capture" || "$1" == "--frames" || "$1" == "--sheets" ]]; then
  "$APP/Contents/MacOS/Keep Working Preview" "$@"
else
  open "$APP"
fi
