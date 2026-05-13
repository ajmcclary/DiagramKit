import Foundation

// MARK: - FrontmatterPrefixMatcher

/// Free-standing prefix extractor. Mirrors `FrontmatterBinding.extractKey`
/// but isn't tied to the `FrontmatterBinding` protocol, so the runner
/// types below can call it without needing to conform.
public enum FrontmatterPrefixMatcher {
    /// Returns the trailing key after the first matching prefix in
    /// `prefixes`, or `nil` if no prefix matches.
    public static func extractKey(path: String, prefixes: [String]) -> String? {
        for prefix in prefixes where path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }
        return nil
    }
}

// MARK: - SingleSectionBinding

/// Runner for frontmatter bindings that own a single config section
/// (ER, Ishikawa, Journey, Kanban, Class, C4, Mindmap, State today).
/// Owns prefix matching, the `hasSection` flag, and the typed config
/// value. Conforming bindings only supply the prefix list and the
/// per-key applier.
public struct SingleSectionBinding<Config: Sendable>: Sendable {
    public var config: Config
    public var hasSection: Bool = false

    public init(config: Config) {
        self.config = config
    }

    /// Match `path` against `prefixes`. On a match, call `applyConfig`
    /// with the trailing key and the in-place config; on success, flip
    /// `hasSection` and return `true`. Returns `false` when no prefix
    /// matches or when `applyConfig` rejects the key/value.
    public mutating func apply(
        path: String,
        value: FrontmatterValue,
        prefixes: [String],
        applyConfig: (String, FrontmatterValue, inout Config) -> Bool
    ) -> Bool {
        guard let key = FrontmatterPrefixMatcher.extractKey(path: path, prefixes: prefixes) else {
            return false
        }
        guard applyConfig(key, value, &config) else { return false }
        hasSection = true
        return true
    }
}

// MARK: - ConfigThemeBinding

/// Runner for frontmatter bindings that own paired config + theme
/// sections (Architecture, Packet, XYChart, Timeline, Requirement,
/// Venn, Quadrant today). Owns prefix matching for both prefix groups,
/// the `hasConfig`/`hasTheme` flags, and the typed values.
public struct ConfigThemeBinding<Config: Sendable, Theme: Sendable>: Sendable {
    public var config: Config
    public var theme: Theme
    public var hasConfig: Bool = false
    public var hasTheme: Bool = false

    public init(config: Config, theme: Theme) {
        self.config = config
        self.theme = theme
    }

    /// Try the config prefixes first, then the theme prefixes. On a
    /// match, call the corresponding applier and flip the matching
    /// flag. Returns `false` when neither prefix matches or when the
    /// applier rejects the key/value.
    public mutating func apply(
        path: String,
        value: FrontmatterValue,
        configPrefixes: [String],
        themePrefixes: [String],
        applyConfig: (String, FrontmatterValue, inout Config) -> Bool,
        applyTheme: (String, FrontmatterValue, inout Theme) -> Bool
    ) -> Bool {
        if let key = FrontmatterPrefixMatcher.extractKey(path: path, prefixes: configPrefixes) {
            guard applyConfig(key, value, &config) else { return false }
            hasConfig = true
            return true
        }
        if let key = FrontmatterPrefixMatcher.extractKey(path: path, prefixes: themePrefixes) {
            guard applyTheme(key, value, &theme) else { return false }
            hasTheme = true
            return true
        }
        return false
    }
}
