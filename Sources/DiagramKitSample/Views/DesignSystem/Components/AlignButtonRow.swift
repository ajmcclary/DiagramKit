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
    private let leading: [DSIcon] = [.alignLeading, .alignCenterHorizontal, .alignTrailing]
    private let trailing: [DSIcon] = [.alignTop, .alignCenterVertical, .alignBottom]

    var body: some View {
        HStack(spacing: DSTokens.Spacing.xs) {
            ForEach(leading, id: \.self) { alignButton($0) }
            Rectangle().fill(environment.theme.colors.borderVariant.color)
                .frame(width: DSTokens.Stroke.hairline, height: DSTokens.Spacing.xl)
            ForEach(trailing, id: \.self) { alignButton($0) }
        }
    }

    private func alignButton(_ icon: DSIcon) -> some View {
        DSIconView(icon, size: DSTokens.Icon.micro, colorRole: .disabled)
            .frame(minWidth: DSTokens.Control.row, minHeight: DSTokens.Control.rowCompact)
            .background(environment.theme.colors.element.color)
            .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.sm))
            .help("Alignment is presentational for auto-laid-out diagrams")
    }

    @Environment(\.dsEnvironment) private var environment
}
