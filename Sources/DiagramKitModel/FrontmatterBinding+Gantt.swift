import Foundation

/// Maps `config.gantt.*` and top-level `displayMode` to `GanttDiagramConfig`.
public struct GanttFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.gantt.", "gantt."]

    private var binding = SingleSectionBinding<GanttDiagramConfig>(config: GanttDiagramConfig())

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        // Top-level `displayMode` alias. Mermaid accepts the key at the
        // frontmatter root but only the literal "compact" actually changes
        // the rendered output; any other value is silently accepted (so
        // `hasSection` flips, but `config.displayMode` stays at its
        // default). The prefixed form `config.gantt.displayMode` keeps
        // the unrestricted behavior handled inside `_applyConfig` below.
        if path == "displayMode" {
            binding.hasSection = true
            if value.string.lowercased() == "compact" {
                binding.config.displayMode = "compact"
            }
            return true
        }

        return binding.apply(
            path: path,
            value: value,
            prefixes: Self.prefixes,
            applyConfig: { key, value, config in
                switch key {
                case "titleTopMargin":        guard let v = value.double else { return false }; config.titleTopMargin = v
                case "barHeight":             guard let v = value.double else { return false }; config.barHeight = v
                case "barGap":                guard let v = value.double else { return false }; config.barGap = v
                case "topPadding":            guard let v = value.double else { return false }; config.topPadding = v
                case "rightPadding":          guard let v = value.double else { return false }; config.rightPadding = v
                case "leftPadding":           guard let v = value.double else { return false }; config.leftPadding = v
                case "gridLineStartPadding":  guard let v = value.double else { return false }; config.gridLineStartPadding = v
                case "fontSize":              guard let v = value.double else { return false }; config.fontSize = v
                case "sectionFontSize":       guard let v = value.double else { return false }; config.sectionFontSize = v
                case "numberSectionStyles":   guard let v = value.int else { return false }; config.numberSectionStyles = v
                case "axisFormat":            config.axisFormat = value.string
                case "tickInterval":          config.tickInterval = value.string
                case "topAxis":               guard let v = value.bool else { return false }; config.topAxis = v
                case "displayMode":           config.displayMode = value.string
                case "weekday":               config.weekday = value.string
                case "useMaxWidth":           guard let v = value.bool else { return false }; config.useMaxWidth = v
                case "useWidth":              guard let v = value.double else { return false }; config.useWidth = v
                default: return false
                }
                return true
            }
        )
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if binding.hasSection { frontmatter.perDiagram.gantt.config = binding.config }
    }
}
