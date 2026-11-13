import Foundation

public struct RadarFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.radar.", "themeVariables."]
    private static let configPrefixes = ["config.radar."]
    // Theme keys may arrive under the `themeVariables.radar.` sub-namespace
    // or directly under `themeVariables.`. The specific prefix wins when
    // both match; the fallback handles the flat form (e.g. `themeVariables.cScale0`).
    private static let themePrefixes = ["themeVariables.radar."]
    private static let themeFallbackPrefixes = ["themeVariables."]

    private var binding = ConfigThemeBinding<RadarDiagramConfig, RadarThemeConfig>(
        config: RadarDiagramConfig(),
        theme: RadarThemeConfig()
    )

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        binding.apply(
            path: path,
            value: value,
            configPrefixes: Self.configPrefixes,
            themePrefixes: Self.themePrefixes,
            themeFallbackPrefixes: Self.themeFallbackPrefixes,
            applyConfig: { key, value, config in
                switch key {
                case "width":            guard let v = value.double else { return false }; config.width = v
                case "height":           guard let v = value.double else { return false }; config.height = v
                case "marginTop":        guard let v = value.double else { return false }; config.marginTop = v
                case "marginRight":      guard let v = value.double else { return false }; config.marginRight = v
                case "marginBottom":     guard let v = value.double else { return false }; config.marginBottom = v
                case "marginLeft":       guard let v = value.double else { return false }; config.marginLeft = v
                case "axisScaleFactor":  guard let v = value.double else { return false }; config.axisScaleFactor = v
                case "axisLabelFactor":  guard let v = value.double else { return false }; config.axisLabelFactor = v
                case "curveTension":     guard let v = value.double else { return false }; config.curveTension = v
                case "useMaxWidth":      guard let v = value.bool else { return false }; config.useMaxWidth = v
                default: return false
                }
                return true
            },
            applyTheme: { key, value, theme in
                // `cScaleN` keys (where N is 0..<cScale.count) target individual
                // entries in the cScale palette array. Mermaid's init directive
                // uses this form (`themeVariables.cScale0`).
                // Theme strings are interpolated into the SVG `<style>` block;
                // a value that could break out of it is rejected.
                if key.hasPrefix("cScale"),
                   let index = Int(key.dropFirst("cScale".count)),
                   index >= 0, index < theme.cScale.count {
                    guard let v = value.cssValue else { return false }
                    theme.cScale[index] = v
                    return true
                }
                switch key {
                case "fontSize":             guard let v = value.double else { return false }; theme.fontSize = v
                case "titleColor":           guard let v = value.cssValue else { return false }; theme.titleColor = v; return true
                case "axisColor":            guard let v = value.cssValue else { return false }; theme.axisColor = v; return true
                case "axisStrokeWidth":      guard let v = value.double else { return false }; theme.axisStrokeWidth = v
                case "axisLabelFontSize":    guard let v = value.double else { return false }; theme.axisLabelFontSize = v
                case "graticuleColor":       guard let v = value.cssValue else { return false }; theme.graticuleColor = v; return true
                case "graticuleOpacity":     guard let v = value.double else { return false }; theme.graticuleOpacity = v
                case "graticuleStrokeWidth": guard let v = value.double else { return false }; theme.graticuleStrokeWidth = v
                case "curveOpacity":         guard let v = value.double else { return false }; theme.curveOpacity = v
                case "curveStrokeWidth":     guard let v = value.double else { return false }; theme.curveStrokeWidth = v
                case "legendFontSize":       guard let v = value.double else { return false }; theme.legendFontSize = v
                default: return false
                }
                return true
            }
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasConfig { frontmatter.perDiagram.radar.config = binding.config }
        if binding.hasTheme { frontmatter.perDiagram.radar.theme = binding.theme }
    }
}
