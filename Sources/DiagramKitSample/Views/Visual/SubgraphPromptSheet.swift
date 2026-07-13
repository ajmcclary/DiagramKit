//
//  SubgraphPromptSheet.swift
//  DiagramPlayground
//
//  Phase 5 / Task 5.2 — small "Name this subgraph" prompt sheeted
//  over VisualPane after the user taps Group with a marquee
//  selection active.
//

import SwiftUI
import DesignKitThemes

struct SubgraphPromptSheet: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    @SwiftUI.State private var titleDraft: String = ""

    var body: some View {
        DSGlassSurface(role: .popover) {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.md) {
            Text("Name this subgraph")
                .dsFont(.headline)
            Text("\(store.state.marqueeSelection.count) nodes will be wrapped in a new subgraph block.")
                .dsFont(.caption2)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
            DSField("Subgraph title", text: $titleDraft, prompt: "e.g. renderers")
                .accessibilityIdentifier(A11yID.Visual.groupNameField)
            HStack {
                Button("Cancel") {
                    store.cancelSubgraphPrompt()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.ds(role: .ghost, size: .compact))
                Spacer()
                Button("Group") {
                    let title = titleDraft.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    Task { await store.commitSubgraph(title: title) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.ds(role: .primary, size: .compact))
                .disabled(titleDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier(A11yID.Visual.groupCommitButton)
            }
        }
        .padding(DSTokens.Spacing.lg)
        }
        .frame(width: 320)
    }
}
