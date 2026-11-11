#!/bin/zsh
# Build a Release copy of Keep Working as a disk image for a GitHub release: build/release/KeepWorking.dmg.
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
# A disk image that opens to a laid-out window: the app on the left, an arrow, Applications on the right, on
# the page's paper colour; the mounted disk carries the app's icon. Built read-write, arranged by Finder, then
# compressed. Arranging needs Finder automation; if macOS refuses it, the image still works, just unarranged.
rm -rf "$OUT/dmg" "$OUT/KeepWorking.dmg" "$OUT/rw.dmg"
mkdir -p "$OUT/dmg/.background"
ditto "$BUILT" "$OUT/dmg/Keep Working.app"
ln -s /Applications "$OUT/dmg/Applications"
cp Tools/dmg/background.tiff "$OUT/dmg/.background/background.tiff"
cp App/Resources/AppIcon.icns "$OUT/dmg/.VolumeIcon.icns"
hdiutil create -quiet -volname "Keep Working" -srcfolder "$OUT/dmg" -ov -format UDRW -fs HFS+ "$OUT/rw.dmg"
MNT=$(hdiutil attach -readwrite -noverify -noautoopen "$OUT/rw.dmg" | awk -F'\t' '/\/Volumes\//{print $NF}')
SetFile -a C "$MNT"
VOL=$(basename "$MNT")   # "Keep Working 1" when another copy is already mounted
osascript <<OSA || echo "release: Finder layout skipped"
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 740, 480}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 96
    set text size of opts to 13
    set background picture of opts to (POSIX file "$MNT/.background/background.tiff" as alias)
    set position of item "Keep Working.app" of container window to {140, 150}
    set position of item "Applications" of container window to {400, 150}
    update without registering applications
    delay 2
    close
  end tell
end tell
OSA
# Finder writes the layout to .DS_Store a moment after the window closes.
for i in {1..20}; do [ -f "$MNT/.DS_Store" ] && break; sleep 0.5; done
[ -f "$MNT/.DS_Store" ] || echo "release: no Finder layout saved"
# The disk's own icon (Finder can drop it while arranging, so it goes in last).
cp App/Resources/AppIcon.icns "$MNT/.VolumeIcon.icns"
SetFile -a C "$MNT"
sync
hdiutil detach -quiet "$MNT"
hdiutil convert -quiet "$OUT/rw.dmg" -format UDZO -o "$OUT/KeepWorking.dmg"
rm -rf "$OUT/dmg" "$OUT/rw.dmg"
# Don't leave a second registered copy of the widget in the build folder (the widget service flips between them).
LOOSE="build/Build/Products/Release/KeepWorkingWidget.appex"
for p in "$BUILT/Contents/PlugIns/KeepWorkingWidget.appex" "$LOOSE"; do
  pluginkit -r "$p" 2>/dev/null || true
  $LS -u "$p" 2>/dev/null || true
done
$LS -u "$BUILT" 2>/dev/null || true
rm -rf "$BUILT" "$LOOSE" build/Build/Products/Release/*.dSYM
ls -lh "$OUT/KeepWorking.dmg"
shasum -a 256 "$OUT/KeepWorking.dmg"
