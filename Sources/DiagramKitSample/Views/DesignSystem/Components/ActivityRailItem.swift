//
//  ActivityRailItem.swift
//  DiagramPlayground
//
//  A single 38×38 tile in the far-left activity rail; active tile gets an accent
//  tint + a left marker bar (transcription §1.4 / §3.1).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct ActivityRailItem: View {
    let systemImage: String
    let isActive: Bool
    let help: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            DSIconView(icon, size: DSTokens.Icon.sm, colorRole: isActive ? .primary : .muted)
                .overlay(alignment: .leading) {
                    if isActive {
                        RoundedRectangle(cornerRadius: DSTokens.Radius.xs)
                            .fill(environment.theme.colors.accent.color)
                            .frame(width: DSTokens.Control.accentBar)
                            .padding(.vertical, DSTokens.Spacing.sm)
                            .offset(x: -DSTokens.Spacing.md)
                    }
                }
        }
        .buttonStyle(.ds(role: isActive ? .secondary : .ghost, size: .regular))
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .help(help)
    }

    @Environment(\.dsEnvironment) private var environment

    private var icon: DSIcon {
        switch systemImage {
        case "magnifyingglass": .search
        case "chevron.left.forwardslash.chevron.right": .code
        case "slider.horizontal.3": .settings
        case "list.bullet.indent": .rearrange
        default: .diagram
        }
    }
}
