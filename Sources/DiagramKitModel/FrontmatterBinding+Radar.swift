import Foundation

public struct RadarFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.radar.", "themeVariables."]
    private static let configPrefixes = ["config.radar."]
    private static let themePrefixes = ["themeVariables."]

    private var config = RadarDiagramConfig()
    private var theme = RadarThemeConfig()
    private var hasConfig = false
    private var hasTheme = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        if let key = Self.extractKey(path: path, prefixes: Self.configPrefixes) {
            guard _applyConfig(key, value) else { return false }
            hasConfig = true
            return true
        }
        if let key = Self.extractKey(path: path, prefixes: Self.themePrefixes) {
            guard _applyTheme(key, value) else { return false }
            hasTheme = true
            return true
        }
        return false
    }

    private mutating func _applyConfig(_ key: String, _ value: FrontmatterValue) -> Bool {
        switch key {
        case "width":          guard let v = value.double else { return false }; config.width = v
        case "height":         guard let v = value.double else { return false }; config.height = v
        case "marginTop":      guard let v = value.double else { return false }; config.marginTop = v
        case "marginRight":    guard let v = value.double else { return false }; config.marginRight = v
        case "marginBottom":   guard let v = value.double else { return false }; config.marginBottom = v
        case "marginLeft":     guard let v = value.double else { return false }; config.marginLeft = v
        case "axisScaleFactor":  guard let v = value.double else { return false }; config.axisScaleFactor = v
        case "axisLabelFactor":  guard let v = value.double else { return false }; config.axisLabelFactor = v
        case "curveTension":   guard let v = value.double else { return false }; config.curveTension = v
        case "useMaxWidth":    guard let v = value.bool else { return false }; config.useMaxWidth = v
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(_ rawKey: String, _ value: FrontmatterValue) -> Bool {
        // Theme keys can arrive flat (`themeVariables.axisColor`) or nested
        // under a `radar.` sub-namespace (`themeVariables.radar.axisColor`).
        // Strip the sub-namespace so the inner switch handles both shapes.
        let key: String
        if rawKey.hasPrefix("radar.") {
            key = String(rawKey.dropFirst("radar.".count))
        } else {
            key = rawKey
        }
        // `cScaleN` keys (where N is 0..<cScale.count) target individual
        // entries in the cScale palette array. Mermaid's init directive
        // uses this form (`themeVariables.cScale0`).
        if key.hasPrefix("cScale"),
           let index = Int(key.dropFirst("cScale".count)),
           index >= 0, index < theme.cScale.count {
            theme.cScale[index] = value.string
            return true
        }
        switch key {
        case "fontSize":            guard let v = value.double else { return false }; theme.fontSize = v
        case "titleColor":          theme.titleColor = value.string; return true
        case "axisColor":           theme.axisColor = value.string; return true
        case "axisStrokeWidth":     guard let v = value.double else { return false }; theme.axisStrokeWidth = v
        case "axisLabelFontSize":   guard let v = value.double else { return false }; theme.axisLabelFontSize = v
        case "graticuleColor":      theme.graticuleColor = value.string; return true
        case "graticuleOpacity":    guard let v = value.double else { return false }; theme.graticuleOpacity = v
        case "graticuleStrokeWidth": guard let v = value.double else { return false }; theme.graticuleStrokeWidth = v
        case "curveOpacity":        guard let v = value.double else { return false }; theme.curveOpacity = v
        case "curveStrokeWidth":    guard let v = value.double else { return false }; theme.curveStrokeWidth = v
        case "legendFontSize":      guard let v = value.double else { return false }; theme.legendFontSize = v
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.radarConfig = config }
        if hasTheme { frontmatter.radarTheme = theme }
    }
}
