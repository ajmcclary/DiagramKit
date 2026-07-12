//
//  StateStepper.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.6 — 7 numbered steps + ‹/› nav for walking the
//  Stage state machine in demos. Hidden by default; visible when
//  state.demoStepperVisible is on.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct StateStepper: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSGlassSurface(role: .popover) {
        HStack(spacing: DSTokens.Spacing.xs) {
            DSIconButton(.disclosureRight, label: "Previous stage", action: previousStage)
                .rotationEffect(.degrees(180))
            .a11y(label: "Previous stage", id: A11yID.Visual.tool("stage.prev"))

            ForEach(Array(VisualEditorState.Stage.allCases.enumerated()), id: \.offset) { index, stage in
                let isActive = stage == store.state.visualStage
                Button {
                    store.setVisualStage(stage)
                } label: {
                    Text("\(index + 1)")
                        .dsFont(.metric)
                        .frame(width: DSTokens.Control.chip, height: DSTokens.Control.chip)
                        .background(
                            Circle().fill(
                                isActive
                                    ? environment.theme.colors.accent.color
                                    : environment.theme.colors.element.color
                            )
                        )
                        .foregroundStyle(
                            isActive
                                ? environment.theme.colors.onAccent.color
                                : environment.theme.colors.textPrimary.color
                        )
                }
                .buttonStyle(.ds(role: isActive ? .secondary : .ghost, size: .compact))
                .help(stage.label)
                .a11y(
                    label: LocalizedStringKey(stage.label),
                    id: A11yID.Visual.tool("stage.\(stage.rawValue)")
                )
            }

            DSIconButton(.disclosureRight, label: "Next stage", action: nextStage)
            .a11y(label: "Next stage", id: A11yID.Visual.tool("stage.next"))
        }
        .padding(DSTokens.Spacing.sm)
        }
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
