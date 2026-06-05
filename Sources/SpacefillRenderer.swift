import AppKit
import SceneKit
import simd

enum SpacefillRenderer: Renderer {

    static func build(from s: ParsedStructure) -> SCNNode {
        let root = SCNNode()
        let scale: Float = RendererOptions.viewspaceRadius / s.radius
        let atoms = s.atoms.filter { $0.resName != "HOH" && $0.element != "H" }

        // Per-element sphere with the right Van der Waals radius and CPK color.
        var spheres: [String: SCNGeometry] = [:]
        func sphere(for element: String) -> SCNGeometry {
            if let g = spheres[element] { return g }
            let g = SCNSphere(radius: CGFloat(CPKPalette.radius(forElement: element)))
            g.segmentCount = 14
            let mat = SCNMaterial()
            mat.diffuse.contents = CPKPalette.color(forElement: element)
            mat.specular.contents = NSColor(white: 0.5, alpha: 1)
            mat.shininess = 0.3
            mat.lightingModel = .blinn
            g.materials = [mat]
            spheres[element] = g
            return g
        }

        for atom in atoms {
            let p = (atom.position - s.center) * scale
            let n = SCNNode(geometry: sphere(for: atom.element))
            // Geometry radius is in molecule-space Å; node scale converts to viewspace.
            n.scale = SCNVector3(CGFloat(scale), CGFloat(scale), CGFloat(scale))
            n.position = SCNVector3(p.x, p.y, p.z)
            root.addChildNode(n)
        }

        return GeomKit.spinning(root)
    }
}
