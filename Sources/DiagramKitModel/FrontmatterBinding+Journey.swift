import Foundation

/// Maps `config.journey.*` to `JourneyDiagramConfig`.
public struct JourneyFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.journey.", "journey."]

    private var section = SingleSectionBinding<JourneyDiagramConfig>(config: JourneyDiagramConfig())

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        section.apply(path: path, value: value, prefixes: Self.prefixes) { key, value, config in
            switch key {
            case "diagramMarginX":   guard let v = value.double else { return false }; config.diagramMarginX = v
            case "diagramMarginY":   guard let v = value.double else { return false }; config.diagramMarginY = v
            case "leftMargin":       guard let v = value.double else { return false }; config.leftMargin = v
            case "maxLabelWidth":    guard let v = value.double else { return false }; config.maxLabelWidth = v
            case "width":            guard let v = value.double else { return false }; config.width = v
            case "height":           guard let v = value.double else { return false }; config.height = v
            case "boxMargin":        guard let v = value.double else { return false }; config.boxMargin = v
            case "boxTextMargin":    guard let v = value.double else { return false }; config.boxTextMargin = v
            case "noteMargin":       guard let v = value.double else { return false }; config.noteMargin = v
            case "messageMargin":    guard let v = value.double else { return false }; config.messageMargin = v
            case "messageAlign":     config.messageAlign = value.string
            case "bottomMarginAdj":  guard let v = value.double else { return false }; config.bottomMarginAdj = v
            case "useMaxWidth":      guard let v = value.bool else { return false }; config.useMaxWidth = v
            case "rightAngles":      guard let v = value.bool else { return false }; config.rightAngles = v
            case "taskFontSize":     guard let v = value.double else { return false }; config.taskFontSize = v
            case "taskFontFamily":   config.taskFontFamily = value.string
            case "taskMargin":       guard let v = value.double else { return false }; config.taskMargin = v
            case "activationWidth":  guard let v = value.double else { return false }; config.activationWidth = v
            case "textPlacement":    config.textPlacement = value.string
            case "actorColours":
                if let arr = _parseYamlStringArray(value.string) { config.actorColours = arr }
            case "sectionFills":
                if let arr = _parseYamlStringArray(value.string) { config.sectionFills = arr }
            case "sectionColours":
                if let arr = _parseYamlStringArray(value.string) { config.sectionColours = arr }
            case "titleColor":       config.titleColor = value.string
            case "titleFontFamily":  config.titleFontFamily = value.string
            case "titleFontSize":    config.titleFontSize = value.string
            case "faceColor":        config.faceColor = value.string
            default: return false
            }
            return true
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if section.hasSection { frontmatter.journeyConfig = section.config }
    }
}
