import Foundation

public struct IshikawaFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.ishikawa."]

    private var config = IshikawaDiagramConfig()
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
