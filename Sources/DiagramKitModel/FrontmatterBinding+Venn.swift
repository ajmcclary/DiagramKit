import Foundation

public struct VennFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.venn.", "venn.", "config.themeVariables.", "themeVariables."]
    private static let configPrefixes = ["config.venn.", "venn."]
    private static let themePrefixes = ["config.themeVariables.", "themeVariables."]

    private var binding = ConfigThemeBinding<VennDiagramConfig, [String: String]>(
        config: VennDiagramConfig(),
        theme: [:]
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
                case "useMaxWidth":   guard let v = value.bool else { return false }; config.useMaxWidth = v
                case "width":         guard let v = value.double else { return false }; config.width = v
                case "height":        guard let v = value.double else { return false }; config.height = v
                case "padding":       guard let v = value.double else { return false }; config.padding = v
                case "useDebugLayout": guard let v = value.bool else { return false }; config.useDebugLayout = v
                default: return false
                }
                return true
            },
            applyTheme: { key, value, theme in
                // Venn theme variables are free-form key-value pairs.
                theme[key] = value.string
                return true
            }
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasConfig { frontmatter.perDiagram.venn.config = binding.config }
        if binding.hasTheme { frontmatter.perDiagram.venn.theme = binding.theme }
    }
}
