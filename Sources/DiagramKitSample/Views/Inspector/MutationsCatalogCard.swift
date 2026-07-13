//
//  MutationsCatalogCard.swift
//  DiagramPlayground
//
//  Phase 10 / Task 10.2 — Inspector card listing every mutation
//  the editor exposes. Each row carries label + rationale + a
//  "demo →" button that bounces state.visualStage so the user can
//  see the corresponding canvas state.
//

import SwiftUI
import DesignKitThemes

struct MutationsCatalogCard: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        InspectorSectionHeader(title: "Mutations catalog", systemImage: "list.bullet.rectangle")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { store.state.demoStepperVisible },
                set: { store.setDemoStepperVisible($0) }
            )) {
                Text("Show demo state stepper")
                    .dsFont(.badge)
            }
            .toggleStyle(.ds)
            .padding(.bottom, Tokens.Spacing.xxs)
            ForEach(MutationCatalogEntry.Group.allCases, id: \.self) { group in
                let entries = MutationCatalog.all.filter { $0.group == group }
                if !entries.isEmpty {
                    section(title: group.label, entries: entries)
                }
            }
        }
        .padding(Tokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .accessibilityIdentifier("inspector.mutations")
        .accessibilityElement(children: .contain)
    }

    private func section(title: String, entries: [MutationCatalogEntry]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
            DSSectionHeader(title)
                .padding(.top, Tokens.Spacing.xxxs)
            ForEach(entries) { entry in
                row(entry)
            }
        }
    }

    private func row(_ entry: MutationCatalogEntry) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.xs) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                HStack(spacing: Tokens.Spacing.xxs) {
                    Text(entry.label)
                        .dsFont(.code)
                        .lineLimit(1)
                    if entry.wasFiction {
                        DSCodeBadge("landed Phase 5")
                    }
                }
                Text(entry.rationale)
                    .dsFont(.caption2)
                    .lineLimit(3)
            }
            Spacer()
            Button("demo →") {
                store.setDemoStepperVisible(true)
                store.setVisualStage(entry.demoStage)
                store.setWorkspaceMode(.visual)
            }
            .buttonStyle(.ds(role: .secondary, size: .compact))
            .a11y(label: "Demo \(entry.id)", id: "mutations.demo.\(entry.id)")
        }
        .padding(.vertical, Tokens.Shape.strokeThick)
    }
}
