//
//  AlignButtonRow.swift
//  DiagramPlayground
//
//  ARRANGE align buttons. Presentational this cycle — an ELK auto-layout graph
//  has no free node positions to align (see design spec "Backing-mutation
//  boundary"). Rendered disabled-looking; no mutation is wired.
//

import SwiftUI

struct AlignButtonRow: View {
    @Environment(\.playgroundTokens) private var tokens
    private let leading = ["align.horizontal.left.fill", "align.horizontal.center.fill", "align.horizontal.right.fill"]
    private let trailing = ["align.vertical.top.fill", "align.vertical.center.fill", "align.vertical.bottom.fill"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(leading, id: \.self) { alignButton($0) }
            Rectangle().fill(tokens.palette.borderHairline).frame(width: 0.5, height: 20)
            ForEach(trailing, id: \.self) { alignButton($0) }
        }
    }

    private func alignButton(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 13))
            .foregroundStyle(tokens.palette.fg2.opacity(0.5))
            .frame(width: 34, height: 30)
            .background(tokens.palette.bgTrack)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .help("Alignment is presentational for auto-laid-out diagrams")
    }
}
