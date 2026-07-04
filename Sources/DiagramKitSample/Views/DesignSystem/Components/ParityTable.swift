//
//  ParityTable.swift
//  DiagramPlayground
//
//  Platform-parity table: FEATURE + target columns, cells check/partial/dash
//  (transcription §5.5).
//

import SwiftUI

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
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                rowView(row)
                if i < rows.count - 1 { Rectangle().fill(tokens.palette.borderFaint).frame(height: 0.5) }
            }
        }
        .background(tokens.palette.bgCard)
        .overlay(RoundedRectangle(cornerRadius: PlaygroundRadius.md).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: PlaygroundRadius.md))
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("FEATURE").font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
                .foregroundStyle(tokens.palette.fg3).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(columns, id: \.self) { c in
                Text(c.uppercased()).font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
                    .foregroundStyle(tokens.palette.fg3).frame(width: 60)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5), alignment: .bottom)
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(row.feature).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg1)
                if let mono = row.mono { Text(mono).font(PlaygroundFont.mono(11)).foregroundStyle(tokens.palette.fg3) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                cellView(cell).frame(width: 60)
            }
        }.padding(.horizontal, 14).padding(.vertical, 11)
    }

    @ViewBuilder private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .full:
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(tokens.palette.statusSuccess)
        case .partial:
            Circle().fill(tokens.palette.statusWarning).frame(width: 8, height: 8)
        case .unsupported:
            Text("—").font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.textFaintest)
        }
    }
}
