#!/bin/zsh
# Build a Release copy of Keep Working and zip it for a GitHub release: build/release/KeepWorking.zip.
# Signed with this Mac's Apple Development identity, not notarized (no Developer ID), so people allow it once
# in System Settings > Privacy & Security. The installed copy in /Applications is left alone.
set -e
cd "$(dirname "$0")"
LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
BUILT="build/Build/Products/Release/Keep Working.app"
OUT=build/release
xcodegen generate -q
rm -rf "$BUILT"
mkdir -p build "$OUT"
LOG=build/xcodebuild-release.log
xcodebuild -project KeepWorking.xcodeproj -scheme KeepWorking -configuration Release \
  -derivedDataPath build -allowProvisioningUpdates build > "$LOG" 2>&1 || true
if ! grep -q "\*\* BUILD SUCCEEDED \*\*" "$LOG" || [ ! -x "$BUILT/Contents/PlugIns/KeepWorkingWidget.appex/Contents/MacOS/KeepWorkingWidget" ]; then
  echo "release: build failed (see $LOG)" >&2
  exit 1
fi
codesign --verify --deep --strict "$BUILT"
rm -f "$OUT/KeepWorking.zip"
ditto -c -k --sequesterRsrc --keepParent "$BUILT" "$OUT/KeepWorking.zip"
# Don't leave a second registered copy of the widget in the build folder (the widget service flips between them).
LOOSE="build/Build/Products/Release/KeepWorkingWidget.appex"
for p in "$BUILT/Contents/PlugIns/KeepWorkingWidget.appex" "$LOOSE"; do
  pluginkit -r "$p" 2>/dev/null || true
  $LS -u "$p" 2>/dev/null || true
done
$LS -u "$BUILT" 2>/dev/null || true
rm -rf "$BUILT" "$LOOSE" build/Build/Products/Release/*.dSYM
ls -lh "$OUT/KeepWorking.zip"
shasum -a 256 "$OUT/KeepWorking.zip"
