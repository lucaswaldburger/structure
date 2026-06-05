import AppKit

enum ChainPalette {
    static let colors: [NSColor] = [
        NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1),
        NSColor(red: 0.30, green: 0.65, blue: 0.95, alpha: 1),
        NSColor(red: 0.45, green: 0.85, blue: 0.50, alpha: 1),
        NSColor(red: 0.98, green: 0.78, blue: 0.30, alpha: 1),
        NSColor(red: 0.75, green: 0.45, blue: 0.95, alpha: 1),
        NSColor(red: 0.98, green: 0.55, blue: 0.30, alpha: 1),
        NSColor(red: 0.35, green: 0.85, blue: 0.85, alpha: 1),
        NSColor(red: 0.95, green: 0.55, blue: 0.75, alpha: 1),
    ]

    static func color(forChainIndex i: Int) -> NSColor {
        colors[((i % colors.count) + colors.count) % colors.count]
    }
}

/// CPK element coloring (Corey-Pauling-Koltun, as standardized by Jmol/PyMOL),
/// plus approximate Van der Waals radii for spacefill rendering.
enum CPKPalette {
    static let elementColor: [String: NSColor] = [
        "H":  NSColor(white: 0.95, alpha: 1),
        "C":  NSColor(white: 0.50, alpha: 1),
        "N":  NSColor(red: 0.20, green: 0.40, blue: 0.95, alpha: 1),
        "O":  NSColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1),
        "S":  NSColor(red: 0.95, green: 0.85, blue: 0.20, alpha: 1),
        "P":  NSColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1),
        "F":  NSColor(red: 0.55, green: 0.95, blue: 0.55, alpha: 1),
        "CL": NSColor(red: 0.45, green: 0.85, blue: 0.30, alpha: 1),
        "BR": NSColor(red: 0.65, green: 0.30, blue: 0.10, alpha: 1),
        "I":  NSColor(red: 0.55, green: 0.20, blue: 0.55, alpha: 1),
        "FE": NSColor(red: 0.88, green: 0.50, blue: 0.10, alpha: 1),
        "MG": NSColor(red: 0.55, green: 0.95, blue: 0.50, alpha: 1),
        "MN": NSColor(red: 0.65, green: 0.50, blue: 0.65, alpha: 1),
        "ZN": NSColor(red: 0.50, green: 0.50, blue: 0.85, alpha: 1),
        "NA": NSColor(red: 0.45, green: 0.45, blue: 0.95, alpha: 1),
        "K":  NSColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1),
        "CU": NSColor(red: 0.80, green: 0.45, blue: 0.15, alpha: 1),
    ]

    static func color(forElement element: String) -> NSColor {
        elementColor[element.uppercased()] ?? NSColor(red: 0.85, green: 0.35, blue: 0.85, alpha: 1)
    }

    /// Van der Waals radii in Ångströms (Bondi 1964 + later additions).
    static let vdwRadius: [String: Float] = [
        "H":  1.20, "C":  1.70, "N":  1.55, "O":  1.52, "S":  1.80, "P":  1.80,
        "F":  1.47, "CL": 1.75, "BR": 1.85, "I":  1.98,
        "FE": 2.00, "MG": 1.73, "ZN": 1.39, "MN": 2.05, "NA": 2.27, "K":  2.75, "CU": 1.40,
    ]

    static func radius(forElement element: String) -> Float {
        vdwRadius[element.uppercased()] ?? 1.70
    }
}
