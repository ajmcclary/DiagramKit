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

struct CorpusThumbnail: View {
    let entry: CorpusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.16))
                Image(systemName: glyph)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(tint)
            }
            .frame(height: 96)

            Text(entry.name)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Text(entry.id)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                facetChip
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 0.5)
                )
        )
        .accessibilityIdentifier("corpus.thumbnail.\(entry.id)")
    }

    // MARK: - Helpers

    private var familyType: DiagramType? {
        DiagramType(rawValue: entry.category)
    }

    private var glyph: String {
        if let family = familyType {
            return CoverageMatrixSeed.glyph(for: family)
        }
        return "doc"
    }

    private var tint: Color {
        switch entry.category.lowercased() {
        case "flowchart":  return .blue
        case "sequence":   return .pink
        case "class":      return .green
        case "state":      return .orange
        case "er":         return .purple
        case "timeline":   return .teal
        case "gantt":      return .red
        case "mindmap":    return .indigo
        case "c4":         return .brown
        case "pie":        return .yellow
        case "kanban":     return .mint
        case "block":      return .cyan
        default:           return .gray
        }
    }

    @ViewBuilder
    private var facetChip: some View {
        switch entry.diagnosticFacet {
        case .clean:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.system(size: 10))
        case .warn:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 10))
        }
    }
}
