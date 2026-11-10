#!/bin/zsh
# Builds and runs the film renderer (Tools/Film.swift): the showcase video, drawn frame by frame from the
# widget's own views. Output is not kept in git.
#   Tools/film.sh out.mp4            Tools/film.sh out.mp4 2 20            Tools/film.sh --still 13.2 f.png
set -e
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -parse-as-library -D RENDER_HARNESS \
  Shared/SessionStore.swift Widget/KeepWorkingWidget.swift Widget/ClawdMotion.swift Tools/Film.swift \
  -o build/film
build/film "$@"
