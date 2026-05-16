import Foundation

/// Maps `config.timeline.*` and theme variables to
/// `TimelineDiagramConfig` and `TimelineThemeConfig`.
public struct TimelineFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.timeline.", "timeline.",
        "config.themeVariables.", "themeVariables.",
    ]
    private static let configPrefixes = ["config.timeline.", "timeline."]
    private static let themePrefixes = ["config.themeVariables.", "themeVariables."]

    private var binding = ConfigThemeBinding<TimelineDiagramConfig, TimelineThemeConfig>(
        config: TimelineDiagramConfig(),
        theme: TimelineThemeConfig()
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
                case "disableMulticolor": guard let v = value.bool else { return false }; config.disableMulticolor = v
                case "leftMargin":       guard let v = value.double else { return false }; config.leftMargin = v
                case "padding":          guard let v = value.double else { return false }; config.padding = v
                case "useMaxWidth":      guard let v = value.bool else { return false }; config.useMaxWidth = v
                case "useWidth":         guard let v = value.double else { return false }; config.useWidth = v
                case "taskFontSize":     guard let v = value.double else { return false }; config.taskFontSize = v
                case "taskFontFamily":   config.taskFontFamily = value.string
                case "textPlacement":    config.textPlacement = value.string
                case "width":            guard let v = value.double else { return false }; config.width = v
                case "height":           guard let v = value.double else { return false }; config.height = v
                default: return false
                }
                return true
            },
            applyTheme: { key, value, theme in
                guard _isTimelineThemeKey(key) else { return false }
                if key.hasPrefix("cScale"), key.count > 6 {
                    let numStr = String(key.dropFirst(6))
                    if let idx = Int(numStr), idx >= 0, idx < theme.cScale.count {
                        theme.cScale[idx] = value.string; return true
                    }
                }
                if key.hasPrefix("cScaleLabel"), key.count > 11 {
                    let numStr = String(key.dropFirst(11))
                    if let idx = Int(numStr), idx >= 0, idx < theme.cScaleLabel.count {
                        theme.cScaleLabel[idx] = value.string; return true
                    }
                }
                if key.hasPrefix("cScaleInv"), key.count > 9 {
                    let numStr = String(key.dropFirst(9))
                    if let idx = Int(numStr), idx >= 0, idx < theme.cScaleInv.count {
                        theme.cScaleInv[idx] = value.string; return true
                    }
                }
                switch key {
                case "THEME_COLOR_LIMIT":
                    guard let v = value.int else { return false }; theme.themeColorLimit = v
                case "fontFamily":       theme.fontFamily = value.string
                case "fontSize":         guard let v = value.double else { return false }; theme.fontSize = v
                case "mainBkg":          theme.mainBkg = value.string
                case "nodeBorder":       theme.nodeBorder = value.string
                case "useGradient":      guard let v = value.bool else { return false }; theme.useGradient = v
                case "gradientStart":    theme.gradientStart = value.string
                case "gradientStop":     theme.gradientStop = value.string
                case "dropShadow":       theme.dropShadow = value.string
                default: return false
                }
                return true
            }
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasConfig { frontmatter.perDiagram.timeline.config = binding.config }
        if binding.hasTheme { frontmatter.perDiagram.timeline.theme = binding.theme }
    }
}
