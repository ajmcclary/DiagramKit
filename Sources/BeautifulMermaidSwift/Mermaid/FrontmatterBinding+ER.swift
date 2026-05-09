import Foundation

/// Maps `config.er.*` to `ErDiagramConfig`.
public struct ERFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.er.", "er."]

    private var config = ErDiagramConfig()
    private var hasSection = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        if path.hasPrefix(Self.prefixes[0]) {
            hasSection = true
            return _applyConfig(key: String(path.dropFirst(Self.prefixes[0].count)), value: value)
        }
        if path.hasPrefix(Self.prefixes[1]) {
            hasSection = true
            return _applyConfig(key: String(path.dropFirst(Self.prefixes[1].count)), value: value)
        }
        return false
    }

    private mutating func _applyConfig(key: String, value: FrontmatterValue) -> Bool {
        switch key {
        case "titleTopMargin":       guard let v = value.double else { return false }; config.titleTopMargin = v
        case "diagramPadding":       guard let v = value.double else { return false }; config.diagramPadding = v
        case "layoutDirection":      config.layoutDirection = ErDirection(rawValue: value.string.uppercased())
        case "minEntityWidth":       guard let v = value.double else { return false }; config.minEntityWidth = v
        case "minEntityHeight":      guard let v = value.double else { return false }; config.minEntityHeight = v
        case "entityPadding":        guard let v = value.double else { return false }; config.entityPadding = v
        case "nodeSpacing":          guard let v = value.double else { return false }; config.nodeSpacing = v
        case "rankSpacing":          guard let v = value.double else { return false }; config.rankSpacing = v
        case "stroke":               config.stroke = value.string
        case "fill":                 config.fill = value.string
        case "fontSize":             guard let v = value.double else { return false }; config.fontSize = v
        case "useMaxWidth":          guard let v = value.bool else { return false }; config.useMaxWidth = v
        case "erEdgeLabelBackground": config.erEdgeLabelBackground = value.string
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.erConfig = config }
    }
}
