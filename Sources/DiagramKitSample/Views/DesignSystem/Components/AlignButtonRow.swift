//
//  AlignButtonRow.swift
//  DiagramPlayground
//
//  ARRANGE align buttons. Presentational this cycle — an ELK auto-layout graph
//  has no free node positions to align (see design spec "Backing-mutation
//  boundary"). Rendered disabled-looking; no mutation is wired.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct AlignButtonRow: View {
    private let leading = ["align.horizontal.left.fill", "align.horizontal.center.fill", "align.horizontal.right.fill"]
    private let trailing = ["align.vertical.top.fill", "align.vertical.center.fill", "align.vertical.bottom.fill"]

    var body: some View {
        HStack(spacing: DSTokens.Spacing.xs) {
            ForEach(leading, id: \.self) { alignButton($0) }
            Rectangle().fill(environment.theme.colors.borderVariant.color)
                .frame(width: DSTokens.Stroke.hairline, height: DSTokens.Spacing.xl)
            ForEach(trailing, id: \.self) { alignButton($0) }
        }
    }

    private func alignButton(_ symbol: String) -> some View {
        DSIconView(.rearrange, size: DSTokens.Icon.micro, colorRole: .disabled)
            .frame(minWidth: DSTokens.Control.row, minHeight: DSTokens.Control.rowCompact)
            .background(environment.theme.colors.element.color)
            .overlay(RoundedRectangle(cornerRadius: DSTokens.Radius.sm).stroke(environment.theme.colors.borderVariant.color, lineWidth: DSTokens.Stroke.thin))
            .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.sm))
            .help("Alignment is presentational for auto-laid-out diagrams")
    }

    @Environment(\.dsEnvironment) private var environment
}
