//
//  EdgeEditPopover.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.5 — edge style/arrow editor. The library doesn't
//  expose an edge-style mutation today, so Phase 3 ships the visible
//  controls and an Auto-route reset button. Commit is intentionally
//  no-op pending an ExportLoader-backed style mutation in a later
//  phase.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct EdgeEditPopover: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    enum LineStyle: String, CaseIterable, Identifiable {
        case solid, dashed, dotted
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    enum ArrowStyle: String, CaseIterable, Identifiable {
        case none, forward, both
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none:    return "—"
            case .forward: return "→"
            case .both:    return "↔"
            }
        }
    }

    @SwiftUI.State private var lineStyle: LineStyle = .solid
    @SwiftUI.State private var arrowStyle: ArrowStyle = .forward

    var body: some View {
        DSSurface(role: .popover) {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.smMd) {
            HStack {
                Text("Edit edge")
                    .dsFont(.headline)
                Spacer()
                if let selection = store.editor?.selection {
                    Text(selection.elementID)
                        .dsFont(.code)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                }
            }

            Picker("Line", selection: $lineStyle) {
                ForEach(LineStyle.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker("Arrow", selection: $arrowStyle) {
                ForEach(ArrowStyle.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button("Auto-route") {
                // Resetting the route is a future-style mutation; for
                // Phase 3 we just bounce the visualStage back to .idle
                // so the user sees feedback.
                store.setVisualStage(.idle)
            }
            .buttonStyle(.ds(role: .secondary, size: .compact))

            HStack {
                Button(role: .destructive) {
                    deleteEdge()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .dsFont(.badge)
                }
                .buttonStyle(.ds(role: .destructive, size: .compact))
                Spacer()
                Button("Done") {
                    store.setVisualStage(.idle)
                }
                .buttonStyle(.ds(role: .primary, size: .compact))
            }
        }
        .padding(DSTokens.Spacing.lg)
        }
        .frame(width: 300)
        .accessibilityIdentifier(A11yID.Visual.edgePopover)
    }

    private func deleteEdge() {
        guard let selection = store.editor?.selection else { return }
        Task {
            try? await store.performMutation(.deleteElement(selection))
        }
        store.setVisualStage(.idle)
    }
}
