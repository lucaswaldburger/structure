import Cocoa
import ScreenSaver
import SceneKit

@objc(StructureView)
public class StructureView: ScreenSaverView {

    /// Per-variant override. When non-nil, the saver always renders in this mode
    /// and ignores the stored `RenderMode` default (the build produces one saver
    /// bundle per mode, each a thin subclass returning its mode here).
    var forcedRenderMode: RenderMode? { nil }

    private let scnView = SCNView()
    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private var moleculeNode: SCNNode?

    private let fetcher = PDBFetcher()
    private var lastSwapAt: Date = .distantPast
    private var swapInFlight = false
    private let infoPanel = InfoPanel()
    private let statusOverlay = StatusOverlay()
    private var isPreviewMode = false

    private var currentStructure: ParsedStructure?
    private var currentMode: RenderMode = .ribbon

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        self.isPreviewMode = isPreview
        Defaults.registerDefaults()
        self.currentMode = forcedRenderMode ?? Defaults.renderMode
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        Defaults.registerDefaults()
        self.currentMode = forcedRenderMode ?? Defaults.renderMode
        commonInit()
    }

    private func commonInit() {
        animationTimeInterval = 1.0 / 30.0
        wantsLayer = true

        scnView.frame = bounds
        scnView.autoresizingMask = [.width, .height]
        scnView.scene = scene
        scnView.antialiasingMode = .multisampling16X
        scnView.allowsCameraControl = false
        addSubview(scnView)

        applyBackgroundColor()

        let cam = SCNCamera()
        cam.zNear = 0.1
        cam.zFar = 5000
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 0, CGFloat(RendererOptions.cameraDistance))
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

        infoPanel.isHidden = isPreviewMode || !Defaults.fullAnnotation
        infoPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(infoPanel)
        NSLayoutConstraint.activate([
            infoPanel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 36),
            infoPanel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -36),
            infoPanel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.48),
        ])

        statusOverlay.translatesAutoresizingMaskIntoConstraints = false
        statusOverlay.isHidden = true
        addSubview(statusOverlay)
        NSLayoutConstraint.activate([
            statusOverlay.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusOverlay.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // While no structure is on screen yet (e.g. first run, nothing cached),
        // surface the download/loading status from the fetcher.
        fetcher.statusHandler = { [weak self] message in
            guard let self, self.moleculeNode == nil else { return }
            self.statusOverlay.show(message)
        }

        triggerSwap()
    }

    /// Bind every layer-backed subview's contentsScale to the window's
    /// backingScaleFactor. Without this, NSTextField text rasterizes at 1x
    /// into the parent layer and looks fuzzy on Retina. Fires when the view
    /// attaches to a window and any time the backing scale changes (e.g.
    /// dragged between displays).
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        applyContentsScale(scale, to: self)
    }

    private func applyContentsScale(_ scale: CGFloat, to view: NSView) {
        view.layer?.contentsScale = scale
        for sub in view.subviews { applyContentsScale(scale, to: sub) }
    }

    public override func animateOneFrame() {
        super.animateOneFrame()
        if Date().timeIntervalSince(lastSwapAt) > Defaults.displayPeriod {
            triggerSwap()
        }
    }

    private func triggerSwap() {
        guard !swapInFlight else { return }
        swapInFlight = true
        lastSwapAt = Date()

        if moleculeNode == nil { statusOverlay.show("Connecting…") }

        fetcher.fetchRandom { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.swapInFlight = false
                switch result {
                case .success(let parsed):
                    self.statusOverlay.hide()
                    self.currentStructure = parsed
                    self.installMolecule(parsed, mode: self.currentMode)
                    self.infoPanel.isHidden = self.isPreviewMode || !Defaults.fullAnnotation
                    self.infoPanel.update(with: parsed)
                case .failure(let err):
                    NSLog("Structure: fetch failed: \(err)")
                    if self.moleculeNode == nil {
                        self.statusOverlay.show("Connection failed — retrying…")
                    }
                    self.lastSwapAt = .distantPast
                }
            }
        }
    }

    private func applyBackgroundColor() {
        let color = Defaults.backgroundColor
        scnView.backgroundColor = color
        scene.background.contents = color
    }

    private func installMolecule(_ parsed: ParsedStructure, mode: RenderMode) {
        let new = mode.renderer.build(from: parsed)
        new.opacity = 0
        scene.rootNode.addChildNode(new)
        new.runAction(.fadeIn(duration: 0.6))

        if let old = moleculeNode {
            old.runAction(.sequence([.fadeOut(duration: 0.6), .removeFromParentNode()]))
        }
        moleculeNode = new
    }

    // MARK: Keyboard shortcuts

    public override var acceptsFirstResponder: Bool { true }

    public override func keyDown(with event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers else {
            super.keyDown(with: event); return
        }
        switch chars {
        case "1":
            if let id = currentStructure?.id,
               let url = URL(string: "https://www.rcsb.org/structure/\(id.uppercased())") {
                NSWorkspace.shared.open(url)
            }
        case "2":
            saveScreenshot()
        case "3":
            // Fixed-mode variants ignore the cycle key so they stay on their mode.
            if forcedRenderMode == nil {
                currentMode = currentMode.next()
                Defaults.renderMode = currentMode
                if let s = currentStructure { installMolecule(s, mode: currentMode) }
            }
        case "4":
            triggerSwap()
        default:
            super.keyDown(with: event)
        }
    }

    private func saveScreenshot() {
        let image = scnView.snapshot()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        let id = currentStructure?.id.uppercased() ?? "Structure"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let url = FileManager.default
            .urls(for: .desktopDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Structure-\(id)-\(stamp).png")
        try? png.write(to: url)
        NSLog("Structure: screenshot → \(url.path)")
    }

}
