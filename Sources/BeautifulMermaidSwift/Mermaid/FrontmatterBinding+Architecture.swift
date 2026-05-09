import Foundation

/// Maps `config.architecture.*` and theme variables to
/// `ArchitectureDiagramConfig` and `ArchitectureThemeConfig`.
public struct ArchitectureFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.architecture.", "architecture.",
        "config.themeVariables.", "themeVariables.",
    ]

    private var config = ArchitectureDiagramConfig()
    private var theme = ArchitectureThemeConfig()
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
            let key = String(path.dropFirst(Self.prefixes[2].count))
            if _isArchThemeKey(key) {
                hasTheme = true
                return _applyTheme(key: key, value: value)
            }
            return false
        }
        if path.hasPrefix(Self.prefixes[3]) {
            let key = String(path.dropFirst(Self.prefixes[3].count))
            if _isArchThemeKey(key) {
                hasTheme = true
                return _applyTheme(key: key, value: value)
            }
            return false
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
