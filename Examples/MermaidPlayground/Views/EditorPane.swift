//
//  EditorPane.swift
//  MermaidPlayground
//
//  Editor pane with Code/Config tab bar and the source editor.
//  The Config tab is a placeholder for Phase 3.
//

import SwiftUI
import DiagramKit

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct EditorPane: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (extracted component)
            EditorModePicker(
                editorMode: $store.state.editorMode,
                theme: store.theme
            )
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .background(Color(store.theme.background))

            // Editor content
            Group {
                switch store.state.editorMode {
                case .code:
                    SourceEditor(store: store)
                case .config:
                    ConfigEditor(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(store.theme.background))
    }
}


