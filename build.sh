#!/usr/bin/env zsh
# Builds the Structure screensaver variants without Xcode using swiftc directly.
# One .saver per render mode (the legacy "Options..." sheet is gone on modern
# macOS, so each mode ships as its own installable saver).
# Output: build/Structure-<Mode>.saver  +  build/Structure Settings.app
set -euo pipefail
cd "${0:A:h}"

NAME=Structure
BUILD=build

rm -rf "$BUILD"
mkdir -p "$BUILD"

if [[ ! -f Resources/pdb_entry_type.txt ]]; then
    echo "Resources/pdb_entry_type.txt is missing. Fetch it first:"
    echo "  curl -sSfL https://files.wwpdb.org/pub/pdb/derived_data/pdb_entry_type.txt \\"
    echo "    -o Resources/pdb_entry_type.txt"
    exit 1
fi

build_saver() {
    local variant="$1"          # subfolder under Variants/ (e.g. Backbone)
    local saver="$BUILD/$NAME-$variant.saver"
    local contents="$saver/Contents"
    mkdir -p "$contents/MacOS" "$contents/Resources"

    xcrun -sdk macosx swiftc \
        -O \
        -target arm64-apple-macos13 \
        -module-name "$NAME" \
        -emit-library \
        -Xlinker -bundle \
        -framework AppKit \
        -framework ScreenSaver \
        -framework SceneKit \
        -o "$contents/MacOS/$NAME" \
        Sources/*.swift "Variants/$variant/PrincipalView.swift"

    cp "Variants/$variant/Info.plist" "$contents/Info.plist"
    cp Resources/pdb_entry_type.txt "$contents/Resources/"
    if [[ -d Resources/PDB ]]; then
        mkdir -p "$contents/Resources/PDB"
        cp Resources/PDB/*.pdb "$contents/Resources/PDB/" 2>/dev/null || true
    fi

    # Ad-hoc sign so Gatekeeper will load the bundle from System Settings.
    codesign --force --sign - --timestamp=none "$saver"
    echo "Built: $saver"
}

for variant in Backbone BallStick Spacefill Ribbon Cartoon; do
    build_saver "$variant"
done

# Standalone settings app. Controls the settings shared by every variant
# (display period, background color, cache, internet, info overlay).
SETTINGS_APP="$BUILD/Structure Settings.app"
SETTINGS_CONTENTS="$SETTINGS_APP/Contents"
mkdir -p "$SETTINGS_CONTENTS/MacOS"

xcrun -sdk macosx swiftc \
    -O \
    -target arm64-apple-macos13 \
    -framework AppKit \
    -framework ScreenSaver \
    -o "$SETTINGS_CONTENTS/MacOS/StructureSettings" \
    SettingsApp/main.swift

cp SettingsApp/Info.plist "$SETTINGS_CONTENTS/"
codesign --force --sign - --timestamp=none "$SETTINGS_APP"
echo "Built: $SETTINGS_APP"

echo
echo "Install a saver: double-click it in Finder, or e.g.:"
echo "  open '$BUILD/$NAME-Cartoon.saver'"
echo "Change shared settings: open '$SETTINGS_APP'"
