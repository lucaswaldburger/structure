import Cocoa
import ScreenSaver

final class ConfigureSheetController: NSObject {

    static let shared = ConfigureSheetController()

    private var sheet: NSWindow?
    private var applyHandler: (() -> Void)?

    private var displayPeriodField: NSTextField!
    private var cacheSizeField:     NSTextField!
    private var renderModePopup:    NSPopUpButton!
    private var internetCheckbox:   NSButton!
    private var localOnlyCheckbox:  NSButton!
    private var annotationCheckbox: NSButton!

    func window(applyHandler: @escaping () -> Void) -> NSWindow {
        self.applyHandler = applyHandler
        if sheet == nil { sheet = buildSheet() }
        loadValuesFromDefaults()
        return sheet!
    }

    private func buildSheet() -> NSWindow {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 340),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        win.title = "PDB Structure"

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        win.contentView = content

        let form = NSStackView()
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 14
        form.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(form)

        displayPeriodField = makeIntField(width: 60)
        cacheSizeField     = makeIntField(width: 60)
        renderModePopup    = NSPopUpButton(frame: .zero, pullsDown: false)
        renderModePopup.translatesAutoresizingMaskIntoConstraints = false
        for mode in RenderMode.allCases { renderModePopup.addItem(withTitle: mode.title) }

        internetCheckbox   = NSButton(checkboxWithTitle: "Download new structures from RCSB", target: nil, action: nil)
        localOnlyCheckbox  = NSButton(checkboxWithTitle: "Only use locally cached or bundled structures", target: nil, action: nil)
        annotationCheckbox = NSButton(checkboxWithTitle: "Show information overlay", target: nil, action: nil)

        form.addArrangedSubview(row(label: "Display period (s):", field: displayPeriodField))
        form.addArrangedSubview(row(label: "Cache size:",         field: cacheSizeField))
        form.addArrangedSubview(row(label: "Render mode:",        field: renderModePopup))
        form.addArrangedSubview(internetCheckbox)
        form.addArrangedSubview(localOnlyCheckbox)
        form.addArrangedSubview(annotationCheckbox)

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        let ok = NSButton(title: "OK", target: self, action: #selector(okClicked))
        ok.keyEquivalent = "\r"
        let buttons = NSStackView(views: [NSView(), cancel, ok])
        buttons.orientation = .horizontal
        buttons.spacing = 12
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

        return win
    }

    private func row(label text: String, field: NSView) -> NSStackView {
        let lbl = NSTextField(labelWithString: text)
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        lbl.alignment = .right
        let widthConstraint = lbl.widthAnchor.constraint(equalToConstant: 150)
        widthConstraint.priority = .defaultHigh
        widthConstraint.isActive = true
        let row = NSStackView(views: [lbl, field])
        row.orientation = .horizontal
        row.spacing = 10
        return row
    }

    private func makeIntField(width: CGFloat) -> NSTextField {
        let f = NSTextField()
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(equalToConstant: width).isActive = true
        return f
    }

    private func loadValuesFromDefaults() {
        displayPeriodField.integerValue = Int(Defaults.displayPeriod)
        cacheSizeField.integerValue     = Defaults.cacheSize
        renderModePopup.selectItem(at: Defaults.renderMode.rawValue)
        internetCheckbox.state   = Defaults.enableInternet  ? .on : .off
        localOnlyCheckbox.state  = Defaults.onlyLocal       ? .on : .off
        annotationCheckbox.state = Defaults.fullAnnotation  ? .on : .off
    }

    @objc private func cancelClicked() {
        end()
    }

    @objc private func okClicked() {
        Defaults.write([
            "DisplayPeriod":         max(5, displayPeriodField.integerValue),
            "CacheSize":             max(1, cacheSizeField.integerValue),
            "RenderMode":            renderModePopup.indexOfSelectedItem,
            "EnableInternetAccess":  internetCheckbox.state   == .on,
            "OnlyLoadLocalFiles":    localOnlyCheckbox.state  == .on,
            "FullTextualAnnotation": annotationCheckbox.state == .on,
        ])
        applyHandler?()
        end()
    }

    private func end() {
        guard let sheet = sheet, let parent = sheet.sheetParent else {
            sheet?.orderOut(nil); return
        }
        parent.endSheet(sheet)
    }
}
