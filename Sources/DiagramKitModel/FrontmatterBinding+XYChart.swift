import Foundation

/// Maps `config.xyChart.*`, `config.themeVariables.xyChart.*`, and JSON-init
/// equivalents to `XYChartConfig` and `XYChartThemeConfig`.
public struct XYChartFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.xyChart.", "xyChart.",
        "config.themeVariables.xyChart.", "themeVariables.xyChart.",
    ]
    private static let configPrefixes = ["config.xyChart.", "xyChart."]
    private static let themePrefixes = ["config.themeVariables.xyChart.", "themeVariables.xyChart."]

    private var binding = ConfigThemeBinding<XYChartConfig, XYChartThemeConfig>(
        config: XYChartConfig(),
        theme: XYChartThemeConfig()
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
                case "width":                    guard let v = value.double else { return false }; config.width = v; return true
                case "height":                   guard let v = value.double else { return false }; config.height = v; return true
                case "titleFontSize":            guard let v = value.double else { return false }; config.titleFontSize = v; return true
                case "titlePadding":             guard let v = value.double else { return false }; config.titlePadding = v; return true
                case "showTitle":                guard let v = value.bool else { return false }; config.showTitle = v; return true
                case "showDataLabel":            guard let v = value.bool else { return false }; config.showDataLabel = v; return true
                case "showDataLabelOutsideBar":  guard let v = value.bool else { return false }; config.showDataLabelOutsideBar = v; return true
                case "chartOrientation":         config.chartOrientation = value.string; return true
                case "plotReservedSpacePercent": guard let v = value.double else { return false }; config.plotReservedSpacePercent = v; return true
                default: break
                }
                if key.hasPrefix("xAxis.") {
                    return _applyXYAxisKey(String(key.dropFirst("xAxis.".count)), value: value, axis: &config.xAxis)
                }
                if key.hasPrefix("yAxis.") {
                    return _applyXYAxisKey(String(key.dropFirst("yAxis.".count)), value: value, axis: &config.yAxis)
                }
                return false
            },
            applyTheme: { key, value, theme in
                let v = value.string
                switch key {
                case "backgroundColor":   theme.backgroundColor = v
                case "titleColor":        theme.titleColor = v
                case "dataLabelColor":    theme.dataLabelColor = v
                case "xAxisLabelColor":   theme.xAxisLabelColor = v
                case "xAxisTitleColor":   theme.xAxisTitleColor = v
                case "xAxisTickColor":    theme.xAxisTickColor = v
                case "xAxisLineColor":    theme.xAxisLineColor = v
                case "yAxisLabelColor":   theme.yAxisLabelColor = v
                case "yAxisTitleColor":   theme.yAxisTitleColor = v
                case "yAxisTickColor":    theme.yAxisTickColor = v
                case "yAxisLineColor":    theme.yAxisLineColor = v
                case "plotColorPalette":  theme.plotColorPalette = v
                default: return false
                }
                return true
            }
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasConfig { frontmatter.perDiagram.xyChart.config = binding.config }
        if binding.hasTheme { frontmatter.perDiagram.xyChart.theme = binding.theme }
    }
}

private func _applyXYAxisKey(_ key: String, value: FrontmatterValue, axis: inout XYChartAxisConfig) -> Bool {
    switch key {
    case "showLabel":      guard let v = value.bool else { return false }; axis.showLabel = v
    case "labelFontSize":  guard let v = value.double else { return false }; axis.labelFontSize = v
    case "labelPadding":   guard let v = value.double else { return false }; axis.labelPadding = v
    case "showTitle":      guard let v = value.bool else { return false }; axis.showTitle = v
    case "titleFontSize":  guard let v = value.double else { return false }; axis.titleFontSize = v
    case "titlePadding":   guard let v = value.double else { return false }; axis.titlePadding = v
    case "showTick":       guard let v = value.bool else { return false }; axis.showTick = v
    case "tickLength":     guard let v = value.double else { return false }; axis.tickLength = v
    case "tickWidth":      guard let v = value.double else { return false }; axis.tickWidth = v
    case "showAxisLine":   guard let v = value.bool else { return false }; axis.showAxisLine = v
    case "axisLineWidth":  guard let v = value.double else { return false }; axis.axisLineWidth = v
    default: return false
    }
    return true
}
