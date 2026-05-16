import Foundation

public struct EventModelingFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.eventmodeling.", "themeVariables."]
    private static let configPrefixes = ["config.eventmodeling."]
    private static let themePrefixes = ["themeVariables."]

    private var binding = ConfigThemeBinding<EventModelingDiagramConfig, EventModelingThemeVariables>(
        config: EventModelingDiagramConfig(),
        theme: EventModelingThemeVariables()
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
                case "padding":     guard let v = value.double else { return false }; config.padding = v
                case "rowHeight":   guard let v = value.double else { return false }; config.rowHeight = v
                case "useMaxWidth": guard let v = value.bool else { return false }; config.useMaxWidth = v
                default: return false
                }
                return true
            },
            applyTheme: { key, value, theme in
                let v = value.string
                switch key {
                case "emUiFill":                    theme.emUiFill = v
                case "emUiStroke":                  theme.emUiStroke = v
                case "emProcessorFill":             theme.emProcessorFill = v
                case "emProcessorStroke":           theme.emProcessorStroke = v
                case "emReadModelFill":             theme.emReadModelFill = v
                case "emReadModelStroke":           theme.emReadModelStroke = v
                case "emCommandFill":               theme.emCommandFill = v
                case "emCommandStroke":             theme.emCommandStroke = v
                case "emEventFill":                 theme.emEventFill = v
                case "emEventStroke":               theme.emEventStroke = v
                case "emSwimlaneBackgroundOdd":     theme.emSwimlaneBackgroundOdd = v
                case "emSwimlaneBackgroundStroke":  theme.emSwimlaneBackgroundStroke = v
                case "emRelationStroke":            theme.emRelationStroke = v
                case "emArrowhead":                 theme.emArrowhead = v
                default: return false
                }
                return true
            }
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasConfig { frontmatter.perDiagram.eventModeling.config = binding.config }
        if binding.hasTheme { frontmatter.perDiagram.eventModeling.theme = binding.theme }
    }
}
