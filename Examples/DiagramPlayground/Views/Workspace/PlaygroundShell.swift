//
//  PlaygroundShell.swift
//  DiagramPlayground
//
//  Custom three-column shell that replaces NavigationSplitView for
//  iPad-regular / macOS layouts. Phase 1 wires Titlebar / Sidebar /
//  EditorPane / Inspector / Statusbar; Phases 2+ swap the body for
//  Visual / Split surfaces.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct PlaygroundShell: View {
    @Bindable var store: LiveEditorStore

    @AppStorage("playground.shell.sidebarVisible") private var sidebarVisible = true
    @AppStorage("playground.shell.inspectorVisible") private var inspectorVisible = true

    var body: some View {
        VStack(spacing: 0) {
            TitlebarView(store: store)
            Divider()
            HStack(spacing: 0) {
                if sidebarVisible {
                    SidebarView(store: store)
                        .frame(width: 260)
                    Divider()
                }
                EditorPane(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if inspectorVisible {
                    Divider()
                    InspectorView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            StatusbarView(store: store)
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
    }
}
