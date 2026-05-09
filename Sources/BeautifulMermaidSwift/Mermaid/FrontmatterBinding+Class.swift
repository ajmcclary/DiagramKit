import Foundation

/// Maps `config.class.*` and `class.*` to `ClassConfig`.
public struct ClassFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.class.", "class."]

    private var config = ClassConfig()
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

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.classConfig = config }
    }
}
