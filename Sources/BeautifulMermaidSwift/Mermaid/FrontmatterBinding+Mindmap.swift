import Foundation

/// Maps `config.mindmap.*` to `MindmapConfig`.
public struct MindmapFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.mindmap.", "mindmap."]

    private var config = MindmapConfig()
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
