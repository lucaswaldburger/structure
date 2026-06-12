#!/usr/bin/env zsh
# Renders README media (still PNGs + animated GIF) into media/ using the
# screensaver's real renderers. Run from the repo root: ./Tools/make-media.sh
set -euo pipefail
cd "${0:A:h}/.."

BIN=$(mktemp -t render-media)

xcrun -sdk macosx swiftc \
    -O \
    -target arm64-apple-macos13 \
    -framework AppKit \
    -framework SceneKit \
    -framework ImageIO \
    -o "$BIN" \
    Tools/main.swift \
    Sources/Model.swift \
    Sources/PDBParser.swift \
    Sources/Palettes.swift \
    Sources/Renderer.swift \
    Sources/BackboneRenderer.swift \
    Sources/BallStickRenderer.swift \
    Sources/SpacefillRenderer.swift \
    Sources/RibbonRenderer.swift \
    Sources/CartoonRenderer.swift

"$BIN"
rm -f "$BIN"
