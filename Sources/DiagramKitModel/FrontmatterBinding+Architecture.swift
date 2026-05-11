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

    private var config = ArchitectureDiagramConfig()
    private var theme = ArchitectureThemeConfig()
    private var hasConfig = false
    private var hasTheme = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        if let key = Self.extractKey(path: path, prefixes: Self.configPrefixes) {
            guard _applyConfig(key: key, value: value) else { return false }
            hasConfig = true
            return true
        }
        if let key = Self.extractKey(path: path, prefixes: Self.themePrefixes) {
            guard _isArchThemeKey(key) else { return false }
            guard _applyTheme(key: key, value: value) else { return false }
            hasTheme = true
            return true
        }
        return false
    }

    private mutating func _applyConfig(key: String, value: FrontmatterValue) -> Bool {
        switch key {
        case "padding":      guard let v = value.double else { return false }; config.padding = v
        case "iconSize":     guard let v = value.double else { return false }; config.iconSize = v
        case "fontSize":     guard let v = value.double else { return false }; config.fontSize = v
        case "randomize":    guard let v = value.bool else { return false }; config.randomize = v
        case "useMaxWidth":  guard let v = value.bool else { return false }; config.useMaxWidth = v
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(key: String, value: FrontmatterValue) -> Bool {
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

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.archConfig = config }
        if hasTheme { frontmatter.archTheme = theme }
    }
}
