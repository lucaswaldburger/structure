import AppKit
import SceneKit
import simd

/// Ribbon: Catmull-Rom spline through CA atoms, sampled at sub-residue resolution and
/// drawn as short cylinders. Helix and sheet spans (from HELIX/SHEET records) get
/// thicker, color-modulated segments.
enum RibbonRenderer: Renderer {

    private static let subSamples = 16

    static func build(from s: ParsedStructure) -> SCNNode {
        let root = SCNNode()
        let scale: Float = RendererOptions.viewspaceRadius / s.radius

        for (chainIdx, chain) in s.chains.enumerated() {
            let ca = s.caAtoms(chain: chain.id)
            guard ca.count >= 2 else { continue }
            let points = ca.map { ($0.position - s.center) * scale }
            let residueIds = ca.map { $0.resSeq }
            root.addChildNode(buildChainTube(
                points: points,
                residueIds: residueIds,
                chain: chain.id,
                secondary: s.secondary,
                chainColor: ChainPalette.color(forChainIndex: chainIdx)
            ))
        }
        return GeomKit.spinning(root)
    }

    private static func buildChainTube(
        points: [SIMD3<Float>],
        residueIds: [Int],
        chain: Character,
        secondary: [SSSpan],
        chainColor: NSColor
    ) -> SCNNode {
        let parent = SCNNode()

        // Three shared cylinder geometries — one per SS state. Each uses node.scale
        // for per-segment radius/length so geometry can be shared across hundreds of
        // segments per chain.
        let helixGeom = unitCyl(color: blend(chainColor, with: NSColor.systemRed,    t: 0.45), radial: 18)
        let sheetGeom = unitCyl(color: blend(chainColor, with: NSColor.systemYellow, t: 0.45), radial: 18)
        let coilGeom  = unitCyl(color: chainColor, radial: 14)

        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]

            // Skip giant chain breaks (missing residues, alt locs, gaps).
            if simd_distance(p1, p2) > 12 { continue }

            let ssAt0 = ssKind(chain: chain, resSeq: residueIds[i],   in: secondary)
            let ssAt1 = ssKind(chain: chain, resSeq: residueIds[i+1], in: secondary)

            for sub in 0..<subSamples {
                let t0 = Float(sub) / Float(subSamples)
                let t1 = Float(sub + 1) / Float(subSamples)
                let q0 = catmullRom(p0, p1, p2, p3, t: t0)
                let q1 = catmullRom(p0, p1, p2, p3, t: t1)
                let ss = (sub < subSamples / 2) ? ssAt0 : ssAt1
                let radius: Float = (ss == nil) ? 0.9 : 1.6
                let geom: SCNCylinder
                switch ss {
                case .helix: geom = helixGeom
                case .sheet: geom = sheetGeom
                case .none:  geom = coilGeom
                }
                parent.addChildNode(cylinderNode(from: q0, to: q1, radius: radius, geometry: geom))
            }
        }
        return parent
    }

    private static func unitCyl(color: NSColor, radial: Int) -> SCNCylinder {
        let c = SCNCylinder(radius: 1, height: 1)
        c.radialSegmentCount = radial
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.specular.contents = NSColor(white: 0.5, alpha: 1)
        mat.shininess = 0.4
        mat.lightingModel = .blinn
        c.materials = [mat]
        return c
    }

    private static func catmullRom(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>, _ p2: SIMD3<Float>, _ p3: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        let t2 = t * t
        let t3 = t2 * t
        let a: SIMD3<Float> = 2 * p1
        let b: SIMD3<Float> = (p2 - p0) * t
        let c: SIMD3<Float> = (2*p0 - 5*p1 + 4*p2 - p3) * t2
        let d: SIMD3<Float> = (3*p1 - 3*p2 + p3 - p0) * t3
        return 0.5 * (a + b + c + d)
    }

    private static func ssKind(chain: Character, resSeq: Int, in spans: [SSSpan]) -> SSSpan.Kind? {
        for s in spans where s.chain == chain && resSeq >= s.startResSeq && resSeq <= s.endResSeq {
            return s.kind
        }
        return nil
    }

    private static func blend(_ a: NSColor, with b: NSColor, t: CGFloat) -> NSColor {
        guard let ca = a.usingColorSpace(.sRGB), let cb = b.usingColorSpace(.sRGB) else { return a }
        return NSColor(
            red:   ca.redComponent   * (1-t) + cb.redComponent   * t,
            green: ca.greenComponent * (1-t) + cb.greenComponent * t,
            blue:  ca.blueComponent  * (1-t) + cb.blueComponent  * t,
            alpha: 1
        )
    }
}
