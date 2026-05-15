//
//  InspectorHistorySection.swift
//  DiagramPlayground
//
//  Recent manual + auto entries. Clicking a row restores via the
//  existing LiveHistoryStore.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct InspectorHistorySection: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        InspectorSectionHeader(title: "History", systemImage: "clock.arrow.circlepath")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: 4) {
            let entries = recentEntries
            if entries.isEmpty {
                Text("No history yet")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    Button {
                        store.restoreFromHistory(entry)
                    } label: {
                        HStack {
                            Image(systemName: icon(for: entry))
                                .foregroundStyle(.secondary)
                                .font(.system(size: 10, weight: .semibold))
                            Text(entry.displayLabel)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.06))
        )
        .accessibilityIdentifier(A11yID.Inspector.historySection)
        .accessibilityElement(children: .contain)
    }

    private var recentEntries: [LiveHistoryEntry] {
        let manual = store.historyStore.manualEntries.prefix(5)
        let auto = store.historyStore.autoEntries.prefix(5)
        return Array(manual) + Array(auto)
    }

    private func icon(for entry: LiveHistoryEntry) -> String {
        switch entry.origin {
        case .manual: return "bookmark"
        case .auto:   return "clock"
        case .loader: return "arrow.down.circle"
        }
    }
}
