import Foundation

/// Maps `config.packet.*` and `config.themeVariables.packet.*`
/// to `PacketDiagramConfig` and `PacketThemeConfig`.
public struct PacketFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.packet.", "packet.",
        "config.themeVariables.packet.", "themeVariables.packet.",
    ]
    private static let configPrefixes = ["config.packet.", "packet."]
    private static let themePrefixes = ["config.themeVariables.packet.", "themeVariables.packet."]

    private var binding = ConfigThemeBinding<PacketDiagramConfig, PacketThemeConfig>(
        config: PacketDiagramConfig(),
        theme: PacketThemeConfig()
    )

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        binding.apply(
            path: path,
            value: value,
            configPrefixes: Self.configPrefixes,
            themePrefixes: Self.themePrefixes,
            applyConfig: { key, value, config in
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
            },
            applyTheme: { key, value, theme in
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
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasConfig { frontmatter.packetConfig = binding.config }
        if binding.hasTheme { frontmatter.packetTheme = binding.theme }
    }
}
