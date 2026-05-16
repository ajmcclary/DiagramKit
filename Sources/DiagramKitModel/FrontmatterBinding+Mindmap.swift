import Foundation

/// Maps `config.mindmap.*` to `MindmapConfig`.
public struct MindmapFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.mindmap.", "mindmap."]

    private var section = SingleSectionBinding<MindmapConfig>(config: MindmapConfig())

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        section.apply(path: path, value: value, prefixes: Self.prefixes) { key, value, config in
            switch key {
            case "padding":          guard let v = value.double else { return false }; config.padding = v
            case "maxNodeWidth":     guard let v = value.double else { return false }; config.maxNodeWidth = v
            case "useMaxWidth":      guard let v = value.bool else { return false }; config.useMaxWidth = v
            case "layoutAlgorithm":  config.layoutAlgorithm = value.string
            default: return false
            }
            return true
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if section.hasSection { frontmatter.perDiagram.mindmap.config = section.config }
    }
}
