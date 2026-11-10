#!/bin/zsh
# Build, install to /Applications, and leave only ONE registered copy of the widget
# (a second copy in the build folder makes the system widget service flip between them).
set -e
cd "$(dirname "$0")"
LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
BUILT="build/Build/Products/Release/Session Pulse.app"
DEST="/Applications/Session Pulse.app"
xcodegen generate -q
xcodebuild -project SessionPulse.xcodeproj -scheme SessionPulse -configuration Release \
  -derivedDataPath build -allowProvisioningUpdates build | grep -E "error|BUILD" || true
pkill -x "Session Pulse" || true
true
rsync -a --delete "$BUILT/" "$DEST/"
pluginkit -r "$BUILT/Contents/PlugIns/SessionPulseWidget.appex" 2>/dev/null || true
$LS -u "$BUILT" 2>/dev/null || true
rm -rf "$BUILT"
$LS -f "$DEST"
open "$DEST"
pluginkit -m -v -i xyz.krsatvik.SessionPulse.Widget
