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
    @Environment(\.designTheme) private var theme

    var body: some View {
        DSSectionHeader("History")
            .padding(.bottom, Tokens.Spacing.xxs)
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            let entries = recentEntries
            if entries.isEmpty {
                Text("No history yet")
                    .dsFont(.caption2)
                    .foregroundStyle(theme.colors.textSecondary.color)
            } else {
                ForEach(entries) { entry in
                    Button {
                        store.restoreFromHistory(entry)
                    } label: {
                        HStack {
                            DSIconView(.history, size: Tokens.Size.Icon.micro, colorRole: .muted)
                            Text(entry.displayLabel)
                                .dsFont(.caption2)
                                .foregroundStyle(theme.colors.textPrimary.color)
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
        .padding(Tokens.Spacing.sm)
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
