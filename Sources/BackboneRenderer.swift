import AppKit
import SceneKit
import simd

enum BackboneRenderer: Renderer {

    static func build(from s: ParsedStructure) -> SCNNode {
        let root = SCNNode()
        let scale: Float = RendererOptions.viewspaceRadius / s.radius
        for (i, chain) in s.chains.enumerated() {
            let color = ChainPalette.color(forChainIndex: i)
            let positions = s.caAtoms(chain: chain.id).map { $0.position }
            root.addChildNode(buildChain(positions: positions, color: color, center: s.center, scale: scale))
        }
        return GeomKit.spinning(root)
    }

    private static func buildChain(positions: [SIMD3<Float>], color: NSColor, center: SIMD3<Float>, scale: Float) -> SCNNode {
        let parent = SCNNode()
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.specular.contents = NSColor(white: 0.5, alpha: 1)
        mat.shininess = 0.4
        mat.lightingModel = .blinn

        // Shared geometry across all atoms/bonds of this chain.
        let sphere = SCNSphere(radius: 1.5)
        sphere.segmentCount = 32
        sphere.materials = [mat]
        let unitCyl = SCNCylinder(radius: 1, height: 1)
        unitCyl.radialSegmentCount = 16
        unitCyl.materials = [mat]

        var prev: SIMD3<Float>?
        for raw in positions {
            let p = (raw - center) * scale
            let n = SCNNode(geometry: sphere)
            n.position = SCNVector3(p.x, p.y, p.z)
            parent.addChildNode(n)
            if let q = prev, simd_distance(p, q) < 8 * scale {
                parent.addChildNode(cylinderNode(from: q, to: p, radius: 0.7, geometry: unitCyl))
            }
            prev = p
        }
        return parent
    }
}

/// Shared cylinder-node builder. Scales the unit cylinder geometry along (radius,
/// length, radius) and rotates its +Y axis to align with vector (b - a). Mutates
/// node only — the geometry is shared across many nodes.
func cylinderNode(from a: SIMD3<Float>, to b: SIMD3<Float>, radius: Float, geometry: SCNCylinder) -> SCNNode {
    let v = b - a
    let len = simd_length(v)
    let node = SCNNode(geometry: geometry)
    node.scale = SCNVector3(CGFloat(radius), CGFloat(len), CGFloat(radius))
    let mid = (a + b) / 2
    node.position = SCNVector3(mid.x, mid.y, mid.z)
    let y = SIMD3<Float>(0, 1, 0)
    let dir = simd_normalize(v)
    let d = simd_dot(y, dir)
    if d > 0.99999 {
        // already aligned
    } else if d < -0.99999 {
        node.eulerAngles = SCNVector3(CGFloat.pi, 0, 0)
    } else {
        let axis = simd_normalize(simd_cross(y, dir))
        let angle = CGFloat(acos(d))
        node.rotation = SCNVector4(CGFloat(axis.x), CGFloat(axis.y), CGFloat(axis.z), angle)
    }
    return node
}
