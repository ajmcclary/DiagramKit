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
import DiagramKitSampleDesignSystem

/// Segmented picker for switching between Code and Config editor modes.
///
/// Extracted from ``EditorPane`` so it can be reused in toolbar or
/// navigation contexts.
struct EditorModePicker: View {
    @Binding var editorMode: EditorMode

    var body: some View {
        DSSegmentedControl(EditorMode.allCases, selection: $editorMode) { mode in
            Text(mode.tabLabel)
                .accessibilityAddTraits(editorMode == mode ? .isSelected : [])
        }
        .accessibilityElement(children: .contain)
        .a11y(label: "Editor mode", id: A11yID.Pickers.editorMode)
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

#if DEBUG && !DIAGRAMKIT_SWIFTPM
#Preview {
    @Previewable @SwiftUI.State var mode: EditorMode = .code
    EditorModePicker(editorMode: $mode)
    .padding()
    .dsTheme(family: .lcars, mode: .dark)
}
#endif
