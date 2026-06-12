import SceneKit

protocol Renderer {
    static func build(from structure: ParsedStructure) -> SCNNode
}

enum RenderMode: Int, CaseIterable {
    case backbone     = 0
    case ballAndStick = 1
    case spacefill    = 2
    case ribbon       = 3
    case cartoon      = 4

    var title: String {
        switch self {
        case .backbone:     return "Backbone trace"
        case .ballAndStick: return "Ball and stick"
        case .spacefill:    return "Spacefill (CPK)"
        case .ribbon:       return "Ribbon"
        case .cartoon:      return "Cartoon (tube)"
        }
    }

    var renderer: Renderer.Type {
        switch self {
        case .backbone:     return BackboneRenderer.self
        case .ballAndStick: return BallStickRenderer.self
        case .spacefill:    return SpacefillRenderer.self
        case .ribbon:       return RibbonRenderer.self
        case .cartoon:      return CartoonRenderer.self
        }
    }

    func next() -> RenderMode {
        let all = RenderMode.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }
}

enum RendererOptions {
    /// Camera position along +Z relative to molecule center.
    static let cameraDistance: Float = 260
    /// Molecules are uniformly scaled so the longest half-extent maps to this value.
    static let viewspaceRadius: Float = 110
    /// Spin period (seconds for one full Y revolution).
    static let spinDuration: TimeInterval = 24
}

enum GeomKit {
    /// Spin and return the same node (chainable in renderer build functions).
    static func spinning(_ node: SCNNode) -> SCNNode {
        let spin = SCNAction.repeatForever(
            .rotateBy(x: 0, y: .pi * 2, z: 0, duration: RendererOptions.spinDuration)
        )
        node.runAction(spin)
        return node
    }
}
