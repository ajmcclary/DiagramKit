//
//  EditorModePicker.swift
//  DiagramPlayground
//
//  Extracted Code / Config segmented tab bar.
//  Used by EditorPane to switch between source and config editing.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

/// Segmented picker for switching between Code and Config editor modes.
///
/// Extracted from ``EditorPane`` so it can be reused in toolbar or
/// navigation contexts.
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct EditorModePicker: View {
    @Binding var editorMode: EditorMode
    let theme: DiagramTheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EditorMode.allCases, id: \.self) { mode in
                Button {
                    editorMode = mode
                } label: {
                    Text(mode.tabLabel)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundColor(
                    editorMode == mode
                        ? Color(theme.foreground)
                        : Color(theme.effectiveMuted())
                )
                .background(
                    editorMode == mode
                        ? Color(theme.foreground).opacity(0.08)
                        : Color.clear
                )
            }
        }
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

#if DEBUG
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
#Preview {
    @Previewable @SwiftUI.State var mode: EditorMode = .code
    let previewTheme = DiagramTheme.default
    EditorModePicker(
        editorMode: $mode,
        theme: previewTheme
    )
    .padding()
    .background(Color(previewTheme.background))
}
#endif
