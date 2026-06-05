import AppKit
import SceneKit
import simd

enum BallStickRenderer: Renderer {

    static func build(from s: ParsedStructure) -> SCNNode {
        let root = SCNNode()
        let scale: Float = RendererOptions.viewspaceRadius / s.radius
        let atoms = s.atoms.filter { $0.resName != "HOH" && $0.element != "H" }
        let positions = atoms.map { ($0.position - s.center) * scale }

        // One shared sphere geometry per element (carbon-gray, oxygen-red, etc.).
        var spheres: [String: SCNGeometry] = [:]
        func sphere(for element: String) -> SCNGeometry {
            if let g = spheres[element] { return g }
            let g = SCNSphere(radius: 0.5)
            g.segmentCount = 24
            let mat = SCNMaterial()
            mat.diffuse.contents = CPKPalette.color(forElement: element)
            mat.specular.contents = NSColor(white: 0.6, alpha: 1)
            mat.shininess = 0.5
            mat.lightingModel = .blinn
            g.materials = [mat]
            spheres[element] = g
            return g
        }

        for (i, atom) in atoms.enumerated() {
            let n = SCNNode(geometry: sphere(for: atom.element))
            let p = positions[i]
            n.position = SCNVector3(p.x, p.y, p.z)
            root.addChildNode(n)
        }

        // Bonds: spatial-hash distance inference, single neutral cylinder geometry.
        let unitCyl = SCNCylinder(radius: 1, height: 1)
        unitCyl.radialSegmentCount = 12
        let bondMat = SCNMaterial()
        bondMat.diffuse.contents = NSColor(white: 0.6, alpha: 1)
        bondMat.lightingModel = .blinn
        unitCyl.materials = [bondMat]

        let cellSize = 1.9 * scale
        var grid: [SIMD3<Int>: [Int]] = [:]
        for (i, p) in positions.enumerated() {
            let c = SIMD3<Int>(
                Int((p.x / cellSize).rounded(.down)),
                Int((p.y / cellSize).rounded(.down)),
                Int((p.z / cellSize).rounded(.down))
            )
            grid[c, default: []].append(i)
        }
        let cutoff2 = (1.9 * scale) * (1.9 * scale)
        let minBond2 = (0.4 * scale) * (0.4 * scale)
        for (cell, idxs) in grid {
            for dx in -1...1 {
                for dy in -1...1 {
                    for dz in -1...1 {
                        let key = SIMD3<Int>(cell.x + dx, cell.y + dy, cell.z + dz)
                        guard let neigh = grid[key] else { continue }
                        for i in idxs {
                            for j in neigh where i < j {
                                let d2 = simd_distance_squared(positions[i], positions[j])
                                if d2 > minBond2 && d2 < cutoff2 {
                                    root.addChildNode(cylinderNode(
                                        from: positions[i], to: positions[j],
                                        radius: 0.18, geometry: unitCyl
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }

        return GeomKit.spinning(root)
    }
}
