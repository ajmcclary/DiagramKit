import Foundation

/// A single entry in the diagram corpus (test-diagrams.json).
/// Decodes both the legacy single-format schema and the new multi-format schema.
public struct CorpusEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let name: String

    /// The primary Mermaid source. Always populated, either from the
    /// top-level `source` field (legacy) or from `sources["mermaid"]`.
    /// When both exist they must be identical (enforced by post-decode validation).
    public let source: String

    /// Format-to-source map. Keys are normalized lowercase format identifiers
    /// (e.g. "mermaid", "d2", "graphviz").
    public let sources: [String: String]?

    /// Format identifier to expected importer name for routing tests.
    public let expectedImporters: [String: String]?

    /// Expected non-fatal diagnostics.
    public let expectedDiagnostics: [ExpectedDiagnostic]?

    /// Human note for unsupported features.
    public let unsupportedNote: String?

    /// Format names to skip in snapshot tests.
    public let skipSnapshots: [String]?

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, category, name, source
        case sources
        case expectedImporters
        case expectedDiagnostics
        case unsupportedNote
        case skipSnapshots
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        name = try container.decode(String.self, forKey: .name)
        sources = try Self.normalizedFormatMap(
            container.decodeIfPresent([String: String].self, forKey: .sources)
        )
        expectedImporters = try Self.normalizedFormatMap(
            container.decodeIfPresent([String: String].self, forKey: .expectedImporters)
        )
        expectedDiagnostics = try container.decodeIfPresent(
            [ExpectedDiagnostic].self, forKey: .expectedDiagnostics
        )
        unsupportedNote = try container.decodeIfPresent(String.self, forKey: .unsupportedNote)
        skipSnapshots = try container
            .decodeIfPresent([String].self, forKey: .skipSnapshots)?
            .map(Self.normalizedFormat)

        // Decode the top-level `source` and compare against `sources["mermaid"]`
        // when both are present. They must be identical; mismatches are a
        // decoding error (ambiguous canonical source).
        let topLevelSource = try container.decode(String.self, forKey: .source)
        if let sources {
            guard let mermaidSource = sources["mermaid"] else {
                throw CorpusEntryError.sourcesMissingMermaid(id: id)
            }
            if mermaidSource != topLevelSource {
                throw CorpusEntryError.sourceMermaidMismatch(id: id)
            }
            source = mermaidSource
        } else {
            source = topLevelSource
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(name, forKey: .name)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(sources, forKey: .sources)
        try container.encodeIfPresent(expectedImporters, forKey: .expectedImporters)
        try container.encodeIfPresent(expectedDiagnostics, forKey: .expectedDiagnostics)
        try container.encodeIfPresent(unsupportedNote, forKey: .unsupportedNote)
        try container.encodeIfPresent(skipSnapshots, forKey: .skipSnapshots)
    }

    // MARK: - Validation

    /// Post-decode validation: when both `source` and `sources["mermaid"]`
    /// are present, they must be identical.
    public func validate() throws {
        if let mermaidSource = sources?["mermaid"], mermaidSource != source {
            throw CorpusEntryError.sourceMermaidMismatch(id: id)
        }
    }

    // MARK: - Helpers

    /// Source text for a given format name.
    /// Special-cases "mermaid" to fall back to the legacy `source` property
    /// when `sources` is nil, preserving the invariant that Mermaid source
    /// is always available.
    public func source(for format: String) -> String? {
        let key = Self.normalizedFormat(format)
        if key == "mermaid" {
            return sources?[key] ?? source
        }
        return sources?[key]
    }

    /// All format names present in sources.
    public var availableFormats: [String] {
        sources?.keys.sorted() ?? ["mermaid"]
    }

    /// Whether this entry carries a source for the given format.
    public func hasSource(for format: String) -> Bool {
        source(for: format) != nil
    }

    /// Whether snapshots should be skipped for the given format.
    public func shouldSkipSnapshot(for format: String) -> Bool {
        skipSnapshots?.contains(Self.normalizedFormat(format)) ?? false
    }

    private static func normalizedFormat(_ format: String) -> String {
        format.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizedFormatMap(
        _ values: [String: String]?
    ) throws -> [String: String]? {
        guard let values else { return nil }

        var normalized: [String: String] = [:]
        for (key, value) in values {
            let normalizedKey = normalizedFormat(key)
            if normalized[normalizedKey] != nil {
                throw CorpusEntryError.duplicateFormatKey(key: normalizedKey)
            }
            normalized[normalizedKey] = value
        }
        return normalized
    }
}

// MARK: - CorpusEntryError

public enum CorpusEntryError: Error, CustomStringConvertible, Sendable {
    case sourceMermaidMismatch(id: String)
    case sourcesMissingMermaid(id: String)
    case duplicateFormatKey(key: String)

    public var description: String {
        switch self {
        case .sourceMermaidMismatch(let id):
            return "Entry \"\(id)\": top-level `source` differs from `sources[\"mermaid\"]`"
        case .sourcesMissingMermaid(let id):
            return "Entry \"\(id)\": `sources` must include a `mermaid` source"
        case .duplicateFormatKey(let key):
            return "Duplicate format key after normalization: \"\(key)\""
        }
    }
}

// MARK: - ExpectedDiagnostic

/// Expected diagnostic shape in the fixture.
public struct ExpectedDiagnostic: Codable, Sendable, Equatable {
    public let severity: String
    public let messageContains: String?
}

// MARK: - CorpusFile

/// Top-level container for test-diagrams.json.
public struct CorpusFile: Codable, Sendable {
    public let version: String?
    public let description: String?
    public let diagrams: [CorpusEntry]
}
