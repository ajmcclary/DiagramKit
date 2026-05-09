import Foundation

/// Maps `config.flowchart.*` and `flowchart` curve key to `FlowchartConfig`.
public struct FlowchartFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.flowchart.", "flowchart."]

    private var config = original_src_types.FlowchartConfig()
    private var hasSection = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        // Top-level "flowchart" key sets the curve
        if path == "flowchart" || path == "config.flowchart" {
            hasSection = true
            if !value.string.isEmpty { config.curve = value.string }
            return true
        }
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
        case "curve": config.curve = value.string.isEmpty ? nil : value.string
        case "htmlLabels": guard let v = value.bool else { return false }; config.htmlLabels = v
        case "markdownAutoWrap": guard let v = value.bool else { return false }; config.markdownAutoWrap = v
        case "width": guard let v = value.int else { return false }; config.width = v
        case "inheritDir": guard let v = value.bool else { return false }; config.inheritDir = v
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.flowchartConfig = config }
    }
}
