import AppKit
import SceneKit
import simd

/// Ribbon: PyMOL-style cartoon. Helices and sheets render as flat extruded ribbons,
/// β-sheets get a C-terminal arrowhead (the last residue tapers from a wide base to
/// a point), and loops render as a thin tube. The cross-section is swept along a
/// Catmull-Rom spline through CA atoms using a parallel-transport frame, which keeps
/// the ribbon plane from flipping at curve inflections.
enum RibbonRenderer: Renderer {

    private static let subSamples = 10

    // Cross-section half-dimensions (width along ribbon plane × thickness perpendicular).
    private static let helixHW: Float     = 2.2
    private static let helixHT: Float     = 0.35
    private static let sheetHW: Float     = 1.9
    private static let sheetHT: Float     = 0.35
    private static let arrowBaseHW: Float = 3.4
    private static let coilHW: Float      = 0.55
    private static let coilHT: Float      = 0.55

    static func build(from s: ParsedStructure) -> SCNNode {
        let root = SCNNode()
        let scale: Float = RendererOptions.viewspaceRadius / s.radius

        for (chainIdx, chain) in s.chains.enumerated() {
            let ca = s.caAtoms(chain: chain.id)
            guard ca.count >= 2 else { continue }
            let positions = ca.map { ($0.position - s.center) * scale }
            let resIds = ca.map { $0.resSeq }
            let chainColor = ChainPalette.color(forChainIndex: chainIdx)

            for segment in contiguousSegments(positions: positions) {
                if let node = buildRibbonSegment(
                    positions:  Array(positions[segment]),
                    resIds:     Array(resIds[segment]),
                    chain:      chain.id,
                    secondary:  s.secondary,
                    chainColor: chainColor
                ) {
                    root.addChildNode(node)
                }
            }
        }
        return GeomKit.spinning(root)
    }

    /// Split the CA list at large gaps (missing residues, alt locs) so the spline
    /// doesn't jump across the molecule.
    private static func contiguousSegments(positions: [SIMD3<Float>]) -> [Range<Int>] {
        var out: [Range<Int>] = []
        var start = 0
        for i in 1..<positions.count {
            if simd_distance(positions[i - 1], positions[i]) > 12 {
                if i - start >= 2 { out.append(start..<i) }
                start = i
            }
        }
        if positions.count - start >= 2 { out.append(start..<positions.count) }
        return out
    }

    private struct Sample {
        var p: SIMD3<Float>   // position along the spline
        var residue: Int      // index into resSS/resIds
        var t: Float          // 0..1 within this residue's spline interval
    }

    private static func buildRibbonSegment(
        positions:  [SIMD3<Float>],
        resIds:     [Int],
        chain:      Character,
        secondary:  [SSSpan],
        chainColor: NSColor
    ) -> SCNNode? {
        guard positions.count >= 2 else { return nil }

        // Per-residue SS classification.
        let resSS: [SSSpan.Kind?] = (0..<positions.count).map {
            ssKind(chain: chain, resSeq: resIds[$0], in: secondary)
        }
        // Last residue of each contiguous sheet run — these get the arrow taper.
        var sheetTip: Set<Int> = []
        for i in 0..<positions.count {
            if resSS[i] == .sheet && (i + 1 == positions.count || resSS[i + 1] != .sheet) {
                sheetTip.insert(i)
            }
        }

        // Sample the spline. For each interval [i, i+1) generate `subSamples` points;
        // append a final closing sample at CA[last] (and, if the chain ends mid-arrow,
        // an extra tip sample so the arrowhead actually comes to a point).
        var samples: [Sample] = []
        samples.reserveCapacity((positions.count - 1) * subSamples + 2)
        for i in 0..<(positions.count - 1) {
            let p0 = positions[max(i - 1, 0)]
            let p1 = positions[i]
            let p2 = positions[i + 1]
            let p3 = positions[min(i + 2, positions.count - 1)]
            for sub in 0..<subSamples {
                let t = Float(sub) / Float(subSamples)
                samples.append(Sample(p: catmullRom(p0, p1, p2, p3, t: t), residue: i, t: t))
            }
        }
        // Closing sample at CA[last]. If the last residue is a sheet tip we want
        // (a) the arrow base at this position and (b) a true point past it.
        let last = positions.count - 1
        samples.append(Sample(p: positions[last], residue: last, t: 0))
        if sheetTip.contains(last) {
            // Extrapolate slightly along the trailing tangent for the point.
            let tangent = normalize(positions[last] - positions[last - 1])
            let tipP = positions[last] + tangent * 1.6
            samples.append(Sample(p: tipP, residue: last, t: 1))
        }

        // Tangents via central differences.
        var tangents = [SIMD3<Float>](repeating: .zero, count: samples.count)
        for i in 0..<samples.count {
            let prev = samples[max(i - 1, 0)].p
            let next = samples[min(i + 1, samples.count - 1)].p
            let d = next - prev
            tangents[i] = simd_length(d) > 1e-6 ? normalize(d) : SIMD3<Float>(0, 0, 1)
        }

        // Parallel-transport frame: an initial normal perpendicular to t0, then
        // rotate it incrementally to track the curve without flipping.
        var normals  = [SIMD3<Float>](repeating: .zero, count: samples.count)
        var binormals = [SIMD3<Float>](repeating: .zero, count: samples.count)
        let up0: SIMD3<Float> = abs(tangents[0].y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        var n = normalize(cross(up0, tangents[0]))
        if !n.x.isFinite || simd_length(n) < 1e-6 { n = SIMD3<Float>(1, 0, 0) }
        normals[0] = n
        binormals[0] = normalize(cross(tangents[0], n))
        for i in 1..<samples.count {
            let prevT = tangents[i - 1]
            let currT = tangents[i]
            let axis = cross(prevT, currT)
            let len = simd_length(axis)
            var nv = normals[i - 1]
            if len > 1e-6 {
                let angle = atan2(len, dot(prevT, currT))
                let q = simd_quatf(angle: angle, axis: axis / len)
                nv = q.act(nv)
            }
            // Re-orthogonalize against the new tangent.
            nv = nv - dot(nv, currT) * currT
            let nLen = simd_length(nv)
            nv = nLen > 1e-6 ? nv / nLen : normals[i - 1]
            normals[i] = nv
            binormals[i] = normalize(cross(currT, nv))
        }

        // Per-sample cross-section dimensions.
        func dims(for s: Sample) -> (hw: Float, ht: Float) {
            switch resSS[s.residue] {
            case .helix:
                return (helixHW, helixHT)
            case .sheet:
                // Arrow tip residue tapers from the wide base (at t=0) to a point.
                // The width jump at the boundary between the previous body residue
                // and the tip residue produces the classic flanged shoulders.
                if sheetTip.contains(s.residue) {
                    return (arrowBaseHW * (1 - s.t), sheetHT)
                }
                return (sheetHW, sheetHT)
            case .none:
                return (coilHW, coilHT)
            }
        }

        // SS-tinted colors per chain.
        let helixCol = blend(chainColor, with: NSColor.systemRed,    t: 0.55)
        let sheetCol = blend(chainColor, with: NSColor.systemYellow, t: 0.55)
        let coilCol  = chainColor
        func colorFor(_ s: Sample) -> SIMD4<Float> {
            switch resSS[s.residue] {
            case .helix: return nsColorVec(helixCol)
            case .sheet: return nsColorVec(sheetCol)
            case .none:  return nsColorVec(coilCol)
            }
        }

        // Extrude: 4 vertices per cross-section, indexed as a rectangular tube.
        var vertices = [SCNVector3]()
        var vNormals = [SCNVector3]()
        var vColors  = [SIMD4<Float>]()
        vertices.reserveCapacity(samples.count * 4)
        vNormals.reserveCapacity(samples.count * 4)
        vColors.reserveCapacity(samples.count * 4)
        for i in 0..<samples.count {
            let s = samples[i]
            let nv = normals[i]
            let bv = binormals[i]
            let (hw, ht) = dims(for: s)
            // Corners: v0 +n+b, v1 -n+b, v2 -n-b, v3 +n-b (CCW seen from +tangent).
            let v0 = s.p + nv * hw + bv * ht
            let v1 = s.p - nv * hw + bv * ht
            let v2 = s.p - nv * hw - bv * ht
            let v3 = s.p + nv * hw - bv * ht
            vertices.append(SCNVector3(v0))
            vertices.append(SCNVector3(v1))
            vertices.append(SCNVector3(v2))
            vertices.append(SCNVector3(v3))
            // Smooth-shaded outward normals (diagonal of the cross-section).
            vNormals.append(SCNVector3(normalize( nv + bv)))
            vNormals.append(SCNVector3(normalize(-nv + bv)))
            vNormals.append(SCNVector3(normalize(-nv - bv)))
            vNormals.append(SCNVector3(normalize( nv - bv)))
            let col = colorFor(s)
            for _ in 0..<4 { vColors.append(col) }
        }

        // Side faces (CCW outward): top (0-1), left (1-2), bottom (2-3), right (3-0).
        var indices: [Int32] = []
        indices.reserveCapacity((samples.count - 1) * 24 + 12)
        for i in 0..<(samples.count - 1) {
            let a = Int32(i * 4)
            let b = Int32((i + 1) * 4)
            indices.append(contentsOf: [a + 0, a + 1, b + 1,  a + 0, b + 1, b + 0])
            indices.append(contentsOf: [a + 1, a + 2, b + 2,  a + 1, b + 2, b + 1])
            indices.append(contentsOf: [a + 2, a + 3, b + 3,  a + 2, b + 3, b + 2])
            indices.append(contentsOf: [a + 3, a + 0, b + 0,  a + 3, b + 0, b + 3])
        }
        // Start cap (CCW seen from -tangent) and end cap (CCW seen from +tangent).
        let endBase = Int32((samples.count - 1) * 4)
        indices.append(contentsOf: [Int32(1), Int32(0), Int32(3),  Int32(1), Int32(3), Int32(2)])
        indices.append(contentsOf: [endBase + 0, endBase + 1, endBase + 2,
                                    endBase + 0, endBase + 2, endBase + 3])

        let vSrc = SCNGeometrySource(vertices: vertices)
        let nSrc = SCNGeometrySource(normals: vNormals)
        let cSrc = colorSource(from: vColors)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geom = SCNGeometry(sources: [vSrc, nSrc, cSrc], elements: [element])

        let mat = SCNMaterial()
        mat.lightingModel = .blinn
        mat.diffuse.contents  = NSColor.white     // vertex colors modulate this
        mat.specular.contents = NSColor(white: 0.45, alpha: 1)
        mat.shininess = 0.4
        mat.isDoubleSided = false
        geom.materials = [mat]

        return SCNNode(geometry: geom)
    }

    private static func colorSource(from colors: [SIMD4<Float>]) -> SCNGeometrySource {
        let data = colors.withUnsafeBytes { Data($0) }
        return SCNGeometrySource(
            data: data,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
    }

    private static func nsColorVec(_ c: NSColor) -> SIMD4<Float> {
        guard let s = c.usingColorSpace(.sRGB) else { return SIMD4<Float>(1, 1, 1, 1) }
        return SIMD4<Float>(Float(s.redComponent), Float(s.greenComponent), Float(s.blueComponent), 1)
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
            red:   ca.redComponent   * (1 - t) + cb.redComponent   * t,
            green: ca.greenComponent * (1 - t) + cb.greenComponent * t,
            blue:  ca.blueComponent  * (1 - t) + cb.blueComponent  * t,
            alpha: 1
        )
    }
}
