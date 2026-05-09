import Foundation

/// Maps `config.packet.*` and `config.themeVariables.packet.*`
/// to `PacketDiagramConfig` and `PacketThemeConfig`.
public struct PacketFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.packet.", "packet.",
        "config.themeVariables.packet.", "themeVariables.packet.",
    ]

    private var config = PacketDiagramConfig()
    private var theme = PacketThemeConfig()
    private var hasConfig = false
    private var hasTheme = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        if path.hasPrefix(Self.prefixes[0]) {
            hasConfig = true
            return _applyConfig(key: String(path.dropFirst(Self.prefixes[0].count)), value: value)
        }
        if path.hasPrefix(Self.prefixes[1]) {
            hasConfig = true
            return _applyConfig(key: String(path.dropFirst(Self.prefixes[1].count)), value: value)
        }
        if path.hasPrefix(Self.prefixes[2]) {
            hasTheme = true
            return _applyTheme(key: String(path.dropFirst(Self.prefixes[2].count)), value: value)
        }
        if path.hasPrefix(Self.prefixes[3]) {
            hasTheme = true
            return _applyTheme(key: String(path.dropFirst(Self.prefixes[3].count)), value: value)
        }
        return false
    }

    private mutating func _applyConfig(key: String, value: FrontmatterValue) -> Bool {
        switch key {
        case "rowHeight":    guard let v = value.double else { return false }; config.rowHeight = v
        case "bitWidth":     guard let v = value.double else { return false }; config.bitWidth = v
        case "bitsPerRow":   guard let v = value.int else { return false }; config.bitsPerRow = v
        case "showBits":     guard let v = value.bool else { return false }; config.showBits = v
        case "paddingX":     guard let v = value.double else { return false }; config.paddingX = v
        case "paddingY":     guard let v = value.double else { return false }; config.paddingY = v
        case "useMaxWidth":  guard let v = value.bool else { return false }; config.useMaxWidth = v
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(key: String, value: FrontmatterValue) -> Bool {
        let v = value.string
        switch key {
        case "byteFontSize":     theme.byteFontSize = v
        case "startByteColor":   theme.startByteColor = v
        case "endByteColor":     theme.endByteColor = v
        case "labelColor":       theme.labelColor = v
        case "labelFontSize":    theme.labelFontSize = v
        case "titleColor":       theme.titleColor = v
        case "titleFontSize":    theme.titleFontSize = v
        case "blockStrokeColor": theme.blockStrokeColor = v
        case "blockStrokeWidth": theme.blockStrokeWidth = v
        case "blockFillColor":   theme.blockFillColor = v
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.packetConfig = config }
        if hasTheme { frontmatter.packetTheme = theme }
    }
}
