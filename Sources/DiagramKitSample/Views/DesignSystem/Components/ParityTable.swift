//
//  ParityTable.swift
//  DiagramPlayground
//
//  Platform-parity table: FEATURE + target columns, cells check/partial/dash
//  (transcription §5.5).
//

import SwiftUI
import DiagramKitSampleDesignSystem

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
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                rowView(row)
                if i < rows.count - 1 { Rectangle().fill(environment.theme.colors.borderVariant.color).frame(height: DSTokens.Stroke.hairline) }
            }
        }
        .background { DSSurface(role: .card) { Color.clear } }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("FEATURE").dsFont(.overline)
                .foregroundStyle(environment.theme.colors.textSecondary.color).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(columns, id: \.self) { c in
                Text(c.uppercased()).dsFont(.overline)
                    .foregroundStyle(environment.theme.colors.textSecondary.color).frame(width: 60)
            }
        }
        .padding(.horizontal, DSTokens.Spacing.lg).padding(.vertical, DSTokens.Spacing.sm)
        .overlay(Rectangle().fill(environment.theme.colors.borderVariant.color).frame(height: DSTokens.Stroke.hairline), alignment: .bottom)
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: DSTokens.Spacing.xs) {
                Text(row.feature).dsFont(.caption).foregroundStyle(environment.theme.colors.textPrimary.color)
                if let mono = row.mono { Text(mono).dsFont(.code).foregroundStyle(environment.theme.colors.textSecondary.color) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                cellView(cell).frame(width: 60)
            }
        }.padding(.horizontal, DSTokens.Spacing.lg).padding(.vertical, DSTokens.Spacing.smMd)
    }

    @ViewBuilder private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .full:
            DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
        case .partial:
            DSIconView(.warning, size: DSTokens.Icon.micro, colorRole: .warning)
        case .unsupported:
            DSIconView(.error, size: DSTokens.Icon.micro, colorRole: .disabled)
        }
    }
}
