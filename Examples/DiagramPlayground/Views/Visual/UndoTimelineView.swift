//
//  UndoTimelineView.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.6 — bottom strip showing the editor's undo
//  history. Past entries left-to-right, current cursor highlighted,
//  future (redo) entries dimmed. Phase 3.2 ships a placeholder that
//  binds to canUndo / canRedo; Task 3.6 fills in the real entries.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct UndoTimelineView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        HStack(spacing: 6) {
            Text("Undo timeline")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            ForEach(entries, id: \.self) { entry in
                Text(entry)
                    .font(.system(size: 10, weight: .regular).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.gray.opacity(0.18)))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.undoTimeline)
    }

    private var entries: [String] {
        store.undoEntries.map(\.displayLabel)
    }
}
