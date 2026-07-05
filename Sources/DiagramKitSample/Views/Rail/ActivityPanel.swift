//
//  ActivityPanel.swift
//  DiagramPlayground
//
//  236px switchable side panel adjacent to the activity rail; shows the panel for
//  the active rail tab (transcription §3.1 / turn 2).
//

import SwiftUI

struct ActivityPanel: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        Group {
            switch store.state.activeRailTab {
            case .organize: OrganizePanel(store: store)
            case .browse: BrowsePanel(store: store)
            case .search: SearchPanel(store: store)
            case .source: SourcePanel(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(tokens.palette.bgPanel)
    }
}
