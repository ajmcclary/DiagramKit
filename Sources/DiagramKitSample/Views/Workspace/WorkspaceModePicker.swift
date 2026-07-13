//
//  WorkspaceModePicker.swift
//  DiagramPlayground
//
//  Phase 1 / Task 1.3 — three-way segmented picker in the Titlebar.
//  Only `.code` is enabled in Phase 1; `.visual` and `.split` light up
//  in Phases 3 and 2 respectively.
//

import SwiftUI
import DesignKitThemes

struct WorkspaceModePicker: View {
    @Bindable var store: LiveEditorStore
    var body: some View {
        DSSegmentedControl(
            WorkspaceMode.allCases,
            selection: Binding(
                get: { store.state.workspaceMode },
                set: { store.setWorkspaceMode($0) }
            )
        ) { mode in
            Text(mode.label)
                .accessibilityIdentifier(identifier(for: mode))
        }
    }

    private func identifier(for mode: WorkspaceMode) -> String {
        switch mode {
        case .code:   return A11yID.Titlebar.modeCode
        case .visual: return A11yID.Titlebar.modeVisual
        case .split:  return A11yID.Titlebar.modeSplit
        }
    }
}
