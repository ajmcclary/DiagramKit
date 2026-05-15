//
//  CorpusIndex.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.4 — wraps TestDiagrams.all into a faceted
//  index for CorpusBrowserView. Phase 8 doesn't re-decode
//  test-diagrams.json — TestDiagrams already loads it at startup.
//

import Foundation

public struct CorpusIndex: Sendable {

    public let entries: [CorpusEntry]
    public let categoryCounts: [String: Int]
    public let formatCounts: [String: Int]
    public let diagnosticFacetCounts: [CorpusEntry.DiagnosticFacet: Int]
    public let linuxFacetCounts: [CorpusEntry.LinuxFacet: Int]

    public init(entries: [CorpusEntry]) {
        self.entries = entries
        self.categoryCounts = entries.reduce(into: [String: Int]()) { acc, e in
            acc[e.category, default: 0] += 1
        }
        var formatCounts: [String: Int] = [:]
        for e in entries {
            for f in e.formats { formatCounts[f, default: 0] += 1 }
        }
        self.formatCounts = formatCounts
        self.diagnosticFacetCounts = entries.reduce(into: [CorpusEntry.DiagnosticFacet: Int]()) { acc, e in
            acc[e.diagnosticFacet, default: 0] += 1
        }
        self.linuxFacetCounts = entries.reduce(into: [CorpusEntry.LinuxFacet: Int]()) { acc, e in
            acc[e.linuxFacet, default: 0] += 1
        }
    }

    public static let shared = CorpusIndex(
        entries: TestDiagrams.all.map(CorpusEntry.init(from:))
    )

    /// Filter entries by every facet currently selected on the
    /// browser. Empty / nil facets pass through.
    public func filtered(
        search: String,
        category: String?,
        format: String?,
        diagnostic: CorpusEntry.DiagnosticFacet?,
        linux: CorpusEntry.LinuxFacet?
    ) -> [CorpusEntry] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        return entries.filter { entry in
            if let category, entry.category != category { return false }
            if let format, !entry.formats.contains(format) { return false }
            if let diagnostic, entry.diagnosticFacet != diagnostic { return false }
            if let linux, entry.linuxFacet != linux { return false }
            if !needle.isEmpty {
                let haystack = "\(entry.id) \(entry.name) \(entry.category)".lowercased()
                if !haystack.contains(needle) { return false }
            }
            return true
        }
    }
}
