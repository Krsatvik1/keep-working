#!/bin/zsh
# Builds and runs the film renderer (Tools/Film.swift): the showcase video, drawn frame by frame from the
# widget's own views. Output is not kept in git.
#   Tools/film.sh out.mp4            Tools/film.sh out.mp4 2 20            Tools/film.sh --still 13.2 f.png
set -e
cd "$(dirname "$0")/.."
mkdir -p build/film-assets
# The desktop shot's backdrop: a stock macOS wallpaper, converted once from this Mac's own copy.
[ -f build/film-assets/wallpaper.jpg ] || sips -s format jpeg -s formatOptions 90 -Z 2880 -m "/System/Library/ColorSync/Profiles/sRGB Profile.icc" \
  "/System/Library/Desktop Pictures/Sonoma.heic" --out build/film-assets/wallpaper.jpg >/dev/null
# The widget is built from its last commit (FILM_WIDGET_REV, default HEAD), not the working folder, so
# unfinished widget work (another session's, say) never ends up in a render. FILM_WIDGET_REV=worktree uses the folder.
REV="${FILM_WIDGET_REV:-HEAD}"
SRC=build/film-src; rm -rf "$SRC"; mkdir -p "$SRC"
for f in Shared/SessionStore.swift Widget/KeepWorkingWidget.swift Widget/ClawdMotion.swift; do
  if [[ "$REV" == worktree ]]; then cp "$f" "$SRC/"; else git show "$REV:$f" > "$SRC/$(basename $f)"; fi
done
swiftc -O -parse-as-library -D RENDER_HARNESS \
  "$SRC/SessionStore.swift" "$SRC/KeepWorkingWidget.swift" "$SRC/ClawdMotion.swift" Tools/Film.swift Tools/InstallFilm.swift \
  -o build/film
build/film "$@"
