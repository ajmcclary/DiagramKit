import Foundation

/// Maps `config.kanban.*` to `KanbanDiagramConfig`.
public struct KanbanFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.kanban.", "kanban."]

    private var section = SingleSectionBinding<KanbanDiagramConfig>(config: KanbanDiagramConfig())

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        section.apply(path: path, value: value, prefixes: Self.prefixes) { key, value, config in
            switch key {
            case "padding":        guard let v = value.double else { return false }; config.padding = v
            case "sectionWidth":   guard let v = value.double else { return false }; config.sectionWidth = v
            case "ticketBaseUrl":  config.ticketBaseUrl = value.string
            case "useMaxWidth":    guard let v = value.bool else { return false }; config.useMaxWidth = v
            default: return false
            }
            return true
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if section.hasSection { frontmatter.kanbanConfig = section.config }
    }
}
