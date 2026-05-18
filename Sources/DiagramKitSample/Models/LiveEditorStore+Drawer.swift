//
//  LiveEditorStore+Drawer.swift
//  DiagramPlayground
//
//  Phase 6 diagnostics drawer state, filters, Explain popover, and the
//  DrawerDiagnostic row model. Extracted from LiveEditorStore.swift.
//

import SwiftUI
import DiagramKit
import DiagramKitImport

extension LiveEditorStore {

    // MARK: - Diagnostics drawer (Phase 6 / Task 6.1)

    public func toggleDiagnosticsDrawer() {
        state.diagDrawer.isOpen.toggle()
    }

    public func setDiagnosticsDrawerOpen(_ flag: Bool) {
        state.diagDrawer.isOpen = flag
    }

    public func setDiagnosticSeverityFilter(_ filter: DiagnosticsDrawerState.SeverityFilter) {
        state.diagDrawer.severity = filter
    }

    public func setDiagnosticCategoryFilter(_ category: DiagnosticCategory?) {
        state.diagDrawer.category = category
    }

    public func setDiagnosticTierFilter(_ filter: DiagnosticsDrawerState.TierFilter) {
        state.diagDrawer.tier = filter
    }

    public func setDiagnosticPairedFilter(_ filter: DiagnosticsDrawerState.PairedFilter) {
        state.diagDrawer.paired = filter
    }

    public func presentExplain(for diagnostic: DrawerDiagnostic) {
        diagnosticExplainTarget = diagnostic
    }

    public func dismissExplain() {
        diagnosticExplainTarget = nil
    }

    /// Map editor diagnostics into the drawer's tier-aware row model.
    /// Phase 6 derives a tier from EditorDiagnostic.source — the
    /// playground store doesn't yet preserve typed `DiagnosticCategory`
    /// off the importer pipeline, so category stays nil for now and
    /// the category facet only filters on rows that future phases
    /// upgrade.
    public var allDiagnostics: [DrawerDiagnostic] {
        diagnostics.map { editor in
            DrawerDiagnostic(
                editor: editor,
                tier: tier(for: editor.source),
                category: nil
            )
        }
    }

    /// All rows after applying the drawer's facet filters.
    public var filteredDrawerDiagnostics: [DrawerDiagnostic] {
        let filter = state.diagDrawer
        return allDiagnostics.filter { row in
            // Severity
            switch filter.severity {
            case .all:         break
            case .warning:     guard row.editor.severity == .warning else { return false }
            case .info:        guard row.editor.severity == .info else { return false }
            case .unsupported:
                // EditorDiagnostic doesn't model unsupported separately;
                // surface only category-tagged rows here.
                guard row.category?.severity == .unsupported else { return false }
            }
            // Category
            if let category = filter.category, row.category != category { return false }
            // Tier
            switch filter.tier {
            case .all:    break
            case .import: guard row.tier == .import else { return false }
            case .layout: guard row.tier == .layout else { return false }
            case .config: guard row.tier == .config else { return false }
            }
            // Paired
            switch filter.paired {
            case .all:      break
            case .paired:   guard row.isPaired else { return false }
            case .unpaired: guard !row.isPaired else { return false }
            }
            return true
        }
    }

    fileprivate func tier(for source: EditorDiagnostic.DiagnosticSource) -> DiagnosticsDrawerState.TierFilter {
        switch source {
        case .parse:   return .import
        case .config:  return .config
        case .runtime: return .layout
        }
    }
}

// MARK: - DrawerDiagnostic

/// Tier-aware row consumed by the bottom diagnostics drawer.
public struct DrawerDiagnostic: Identifiable, Sendable {
    public let editor: EditorDiagnostic
    public let tier: DiagnosticsDrawerState.TierFilter
    public let category: DiagnosticCategory?

    public var id: EditorDiagnostic.ID { editor.id }

    /// Heuristic — Phase 6 doesn't yet hook the RoundTripHarness into
    /// the playground, so "paired" is true when the row has a
    /// non-nil category that maps to a known lossy transform.
    public var isPaired: Bool {
        guard let category else { return false }
        switch category.severity {
        case .warning, .unsupported: return true
        case .info:                  return false
        }
    }
}
