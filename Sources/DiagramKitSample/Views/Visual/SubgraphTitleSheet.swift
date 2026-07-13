//
//  SubgraphTitleSheet.swift
//  DiagramPlayground
//
//  Shared title prompt for empty-subgraph insert and subgraph rename
//  (visual editor plan 3). Sibling of SubgraphPromptSheet, which
//  remains dedicated to the marquee → group flow.
//

import SwiftUI
import DesignKitThemes

struct SubgraphTitleSheet: View {
    @Bindable var store: LiveEditorStore
    let prompt: SubgraphTitlePrompt

    @SwiftUI.State private var titleDraft: String = ""

    private var heading: String {
        switch prompt {
        case .insertEmpty: return "Name the new subgraph"
        case .rename: return "Rename subgraph"
        }
    }

    private var commitLabel: String {
        switch prompt {
        case .insertEmpty: return "Add"
        case .rename: return "Rename"
        }
    }

    var body: some View {
        DSGlassSurface(role: .popover) {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.md) {
            Text(heading)
                .dsFont(.headline)
            DSField("Subgraph title", text: $titleDraft)
            HStack {
                Button("Cancel") {
                    store.cancelTitlePrompt()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.ds(role: .ghost, size: .compact))
                Spacer()
                Button(commitLabel) {
                    let title = titleDraft.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    Task { await store.commitTitlePrompt(title: title) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.ds(role: .primary, size: .compact))
                .disabled(titleDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DSTokens.Spacing.lg)
        }
        .frame(width: 320)
        .onAppear {
            if case .rename(_, let current) = prompt {
                titleDraft = current
            }
        }
    }
}
