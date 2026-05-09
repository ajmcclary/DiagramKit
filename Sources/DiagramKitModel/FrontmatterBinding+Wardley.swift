import Foundation

public struct WardleyFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.wardley-beta.", "config.wardleyBeta.", "themeVariables."]

    private var config = WardleyDiagramConfig()
    private var theme = WardleyThemeVariables()
    private var hasConfig = false
    private var hasTheme = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        if path.hasPrefix(Self.prefixes[0]) || path.hasPrefix(Self.prefixes[1]) {
            hasConfig = true
            let key: String
            if path.hasPrefix(Self.prefixes[0]) {
                key = String(path.dropFirst(Self.prefixes[0].count))
            } else {
                key = String(path.dropFirst(Self.prefixes[1].count))
            }
            return _applyConfig(key, value)
        }
        if path.hasPrefix(Self.prefixes[2]) {
            hasTheme = true
            return _applyTheme(String(path.dropFirst(Self.prefixes[2].count)), value)
        }
        return false
    }

    private mutating func _applyConfig(_ key: String, _ value: FrontmatterValue) -> Bool {
        switch key {
        case "width":                 guard let v = value.double else { return false }; config.width = v
        case "height":                guard let v = value.double else { return false }; config.height = v
        case "padding":               guard let v = value.double else { return false }; config.padding = v
        case "useMaxWidth":           guard let v = value.bool else { return false }; config.useMaxWidth = v
        case "nodeRadius":            guard let v = value.double else { return false }; config.nodeRadius = v
        case "axisFontSize":          guard let v = value.double else { return false }; config.axisFontSize = v
        case "labelFontSize":         guard let v = value.double else { return false }; config.labelFontSize = v
        case "nodeLabelOffset":       guard let v = value.double else { return false }; config.nodeLabelOffset = v
        case "showGrid":              guard let v = value.bool else { return false }; config.showGrid = v
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(_ rawKey: String, _ value: FrontmatterValue) -> Bool {
        // Strip "wardley." sub-namespace prefix when theme variables are
        // nested under a wardley key (e.g. "themeVariables.wardley.backgroundColor").
        let key: String
        if rawKey.hasPrefix("wardley.") {
            key = String(rawKey.dropFirst("wardley.".count))
        } else {
            key = rawKey
        }
        let v = value.string
        switch key {
        case "backgroundColor":       theme.backgroundColor = v; return true
        case "axisColor":             theme.axisColor = v; return true
        case "axisTextColor":         theme.axisTextColor = v; return true
        case "linkStroke":            theme.linkStroke = v; return true
        case "evolutionStroke":       theme.evolutionStroke = v; return true
        case "evolutionColor":        theme.evolutionColor = v; return true
        case "componentStroke":       theme.componentStroke = v; return true
        case "componentFill":         theme.componentFill = v; return true
        case "componentLabelColor":   theme.componentLabelColor = v; return true
        case "annotationStroke":      theme.annotationStroke = v; return true
        case "annotationTextColor":   theme.annotationTextColor = v; return true
        case "annotationFill":        theme.annotationFill = v; return true
        case "gridColor":             theme.gridColor = v; return true
        // Flat theme variable path: wardleyEvolutionColor (no sub-namespace)
        case "wardleyEvolutionColor":
            theme.evolutionStroke = v
            theme.evolutionColor = v
            return true
        default: return false
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.wardleyBetaConfig = config }
        if hasTheme { frontmatter.wardleyTheme = theme }
    }
}
