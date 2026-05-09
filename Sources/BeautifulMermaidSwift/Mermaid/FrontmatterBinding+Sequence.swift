import Foundation

/// Maps `config.sequence.*` frontmatter keys to `SequenceDiagramConfig`.
/// Reusable across both YAML frontmatter and JSON init-directive paths.
public struct SequenceFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.sequence."]

    private var config = SequenceDiagramConfig()
    private var hasSection = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        guard path.hasPrefix(Self.prefixes[0]) else { return false }
        hasSection = true
        let key = String(path.dropFirst(Self.prefixes[0].count))
        return _apply(key: key, value: value)
    }

    private mutating func _apply(key: String, value: FrontmatterValue) -> Bool {
        switch key {
        case "diagramMarginX":
            guard let v = value.double else { return false }; config.diagramMarginX = v
        case "diagramMarginY":
            guard let v = value.double else { return false }; config.diagramMarginY = v
        case "actorMargin":
            guard let v = value.double else { return false }; config.actorMargin = v
        case "width":
            guard let v = value.double else { return false }; config.width = v
        case "height":
            guard let v = value.double else { return false }; config.height = v
        case "boxMargin":
            guard let v = value.double else { return false }; config.boxMargin = v
        case "boxTextMargin":
            guard let v = value.double else { return false }; config.boxTextMargin = v
        case "noteMargin":
            guard let v = value.double else { return false }; config.noteMargin = v
        case "messageMargin":
            guard let v = value.double else { return false }; config.messageMargin = v
        case "activationWidth":
            guard let v = value.double else { return false }; config.activationWidth = v
        case "messageAlign":
            guard let align = SequenceDiagramConfig.TextAlign(rawValue: value.string.lowercased()) else { return false }
            config.messageAlign = align
        case "noteAlign":
            guard let align = SequenceDiagramConfig.TextAlign(rawValue: value.string.lowercased()) else { return false }
            config.noteAlign = align
        case "bottomMarginAdj":
            guard let v = value.double else { return false }; config.bottomMarginAdj = v
        case "useMaxWidth":
            guard let v = value.bool else { return false }; config.useMaxWidth = v
        case "mirrorActors":
            guard let v = value.bool else { return false }; config.mirrorActors = v
        case "hideUnusedParticipants":
            guard let v = value.bool else { return false }; config.hideUnusedParticipants = v
        case "rightAngles":
            guard let v = value.bool else { return false }; config.rightAngles = v
        case "showSequenceNumbers":
            guard let v = value.bool else { return false }; config.showSequenceNumbers = v
        case "forceMenus":
            guard let v = value.bool else { return false }; config.forceMenus = v
        case "arrowMarkerAbsolute":
            guard let v = value.bool else { return false }; config.arrowMarkerAbsolute = v
        case "wrap":
            guard let v = value.bool else { return false }; config.wrap = v
        case "wrapPadding":
            guard let v = value.double else { return false }; config.wrapPadding = v
        case "labelBoxWidth":
            guard let v = value.double else { return false }; config.labelBoxWidth = v
        case "labelBoxHeight":
            guard let v = value.double else { return false }; config.labelBoxHeight = v
        case "actorFontFamily": config.actorFontFamily = value.string
        case "actorFontSize":
            guard let v = value.double else { return false }; config.actorFontSize = v
        case "actorFontWeight": config.actorFontWeight = value.string
        case "messageFontFamily": config.messageFontFamily = value.string
        case "messageFontSize":
            guard let v = value.double else { return false }; config.messageFontSize = v
        case "messageFontWeight": config.messageFontWeight = value.string
        case "noteFontFamily": config.noteFontFamily = value.string
        case "noteFontSize":
            guard let v = value.double else { return false }; config.noteFontSize = v
        case "noteFontWeight": config.noteFontWeight = value.string
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.sequenceConfig = config }
    }
}
