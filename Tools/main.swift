// Offscreen renderer that produces README media (still PNGs + an animated GIF)
// using the screensaver's real SceneKit renderers and bundled PDB files.
//
// Build/run via Tools/make-media.sh (compiles this together with the renderer
// sources, with no ScreenSaver dependency).

import AppKit
import SceneKit
import ImageIO
import UniformTypeIdentifiers
import simd

// MARK: - Scene setup (mirrors StructureView)

let device = MTLCreateSystemDefaultDevice()!
let sceneRenderer = SCNRenderer(device: device, options: nil)

func makeScene(_ parsed: ParsedStructure, mode: RenderMode, tiltX: CGFloat = 0) -> (SCNScene, SCNNode) {
    let scene = SCNScene()
    scene.background.contents = NSColor.black

    let cameraNode = SCNNode()
    let cam = SCNCamera()
    cam.zNear = 0.1
    cam.zFar = 5000
    cameraNode.camera = cam
    // Slightly tighter framing than the live saver so the molecule fills these
    // README thumbnails instead of floating in a large black margin.
    cameraNode.position = SCNVector3(0, 0, CGFloat(RendererOptions.cameraDistance) * 0.62)
    scene.rootNode.addChildNode(cameraNode)

    let key = SCNNode()
    key.light = SCNLight()
    key.light!.type = .omni
    key.light!.intensity = 1100
    key.position = SCNVector3(120, 140, 220)
    scene.rootNode.addChildNode(key)

    let ambient = SCNNode()
    ambient.light = SCNLight()
    ambient.light!.type = .ambient
    ambient.light!.color = NSColor(white: 0.35, alpha: 1)
    scene.rootNode.addChildNode(ambient)

    // The molecule spins about its own Y; an optional X tilt on a wrapper lets a
    // still view a structure (e.g. a DNA helix) side-on instead of end-on.
    let tilt = SCNNode()
    tilt.eulerAngles = SCNVector3(tiltX, 0, 0)
    tilt.addChildNode(mode.renderer.build(from: parsed))
    scene.rootNode.addChildNode(tilt)
    return (scene, cameraNode)
}

func render(_ scene: SCNScene, pov: SCNNode, size: CGSize, time: TimeInterval) -> NSImage {
    sceneRenderer.scene = scene
    sceneRenderer.pointOfView = pov
    return sceneRenderer.snapshot(atTime: time, with: size, antialiasingMode: .multisampling4X)
}

// MARK: - File output

func load(_ id: String) -> ParsedStructure {
    let url = URL(fileURLWithPath: "Resources/PDB/\(id).pdb")
    let text = try! String(contentsOf: url, encoding: .utf8)
    return PDBParser.parse(text, id: id)
}

func savePNG(_ image: NSImage, to url: URL) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed for \(url.lastPathComponent)")
    }
    try! data.write(to: url)
    print("wrote \(url.path)")
}

func saveGIF(_ frames: [NSImage], to url: URL, delay: Double) {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.gif.identifier as CFString, frames.count, nil
    ) else { fatalError("GIF destination failed") }

    CGImageDestinationSetProperties(dest, [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
    ] as CFDictionary)

    let frameProps = [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]
    ] as CFDictionary

    for img in frames {
        guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
        CGImageDestinationAddImage(dest, cg, frameProps)
    }
    guard CGImageDestinationFinalize(dest) else { fatalError("GIF finalize failed") }
    print("wrote \(url.path) (\(frames.count) frames)")
}

// MARK: - Drive

let outDir = URL(fileURLWithPath: "media")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// One still per render mode, each on a structure that shows the mode off well.
let stillSize = CGSize(width: 1200, height: 760)
struct Still { let id: String; let mode: RenderMode; let name: String; let time: TimeInterval; let tiltX: CGFloat }
let stills = [
    Still(id: "2dhb", mode: .backbone,     name: "backbone",  time: 2.0, tiltX: 0),
    Still(id: "1bna", mode: .ballAndStick, name: "ballstick", time: 0.0, tiltX: .pi / 2),
    Still(id: "1mbn", mode: .spacefill,    name: "spacefill", time: 1.0, tiltX: 0),
    Still(id: "1gfl", mode: .ribbon,       name: "ribbon",    time: 4.0, tiltX: 0),
    Still(id: "1gfl", mode: .cartoon,      name: "cartoon",   time: 4.0, tiltX: 0),
]
for s in stills {
    let (scene, pov) = makeScene(load(s.id), mode: s.mode, tiltX: s.tiltX)
    let img = render(scene, pov: pov, size: stillSize, time: s.time)
    savePNG(img, to: outDir.appendingPathComponent("\(s.name)-\(s.id).png"))
}

// Animated GIF: one structure rotating continuously while cycling every render
// mode. Total spans exactly one revolution so the loop is seamless.
let gifSize = CGSize(width: 520, height: 340)
let gifID = "2dhb"
let modes: [RenderMode] = [.backbone, .ballAndStick, .spacefill, .ribbon, .cartoon]
let framesPerMode = 10
let totalFrames = modes.count * framesPerMode
let revolution = RendererOptions.spinDuration

let parsed = load(gifID)
let scenes = modes.map { makeScene(parsed, mode: $0) }

var frames: [NSImage] = []
for i in 0..<totalFrames {
    let (scene, pov) = scenes[i / framesPerMode]
    let t = revolution * Double(i) / Double(totalFrames)
    frames.append(render(scene, pov: pov, size: gifSize, time: t))
}
saveGIF(frames, to: outDir.appendingPathComponent("structure.gif"), delay: 0.07)
