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
                    .font(.system(size: 11, weight: .medium))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .padding(.bottom, 4)
            ForEach(MutationCatalogEntry.Group.allCases, id: \.self) { group in
                let entries = MutationCatalog.all.filter { $0.group == group }
                if !entries.isEmpty {
                    section(title: group.label, entries: entries)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.06))
        )
        .accessibilityIdentifier("inspector.mutations")
        .accessibilityElement(children: .contain)
    }

    private func section(title: String, entries: [MutationCatalogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 2)
            ForEach(entries) { entry in
                row(entry)
            }
        }
    }

    private func row(_ entry: MutationCatalogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.label)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                    if entry.wasFiction {
                        Text("landed Phase 5")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.green.opacity(0.18)))
                            .foregroundStyle(.green)
                    }
                }
                Text(entry.rationale)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer()
            Button("demo →") {
                store.setDemoStepperVisible(true)
                store.setVisualStage(entry.demoStage)
                store.setWorkspaceMode(.visual)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .a11y(label: "Demo \(entry.id)", id: "mutations.demo.\(entry.id)")
        }
        .padding(.vertical, 3)
    }
}
