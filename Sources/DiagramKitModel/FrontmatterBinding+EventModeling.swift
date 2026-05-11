import Foundation

public struct EventModelingFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.eventmodeling.", "themeVariables."]
    private static let configPrefixes = ["config.eventmodeling."]
    private static let themePrefixes = ["themeVariables."]

    private var config = EventModelingDiagramConfig()
    private var theme = EventModelingThemeVariables()
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
        case "padding":     guard let v = value.double else { return false }; config.padding = v
        case "rowHeight":   guard let v = value.double else { return false }; config.rowHeight = v
        case "useMaxWidth": guard let v = value.bool else { return false }; config.useMaxWidth = v
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(_ key: String, _ value: FrontmatterValue) -> Bool {
        let v = value.string
        switch key {
        case "emUiFill":                    theme.emUiFill = v; return true
        case "emUiStroke":                  theme.emUiStroke = v; return true
        case "emProcessorFill":             theme.emProcessorFill = v; return true
        case "emProcessorStroke":           theme.emProcessorStroke = v; return true
        case "emReadModelFill":             theme.emReadModelFill = v; return true
        case "emReadModelStroke":           theme.emReadModelStroke = v; return true
        case "emCommandFill":               theme.emCommandFill = v; return true
        case "emCommandStroke":             theme.emCommandStroke = v; return true
        case "emEventFill":                 theme.emEventFill = v; return true
        case "emEventStroke":               theme.emEventStroke = v; return true
        case "emSwimlaneBackgroundOdd":     theme.emSwimlaneBackgroundOdd = v; return true
        case "emSwimlaneBackgroundStroke":  theme.emSwimlaneBackgroundStroke = v; return true
        case "emRelationStroke":            theme.emRelationStroke = v; return true
        case "emArrowhead":                 theme.emArrowhead = v; return true
        default: return false
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.eventmodelingConfig = config }
        if hasTheme { frontmatter.eventmodelingThemeVariables = theme }
    }
}
