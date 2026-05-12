import Foundation
#if canImport(AppKit) || canImport(UIKit)
import CoreGraphics
#endif

// MARK: - Mermaid Color Parser

/// A unified CSS color parser for Mermaid diagram renderers.
///
/// Supports hex colors (`#RGB`, `#RRGGBB`, `#RRGGBBAA`), `rgb()`/`rgba()`
/// functional notation, and a small set of named colors used by Mermaid
/// theme defaults.
///
/// Replaces the duplicated `_hexToCGColor`, `_thexToCGColor`, and ad-hoc
/// CSS color parsers in individual renderer extensions.
///
/// Apple-only — depends on `BMColor` (UIColor/NSColor typealias).
#if canImport(UIKit) || canImport(AppKit)
public enum DiagramColorParser {

    /// Parse a color string into a `BMColor`, or `nil` if invalid.
    ///
    /// Supported formats:
    /// - `"#RGB"`, `"#RRGGBB"`, `"#RRGGBBAA"` (hex)
    /// - `"rgb(r, g, b)"`, `"rgba(r, g, b, a)"` (functional)
    /// - `"transparent"` (returns clear black)
    ///
    /// Unknown or invalid values return `nil` rather than defaulting to black,
    /// so callers can apply their own fallback.
    public static func color(_ value: String) -> BMColor? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        if let named = _namedColor(trimmed) {
            return named
        }

        if trimmed.hasPrefix("#") {
            return _parseHex(trimmed)
        }

        if trimmed.hasPrefix("rgb") {
            return _parseRGBFunction(trimmed)
        }

        return nil
    }

    /// Parse a hex color string into a `BMColor`.
    /// Accepts `#RGB`, `#RRGGBB`, `#RRGGBBAA` with or without the `#` prefix.
    /// Returns `nil` if the hex string is invalid.
    public static func hexColor(_ value: String) -> BMColor? {
        var raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        raw = raw.replacingOccurrences(of: "#", with: "")
        var intValue: UInt64 = 0
        guard Scanner(string: raw).scanHexInt64(&intValue),
              raw.count == 3 || raw.count == 6 || raw.count == 8
        else { return nil }

        let r, g, b, a: CGFloat
        switch raw.count {
        case 3:
            let rr = CGFloat((intValue & 0xF00) >> 8) / 15
            let gg = CGFloat((intValue & 0x0F0) >> 4) / 15
            let bb = CGFloat(intValue & 0x00F) / 15
            r = rr; g = gg; b = bb; a = 1
        case 6:
            r = CGFloat((intValue & 0xFF0000) >> 16) / 255
            g = CGFloat((intValue & 0x00FF00) >> 8) / 255
            b = CGFloat(intValue & 0x0000FF) / 255
            a = 1
        case 8:
            r = CGFloat((intValue & 0xFF000000) >> 24) / 255
            g = CGFloat((intValue & 0x00FF0000) >> 16) / 255
            b = CGFloat((intValue & 0x0000FF00) >> 8) / 255
            a = CGFloat(intValue & 0x000000FF) / 255
        default:
            return nil
        }
        return BMColor(red: r, green: g, blue: b, alpha: a)
    }

    /// Convenience: parse a hex color and return `CGColor?` directly.
    /// Used by CG renderer extensions that previously called `_hexToCGColor`.
    public static func cgHex(_ value: String) -> CGColor? {
        return hexColor(value)?.cgColor
    }

    // MARK: - Private

    private static func _parseHex(_ value: String) -> BMColor? {
        return hexColor(value)
    }

    private static func _parseRGBFunction(_ value: String) -> BMColor? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parenStart = trimmed.firstIndex(of: "("),
              let parenEnd = trimmed.lastIndex(of: ")"),
              parenStart < parenEnd
        else { return nil }

        let inner = String(trimmed[trimmed.index(after: parenStart)..<parenEnd])
        let components = inner.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard components.count >= 3, components.count <= 4 else { return nil }

        let values = components.compactMap { Double($0) }
        guard values.count == components.count else { return nil }

        let r = CGFloat(values[0]) / 255
        let g = CGFloat(values[1]) / 255
        let b = CGFloat(values[2]) / 255
        let a: CGFloat = values.count >= 4 ? CGFloat(values[3]) : 1.0

        return BMColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func _namedColor(_ value: String) -> BMColor? {
        switch value.lowercased() {
        case "transparent":
            return BMColor(red: 0, green: 0, blue: 0, alpha: 0)
        case "black":
            return BMColor(red: 0, green: 0, blue: 0, alpha: 1)
        case "white":
            return BMColor(red: 1, green: 1, blue: 1, alpha: 1)
        default:
            return nil
        }
    }
}

// MARK: - Phase 0 backward-compat deprecated alias

@available(*, deprecated, renamed: "DiagramColorParser")
public typealias MermaidColorParser = DiagramColorParser
#endif
