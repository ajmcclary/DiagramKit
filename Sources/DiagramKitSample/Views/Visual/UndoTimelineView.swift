//
//  UndoTimelineView.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.6 — bottom strip showing the editor's undo
//  history. Past entries left-to-right with the current cursor
//  highlighted; future (redo) entries dimmed.
//

import SwiftUI

struct UndoTimelineView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        let entries = store.undoEntries
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            if entries.isEmpty {
                Text("No history yet")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                            chip(for: entry)
                        }
                    }
                }
                .frame(maxWidth: 240)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.undoTimeline)
    }

    private func chip(for entry: UndoEntry) -> some View {
        let tint = chipTint(for: entry)
        return HStack(spacing: 4) {
            Image(systemName: chipIcon(for: entry.kind))
                .font(.system(size: 8, weight: .semibold))
            Text(entry.displayLabel)
                .font(.system(size: 10, weight: entry.isCurrent ? .semibold : .regular).monospacedDigit())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(tint.background))
        .foregroundStyle(tint.foreground)
        .opacity(entry.isFuture ? 0.5 : 1)
    }

    private func chipTint(for entry: UndoEntry) -> (background: Color, foreground: Color) {
        if entry.isCurrent {
            return (Color.accentColor.opacity(0.22), Color.accentColor)
        }
        if entry.isFuture {
            return (Color.gray.opacity(0.10), .secondary)
        }
        return (Color.gray.opacity(0.18), .primary)
    }

    private func chipIcon(for kind: UndoEntry.Kind) -> String {
        switch kind {
        case .noop:              return "circle"
        case .setLabel:          return "textformat"
        case .setTitle:          return "text.alignleft"
        case .insertNode:        return "plus.app"
        case .insertEdge:        return "arrow.left.and.right"
        case .deleteElement:     return "trash"
        case .groupIntoSubgraph: return "rectangle.stack"
        }
    }
}
