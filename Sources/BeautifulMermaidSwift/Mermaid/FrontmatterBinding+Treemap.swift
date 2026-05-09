import Foundation

public struct TreemapFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.treemap."]

    private var config = TreemapDiagramConfig()
    private var hasSection = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        guard path.hasPrefix(Self.prefixes[0]) else { return false }
        hasSection = true
        let key = String(path.dropFirst(Self.prefixes[0].count))
        switch key {
        case "useMaxWidth":     guard let v = value.bool else { return false }; config.useMaxWidth = v
        case "padding":         guard let v = value.double else { return false }; config.padding = v
        case "diagramPadding":  guard let v = value.double else { return false }; config.diagramPadding = v
        case "showValues":      guard let v = value.bool else { return false }; config.showValues = v
        case "nodeWidth":       guard let v = value.double else { return false }; config.nodeWidth = v
        case "nodeHeight":      guard let v = value.double else { return false }; config.nodeHeight = v
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.treemapConfig = config }
    }
}
