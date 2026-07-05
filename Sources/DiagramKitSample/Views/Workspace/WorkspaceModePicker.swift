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
    @Environment(\.playgroundTokens) private var tokens

    /// Height of the selectable pills. The track wraps this with a 2pt
    /// inset, so the pills fill the track instead of floating shorter than
    /// its background.
    private let pillHeight: CGFloat = 22

    var body: some View {
        HStack(spacing: 2) {
            ForEach(WorkspaceMode.allCases, id: \.self) { mode in
                button(for: mode)
            }
        }
        .frame(height: pillHeight)
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tokens.palette.bgTrack)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func button(for mode: WorkspaceMode) -> some View {
        let isSelected = store.state.workspaceMode == mode
        Button {
            store.setWorkspaceMode(mode)
        } label: {
            Text(mode.label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? tokens.palette.onAccent : tokens.palette.fg3)
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? tokens.palette.accent : .clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.playground)
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
