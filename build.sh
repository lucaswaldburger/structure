#!/usr/bin/env zsh
# Builds Structure.saver without Xcode using swiftc directly.
# Output: build/Structure.saver
set -euo pipefail
cd "${0:A:h}"

NAME=Structure
BUILD=build
SAVER="$BUILD/$NAME.saver"
CONTENTS="$SAVER/Contents"

rm -rf "$BUILD"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

if [[ ! -f Resources/pdb_entry_type.txt ]]; then
    echo "Resources/pdb_entry_type.txt is missing. Fetch it first:"
    echo "  curl -sSfL https://files.wwpdb.org/pub/pdb/derived_data/pdb_entry_type.txt \\"
    echo "    -o Resources/pdb_entry_type.txt"
    exit 1
fi

xcrun -sdk macosx swiftc \
    -O \
    -target arm64-apple-macos13 \
    -module-name "$NAME" \
    -emit-library \
    -Xlinker -bundle \
    -framework AppKit \
    -framework ScreenSaver \
    -framework SceneKit \
    -o "$CONTENTS/MacOS/$NAME" \
    Sources/*.swift

cp Info.plist "$CONTENTS/"
cp Resources/pdb_entry_type.txt "$CONTENTS/Resources/"
if [[ -d Resources/PDB ]]; then
    mkdir -p "$CONTENTS/Resources/PDB"
    cp Resources/PDB/*.pdb "$CONTENTS/Resources/PDB/" 2>/dev/null || true
fi

# Ad-hoc sign so Gatekeeper will load the bundle from System Settings.
codesign --force --sign - --timestamp=none "$SAVER"

echo
echo "Built: $SAVER"
echo "Install: double-click the .saver in Finder, or:"
echo "  open '$SAVER'"
