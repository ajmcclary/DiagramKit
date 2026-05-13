//
//  SourceFormat.swift
//  DiagramPlayground
//
//  UI-facing enum mirroring `DiagramFormatID` for the multi-format
//  playground. Persisted in `LiveEditorState` so the active format
//  round-trips through save/restore.
//

import Foundation
import DiagramKit
import DiagramKitExport
import DiagramKitImport

/// Source format the editor is currently displaying.
///
/// Maps 1:1 to `DiagramFormatID` for dispatch and to the `sources`
/// dictionary keys in `test-diagrams.json` for sample loading.
public enum SourceFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case mermaid
    case d2
    case graphviz
    case structurizr
    case plantuml

    public var id: String { rawValue }

    /// Human-readable label for menus and tabs.
    public var displayName: String {
        switch self {
        case .mermaid:     return "Mermaid"
        case .d2:          return "D2"
        case .graphviz:    return "Graphviz DOT"
        case .structurizr: return "Structurizr"
        case .plantuml:    return "PlantUML"
        }
    }

    /// Short tag suitable for chips and badges.
    public var shortName: String {
        switch self {
        case .mermaid:     return "Mermaid"
        case .d2:          return "D2"
        case .graphviz:    return "DOT"
        case .structurizr: return "Structurizr"
        case .plantuml:    return "PlantUML"
        }
    }

    /// Suggested file extension for exports.
    public var fileExtension: String {
        switch self {
        case .mermaid:     return "mmd"
        case .d2:          return "d2"
        case .graphviz:    return "dot"
        case .structurizr: return "dsl"
        case .plantuml:    return "puml"
        }
    }

    /// Format ID used by the library's exporter/importer dispatch.
    public var formatID: DiagramFormatID {
        switch self {
        case .mermaid:     return .mermaid
        case .d2:          return .d2
        case .graphviz:    return .graphviz
        case .structurizr: return .structurizr
        case .plantuml:    return .plantuml
        }
    }

    /// All file extensions (lowercase, no leading dot) commonly used for
    /// this format. Includes ``fileExtension`` plus widely accepted aliases.
    public var fileExtensions: [String] {
        switch self {
        case .mermaid:     return ["mmd", "mermaid"]
        case .d2:          return ["d2"]
        case .graphviz:    return ["dot", "gv"]
        case .structurizr: return ["dsl"]
        case .plantuml:    return ["puml", "plantuml", "iuml", "pu"]
        }
    }

    /// Map a file extension (with or without a leading dot, case-insensitive)
    /// to a `SourceFormat`, or `nil` when the extension is unknown.
    public static func from(fileExtension ext: String) -> SourceFormat? {
        let normalized = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !normalized.isEmpty else { return nil }
        return allCases.first { $0.fileExtensions.contains(normalized) }
    }

    /// Sniff a `SourceFormat` from a filename or URL path. Returns `nil`
    /// when the path carries no extension or an unrecognized one.
    public static func from(filename: String) -> SourceFormat? {
        guard let dot = filename.lastIndex(of: ".") else { return nil }
        let ext = filename[filename.index(after: dot)...]
        return from(fileExtension: String(ext))
    }

    /// Sniff a `SourceFormat` from a URL's last path component.
    public static func from(url: URL) -> SourceFormat? {
        from(filename: url.lastPathComponent)
    }
}
