import AppKit

extension NSColor {
    /// `#RRGGBB` in sRGB. Useful for storing a color in string-based defaults.
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(max(0, min(1, c.redComponent))   * 255))
        let g = Int(round(max(0, min(1, c.greenComponent)) * 255))
        let b = Int(round(max(0, min(1, c.blueComponent))  * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Parses `#RRGGBB` / `RRGGBB` (and 3-digit `#RGB`) into an sRGB color.
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >>  8) & 0xFF) / 255
        let b = CGFloat( value        & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
