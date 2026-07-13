#!/usr/bin/env zsh
# install.sh — install the Structure screensaver variants on this Mac.
#
# Why this exists: the .saver bundles are ad-hoc signed, not notarized. When you
# DOWNLOAD them (GitHub Releases, a browser, curl) macOS attaches a quarantine
# flag, and on modern macOS Gatekeeper then refuses to open them with
#   "Structure-<Mode>.saver Not Opened — Apple could not verify ... is free of
#    malware that may harm your Mac or compromise your privacy."
# The old "right-click → Open" bypass no longer works for screensavers on
# macOS 15+. Removing the quarantine flag does, and that is all this script does
# (plus copy the bundles into ~/Library/Screen Savers/ so you can pick them in
# System Settings).
#
# Usage:
#   ./install.sh                      # install every Structure-*.saver it finds
#   ./install.sh path/to/Foo.saver …  # install specific bundles
#
# It looks for bundles (in priority order): any passed as arguments, then in
# build/ (produced by ./build.sh), then next to this script (an unzipped
# release), then in ~/Downloads.
set -euo pipefail
cd "${0:A:h}"

DEST="$HOME/Library/Screen Savers"

# Gather the .saver bundles to install.
typeset -a savers
if (( $# )); then
    savers=("$@")
else
    for dir in build . "$HOME/Downloads"; do
        savers+=("$dir"/Structure-*.saver(N/))
    done
fi

if (( ! ${#savers} )); then
    print -u2 "No Structure-*.saver bundles found."
    print -u2 "Build them first with ./build.sh, or pass paths, e.g.:"
    print -u2 "  ./install.sh ~/Downloads/Structure-Ribbon.saver"
    exit 1
fi

mkdir -p "$DEST"
for saver in $savers; do
    if [[ ! -d "$saver" ]]; then
        print -u2 "Skipping '$saver': not a .saver bundle."
        continue
    fi
    name="${saver:t}"
    print "Installing $name"
    # Remove the download quarantine flag that triggers the Gatekeeper block.
    # xattr -dr is idempotent (exit 0 even when the flag is absent), so a
    # locally-built, never-quarantined bundle is handled the same way.
    xattr -dr com.apple.quarantine "$saver"
    rm -rf "$DEST/$name"
    cp -R "$saver" "$DEST/$name"
    # Strip again at the destination in case the copy carried metadata over.
    xattr -dr com.apple.quarantine "$DEST/$name"
done

print
print "Installed into: $DEST"
print "Open System Settings → Screen Saver and choose a 'Structure (…)' variant."
