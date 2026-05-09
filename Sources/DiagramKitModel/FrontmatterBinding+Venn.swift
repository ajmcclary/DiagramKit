import Foundation

public struct VennFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.venn."]

    private var config = VennDiagramConfig()
    private var themeVars: [String: String] = [:]
    private var hasConfig = false
    private var hasTheme = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        guard path.hasPrefix(Self.prefixes[0]) else { return false }
        hasConfig = true
        let key = String(path.dropFirst(Self.prefixes[0].count))
        switch key {
        case "useMaxWidth":   guard let v = value.bool else { return false }; config.useMaxWidth = v
        case "width":         guard let v = value.double else { return false }; config.width = v
        case "height":        guard let v = value.double else { return false }; config.height = v
        case "padding":       guard let v = value.double else { return false }; config.padding = v
        case "useDebugLayout": guard let v = value.bool else { return false }; config.useDebugLayout = v
        default: return false
        }
        return true
    }

    /// Venn theme variables are free-form key-value pairs.
    public mutating func applyThemeVar(_ key: String, _ value: FrontmatterValue) {
        hasTheme = true
        themeVars[key] = value.string
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.vennConfig = config }
        if hasTheme { frontmatter.vennThemeVariables = themeVars }
    }
}
