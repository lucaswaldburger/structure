# Structure

A macOS screensaver that displays a random protein structure from the RCSB PDB,
rendered with SceneKit (Metal) and colored by chain.

Modern Swift re-implementation of [bblonder/structure](https://github.com/bblonder/structure)
— same idea, same name, updated for current macOS (Swift, SceneKit, `URLSession`,
sandboxed cache under `~/Library/Application Support`).

## Render modes

| Mode | Description |
|---|---|
| Ribbon (default) | Catmull-Rom spline through CAs, helix and sheet thickening from HELIX/SHEET records |
| Backbone trace | CA spheres + CA–CA cylinders, colored by chain |
| Ball and stick | All atoms (CPK colors) with distance-inferred bonds |
| Spacefill (CPK) | Van der Waals spheres in CPK colors |

Selectable from the configure sheet in System Settings.

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
open Structure.xcodeproj
```

Build with **⌘B**, then in Finder right-click the `.saver` product
(under Products in the navigator → *Show in Finder*) and double-click it.
System Settings will offer to install it.

### B. Command-line, no Xcode project

```sh
./build.sh
open build/Structure.saver
```

### C. Manual Xcode project

If you don't want XcodeGen, create the project by hand:

1. Xcode → File → New → Project → macOS → **Screen Saver**, name it
   `Structure`, language Swift.
2. Replace the default `.swift` and `Info.plist` with the ones in this repo.
3. Add `pdb_entry_type.txt` and the `PDB/` folder to the target as bundle
   resources (drag into the project navigator, ensure target membership is
   checked).
4. Build.

## Install

The first time you load an ad-hoc-signed screensaver, macOS may refuse with
"can't be opened because it is from an unidentified developer." Right-click
the `.saver` and choose **Open** to bypass once.

System Settings → Screen Saver → select **Structure** from the list.

The cache of downloaded `.pdb` files lives at
`~/Library/Application Support/Structure/cache/` (capped by the configure
sheet's *Cache size* setting, oldest-accessed evicted first). Under the
sandboxed `legacyScreenSaver` host, this maps to
`~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Application Support/Structure/cache/`.

## How it works

- `StructureView` (subclass of `ScreenSaverView`) hosts an `SCNView` and ticks
  at 30 fps. Every `DisplayPeriod` seconds it asks `PDBFetcher` for a new
  structure and crossfades it into the scene.
- `PDBFetcher` picks a random 4-letter ID from `pdb_entry_type.txt` (filtered
  to `prot` / `prot-nuc` entries) and fetches
  `https://files.rcsb.org/download/<ID>.pdb` via `URLSession`. Falls back to
  a bundled offline set (1mbn, 2dhb, 1bna, 1gfl, 1ytb, 2lyz, 1igt, 4ins) on
  any network failure or when *Only use local files* is enabled.
- `PDBParser` reads `ATOM`/`HETATM` records, header metadata
  (HEADER / TITLE / COMPND / SOURCE / EXPDTA / REMARK 2 / AUTHOR), and
  secondary structure (`HELIX` / `SHEET`) from the first MODEL.
- Renderer modules (`BackboneRenderer`, `BallStickRenderer`, `SpacefillRenderer`,
  `RibbonRenderer`) each build an `SCNNode` tree from a parsed structure.
- `InfoPanel` (an attributed `NSTextField`) overlays PDB ID + classification,
  title, authors, method + resolution, source organism, and a per-chain list
  with chain letters colored to match the rendering.

## Defaults

Stored via `ScreenSaverDefaults(forModuleWithName: "Structure")`:

- `DisplayPeriod` (Int, default 30) — seconds between structure swaps
- `CacheSize` (Int, default 100) — max on-disk cached PDB files
- `RenderMode` (Int 0-3, default 0) — see render-modes table above
- `EnableInternetAccess` (Bool, default true)
- `OnlyLoadLocalFiles` (Bool, default false)
- `FullTextualAnnotation` (Bool, default true)
