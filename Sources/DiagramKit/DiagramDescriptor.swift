import Foundation
import DiagramKitModel
import DiagramKitCommon

// MARK: - Diagram Header

/// The first meaningful statement from a Mermaid diagram source.
/// Used by `DiagramDescriptor.matches` for routing decisions.
public struct DiagramHeader: Sendable {
    /// The raw first statement (untrimmed, case-preserved).
    public let raw: String

    /// Lowercased version for prefix matching.
    public var normalized: String { raw.lowercased() }

    /// The raw text split into lines.
    public let rawLines: [String]

    public init(raw: String, rawLines: [String] = []) {
        self.raw = raw
        self.rawLines = rawLines
    }

    /// Convenience: detect from a preprocessed source string.
    public static func detect(from processedSource: String) -> DiagramHeader {
        // If the source begins with frontmatter (`---` ... `---`), pre-strip
        // it so the registry sees the diagram body. Multiple contiguous
        // frontmatter blocks are also stripped.
        let stripped = _stripLeadingFrontmatter(from: processedSource)
        let rawLines = DiagramSourceNormalizer.rawLines(stripped)
        // Skip blank lines AND `%%` comment lines — the registry should match
        // the first content-bearing line of the diagram.
        let firstLine = rawLines.first(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasPrefix("%%")
        })?.trimmingCharacters(in: .whitespaces) ?? ""
        return DiagramHeader(raw: firstLine, rawLines: rawLines)
    }
}

/// Strips one or more leading `---`-bracketed frontmatter blocks from
/// `source` and returns whatever remains. Used by `DiagramHeader.detect`
/// so registry matching ignores YAML frontmatter.
private func _stripLeadingFrontmatter(from source: String) -> String {
    let normalized = source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var cursor = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? lines.endIndex
    var lastEnd = -1
    while cursor < lines.endIndex,
          lines[cursor].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
        guard let endIdx = lines[(cursor + 1)...].firstIndex(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
        }) else { break }
        lastEnd = endIdx
        cursor = endIdx + 1
        while cursor < lines.endIndex,
              lines[cursor].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cursor += 1
        }
    }
    if lastEnd >= 0 {
        return lines[(lastEnd + 1)...].joined(separator: "\n")
    }
    return source
}

// MARK: - Diagram Descriptor

/// Describes one diagram family: how to detect it, parse it, and lay it out.
/// New diagram types are added by appending a descriptor to `DiagramRegistry.all`.
public struct DiagramDescriptor: Sendable {
    public let type: DiagramType

    /// Returns `true` when `header` matches this diagram family.
    /// Order matters: `DiagramRegistry.all` is evaluated in array order;
    /// the first match wins.
    public let matches: @Sendable (DiagramHeader) -> Bool

    /// Parse the preprocessed source into a `DiagramDocument`.
    /// `frontmatter` is the parsed and bound frontmatter (optional).
    public let parse: @Sendable (String, DiagramFrontmatter?) throws -> DiagramDocument

    /// Layout a parsed graph into a `PositionedGraph`.
    public let layout: @Sendable (DiagramDocument, LayoutConfig) throws -> PositionedGraph

    public init(
        type: DiagramType,
        matches: @escaping @Sendable (DiagramHeader) -> Bool,
        parse: @escaping @Sendable (String, DiagramFrontmatter?) throws -> DiagramDocument,
        layout: @escaping @Sendable (DiagramDocument, LayoutConfig) throws -> PositionedGraph
    ) {
        self.type = type
        self.matches = matches
        self.parse = parse
        self.layout = layout
    }
}

// MARK: - Diagram Registry

// MARK: Mermaid-family diagram routing
//
// DiagramRegistry and DiagramDescriptor are Mermaid-specific dispatch types.
// Format-agnostic import dispatch goes through the new
// `DiagramSourceImporter` protocol + `ImporterRegistry` (see DiagramKitImport).
// These types remain public for backward compatibility during the transition.

/// Mermaid-family diagram registry.
/// For multi-format import dispatch, use `ImporterRegistry` + `DiagramLoader`.
public enum DiagramRegistry {

    /// All registered diagram descriptors, in priority order.
    /// Detection is first-match-wins, so narrower prefixes must come before
    /// broader ones (e.g. `stateDiagram-v2` before `stateDiagram`).
    public static let all: [DiagramDescriptor] = [
        // --- Narrowest / most-specific first ---
        _journey,
        _sequenceDiagram,
        _classDiagram,
        _erDiagram,
        _xyChart,
        _pie,
        _gantt,
        _quadrantChart,
        _gitGraph,
        _requirement,
        _mindmap,
        _timeline,
        _sankey,
        _block,
        _packet,
        _kanban,
        _architecture,
        _radar,
        _treemap,
        _venn,
        _ishikawa,
        _treeView,
        _eventModeling,
        _wardley,
        _zenuml,
        _c4,
        // --- Broadest / fallback ---
        _stateDiagram,  // must come after stateDiagram-v2 handled inside
        _flowchart,     // fallback for unrecognized headers
    ]

    /// Find the descriptor matching `header`, or the flowchart fallback.
    public static func detect(_ header: DiagramHeader) -> DiagramDescriptor {
        all.first { $0.matches(header) } ?? _flowchart
    }

    /// Convenience: detect from a preprocessed source string.
    public static func detect(from source: String) -> DiagramDescriptor {
        detect(DiagramHeader.detect(from: source))
    }

    /// The number of registered descriptors. Should equal `DiagramType.allCases.count`.
    public static var registeredCount: Int { all.count }

    /// Look up a descriptor by `DiagramType`. Throws `DiagramStructuralError` if
    /// no descriptor matches the given type.
    public static func descriptor(for type: DiagramType) throws -> DiagramDescriptor {
        guard let descriptor = all.first(where: { $0.type == type }) else {
            throw DiagramStructuralError.payloadMismatch(type)
        }
        return descriptor
    }

    /// Validates that every `DiagramType` case has a corresponding descriptor.
    /// Call once at app start or in a test. Returns `true` if the registry is
    /// consistent with the `DiagramType` enum.
    public static func validate() -> Bool {
        let typeCount = DiagramType.allCases.count
        guard registeredCount == typeCount else {
            _reportDiagramIssue(
                "DiagramRegistry.validate: \(registeredCount) descriptors registered, but DiagramType has \(typeCount) cases. Add missing descriptors or remove stale enum cases."
            )
            return false
        }
        // Extra safety: ensure every DiagramType case has a descriptor by matching types.
        var seen = Set<DiagramType>()
        for d in all { seen.insert(d.type) }
        let missing = Set(DiagramType.allCases).subtracting(seen)
        if !missing.isEmpty {
            _reportDiagramIssue(
                "DiagramRegistry.validate: missing descriptors for types: \(missing.map(\.rawValue).sorted().joined(separator: ", "))"
            )
            return false
        }
        return true
    }
}

// MARK: - Descriptor Definitions
//
// Per-family descriptor bodies live in `DiagramRegistry+<Family>.swift`
// extensions (one file per diagram type). This central file keeps only
// the abstractions and the ordered `all` array.

// MARK: - Error type for payload mismatches

public struct DiagramStructuralError: Error, LocalizedError {
    public let expectedType: DiagramType

    public static func payloadMismatch(_ type: DiagramType) -> DiagramStructuralError {
        DiagramStructuralError(expectedType: type)
    }

    public var errorDescription: String? {
        "DiagramStructuralError: expected payload of type \(expectedType.rawValue)"
    }
}

// MARK: - Phase 0 backward-compat deprecated alias

@available(*, deprecated, renamed: "DiagramStructuralError", message: "Will be removed in the next major version.")
public typealias MermaidStructuralError = DiagramStructuralError
