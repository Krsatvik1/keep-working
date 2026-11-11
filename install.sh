#!/bin/zsh
# Build, install to /Applications, and leave only ONE registered copy of the widget
# (a second copy in the build folder makes the system widget service flip between them).
set -e
cd "$(dirname "$0")"
LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
BUILT="build/Build/Products/Release/Keep Working.app"
DEST="/Applications/Keep Working.app"
xcodegen generate -q
rm -rf "$BUILT"
LOG=build/xcodebuild.log
mkdir -p build
xcodebuild -project KeepWorking.xcodeproj -scheme KeepWorking -configuration Release \
  -derivedDataPath build -allowProvisioningUpdates build > "$LOG" 2>&1 || true
grep -E "error:|\*\* BUILD" "$LOG" || true
# Never touch the installed copy unless the build is whole. A failed build once left a half-built app here,
# rsync copied it over the installed one without its widget, and macOS took the widget off the desktop.
if ! grep -q "\*\* BUILD SUCCEEDED \*\*" "$LOG" || [ ! -x "$BUILT/Contents/PlugIns/KeepWorkingWidget.appex/Contents/MacOS/KeepWorkingWidget" ]; then
  echo "install: build failed, nothing installed (see $LOG)" >&2
  exit 1
fi
pkill -x "Keep Working" || true
rsync -a --delete "$BUILT/" "$DEST/"
# xcodebuild also leaves a loose copy of the extension next to the app; unregister and delete both.
LOOSE="build/Build/Products/Release/KeepWorkingWidget.appex"
for p in "$BUILT/Contents/PlugIns/KeepWorkingWidget.appex" "$LOOSE"; do
  pluginkit -r "$p" 2>/dev/null || true
  $LS -u "$p" 2>/dev/null || true
done
$LS -u "$BUILT" 2>/dev/null || true
rm -rf "$BUILT" "$LOOSE" build/Build/Products/Release/*.dSYM
$LS -f "$DEST"
# The running widget process keeps the old code in memory; stop it so the system relaunches the new binary.
pkill -f "KeepWorkingWidget.appex/Contents/MacOS/KeepWorkingWidget" || true
killall chronod 2>/dev/null || true
open "$DEST"
pluginkit -m -v -i xyz.krsatvik.KeepWorking.Widget
