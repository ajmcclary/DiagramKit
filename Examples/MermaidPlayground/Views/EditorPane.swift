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
    let store: LiveEditorStore

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            editorTabBar

            // Editor content
            Group {
                switch store.state.editorMode {
                case .code:
                    SourceEditor(store: store)
                case .config:
                    configPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(store.theme.background))
    }

    // MARK: - Tab bar

    private var editorTabBar: some View {
        HStack(spacing: 0) {
            ForEach(EditorMode.allCases, id: \.self) { mode in
                Button {
                    store.state.editorMode = mode
                } label: {
                    Text(mode.tabLabel)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundColor(
                    store.state.editorMode == mode
                        ? Color(store.theme.foreground)
                        : Color(store.theme.effectiveMuted())
                )
                .background(
                    store.state.editorMode == mode
                        ? Color(store.theme.foreground).opacity(0.08)
                        : Color.clear
                )
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .background(Color(store.theme.background))
    }

    // MARK: - Config placeholder (Phase 3)

    private var configPlaceholder: some View {
        VStack {
            Image(systemName: "gearshape")
                .font(.system(size: 32))
                .foregroundColor(Color(store.theme.effectiveMuted()))
            Text("Config editor coming in Phase 3")
                .font(.body)
                .foregroundColor(Color(store.theme.effectiveMuted()))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension EditorMode {
    var tabLabel: String {
        switch self {
        case .code: return "Code"
        case .config: return "Config"
        }
    }
}
