//
//  CorpusEntry.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.4 — facet-tagged view of a TestDiagram. Each
//  entry knows its diagnostic state (clean / warn) and Linux
//  facet (full / approximate) so CorpusBrowserView can filter
//  without re-walking expectedDiagnostics every render.
//

import Foundation

public struct CorpusEntry: Identifiable, Sendable, Hashable {

    public enum DiagnosticFacet: String, Codable, CaseIterable, Sendable, Hashable {
        case clean
        case warn

        public var label: String {
            switch self {
            case .clean: return "Clean"
            case .warn:  return "Warn"
            }
        }
    }

    public enum LinuxFacet: String, Codable, CaseIterable, Sendable, Hashable {
        case full
        case approximate

        public var label: String {
            switch self {
            case .full:        return "Full"
            case .approximate: return "Approximate"
            }
        }
    }

    public let id: String
    public let category: String
    public let name: String
    public let source: String
    public let formats: Set<String>
    public let diagnosticFacet: DiagnosticFacet
    public let linuxFacet: LinuxFacet
    public let unsupportedNote: String?

    /// Build from a TestDiagram. Approximate-Linux facet covers the
    /// three CoreText-bound families per CLAUDE.md.
    public init(from diagram: TestDiagram) {
        self.id = diagram.id
        self.category = diagram.category
        self.name = diagram.name
        self.source = diagram.source
        if let multi = diagram.sources, !multi.isEmpty {
            self.formats = Set(multi.keys)
        } else {
            self.formats = ["mermaid"]
        }
        let hasExpected = (diagram.expectedDiagnostics?.isEmpty == false)
        self.diagnosticFacet = hasExpected ? .warn : .clean
        switch diagram.category.lowercased() {
        case "ishikawa", "treeview", "eventmodeling":
            self.linuxFacet = .approximate
        default:
            self.linuxFacet = .full
        }
        self.unsupportedNote = diagram.unsupportedNote
    }
}
