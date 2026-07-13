//
//  CorpusThumbnail.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.5 — small per-family thumbnail card. Uses a
//  family glyph + accent tint so the grid stays scannable; the
//  hand-drawn JSX shape thumbnails are out of scope here.
//

import SwiftUI
import DiagramKitModel
import DesignKitThemes

struct CorpusThumbnail: View {
    let entry: CorpusEntry
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Shape.radiusMD, style: .continuous)
                    .fill(tint.opacity(Tokens.Opacity.glassBorder))
                DSIconView(.diagram, size: Tokens.Size.Icon.md)
            }
            .frame(height: 96)

            Text(entry.name)
                .dsFont(.headline)
                .foregroundStyle(theme.colors.textPrimary.color)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Tokens.Spacing.xxs) {
                Text(entry.id)
                    .dsFont(.code)
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                facetChip
            }
        }
        .padding(Tokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .accessibilityIdentifier("corpus.thumbnail.\(entry.id)")
    }

    // MARK: - Helpers

    private var tint: Color {
        theme.colors.accents[accentIndex].color
    }

    private var accentIndex: Int {
        switch entry.category.lowercased() {
        case "flowchart", "timeline", "kanban": 0
        case "sequence", "state", "gantt": 1
        case "class", "er", "mindmap": 2
        case "c4", "pie", "block": 3
        default: 4
        }
    }

    @ViewBuilder
    private var facetChip: some View {
        switch entry.diagnosticFacet {
        case .clean:
            DSIconView(.success, size: Tokens.Size.Icon.micro, colorRole: .success)
        case .warn:
            DSIconView(.warning, size: Tokens.Size.Icon.micro, colorRole: .warning)
        }
    }
}
