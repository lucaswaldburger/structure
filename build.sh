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

# Universal build: one slice per arch, lipo'd together, so the savers run on
# both Apple Silicon and Intel Macs.
ARCHS=(arm64 x86_64)

# compile_universal <output-path> <swiftc args...>   (do not pass -target/-o)
# Compiles each arch to a temp slice and merges them into a universal binary.
compile_universal() {
    local out="$1"; shift
    local tmp; tmp="$(mktemp -d)"
    local -a slices=()
    local arch
    for arch in $ARCHS; do
        local slice="$tmp/${out:t}.$arch"
        xcrun -sdk macosx swiftc -target "$arch-apple-macos13" -O "$@" -o "$slice"
        slices+=("$slice")
    done
    lipo -create "${slices[@]}" -output "$out"
    rm -rf "$tmp"
}

build_saver() {
    local variant="$1"          # subfolder under Variants/ (e.g. Backbone)
    local saver="$BUILD/$NAME-$variant.saver"
    local contents="$saver/Contents"
    mkdir -p "$contents/MacOS" "$contents/Resources"

    compile_universal "$contents/MacOS/$NAME" \
        -module-name "$NAME" \
        -emit-library \
        -Xlinker -bundle \
        -framework AppKit \
        -framework ScreenSaver \
        -framework SceneKit \
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

compile_universal "$SETTINGS_CONTENTS/MacOS/StructureSettings" \
    -framework AppKit \
    -framework ScreenSaver \
    SettingsApp/main.swift

cp SettingsApp/Info.plist "$SETTINGS_CONTENTS/"
codesign --force --sign - --timestamp=none "$SETTINGS_APP"
echo "Built: $SETTINGS_APP"

echo
echo "Install every variant into ~/Library/Screen Savers/:"
echo "  ./install.sh"
echo "Or install one by hand: open '$BUILD/$NAME-Cartoon.saver'"
echo "Change shared settings: open '$SETTINGS_APP'"
echo
echo "Note: these bundles are ad-hoc signed, not notarized. Locally-built savers"
echo "load fine, but a DOWNLOADED copy is quarantined and Gatekeeper will block"
echo "it ('could not verify ... free of malware'). install.sh strips that flag;"
echo "by hand it's: xattr -dr com.apple.quarantine <path to .saver>"
