import Foundation

public struct IshikawaFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.ishikawa."]

    private var section = SingleSectionBinding<IshikawaDiagramConfig>(config: IshikawaDiagramConfig())

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        section.apply(path: path, value: value, prefixes: Self.prefixes) { key, value, config in
            switch key {
            case "diagramPadding": guard let v = value.double else { return false }; config.diagramPadding = v
            case "useMaxWidth":   guard let v = value.bool else { return false }; config.useMaxWidth = v
            default: return false
            }
            return true
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if section.hasSection { frontmatter.perDiagram.ishikawa.config = section.config }
    }
}
