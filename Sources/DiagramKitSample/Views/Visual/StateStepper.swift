//
//  StateStepper.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.6 — 7 numbered steps + ‹/› nav for walking the
//  Stage state machine in demos. Hidden by default; visible when
//  state.demoStepperVisible is on.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct StateStepper: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        HStack(spacing: 6) {
            Button(action: previousStage) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .a11y(label: "Previous stage", id: A11yID.Visual.tool("stage.prev"))

            ForEach(Array(VisualEditorState.Stage.allCases.enumerated()), id: \.offset) { index, stage in
                let isActive = stage == store.state.visualStage
                Button {
                    store.setVisualStage(stage)
                } label: {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .frame(width: 22, height: 22)
                        .background(
                            Circle().fill(isActive ? Color.accentColor : Color.gray.opacity(0.18))
                        )
                        .foregroundStyle(isActive ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .help(stage.label)
                .a11y(
                    label: LocalizedStringKey(stage.label),
                    id: A11yID.Visual.tool("stage.\(stage.rawValue)")
                )
            }

            Button(action: nextStage) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .a11y(label: "Next stage", id: A11yID.Visual.tool("stage.next"))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        )
        .accessibilityIdentifier(A11yID.Visual.stateStepper)
    }

    private func previousStage() {
        let all = VisualEditorState.Stage.allCases
        guard let i = all.firstIndex(of: store.state.visualStage), i > 0 else { return }
        store.setVisualStage(all[i - 1])
    }

    private func nextStage() {
        let all = VisualEditorState.Stage.allCases
        guard let i = all.firstIndex(of: store.state.visualStage), i + 1 < all.count else { return }
        store.setVisualStage(all[i + 1])
    }
}
