import Foundation

/// Maps `config.requirement.*` and `themeVariables.*` frontmatter keys
/// to `RequirementDiagramConfig` and `RequirementThemeVariables`.
/// Reusable across both YAML frontmatter and JSON init-directive paths.
public struct RequirementFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.requirement.", "themeVariables."]
    private static let configPrefixes = ["config.requirement."]
    private static let themePrefixes = ["themeVariables."]

    private var config = RequirementDiagramConfig()
    private var theme = RequirementThemeVariables()
    private var hasConfig = false
    private var hasTheme = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        if let key = Self.extractKey(path: path, prefixes: Self.configPrefixes) {
            guard _applyConfig(key: key, value: value) else { return false }
            hasConfig = true
            return true
        }
        if let key = Self.extractKey(path: path, prefixes: Self.themePrefixes) {
            guard _applyTheme(key: key, value: value) else { return false }
            hasTheme = true
            return true
        }
        return false
    }

    private mutating func _applyConfig(key: String, value: FrontmatterValue) -> Bool {
        switch key {
        case "useMaxWidth":
            guard let v = value.bool else { return false }; config.useMaxWidth = v
        case "useWidth":
            guard let v = value.double else { return false }; config.useWidth = v
        case "rect_fill": config.rect_fill = value.string
        case "text_color": config.text_color = value.string
        case "rect_border_size": config.rect_border_size = value.string
        case "rect_border_color": config.rect_border_color = value.string
        case "rect_min_width":
            guard let v = value.double else { return false }; config.rect_min_width = v
        case "rect_min_height":
            guard let v = value.double else { return false }; config.rect_min_height = v
        case "fontSize":
            guard let v = value.double else { return false }; config.fontSize = v
        case "rect_padding":
            guard let v = value.double else { return false }; config.rect_padding = v
        case "line_height":
            guard let v = value.double else { return false }; config.line_height = v
        case "nodeSpacing":
            guard let v = value.double else { return false }; config.nodeSpacing = v
        case "rankSpacing":
            guard let v = value.double else { return false }; config.rankSpacing = v
        case "htmlLabels":
            guard let v = value.bool else { return false }; config.htmlLabels = v
        case "look": config.look = value.string
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(key: String, value: FrontmatterValue) -> Bool {
        let v = value.string
        switch key {
        case "requirementBackground": theme.requirementBackground = v
        case "requirementBorderColor": theme.requirementBorderColor = v
        case "requirementBorderSize": theme.requirementBorderSize = v
        case "requirementTextColor": theme.requirementTextColor = v
        case "relationColor": theme.relationColor = v
        case "relationLabelBackground": theme.relationLabelBackground = v
        case "relationLabelColor": theme.relationLabelColor = v
        case "requirementEdgeLabelBackground": theme.requirementEdgeLabelBackground = v
        case "strokeWidth": theme.strokeWidth = v
        case "nodeTextColor": theme.nodeTextColor = v
        case "textColor": theme.textColor = v
        case "nodeBorder": theme.nodeBorder = v
        case "edgeLabelBackground": theme.edgeLabelBackground = v
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.requirementConfig = config }
        if hasTheme { frontmatter.requirementTheme = theme }
    }
}
