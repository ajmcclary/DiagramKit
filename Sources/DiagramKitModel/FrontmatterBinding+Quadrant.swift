import Foundation

/// Maps `config.quadrantChart.*` and theme variables to
/// `QuadrantChartConfig` and `QuadrantChartThemeConfig`.
public struct QuadrantFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.quadrantChart.", "quadrantChart.",
        "config.themeVariables.", "themeVariables.",
    ]
    private static let configPrefixes = ["config.quadrantChart.", "quadrantChart."]
    private static let themePrefixes = ["config.themeVariables.", "themeVariables."]

    private var binding = ConfigThemeBinding<QuadrantChartConfig, QuadrantChartThemeConfig>(
        config: QuadrantChartConfig(),
        theme: QuadrantChartThemeConfig()
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
                case "chartWidth":                       guard let v = value.double else { return false }; config.chartWidth = v
                case "chartHeight":                      guard let v = value.double else { return false }; config.chartHeight = v
                case "titlePadding":                     guard let v = value.double else { return false }; config.titlePadding = v
                case "titleFontSize":                    guard let v = value.double else { return false }; config.titleFontSize = v
                case "quadrantPadding":                  guard let v = value.double else { return false }; config.quadrantPadding = v
                case "quadrantTextTopPadding":           guard let v = value.double else { return false }; config.quadrantTextTopPadding = v
                case "quadrantLabelFontSize":            guard let v = value.double else { return false }; config.quadrantLabelFontSize = v
                case "quadrantInternalBorderStrokeWidth": guard let v = value.double else { return false }; config.quadrantInternalBorderStrokeWidth = v
                case "quadrantExternalBorderStrokeWidth": guard let v = value.double else { return false }; config.quadrantExternalBorderStrokeWidth = v
                case "xAxisLabelPadding":                guard let v = value.double else { return false }; config.xAxisLabelPadding = v
                case "xAxisLabelFontSize":               guard let v = value.double else { return false }; config.xAxisLabelFontSize = v
                case "xAxisPosition":                    config.xAxisPosition = value.string
                case "yAxisLabelPadding":                guard let v = value.double else { return false }; config.yAxisLabelPadding = v
                case "yAxisLabelFontSize":               guard let v = value.double else { return false }; config.yAxisLabelFontSize = v
                case "yAxisPosition":                    config.yAxisPosition = value.string
                case "pointTextPadding":                 guard let v = value.double else { return false }; config.pointTextPadding = v
                case "pointLabelFontSize":               guard let v = value.double else { return false }; config.pointLabelFontSize = v
                case "pointRadius":                      guard let v = value.double else { return false }; config.pointRadius = v
                case "useMaxWidth":                      guard let v = value.bool else { return false }; config.useMaxWidth = v
                default: return false
                }
                return true
            },
            applyTheme: { key, value, theme in
                guard _isQuadrantThemeKey(key) else { return false }
                let v = value.string
                switch key {
                case "quadrant1Fill": theme.quadrant1Fill = v
                case "quadrant2Fill": theme.quadrant2Fill = v
                case "quadrant3Fill": theme.quadrant3Fill = v
                case "quadrant4Fill": theme.quadrant4Fill = v
                case "quadrant1TextFill": theme.quadrant1TextFill = v
                case "quadrant2TextFill": theme.quadrant2TextFill = v
                case "quadrant3TextFill": theme.quadrant3TextFill = v
                case "quadrant4TextFill": theme.quadrant4TextFill = v
                case "quadrantPointFill": theme.quadrantPointFill = v
                case "quadrantPointTextFill": theme.quadrantPointTextFill = v
                case "quadrantXAxisTextFill": theme.quadrantXAxisTextFill = v
                case "quadrantYAxisTextFill": theme.quadrantYAxisTextFill = v
                case "quadrantInternalBorderStrokeFill": theme.quadrantInternalBorderStrokeFill = v
                case "quadrantExternalBorderStrokeFill": theme.quadrantExternalBorderStrokeFill = v
                case "quadrantTitleFill": theme.quadrantTitleFill = v
                default: return false
                }
                return true
            }
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasConfig { frontmatter.perDiagram.quadrant.config = binding.config }
        if binding.hasTheme { frontmatter.perDiagram.quadrant.theme = binding.theme }
    }
}
