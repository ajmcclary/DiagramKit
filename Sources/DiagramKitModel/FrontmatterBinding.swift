import Foundation
import DiagramKitCommon

// MARK: - Frontmatter Value

/// A single value parsed from YAML frontmatter or a JSON init directive.
/// Provides typed accessors with consistent conversion semantics.
public struct FrontmatterValue: Sendable {
    public let raw: String

    public init(raw: String) {
        self.raw = raw
    }

    /// Case-insensitive boolean conversion ("true" / "false", "1" / "0").
    public var bool: Bool? {
        switch raw.lowercased() {
        case "true", "1": return true
        case "false", "0": return false
        default: return nil
        }
    }

    /// Largest magnitude a numeric setting may have. Every frontmatter and
    /// init-directive number reaches layout arithmetic and SVG formatting
    /// (`config.journey.leftMargin: 1e300` trapped the shared SVG root-tag
    /// builder), so values are clamped here once instead of per binding.
    /// The same bound the gitGraph binding already applied to its padding.
    public static let maxNumericMagnitude: Double = 1e6

    /// Double conversion via `Double(_:)`. `nil` for non-finite values
    /// (`inf`, `nan`, `1e999`); finite values are clamped to
    /// ±`maxNumericMagnitude`.
    public var double: Double? {
        guard let value = Double(raw), value.isFinite else { return nil }
        return min(max(value, -Self.maxNumericMagnitude), Self.maxNumericMagnitude)
    }

    /// Integer conversion via `Int(_:)`, clamped to ±`maxNumericMagnitude`
    /// so a setting such as `bitsPerRow: 9223372036854775807` cannot
    /// overflow layout arithmetic.
    public var int: Int? {
        guard let value = Int(raw) else { return nil }
        let bound = Int(Self.maxNumericMagnitude)
        return min(max(value, -bound), bound)
    }

    /// Raw string value.
    public var string: String { raw }

    /// The raw value when it is safe to interpolate into SVG CSS
    /// (`_isSafeCSSThemeValue`), otherwise `nil`. Use it for theme colours
    /// and lengths that are copied into a `<style>` block.
    public var cssValue: String? { _isSafeCSSThemeValue(raw) ? raw : nil }
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

extension FrontmatterBinding {

    /// Apply a frontmatter key-value pair using prefix matching.
    ///
    /// For each prefix in `prefixes`, if `path` starts with that prefix,
    /// the trailing key is extracted and passed to `apply`. If `apply`
    /// returns `true`, `mark` is set to `true` and the method returns
    /// `true`. If no prefix matches, or `apply` returns `false` for all
    /// matching prefixes, the method returns `false` without modifying
    /// `mark`.
    ///
    /// Usage:
    /// ```swift
    /// public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
    ///     guard let key = Self.extractKey(path: path, prefixes: Self.prefixes) else { return false }
    ///     guard _applyConfig(key: key, value: value) else { return false }
    ///     hasSection = true
    ///     return true
    /// }
    /// ```
    ///
    /// Returns the trailing key after the first matching prefix, or `nil`
    /// if no prefix matches.
    ///
    /// Forwards to ``FrontmatterPrefixMatcher/extractKey(path:prefixes:)``
    /// — the protocol-extension method and the free function used to
    /// implement the same prefix-stripping behavior side by side; the
    /// free function is the source of truth now.
    public static func extractKey(path: String, prefixes: [String]) -> String? {
        FrontmatterPrefixMatcher.extractKey(path: path, prefixes: prefixes)
    }
}
