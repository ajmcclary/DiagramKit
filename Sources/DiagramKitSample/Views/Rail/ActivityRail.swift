//
//  ActivityRail.swift
//  DiagramPlayground
//
//  Far-left 52px activity rail: Organize / Browse / Search / Source tiles plus a
//  bottom settings tile (transcription §3.1).
//

import SwiftUI

struct ActivityRail: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(spacing: 4) {
            ForEach(ActivityRailTab.allCases, id: \.self) { tab in
                ActivityRailItem(systemImage: tab.systemImage,
                                 isActive: store.state.activeRailTab == tab,
                                 help: tab.title) {
                    store.setActiveRailTab(tab)
                }
            }
            Spacer()
            ActivityRailItem(systemImage: "slider.horizontal.3", isActive: false, help: "Settings (⌘,)") {
                store.presentSettings()
            }
        }
        .padding(.vertical, 10)
        .frame(width: 52)
        .frame(maxHeight: .infinity)
        .background(tokens.palette.bgRail)
        .overlay(Rectangle().fill(tokens.palette.borderWarm).frame(width: 0.5), alignment: .trailing)
    }
}
