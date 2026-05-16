import Foundation

/// Maps `config.class.*` and `class.*` to `ClassConfig`.
public struct ClassFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.class.", "class."]

    private var section = SingleSectionBinding<ClassConfig>(config: ClassConfig())

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        section.apply(path: path, value: value, prefixes: Self.prefixes) { key, value, config in
            switch key {
            case "hideEmptyMembersBox":
                guard let v = value.bool else { return false }; config.hideEmptyMembersBox = v
            case "hierarchicalNamespaces":
                guard let v = value.bool else { return false }; config.hierarchicalNamespaces = v
            case "padding":
                guard let v = value.double else { return false }; config.padding = v
            default: return false
            }
            return true
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if section.hasSection { frontmatter.perDiagram.classDiagram.config = section.config }
    }
}
