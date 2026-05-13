import Foundation

/// Maps `config.state.*` to `StateConfig`.
public struct StateFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.state.", "state."]

    private var section = SingleSectionBinding<original_src_types.StateConfig>(config: original_src_types.StateConfig())

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        section.apply(path: path, value: value, prefixes: Self.prefixes) { key, value, config in
            switch key {
            case "titleTopMargin":          guard let v = value.double else { return false }; config.titleTopMargin = v
            case "useMaxWidth":             guard let v = value.bool else { return false }; config.useMaxWidth = v
            case "defaultRenderer":         config.defaultRenderer = value.string
            case "arrowMarkerAbsolute":     guard let v = value.bool else { return false }; config.arrowMarkerAbsolute = v
            case "dividerMargin":           guard let v = value.double else { return false }; config.dividerMargin = v
            case "sizeUnit":                guard let v = value.double else { return false }; config.sizeUnit = v
            case "padding":                 guard let v = value.double else { return false }; config.padding = v
            case "textHeight":              guard let v = value.double else { return false }; config.textHeight = v
            case "titleShift":              guard let v = value.double else { return false }; config.titleShift = v
            case "noteMargin":              guard let v = value.double else { return false }; config.noteMargin = v
            case "nodeSpacing":             guard let v = value.int else { return false }; config.nodeSpacing = v
            case "rankSpacing":             guard let v = value.int else { return false }; config.rankSpacing = v
            case "forkWidth":               guard let v = value.double else { return false }; config.forkWidth = v
            case "forkHeight":              guard let v = value.double else { return false }; config.forkHeight = v
            case "miniPadding":             guard let v = value.double else { return false }; config.miniPadding = v
            case "fontSizeFactor":          guard let v = value.double else { return false }; config.fontSizeFactor = v
            case "fontSize":                guard let v = value.double else { return false }; config.fontSize = v
            case "labelHeight":             guard let v = value.double else { return false }; config.labelHeight = v
            case "edgeLengthFactor":        config.edgeLengthFactor = value.string
            case "compositTitleSize":       guard let v = value.double else { return false }; config.compositTitleSize = v
            case "radius":                  guard let v = value.double else { return false }; config.radius = v
            case "scaleWidth":              guard let v = value.int else { return false }; config.scaleWidth = v
            case "hideEmptyDescription":    guard let v = value.bool else { return false }; config.hideEmptyDescription = v
            default: return false
            }
            return true
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if section.hasSection { frontmatter.stateConfig = section.config }
    }
}
