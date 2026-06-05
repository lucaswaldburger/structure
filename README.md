# PDBStructure

A macOS screensaver that displays a random protein structure from the RCSB PDB
as an alpha-carbon backbone trace, colored by chain, slowly rotating.

Inspired by [bblonder/structure](https://github.com/bblonder/structure) — same
idea, modernized for current macOS (Swift, SceneKit/Metal, `URLSession`,
sandboxed cache under `~/Library/Application Support`).

## Build

You need `Resources/pdb_entry_type.txt` (the master list of all PDB IDs, ~5 MB).
Fetch it once:

```sh
curl -sSfL https://files.wwpdb.org/pub/pdb/derived_data/pdb_entry_type.txt \
    -o Resources/pdb_entry_type.txt
```

Then pick one of three build paths:

### A. XcodeGen → Xcode (recommended)

```sh
brew install xcodegen
xcodegen
open PDBStructure.xcodeproj
```

Build with **⌘B**, then in Finder right-click the `.saver` product
(under Products in the navigator → *Show in Finder*) and double-click it.
System Settings will offer to install it.

### B. Command-line, no Xcode project

```sh
./build.sh
open build/PDBStructure.saver
```

### C. Manual Xcode project

If you don't want XcodeGen, create the project by hand:

1. Xcode → File → New → Project → macOS → **Screen Saver**, name it
   `PDBStructure`, language Swift.
2. Replace the default `.swift` and `Info.plist` with the ones in this repo.
3. Add `pdb_entry_type.txt` to the target as a bundle resource (drag into
   the project navigator, ensure target membership is checked).
4. Build.

## Install

The first time you load an ad-hoc-signed screensaver, macOS may refuse with
"can't be opened because it is from an unidentified developer." Right-click
the `.saver` and choose **Open** to bypass once.

System Settings → Screen Saver → select **PDBStructure** from the list.

The cache of downloaded `.pdb` files lives at
`~/Library/Application Support/PDBStructure/cache/` (capped at 100 files,
oldest-accessed evicted first).

## How it works

- `PDBStructureView` (subclass of `ScreenSaverView`) hosts an `SCNView`
  and ticks at 30 fps. Every 30 s it asks `PDBFetcher` for a new structure
  and crossfades it into the scene.
- `PDBFetcher` picks a random 4-letter ID from `pdb_entry_type.txt`
  (filtered to `prot` and `prot-nuc` entries) and fetches
  `https://files.rcsb.org/download/<ID>.pdb` via `URLSession`. Results are
  cached on disk.
- `PDBParser` reads `ATOM` records, keeps `CA` atoms from the first MODEL,
  and groups them by chain.
- `MoleculeScene` builds one `SCNNode` per chain — small spheres at each
  CA plus thin cylinders along consecutive CA-CA bonds — colored from an
  8-entry palette and auto-rotating about Y.

## Things to extend

- **Render mode toggle**: add ball-and-stick or ribbon options through a
  configure sheet (`hasConfigureSheet` / `configureSheet`).
- **Annotations**: the reference repo pulled HEADER/TITLE/SOURCE lines into
  on-screen text. `PDBParser` could surface those for the title overlay.
- **Distance-of-fit**: the camera is fixed at `z = 260`; large viral capsids
  (e.g. 1cd3) still fit, but tiny peptides look lost. Auto-zoom based on
  `parsed.radius` would help.
