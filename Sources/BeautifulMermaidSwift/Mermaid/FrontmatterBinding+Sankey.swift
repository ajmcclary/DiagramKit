import Foundation

/// Maps `config.sankey.*` to `SankeyDiagramConfig`.
public struct SankeyFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.sankey.", "sankey."]

    private var config = SankeyDiagramConfig()
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
        // nodeColors is a dictionary: nodeColors.<name> = <color>
        if key.hasPrefix("nodeColors.") {
            let colorName = String(key.dropFirst("nodeColors.".count))
            config.nodeColors[colorName] = value.string
            return true
        }
        switch key {
        case "width":          guard let v = value.double else { return false }; config.width = v
        case "height":         guard let v = value.double else { return false }; config.height = v
        case "linkColor":
            switch value.string.lowercased() {
            case "source":   config.linkColor = .source
            case "target":   config.linkColor = .target
            case "gradient": config.linkColor = .gradient
            default:         config.linkColor = .fixed(value.string)
            }
        case "nodeAlignment":
            config.nodeAlignment = SankeyNodeAlignment(rawValue: value.string.lowercased()) ?? config.nodeAlignment
        case "useMaxWidth":    guard let v = value.bool else { return false }; config.useMaxWidth = v
        case "showValues":     guard let v = value.bool else { return false }; config.showValues = v
        case "prefix":         config.prefix = value.string
        case "suffix":         config.suffix = value.string
        case "nodeWidth":      guard let v = value.double else { return false }; config.nodeWidth = v
        case "nodePadding":    guard let v = value.double else { return false }; config.nodePadding = v
        case "labelStyle":
            config.labelStyle = SankeyLabelStyle(rawValue: value.string.lowercased()) ?? config.labelStyle
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.sankeyConfig = config }
    }
}
