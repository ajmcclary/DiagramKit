import Foundation

// MARK: - Frontmatter Value

/// A single value parsed from YAML frontmatter or a JSON init directive.
/// Provides typed accessors with consistent conversion semantics.
public struct FrontmatterValue: Sendable {
    public let raw: String

    public init(raw: String) {
        self.raw = raw
    }

    /// Case-insensitive boolean conversion ("true" / "false").
    public var bool: Bool? {
        switch raw.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    /// Double conversion via `Double(_:)`.
    public var double: Double? { Double(raw) }

    /// Integer conversion via `Int(_:)`.
    public var int: Int? { Int(raw) }

    /// Raw string value.
    public var string: String { raw }
}

// MARK: - Frontmatter Binding Protocol

/// A per-diagram-family binding that maps frontmatter key paths
/// into typed config and theme values. Each diagram family with
/// configurable settings implements this protocol.
///
/// Bindings are used by both the YAML frontmatter path and the
/// JSON init-directive path, ensuring consistent key semantics.
public protocol FrontmatterBinding {
    /// The key prefixes this binding handles (e.g. `["config.sequence."]`).
    static var prefixes: [String] { get }

    /// Apply a single key-value pair. The `path` is the flattened YAML path
    /// (e.g. `"config.sequence.diagramMarginX"`). Returns `true` if the
    /// key was recognized and applied.
    mutating func apply(path: String, value: FrontmatterValue) -> Bool

    /// Write the accumulated config/theme values into the shared
    /// `DiagramFrontmatter` struct. Called after all keys have been applied.
    func commit(into frontmatter: inout DiagramFrontmatter)
}
