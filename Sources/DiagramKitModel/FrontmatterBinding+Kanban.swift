import Foundation

/// Maps `config.kanban.*` to `KanbanDiagramConfig`.
public struct KanbanFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.kanban.", "kanban."]

    private var config = KanbanDiagramConfig()
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
        case "padding":        guard let v = value.double else { return false }; config.padding = v
        case "sectionWidth":   guard let v = value.double else { return false }; config.sectionWidth = v
        case "ticketBaseUrl":  config.ticketBaseUrl = value.string
        case "useMaxWidth":    guard let v = value.bool else { return false }; config.useMaxWidth = v
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.kanbanConfig = config }
    }
}
