//
//  WorkspaceModePicker.swift
//  DiagramPlayground
//
//  Phase 1 / Task 1.3 — three-way segmented picker in the Titlebar.
//  Only `.code` is enabled in Phase 1; `.visual` and `.split` light up
//  in Phases 3 and 2 respectively.
//

import SwiftUI

struct WorkspaceModePicker: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(WorkspaceMode.allCases, id: \.self) { mode in
                button(for: mode)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    @ViewBuilder
    private func button(for mode: WorkspaceMode) -> some View {
        let isSelected = store.state.workspaceMode == mode
        Button {
            store.setWorkspaceMode(mode)
        } label: {
            Label(mode.label, systemImage: mode.sfSymbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
                }
        }
        .buttonStyle(.plain)
        .a11yToggle(
            label: LocalizedStringKey(mode.label),
            isOn: isSelected,
            id: identifier(for: mode)
        )
        .disabled(isDisabled(mode))
    }

    private func identifier(for mode: WorkspaceMode) -> String {
        switch mode {
        case .code:   return A11yID.Titlebar.modeCode
        case .visual: return A11yID.Titlebar.modeVisual
        case .split:  return A11yID.Titlebar.modeSplit
        }
    }

    /// Phase 3 unlocks `.visual`. All three modes are now selectable.
    private func isDisabled(_ mode: WorkspaceMode) -> Bool {
        false
    }
}
