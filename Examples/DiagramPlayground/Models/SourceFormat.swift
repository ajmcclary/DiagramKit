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

    /// `true` when `DiagramPipeline.defaultExportRegistry` has a registered
    /// exporter for this format. Graphviz currently has no DOT exporter.
    public var hasExporter: Bool {
        self != .graphviz
    }
}
