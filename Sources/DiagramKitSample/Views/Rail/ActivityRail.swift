//
//  ActivityRail.swift
//  DiagramPlayground
//
//  Far-left 52px activity rail: Organize / Browse / Search / Source tiles plus a
//  bottom settings tile (transcription §3.1).
//

import SwiftUI
import DesignKitThemes

struct ActivityRail: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        DSSurface(role: .titleBar) {
            VStack(spacing: Tokens.Spacing.xxs) {
                ForEach(ActivityRailTab.allCases, id: \.self) { tab in
                    ActivityRailItem(icon: tab.icon,
                                     isActive: store.state.activeRailTab == tab,
                                     help: tab.title) {
                        store.setActiveRailTab(tab)
                    }
                }
                Spacer()
                ActivityRailItem(icon: .settings, isActive: false, help: "Settings (⌘,)") {
                    store.presentSettings()
                }
            }
            .padding(.vertical, Tokens.Spacing.smMd)
            .frame(width: 52)
            .frame(maxHeight: .infinity)
        }
        .overlay(
            Rectangle()
                .fill(theme.colors.borderVariant.color)
                .frame(width: Tokens.Shape.strokeHairline),
            alignment: .trailing
        )
    }
}
