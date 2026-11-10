#!/bin/zsh
# Build, install to /Applications, and leave only ONE registered copy of the widget
# (a second copy in the build folder makes the system widget service flip between them).
set -e
cd "$(dirname "$0")"
LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
BUILT="build/Build/Products/Release/Afoot.app"
DEST="/Applications/Afoot.app"
xcodegen generate -q
xcodebuild -project Afoot.xcodeproj -scheme Afoot -configuration Release \
  -derivedDataPath build -allowProvisioningUpdates build | grep -E "error|BUILD" || true
pkill -x "Afoot" || true
rsync -a --delete "$BUILT/" "$DEST/"
# xcodebuild also leaves a loose copy of the extension next to the app; unregister and delete both.
LOOSE="build/Build/Products/Release/AfootWidget.appex"
for p in "$BUILT/Contents/PlugIns/AfootWidget.appex" "$LOOSE"; do
  pluginkit -r "$p" 2>/dev/null || true
  $LS -u "$p" 2>/dev/null || true
done
$LS -u "$BUILT" 2>/dev/null || true
rm -rf "$BUILT" "$LOOSE" build/Build/Products/Release/*.dSYM
$LS -f "$DEST"
# The running widget process keeps the old code in memory; stop it so the system relaunches the new binary.
pkill -f "AfootWidget.appex/Contents/MacOS/AfootWidget" || true
killall chronod 2>/dev/null || true
open "$DEST"
pluginkit -m -v -i xyz.krsatvik.Afoot.Widget
