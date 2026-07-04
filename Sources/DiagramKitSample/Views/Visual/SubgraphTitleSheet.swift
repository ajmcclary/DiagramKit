//
//  SubgraphTitleSheet.swift
//  DiagramPlayground
//
//  Shared title prompt for empty-subgraph insert and subgraph rename
//  (visual editor plan 3). Sibling of SubgraphPromptSheet, which
//  remains dedicated to the marquee → group flow.
//

import SwiftUI

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
        VStack(alignment: .leading, spacing: 12) {
            Text(heading)
                .font(.system(size: 13, weight: .semibold))
            TextField("Subgraph title", text: $titleDraft)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") {
                    store.cancelTitlePrompt()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                Spacer()
                Button(commitLabel) {
                    let title = titleDraft.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    Task { await store.commitTitlePrompt(title: title) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(titleDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .onAppear {
            if case .rename(_, let current) = prompt {
                titleDraft = current
            }
        }
    }
}
