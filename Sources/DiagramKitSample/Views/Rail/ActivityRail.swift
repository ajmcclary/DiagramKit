//
//  ActivityRail.swift
//  DiagramPlayground
//
//  Far-left 52px activity rail: Organize / Browse / Search / Source tiles plus a
//  bottom settings tile (transcription §3.1).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct ActivityRail: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSSurface(role: .titleBar) {
            VStack(spacing: DSTokens.Spacing.xxs) {
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
            .padding(.vertical, DSTokens.Spacing.smMd)
            .frame(width: 52)
            .frame(maxHeight: .infinity)
        }
        .overlay(
            Rectangle()
                .fill(environment.theme.colors.borderVariant.color)
                .frame(width: DSTokens.Stroke.hairline),
            alignment: .trailing
        )
    }
}
