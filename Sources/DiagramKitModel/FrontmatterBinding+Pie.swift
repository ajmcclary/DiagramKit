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
    private static let configPrefixes = ["config.pie.", "pie."]
    private static let themeSpecificPrefixes = ["config.themeVariables.pie.", "themeVariables.pie."]
    private static let themeFallbackPrefixes = ["config.themeVariables.", "themeVariables."]

    private var binding = ConfigThemeBinding<PieChartConfig, PieChartThemeConfig>(
        config: PieChartConfig(),
        theme: PieChartThemeConfig()
    )

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        binding.apply(
            path: path,
            value: value,
            configPrefixes: Self.configPrefixes,
            themePrefixes: Self.themeSpecificPrefixes,
            themeFallbackPrefixes: Self.themeFallbackPrefixes,
            applyConfig: { key, value, config in
                switch key {
                case "textPosition": guard let v = value.double else { return false }; config.textPosition = v
                case "useWidth":     guard let v = value.double else { return false }; config.useWidth = v
                case "useMaxWidth":  guard let v = value.bool else { return false }; config.useMaxWidth = v
                default: return false
                }
                return true
            },
            applyTheme: { key, value, theme in
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
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasConfig { frontmatter.pieConfig = binding.config }
        if binding.hasTheme { frontmatter.pieTheme = binding.theme }
    }
}
