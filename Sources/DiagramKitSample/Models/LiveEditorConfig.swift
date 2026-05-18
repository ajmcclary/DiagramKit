//
//  LiveEditorConfig.swift
//  DiagramPlayground
//
//  Parses raw config JSON into a permissive JSONValue tree, extracts
//  known DiagramKit settings (theme, layout), preserves unknown keys
//  for round-trips, and surfaces mapping diagnostics.
//

import Foundation
import DiagramKitModel

// MARK: - LiveEditorConfig

/// Parsed representation of the user's config JSON.
///
/// Created by ``parse(_:)`` from the raw JSON string stored in
/// ``LiveEditorState/configJSON``. Extraction is best-effort:
/// - Known keys (theme, layout) are mapped to native DiagramKit types.
/// - Unknown keys are preserved verbatim so they survive save/share/history.
/// - Invalid JSON produces `nil` and an error message.
public struct LiveEditorConfig: Sendable, Equatable {

    // MARK: - Raw input

    /// The original JSON string.
    public let rawJSON: String

    /// The fully-decoded JSON tree (nil when JSON is invalid).
    public let jsonTree: JSONValue?

    // MARK: - Extracted known keys

    /// The config-level `theme` value, if found (e.g. `"dark"`, `"default"`).
    /// Resolved through fuzzy name matching to a DiagramKit theme name.
    public let themeName: String?

    /// Layout parameters extracted from the config tree.
    public let layoutConfig: LayoutConfig

    /// Keys present in the JSON that are not recognized as native settings.
    /// Preserved so round-trips through save/share/history are exact.
    public let unknownKeys: [String: JSONValue]

    // MARK: - Diagnostics

    /// Post-sanitization warnings (from ``ConfigSanitizer``).
    public var warnings: [ConfigSanitizer.Warning] = []

    /// Error message when JSON parsing fails.
    public let parseError: String?

    // MARK: - Init

    public init(
        rawJSON: String,
        jsonTree: JSONValue?,
        themeName: String?,
        layoutConfig: LayoutConfig,
        unknownKeys: [String: JSONValue],
        warnings: [ConfigSanitizer.Warning] = [],
        parseError: String? = nil
    ) {
        self.rawJSON = rawJSON
        self.jsonTree = jsonTree
        self.themeName = themeName
        self.layoutConfig = layoutConfig
        self.unknownKeys = unknownKeys
        self.warnings = warnings
        self.parseError = parseError
    }

    // MARK: - Parsing

    /// Parse raw config JSON into a ``LiveEditorConfig``.
    ///
    /// Returns a config with `parseError` set when JSON is invalid,
    /// but does not throw — the caller should inspect `parseError`.
    public static func parse(_ json: String) -> LiveEditorConfig {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty / only whitespace → no config
        guard !trimmed.isEmpty else {
            return LiveEditorConfig(
                rawJSON: json,
                jsonTree: nil,
                themeName: nil,
                layoutConfig: LayoutConfig(),
                unknownKeys: [:],
                warnings: []
            )
        }

        // Parse JSON
        guard let data = trimmed.data(using: .utf8) else {
            return LiveEditorConfig(
                rawJSON: json,
                jsonTree: nil,
                themeName: nil,
                layoutConfig: LayoutConfig(),
                unknownKeys: [:],
                parseError: "Config is not valid UTF-8"
            )
        }

        let tree: JSONValue
        do {
            tree = try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            return LiveEditorConfig(
                rawJSON: json,
                jsonTree: nil,
                themeName: nil,
                layoutConfig: LayoutConfig(),
                unknownKeys: [:],
                parseError: "Invalid JSON: \(error.localizedDescription)"
            )
        }

        // Extract known keys
        let themeName = extractTheme(from: tree)
        let layoutConfig = extractLayout(from: tree)
        let unknownKeys = collectUnknownKeys(from: tree)

        return LiveEditorConfig(
            rawJSON: json,
            jsonTree: tree,
            themeName: themeName,
            layoutConfig: layoutConfig,
            unknownKeys: unknownKeys
        )
    }

    // MARK: - Key extraction

    /// Number of recognized keys extracted from the config.
    public var recognizedKeyCount: Int {
        var count = 0
        if themeName != nil { count += 1 }
        // Layout counts as 1 group (4 individual params)
        if layoutConfig != LayoutConfig() { count += 1 }
        return count
    }

    /// Total number of top-level keys in the config.
    public var totalKeyCount: Int {
        guard case .object(let dict) = jsonTree else { return 0 }
        return dict.count
    }

    /// Number of keys that aren't recognized.
    public var unknownKeyCount: Int {
        unknownKeys.count
    }

    // MARK: - Private extraction helpers

    /// Extract a theme name from the config tree.
    ///
    /// Looks for `theme` key at any level (mermaid-js config style).
    /// Fuzzy-matches against DiagramKit's known theme names.
    private static func extractTheme(from tree: JSONValue) -> String? {
        // Check top-level theme key
        if case .object(let dict) = tree, let themeValue = dict["theme"] {
            if let themeString = themeValue.stringValue {
                return resolveThemeName(themeString)
            }
        }

        // Check nested in `themeVariables` object
        if case .object(let dict) = tree,
           case .object(let themeVars) = dict["themeVariables"],
           themeVars["background"]?.stringValue != nil {
            // If themeVariables has a background color, don't override theme
            return nil
        }

        return nil
    }

    /// Fuzzy-resolve a user-supplied theme string to a DiagramKit theme name.
    ///
    /// Matches case-insensitively, with common aliases:
    /// - `"dark"` → `"Zinc Dark"`
    /// - `"default"` → `"Zinc Light"`
    /// - `"light"` → `"Zinc Light"`
    private static func resolveThemeName(_ raw: String) -> String? {
        let normalized = raw.lowercased().trimmingCharacters(in: .whitespaces)

        // Direct match against DiagramKit theme names
        if let direct = DiagramTheme.theme(named: raw) {
            // Reverse-lookup the display name
            for (name, theme) in DiagramTheme.allThemes {
                if theme == direct { return name }
            }
        }

        // Common aliases
        switch normalized {
        case "dark": return "Zinc Dark"
        case "light", "default": return "Zinc Light"
        default: break
        }

        // Fuzzy: try removing dashes/underscores and matching substrings
        let fuzzy = normalized.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        for (name, _) in DiagramTheme.allThemes {
            let nameFuzzy = name.lowercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: " ", with: "")
            if nameFuzzy.contains(fuzzy) || fuzzy.contains(nameFuzzy) {
                return name
            }
        }

        // Not found — return nil (won't override theme; unknown key preserved)
        return nil
    }

    /// Extract layout parameters from the config tree.
    ///
    /// Looks for top-level layout keys (`padding`, `nodeSpacing`,
    /// `layerSpacing`, `componentSpacing`) or diagram-type-specific
    /// nesting (e.g. `flowchart.padding`).
    private static func extractLayout(from tree: JSONValue) -> LayoutConfig {
        guard case .object(let dict) = tree else {
            return LayoutConfig()
        }

        // Top-level layout keys
        let padding = dict["padding"]?.doubleValue
        let nodeSpacing = dict["nodeSpacing"]?.doubleValue
        let layerSpacing = dict["layerSpacing"]?.doubleValue
        let componentSpacing = dict["componentSpacing"]?.doubleValue

        // Also check nested under common diagram type keys
        let nestedPadding = dict["flowchart"]?.objectValue?["padding"]?.doubleValue
            ?? dict["config"]?.objectValue?["padding"]?.doubleValue

        return LayoutConfig(
            padding: padding ?? nestedPadding ?? 40,
            nodeSpacing: nodeSpacing ?? 28,
            layerSpacing: layerSpacing ?? 48,
            componentSpacing: componentSpacing ?? 20
        )
    }

    /// Collect keys from the tree that aren't recognized as native settings.
    ///
    /// Recognized top-level keys:
    /// - `theme`, `themeVariables` (theme extraction)
    /// - `padding`, `nodeSpacing`, `layerSpacing`, `componentSpacing` (layout)
    /// - `flowchart`, `config` (layout nesting containers, inspected but not marked unknown)
    private static let recognizedTopLevelKeys: Set<String> = [
        "theme", "themeVariables",
        "padding", "nodeSpacing", "layerSpacing", "componentSpacing",
        "flowchart", "config"
    ]

    private static func collectUnknownKeys(from tree: JSONValue) -> [String: JSONValue] {
        guard case .object(let dict) = tree else { return [:] }
        var unknowns: [String: JSONValue] = [:]

        for (key, value) in dict {
            if recognizedTopLevelKeys.contains(key) {
                // For recognized container keys (flowchart, config),
                // inspect children for unknown sub-keys
                if let subDict = value.objectValue {
                    for (subKey, subValue) in subDict {
                        let qualifiedKey = "\(key).\(subKey)"
                        if !Self.isLayoutKey(subKey) && subKey != "padding" {
                            unknowns[qualifiedKey] = subValue
                        }
                    }
                }
            } else {
                unknowns[key] = value
            }
        }

        return unknowns
    }

    private static func isLayoutKey(_ key: String) -> Bool {
        ["padding", "nodeSpacing", "layerSpacing", "componentSpacing"].contains(key)
    }
}
