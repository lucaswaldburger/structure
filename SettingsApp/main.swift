import Cocoa
import ScreenSaver

extension NSColor {
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(max(0, min(1, c.redComponent))   * 255))
        let g = Int(round(max(0, min(1, c.greenComponent)) * 255))
        let b = Int(round(max(0, min(1, c.blueComponent))  * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >>  8) & 0xFF) / 255
        let b = CGFloat( value        & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

// Mirror of RenderMode in the saver (display titles only — no rendering here).
enum RenderMode: Int, CaseIterable {
    case backbone = 0, ballAndStick = 1, spacefill = 2, ribbon = 3, cartoon = 4
    var title: String {
        switch self {
        case .backbone:     return "Backbone trace"
        case .ballAndStick: return "Ball and stick"
        case .spacefill:    return "Spacefill (CPK)"
        case .ribbon:       return "Ribbon"
        case .cartoon:      return "Cartoon (tube)"
        }
    }
}

enum Defaults {
    static let moduleName = "Structure"
    static var store: ScreenSaverDefaults { ScreenSaverDefaults(forModuleWithName: moduleName)! }

    static func registerDefaults() {
        store.register(defaults: [
            "DisplayPeriod":         30,
            "CacheSize":             100,
            "EnableInternetAccess":  true,
            "FullTextualAnnotation": true,
            "OnlyLoadLocalFiles":    false,
            "RenderMode":            RenderMode.ribbon.rawValue,
            "BackgroundColor":       "#000000",
        ])
    }

    static var displayPeriod: Int   { store.integer(forKey: "DisplayPeriod") }
    static var cacheSize:     Int   { store.integer(forKey: "CacheSize") }
    static var enableInternet: Bool { store.bool(forKey: "EnableInternetAccess") }
    static var fullAnnotation: Bool { store.bool(forKey: "FullTextualAnnotation") }
    static var onlyLocal:      Bool { store.bool(forKey: "OnlyLoadLocalFiles") }
    static var renderMode: RenderMode {
        RenderMode(rawValue: store.integer(forKey: "RenderMode")) ?? .backbone
    }
    static var backgroundColor: NSColor {
        NSColor(hex: store.string(forKey: "BackgroundColor") ?? "#000000") ?? .black
    }

    static func write(_ values: [String: Any]) {
        for (k, v) in values { store.set(v, forKey: k) }
        store.synchronize()
    }
}

final class SettingsWindowController: NSWindowController {
    private var displayPeriodField: NSTextField!
    private var cacheSizeField:     NSTextField!
    private var renderModePopup:    NSPopUpButton!
    private var internetCheckbox:   NSButton!
    private var localOnlyCheckbox:  NSButton!
    private var annotationCheckbox: NSButton!
    private var backgroundColorWell: NSColorWell!

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        win.title = "Structure Settings"
        win.center()
        self.init(window: win)
        buildUI()
        loadValues()
    }

    private func buildUI() {
        guard let win = window else { return }
        let content = NSView()
        win.contentView = content

        let form = NSStackView()
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 14
        form.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(form)

        displayPeriodField = intField()
        cacheSizeField = intField()
        renderModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        renderModePopup.translatesAutoresizingMaskIntoConstraints = false
        for m in RenderMode.allCases { renderModePopup.addItem(withTitle: m.title) }

        backgroundColorWell = NSColorWell()
        backgroundColorWell.translatesAutoresizingMaskIntoConstraints = false
        backgroundColorWell.widthAnchor.constraint(equalToConstant: 60).isActive = true
        backgroundColorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true

        internetCheckbox   = NSButton(checkboxWithTitle: "Download new structures from RCSB", target: nil, action: nil)
        localOnlyCheckbox  = NSButton(checkboxWithTitle: "Only use locally cached or bundled structures", target: nil, action: nil)
        annotationCheckbox = NSButton(checkboxWithTitle: "Show information overlay", target: nil, action: nil)

        form.addArrangedSubview(row("Display period (s):", displayPeriodField))
        form.addArrangedSubview(row("Cache size:",         cacheSizeField))
        form.addArrangedSubview(row("Render mode:",        renderModePopup))
        form.addArrangedSubview(row("Background:",         backgroundColorWell))
        form.addArrangedSubview(internetCheckbox)
        form.addArrangedSubview(localOnlyCheckbox)
        form.addArrangedSubview(annotationCheckbox)

        let restore = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreClicked))
        let cancel  = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        let apply   = NSButton(title: "Apply",  target: self, action: #selector(applyClicked))
        let ok      = NSButton(title: "OK",     target: self, action: #selector(okClicked))
        ok.keyEquivalent = "\r"
        cancel.keyEquivalent = "\u{1b}"

        let buttons = NSStackView(views: [restore, NSView(), cancel, apply, ok])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            form.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            form.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: form.bottomAnchor, constant: 18),
        ])
    }

    private func row(_ text: String, _ field: NSView) -> NSStackView {
        let lbl = NSTextField(labelWithString: text)
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        lbl.alignment = .right
        let w = lbl.widthAnchor.constraint(equalToConstant: 160); w.priority = .defaultHigh; w.isActive = true
        let r = NSStackView(views: [lbl, field])
        r.orientation = .horizontal; r.spacing = 10
        return r
    }

    private func intField() -> NSTextField {
        let f = NSTextField()
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(equalToConstant: 70).isActive = true
        return f
    }

    private func loadValues() {
        Defaults.registerDefaults()
        displayPeriodField.integerValue = Defaults.displayPeriod
        cacheSizeField.integerValue     = Defaults.cacheSize
        renderModePopup.selectItem(at: Defaults.renderMode.rawValue)
        backgroundColorWell.color = Defaults.backgroundColor
        internetCheckbox.state   = Defaults.enableInternet  ? .on : .off
        localOnlyCheckbox.state  = Defaults.onlyLocal       ? .on : .off
        annotationCheckbox.state = Defaults.fullAnnotation  ? .on : .off
    }

    private func writeValues() {
        Defaults.write([
            "DisplayPeriod":         max(5, displayPeriodField.integerValue),
            "CacheSize":             max(1, cacheSizeField.integerValue),
            "RenderMode":            renderModePopup.indexOfSelectedItem,
            "BackgroundColor":       backgroundColorWell.color.hexString,
            "EnableInternetAccess":  internetCheckbox.state   == .on,
            "OnlyLoadLocalFiles":    localOnlyCheckbox.state  == .on,
            "FullTextualAnnotation": annotationCheckbox.state == .on,
        ])
    }

    @objc private func applyClicked()   { writeValues() }
    @objc private func okClicked()      { writeValues(); NSApp.terminate(nil) }
    @objc private func cancelClicked()  { NSApp.terminate(nil) }
    @objc private func restoreClicked() {
        for k in ["DisplayPeriod","CacheSize","RenderMode","BackgroundColor","EnableInternetAccess","OnlyLoadLocalFiles","FullTextualAnnotation"] {
            Defaults.store.removeObject(forKey: k)
        }
        Defaults.store.synchronize()
        loadValues()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: SettingsWindowController?
    func applicationDidFinishLaunching(_ note: Notification) {
        controller = SettingsWindowController()
        controller?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
