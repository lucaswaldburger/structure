import Cocoa

/// Bottom-left overlay rendered as a single wrapping NSTextField with an attributed
/// string. Mirrors the textual annotation block from `bblonder/structure`:
/// PDB ID + classification, title, authors, method · resolution, organism(s),
/// and a per-chain list with each chain letter colored to match its rendering.
final class InfoPanel: NSView {

    private let label = NSTextField(wrappingLabelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame); setup()
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

        label.translatesAutoresizingMaskIntoConstraints = false
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = 580
        label.lineBreakMode = .byWordWrapping
        label.isSelectable = false
        label.isEditable = false
        label.drawsBackground = false
        label.isBordered = false
        label.allowsDefaultTighteningForTruncation = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])
    }

    func update(with s: ParsedStructure) {
        let attr = NSMutableAttributedString()

        let idFont    = NSFont.monospacedSystemFont(ofSize: 30, weight: .semibold)
        let classFont = NSFont.systemFont(ofSize: 14, weight: .medium)
        let titleFont = NSFont.systemFont(ofSize: 16, weight: .regular)
        let labelFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
        let metaFont  = NSFont.systemFont(ofSize: 12, weight: .regular)
        let chainFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        let chainMetaFont = NSFont.systemFont(ofSize: 12, weight: .regular)

        let idColor    = NSColor(white: 0.98, alpha: 1)
        let classColor = NSColor(white: 0.72, alpha: 1)
        let titleColor = NSColor(white: 0.92, alpha: 1)
        let labelColor = NSColor(white: 0.50, alpha: 1)
        let metaColor  = NSColor(white: 0.82, alpha: 1)

        // ID + classification.
        attr.append(.init(string: s.id.uppercased(),
                          attributes: [.font: idFont, .foregroundColor: idColor]))
        if let cls = s.header.classification {
            attr.append(.init(string: "   \(cls)",
                              attributes: [.font: classFont, .foregroundColor: classColor]))
        }
        attr.append(.init(string: "\n"))

        // Title.
        if let title = s.header.title {
            attr.append(.init(string: title + "\n",
                              attributes: [.font: titleFont, .foregroundColor: titleColor]))
        }

        // Authors.
        if !s.header.authors.isEmpty {
            attr.append(labeled("AUTHORS", font: labelFont, color: labelColor))
            attr.append(.init(string: s.header.authors.joined(separator: ",  ") + "\n",
                              attributes: [.font: metaFont, .foregroundColor: metaColor]))
        }

        // Method · resolution.
        var methodPieces: [String] = []
        if let m = s.header.method { methodPieces.append(m) }
        if let r = s.header.resolution { methodPieces.append(String(format: "%.2f Å", r)) }
        if !methodPieces.isEmpty {
            attr.append(labeled("METHOD", font: labelFont, color: labelColor))
            attr.append(.init(string: methodPieces.joined(separator: "  ·  ") + "\n",
                              attributes: [.font: metaFont, .foregroundColor: metaColor]))
        }

        // Organisms.
        if !s.header.organisms.isEmpty {
            attr.append(labeled("SOURCE", font: labelFont, color: labelColor))
            attr.append(.init(string: s.header.organisms.joined(separator: " · ") + "\n",
                              attributes: [.font: metaFont, .foregroundColor: metaColor]))
        }

        // Per-chain list with colored chain letters and molecule names.
        if !s.chains.isEmpty {
            attr.append(labeled("CHAINS", font: labelFont, color: labelColor))
            for (i, chain) in s.chains.enumerated() {
                if i > 0 { attr.append(.init(string: "\n")) }
                attr.append(.init(
                    string: String(chain.id),
                    attributes: [.font: chainFont,
                                 .foregroundColor: ChainPalette.color(forChainIndex: i)]
                ))
                let suffix = "  " + (chain.molecule ?? "—")
                attr.append(.init(
                    string: suffix,
                    attributes: [.font: chainMetaFont, .foregroundColor: metaColor]
                ))
            }
        }

        // Paragraph style: line spacing for readability.
        let para = NSMutableParagraphStyle()
        para.lineHeightMultiple = 1.18
        para.paragraphSpacing = 2
        attr.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: attr.length))

        label.attributedStringValue = attr
    }

    private func labeled(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        .init(string: text + "\n",
              attributes: [.font: font, .foregroundColor: color, .kern: 1.2])
    }
}
