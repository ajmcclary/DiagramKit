//
//  SubgraphPromptSheet.swift
//  DiagramPlayground
//
//  Phase 5 / Task 5.2 — small "Name this subgraph" prompt sheeted
//  over VisualPane after the user taps Group with a marquee
//  selection active.
//

import SwiftUI

struct SubgraphPromptSheet: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var titleDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name this subgraph")
                .font(.system(size: 13, weight: .semibold))
            Text("\(store.state.marqueeSelection.count) nodes will be wrapped in a new subgraph block.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Subgraph title (e.g. renderers)", text: $titleDraft)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(A11yID.Visual.groupNameField)
            HStack {
                Button("Cancel") {
                    store.cancelSubgraphPrompt()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                Spacer()
                Button("Group") {
                    let title = titleDraft.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    Task { await store.commitSubgraph(title: title) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(titleDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier(A11yID.Visual.groupCommitButton)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
    }
}
