//
//  UndoTimelineView.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.6 — bottom strip showing the editor's undo
//  history. Past entries left-to-right with the current cursor
//  highlighted; future (redo) entries dimmed.
//

import SwiftUI
import DesignKitThemes

struct UndoTimelineView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        let entries = store.undoEntries
        DSGlassSurface(role: .popover) {
        HStack(spacing: Tokens.Spacing.xs) {
            DSIconView(.history, size: Tokens.Size.Icon.micro, colorRole: .muted)

            if entries.isEmpty {
                Text("No history yet")
                    .dsFont(.caption2)
                    .foregroundStyle(theme.colors.textSecondary.color)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Tokens.Spacing.xxs) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                            chip(for: entry)
                        }
                    }
                }
                .frame(maxWidth: 240)
            }
        }
        .padding(.horizontal, Tokens.Spacing.smMd)
        .padding(.vertical, Tokens.Spacing.xxs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.undoTimeline)
    }

    private func chip(for entry: UndoEntry) -> some View {
        let tint = chipTint(for: entry)
        return HStack(spacing: Tokens.Spacing.xxs) {
            Label(entry.displayLabel, systemImage: chipIcon(for: entry.kind))
                .labelStyle(.iconOnly)
                .dsFont(.badge)
            Text(entry.displayLabel)
                .dsFont(entry.isCurrent ? .metric : .caption2)
        }
        .padding(.horizontal, Tokens.Spacing.xs)
        .padding(.vertical, Tokens.Spacing.xxxs)
        .background(Capsule().fill(tint.background))
        .foregroundStyle(tint.foreground)
        .opacity(entry.isFuture ? Tokens.Opacity.medium : 1)
    }

    private func chipTint(for entry: UndoEntry) -> (background: Color, foreground: Color) {
        if entry.isCurrent {
            return (
                theme.colors.elementSelected.color,
                theme.colors.accent.color
            )
        }
        if entry.isFuture {
            return (
                theme.colors.element.color,
                theme.colors.textSecondary.color
            )
        }
        return (
            theme.colors.elementHover.color,
            theme.colors.textPrimary.color
        )
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
