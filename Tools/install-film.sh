#!/bin/zsh
# Renders the install walkthrough (Tools/InstallFilm.swift) with the film renderer.
#   Tools/install-film.sh out.mp4            Tools/install-film.sh --still 12.5 f.png
set -e
cd "$(dirname "$0")/.."
mkdir -p build/film-assets
[ -f build/film-assets/wallpaper.jpg ] || sips -s format jpeg -s formatOptions 90 -Z 2880 -m "/System/Library/ColorSync/Profiles/sRGB Profile.icc" \
  "/System/Library/Desktop Pictures/Sonoma.heic" --out build/film-assets/wallpaper.jpg >/dev/null
SRC=build/film-src; rm -rf "$SRC"; mkdir -p "$SRC"
for f in Shared/SessionStore.swift Widget/KeepWorkingWidget.swift Widget/ClawdMotion.swift; do git show "HEAD:$f" > "$SRC/$(basename $f)"; done
swiftc -O -parse-as-library -D RENDER_HARNESS \
  "$SRC/SessionStore.swift" "$SRC/KeepWorkingWidget.swift" "$SRC/ClawdMotion.swift" Tools/Film.swift Tools/InstallFilm.swift \
  -o build/install-film
if [[ "$1" == --still ]]; then build/install-film --install-still "$2" "$3"; elif [[ "$1" == --tile ]]; then build/install-film "$@"; else build/install-film --install "$@"; fi
