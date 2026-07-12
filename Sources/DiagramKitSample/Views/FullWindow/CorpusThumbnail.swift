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
import DiagramKitSampleDesignSystem

struct CorpusThumbnail: View {
    let entry: CorpusEntry
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: DSTokens.Radius.md, style: .continuous)
                    .fill(tint.opacity(DSTokens.Opacity.glassBorder))
                DSIconView(.diagram, size: DSTokens.Icon.md)
            }
            .frame(height: 96)

            Text(entry.name)
                .dsFont(.headline)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DSTokens.Spacing.xxs) {
                Text(entry.id)
                    .dsFont(.code)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                facetChip
            }
        }
        .padding(DSTokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .accessibilityIdentifier("corpus.thumbnail.\(entry.id)")
    }

    // MARK: - Helpers

    private var tint: Color {
        environment.theme.colors.accents[accentIndex].color
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
            DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
        case .warn:
            DSIconView(.warning, size: DSTokens.Icon.micro, colorRole: .warning)
        }
    }
}
