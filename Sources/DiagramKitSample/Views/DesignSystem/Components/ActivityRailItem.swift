//
//  ActivityRailItem.swift
//  DiagramPlayground
//
//  A single 38×38 tile in the far-left activity rail; active tile gets an accent
//  tint + a left marker bar (transcription §1.4 / §3.1).
//

import SwiftUI
import DesignKitThemes

struct ActivityRailItem: View {
    let icon: DSIcon
    let isActive: Bool
    let help: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            DSIconView(icon, size: Tokens.Size.Icon.sm, colorRole: isActive ? .accent : .muted)
                .frame(width: Tokens.Size.Icon.sm + Tokens.Spacing.sm, height: Tokens.Size.Icon.sm + Tokens.Spacing.sm)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
                            .fill(theme.colors.accent.color.opacity(Tokens.Opacity.light))
                            .padding(-Tokens.Spacing.xxs)
                    }
                }
        }
        .buttonStyle(.ds(role: .ghost, size: .regular))
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .help(help)
    }

    @Environment(\.designTheme) private var theme
}
