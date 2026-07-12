//
//  UndoTimelineView.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.6 — bottom strip showing the editor's undo
//  history. Past entries left-to-right with the current cursor
//  highlighted; future (redo) entries dimmed.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct UndoTimelineView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        let entries = store.undoEntries
        DSGlassSurface(role: .popover) {
        HStack(spacing: DSTokens.Spacing.xs) {
            DSIconView(.history, size: DSTokens.Icon.micro, colorRole: .muted)

            if entries.isEmpty {
                Text("No history yet")
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSTokens.Spacing.xxs) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                            chip(for: entry)
                        }
                    }
                }
                .frame(maxWidth: 240)
            }
        }
        .padding(.horizontal, DSTokens.Spacing.smMd)
        .padding(.vertical, DSTokens.Spacing.xxs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.undoTimeline)
    }

    private func chip(for entry: UndoEntry) -> some View {
        let tint = chipTint(for: entry)
        return HStack(spacing: DSTokens.Spacing.xxs) {
            Label(entry.displayLabel, systemImage: chipIcon(for: entry.kind))
                .labelStyle(.iconOnly)
                .dsFont(.badge)
            Text(entry.displayLabel)
                .dsFont(entry.isCurrent ? .metric : .caption2)
        }
        .padding(.horizontal, DSTokens.Spacing.xs)
        .padding(.vertical, DSTokens.Spacing.xxxs)
        .background(Capsule().fill(tint.background))
        .foregroundStyle(tint.foreground)
        .opacity(entry.isFuture ? DSTokens.Opacity.medium : 1)
    }

    private func chipTint(for entry: UndoEntry) -> (background: Color, foreground: Color) {
        if entry.isCurrent {
            return (
                environment.theme.colors.elementSelected.color,
                environment.theme.colors.accent.color
            )
        }
        if entry.isFuture {
            return (
                environment.theme.colors.element.color,
                environment.theme.colors.textSecondary.color
            )
        }
        return (
            environment.theme.colors.elementHover.color,
            environment.theme.colors.textPrimary.color
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
