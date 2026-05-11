import Foundation

/// Maps `config.mindmap.*` to `MindmapConfig`.
public struct MindmapFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.mindmap.", "mindmap."]

    private var config = MindmapConfig()
    private var hasSection = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        guard let key = Self.extractKey(path: path, prefixes: Self.prefixes) else { return false }
        guard _applyConfig(key: key, value: value) else { return false }
        hasSection = true
        return true
    }

    private mutating func _applyConfig(key: String, value: FrontmatterValue) -> Bool {
        switch key {
        case "padding":          guard let v = value.double else { return false }; config.padding = v
        case "maxNodeWidth":     guard let v = value.double else { return false }; config.maxNodeWidth = v
        case "useMaxWidth":      guard let v = value.bool else { return false }; config.useMaxWidth = v
        case "layoutAlgorithm":  config.layoutAlgorithm = value.string
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.mindmapConfig = config }
    }
}
