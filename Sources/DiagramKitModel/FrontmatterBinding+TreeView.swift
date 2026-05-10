import Foundation

public struct TreeViewFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.treeView.", "themeVariables."]

    private var config = TreeViewDiagramConfig()
    private var theme = TreeViewThemeVariables()
    private var hasConfig = false
    private var hasTheme = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        if path.hasPrefix(Self.prefixes[0]) {
            guard _applyConfig(String(path.dropFirst(Self.prefixes[0].count)), value) else { return false }
            hasConfig = true
            return true
        }
        if path.hasPrefix(Self.prefixes[1]) {
            guard _applyTheme(String(path.dropFirst(Self.prefixes[1].count)), value) else { return false }
            hasTheme = true
            return true
        }
        return false
    }

    private mutating func _applyConfig(_ key: String, _ value: FrontmatterValue) -> Bool {
        switch key {
        case "rowIndent":     guard let v = value.double else { return false }; config.rowIndent = v
        case "paddingX":      guard let v = value.double else { return false }; config.paddingX = v
        case "paddingY":      guard let v = value.double else { return false }; config.paddingY = v
        case "lineThickness": guard let v = value.double else { return false }; config.lineThickness = v
        case "showIcons":     guard let v = value.bool else { return false }; config.showIcons = v
        case "useMaxWidth":   guard let v = value.bool else { return false }; config.useMaxWidth = v
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(_ rawKey: String, _ value: FrontmatterValue) -> Bool {
        // Theme variables can arrive either flat (`themeVariables.labelColor`)
        // or nested under a `treeView.` sub-namespace
        // (`themeVariables.treeView.labelColor`). Strip the sub-namespace so
        // the inner switch handles both shapes uniformly.
        let key: String
        if rawKey.hasPrefix("treeView.") {
            key = String(rawKey.dropFirst("treeView.".count))
        } else {
            key = rawKey
        }
        let v = value.string
        switch key {
        case "labelColor":       theme.labelColor = v; return true
        case "labelFontSize":    theme.labelFontSize = v; return true
        case "lineColor":        theme.lineColor = v; return true
        case "iconColor":        theme.iconColor = v; return true
        case "descriptionColor": theme.descriptionColor = v; return true
        case "highlightBg":      theme.highlightBg = v; return true
        case "highlightStroke":  theme.highlightStroke = v; return true
        default: return false
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.treeViewConfig = config }
        if hasTheme { frontmatter.treeViewTheme = theme }
    }
}
