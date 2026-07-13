//
//  InspectorHistorySection.swift
//  DiagramPlayground
//
//  Recent manual + auto entries. Clicking a row restores via the
//  existing LiveHistoryStore.
//

import SwiftUI
import DesignKitThemes

struct InspectorHistorySection: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSSectionHeader("History")
            .padding(.bottom, DSTokens.Spacing.xxs)
        VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
            let entries = recentEntries
            if entries.isEmpty {
                Text("No history yet")
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            } else {
                ForEach(entries) { entry in
                    Button {
                        store.restoreFromHistory(entry)
                    } label: {
                        HStack {
                            DSIconView(.history, size: DSTokens.Icon.micro, colorRole: .muted)
                            Text(entry.displayLabel)
                                .dsFont(.caption2)
                                .foregroundStyle(environment.theme.colors.textPrimary.color)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.ds(role: .ghost, size: .compact))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSTokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .accessibilityIdentifier(A11yID.Inspector.historySection)
        .accessibilityElement(children: .contain)
    }

    private var recentEntries: [LiveHistoryEntry] {
        let manual = store.historyStore.manualEntries.prefix(5)
        let auto = store.historyStore.autoEntries.prefix(5)
        return Array(manual) + Array(auto)
    }
}
