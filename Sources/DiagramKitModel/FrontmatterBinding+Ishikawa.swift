import Foundation

public struct IshikawaFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.ishikawa."]

    private var config = IshikawaDiagramConfig()
    private var hasSection = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        guard path.hasPrefix(Self.prefixes[0]) else { return false }
        hasSection = true
        let key = String(path.dropFirst(Self.prefixes[0].count))
        switch key {
        case "diagramPadding": guard let v = value.double else { return false }; config.diagramPadding = v
        case "useMaxWidth":   guard let v = value.bool else { return false }; config.useMaxWidth = v
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.ishikawaConfig = config }
    }
}
