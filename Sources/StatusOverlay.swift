import Cocoa

/// Centered overlay shown while the first structure is being fetched (e.g. on a
/// fresh install when nothing is cached yet). A spinner plus a status line such
/// as "Downloading 1ABC… 42%".
final class StatusOverlay: NSView {

    private let label = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

    init() {
        super.init(frame: .zero); setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder); setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.42).cgColor
        layer?.cornerRadius = 12
        layer?.borderColor = NSColor(white: 1, alpha: 0.08).cgColor
        layer?.borderWidth = 0.5

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor(white: 0.92, alpha: 1)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [spinner, label])
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
    }

    var text: String {
        get { label.stringValue }
        set { label.stringValue = newValue }
    }

    func show(_ message: String) {
        text = message
        isHidden = false
        spinner.startAnimation(nil)
    }

    func hide() {
        isHidden = true
        spinner.stopAnimation(nil)
    }
}
