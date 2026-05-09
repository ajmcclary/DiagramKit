import Foundation

/// Maps `config.xyChart.*`, `config.themeVariables.xyChart.*`, and JSON-init
/// equivalents to `XYChartConfig` and `XYChartThemeConfig`.
public struct XYChartFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.xyChart.", "xyChart.",
        "config.themeVariables.xyChart.", "themeVariables.xyChart.",
    ]

    private var config = XYChartConfig()
    private var theme = XYChartThemeConfig()
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
            hasTheme = true
            return _applyTheme(key: String(path.dropFirst(Self.prefixes[2].count)), value: value)
        }
        if path.hasPrefix(Self.prefixes[3]) {
            hasTheme = true
            return _applyTheme(key: String(path.dropFirst(Self.prefixes[3].count)), value: value)
        }
        return false
    }

    private mutating func _applyConfig(key: String, value: FrontmatterValue) -> Bool {
        // Top-level keys
        switch key {
        case "width":                    guard let v = value.double else { return false }; config.width = v
        case "height":                   guard let v = value.double else { return false }; config.height = v
        case "titleFontSize":            guard let v = value.double else { return false }; config.titleFontSize = v
        case "titlePadding":             guard let v = value.double else { return false }; config.titlePadding = v
        case "showTitle":                guard let v = value.bool else { return false }; config.showTitle = v
        case "showDataLabel":            guard let v = value.bool else { return false }; config.showDataLabel = v
        case "showDataLabelOutsideBar":  guard let v = value.bool else { return false }; config.showDataLabelOutsideBar = v
        case "chartOrientation":         config.chartOrientation = value.string
        case "plotReservedSpacePercent": guard let v = value.double else { return false }; config.plotReservedSpacePercent = v
        default: break
        }
        // xAxis sub-keys
        if key.hasPrefix("xAxis.") {
            return _applyXAxis(key: String(key.dropFirst("xAxis.".count)), value: value)
        }
        if key.hasPrefix("yAxis.") {
            return _applyYAxis(key: String(key.dropFirst("yAxis.".count)), value: value)
        }
        return false
    }

    private mutating func _applyXAxis(key: String, value: FrontmatterValue) -> Bool {
        switch key {
        case "showLabel":      guard let v = value.bool else { return false }; config.xAxis.showLabel = v
        case "labelFontSize":  guard let v = value.double else { return false }; config.xAxis.labelFontSize = v
        case "labelPadding":   guard let v = value.double else { return false }; config.xAxis.labelPadding = v
        case "showTitle":      guard let v = value.bool else { return false }; config.xAxis.showTitle = v
        case "titleFontSize":  guard let v = value.double else { return false }; config.xAxis.titleFontSize = v
        case "titlePadding":   guard let v = value.double else { return false }; config.xAxis.titlePadding = v
        case "showTick":       guard let v = value.bool else { return false }; config.xAxis.showTick = v
        case "tickLength":     guard let v = value.double else { return false }; config.xAxis.tickLength = v
        case "tickWidth":      guard let v = value.double else { return false }; config.xAxis.tickWidth = v
        case "showAxisLine":   guard let v = value.bool else { return false }; config.xAxis.showAxisLine = v
        case "axisLineWidth":  guard let v = value.double else { return false }; config.xAxis.axisLineWidth = v
        default: return false
        }
        return true
    }

    private mutating func _applyYAxis(key: String, value: FrontmatterValue) -> Bool {
        switch key {
        case "showLabel":      guard let v = value.bool else { return false }; config.yAxis.showLabel = v
        case "labelFontSize":  guard let v = value.double else { return false }; config.yAxis.labelFontSize = v
        case "labelPadding":   guard let v = value.double else { return false }; config.yAxis.labelPadding = v
        case "showTitle":      guard let v = value.bool else { return false }; config.yAxis.showTitle = v
        case "titleFontSize":  guard let v = value.double else { return false }; config.yAxis.titleFontSize = v
        case "titlePadding":   guard let v = value.double else { return false }; config.yAxis.titlePadding = v
        case "showTick":       guard let v = value.bool else { return false }; config.yAxis.showTick = v
        case "tickLength":     guard let v = value.double else { return false }; config.yAxis.tickLength = v
        case "tickWidth":      guard let v = value.double else { return false }; config.yAxis.tickWidth = v
        case "showAxisLine":   guard let v = value.bool else { return false }; config.yAxis.showAxisLine = v
        case "axisLineWidth":  guard let v = value.double else { return false }; config.yAxis.axisLineWidth = v
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(key: String, value: FrontmatterValue) -> Bool {
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

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.xyChartConfig = config }
        if hasTheme { frontmatter.xyChartTheme = theme }
    }
}
