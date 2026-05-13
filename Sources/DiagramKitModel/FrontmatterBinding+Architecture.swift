import Foundation

/// Maps `config.architecture.*` and theme variables to
/// `ArchitectureDiagramConfig` and `ArchitectureThemeConfig`.
public struct ArchitectureFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.architecture.", "architecture.",
        "config.themeVariables.", "themeVariables.",
    ]
    private static let configPrefixes = ["config.architecture.", "architecture."]
    private static let themePrefixes = ["config.themeVariables.", "themeVariables."]

    private var binding = ConfigThemeBinding<ArchitectureDiagramConfig, ArchitectureThemeConfig>(
        config: ArchitectureDiagramConfig(),
        theme: ArchitectureThemeConfig()
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
                case "padding":      guard let v = value.double else { return false }; config.padding = v
                case "iconSize":     guard let v = value.double else { return false }; config.iconSize = v
                case "fontSize":     guard let v = value.double else { return false }; config.fontSize = v
                case "randomize":    guard let v = value.bool else { return false }; config.randomize = v
                case "useMaxWidth":  guard let v = value.bool else { return false }; config.useMaxWidth = v
                default: return false
                }
                return true
            },
            applyTheme: { key, value, theme in
                guard _isArchThemeKey(key) else { return false }
                let v = value.string
                switch key {
                case "archEdgeColor":        theme.archEdgeColor = v
                case "archEdgeArrowColor":   theme.archEdgeArrowColor = v
                case "archEdgeWidth":        theme.archEdgeWidth = v
                case "archGroupBorderColor": theme.archGroupBorderColor = v
                case "archGroupBorderWidth": theme.archGroupBorderWidth = v
                default: return false
                }
                return true
            }
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasConfig { frontmatter.archConfig = binding.config }
        if binding.hasTheme { frontmatter.archTheme = binding.theme }
    }
}
