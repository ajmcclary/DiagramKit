import Foundation

// MARK: - DiagramFamilyFrontmatter
//
// Single per-family slot used by `PerDiagramFrontmatter`. Each diagram
// family stores its parsed config (and, when applicable, theme) in one
// of these. Families that don't have a theme parameterize on `Never`,
// which is `Sendable` and uninhabited — `theme` for those families is
// permanently `nil`.

public struct DiagramFamilyFrontmatter<Config: Sendable, Theme: Sendable>: Sendable {
    public var config: Config?
    public var theme: Theme?

    public init(config: Config? = nil, theme: Theme? = nil) {
        self.config = config
        self.theme = theme
    }
}
