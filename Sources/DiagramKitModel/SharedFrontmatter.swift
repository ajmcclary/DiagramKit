import Foundation

// MARK: - SharedFrontmatter

/// Frontmatter values that apply across all diagram families.
public struct SharedFrontmatter: Sendable {
    public var title: String?
    public var diagramTitle: String?
    public var layout: String?
    public var look: String?
    public var theme: String?
    public var htmlLabels: Bool?
    public var fontSize: Double?
    public var securityLevel: String?

    public init() {}
}
