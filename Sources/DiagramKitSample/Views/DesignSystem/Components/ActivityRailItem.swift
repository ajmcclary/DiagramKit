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
            DSIconView(icon, size: DSTokens.Icon.sm, colorRole: isActive ? .accent : .muted)
                .frame(width: DSTokens.Icon.sm + DSTokens.Spacing.sm, height: DSTokens.Icon.sm + DSTokens.Spacing.sm)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
                            .fill(environment.theme.colors.accent.color.opacity(DSTokens.Opacity.light))
                            .padding(-DSTokens.Spacing.xxs)
                    }
                }
        }
        .buttonStyle(.ds(role: .ghost, size: .regular))
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .help(help)
    }

    @Environment(\.dsEnvironment) private var environment
}
