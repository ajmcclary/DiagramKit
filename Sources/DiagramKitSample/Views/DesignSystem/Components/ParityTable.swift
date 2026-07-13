//
//  ParityTable.swift
//  DiagramPlayground
//
//  Platform-parity table: FEATURE + target columns, cells check/partial/dash
//  (transcription §5.5).
//

import SwiftUI
import DesignKitThemes

struct ParityTable: View {
    enum Cell: Equatable { case full, partial, unsupported }
    struct Row: Identifiable {
        let feature: String
        var mono: String? = nil
        let cells: [Cell]
        var id: String { feature }
    }
    let columns: [String]
    let rows: [Row]
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                rowView(row)
                if i < rows.count - 1 { Rectangle().fill(theme.colors.borderVariant.color).frame(height: Tokens.Shape.strokeHairline) }
            }
        }
        .background { DSSurface(role: .card) { Color.clear } }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("FEATURE").dsFont(.overline)
                .foregroundStyle(theme.colors.textSecondary.color).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(columns, id: \.self) { c in
                Text(c.uppercased()).dsFont(.overline)
                    .foregroundStyle(theme.colors.textSecondary.color).frame(width: 60)
            }
        }
        .padding(.horizontal, Tokens.Spacing.lg).padding(.vertical, Tokens.Spacing.sm)
        .overlay(Rectangle().fill(theme.colors.borderVariant.color).frame(height: Tokens.Shape.strokeHairline), alignment: .bottom)
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: Tokens.Spacing.xs) {
                Text(row.feature).dsFont(.caption).foregroundStyle(theme.colors.textPrimary.color)
                if let mono = row.mono { Text(mono).dsFont(.code).foregroundStyle(theme.colors.textSecondary.color) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                cellView(cell).frame(width: 60)
            }
        }.padding(.horizontal, Tokens.Spacing.lg).padding(.vertical, Tokens.Spacing.smMd)
    }

    @ViewBuilder private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .full:
            DSIconView(.success, size: Tokens.Size.Icon.micro, colorRole: .success)
        case .partial:
            DSIconView(.warning, size: Tokens.Size.Icon.micro, colorRole: .warning)
        case .unsupported:
            DSIconView(.error, size: Tokens.Size.Icon.micro, colorRole: .disabled)
        }
    }
}
