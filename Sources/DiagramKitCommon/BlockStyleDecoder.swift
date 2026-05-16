import Foundation

/// Shared parser for the Block-family inline-style strings that the CG
/// and SVG renderers both interpret (`fill:#abc`, `stroke:#def`,
/// `color:#fed`).
///
/// Both `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift` and
/// `Sources/DiagramKitModel/src_block_renderer.swift` used to inline the
/// same `replacingOccurrences(of: "fill:", with: "").trimmingCharacters(...)`
/// chain; pulling the parsing into one place removes the dual-renderer
/// drift hazard. Defaults stay with the caller (different per format),
/// so the decoder returns `nil` when no matching style is present.
public enum BlockStyleDecoder {

    /// Hex string from the last `fill:` entry in `styles`, or `nil`.
    public static func fillHex(from styles: [String]) -> String? {
        return _lastValue(in: styles, prefix: "fill:")
    }

    /// Hex string from the last `stroke:` entry in `styles`, or `nil`.
    public static func strokeHex(from styles: [String]) -> String? {
        return _lastValue(in: styles, prefix: "stroke:")
    }

    /// Text-colour resolution: an explicit `labelStyle` wins (`fill:` or
    /// `color:` inside it — `fill:` takes precedence to match the CG/SVG
    /// callsites' prior behavior); otherwise look at `node.styles` for a
    /// `color:` entry.
    public static func textColorHex(labelStyle: String?, styles: [String]) -> String? {
        if let labelStyle = labelStyle {
            let parts = labelStyle.split(separator: ";").map(String.init)
            for style in parts.reversed() {
                if let value = _value(in: style, prefix: "fill:") {
                    return value
                }
                if let value = _value(in: style, prefix: "color:") {
                    return value
                }
            }
        }
        return _lastValue(in: styles, prefix: "color:")
    }

    // MARK: - Private

    private static func _lastValue(in styles: [String], prefix: String) -> String? {
        for style in styles.reversed() {
            if let value = _value(in: style, prefix: prefix) {
                return value
            }
        }
        return nil
    }

    private static func _value(in style: String, prefix: String) -> String? {
        guard style.hasPrefix(prefix) else { return nil }
        return style
            .replacingOccurrences(of: prefix, with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
