import Foundation

/// Maps `config.pie.*`, `config.themeVariables.pie.*`, and JSON-init
/// equivalents to `PieChartConfig` and `PieChartThemeConfig`.
public struct PieFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.pie.", "pie.",
        "config.themeVariables.pie.", "themeVariables.pie.",
        // Fallback: flat theme variable paths (e.g. "themeVariables.pie1")
        // without the "pie." sub-namespace.
        "config.themeVariables.", "themeVariables.",
    ]

    private var config = PieChartConfig()
    private var theme = PieChartThemeConfig()
    private var hasConfig = false
    private var hasTheme = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        if path.hasPrefix(Self.prefixes[0]) {
            guard _applyConfig(key: String(path.dropFirst(Self.prefixes[0].count)), value: value) else { return false }
            hasConfig = true
            return true
        }
        if path.hasPrefix(Self.prefixes[1]) {
            guard _applyConfig(key: String(path.dropFirst(Self.prefixes[1].count)), value: value) else { return false }
            hasConfig = true
            return true
        }
        if path.hasPrefix(Self.prefixes[2]) {
            guard _applyTheme(key: String(path.dropFirst(Self.prefixes[2].count)), value: value) else { return false }
            hasTheme = true
            return true
        }
        if path.hasPrefix(Self.prefixes[3]) {
            guard _applyTheme(key: String(path.dropFirst(Self.prefixes[3].count)), value: value) else { return false }
            hasTheme = true
            return true
        }
        if path.hasPrefix(Self.prefixes[4]) {
            guard _applyTheme(key: String(path.dropFirst(Self.prefixes[4].count)), value: value) else { return false }
            hasTheme = true
            return true
        }
        if path.hasPrefix(Self.prefixes[5]) {
            guard _applyTheme(key: String(path.dropFirst(Self.prefixes[5].count)), value: value) else { return false }
            hasTheme = true
            return true
        }
        return false
    }

    private mutating func _applyConfig(key: String, value: FrontmatterValue) -> Bool {
        switch key {
        case "textPosition": guard let v = value.double else { return false }; config.textPosition = v
        case "useWidth":     guard let v = value.double else { return false }; config.useWidth = v
        case "useMaxWidth":  guard let v = value.bool else { return false }; config.useMaxWidth = v
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(key: String, value: FrontmatterValue) -> Bool {
        let v = value.string
        switch key {
        case "pie1": theme.pie1 = v
        case "pie2": theme.pie2 = v
        case "pie3": theme.pie3 = v
        case "pie4": theme.pie4 = v
        case "pie5": theme.pie5 = v
        case "pie6": theme.pie6 = v
        case "pie7": theme.pie7 = v
        case "pie8": theme.pie8 = v
        case "pie9": theme.pie9 = v
        case "pie10": theme.pie10 = v
        case "pie11": theme.pie11 = v
        case "pie12": theme.pie12 = v
        case "pieTitleTextSize": theme.pieTitleTextSize = v
        case "pieTitleTextColor": theme.pieTitleTextColor = v
        case "pieSectionTextSize": theme.pieSectionTextSize = v
        case "pieSectionTextColor": theme.pieSectionTextColor = v
        case "pieLegendTextSize": theme.pieLegendTextSize = v
        case "pieLegendTextColor": theme.pieLegendTextColor = v
        case "pieStrokeColor": theme.pieStrokeColor = v
        case "pieStrokeWidth": theme.pieStrokeWidth = v
        case "pieOuterStrokeWidth": theme.pieOuterStrokeWidth = v
        case "pieOuterStrokeColor": theme.pieOuterStrokeColor = v
        case "pieOpacity": theme.pieOpacity = v
        case "fontFamily": theme.fontFamily = v
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.pieConfig = config }
        if hasTheme { frontmatter.pieTheme = theme }
    }
}
