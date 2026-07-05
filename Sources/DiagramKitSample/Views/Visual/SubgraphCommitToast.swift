//
//  SubgraphCommitToast.swift
//  DiagramPlayground
//
//  Phase 5 / Task 5.2 — bottom-trailing toast confirming a subgraph
//  was committed; auto-dismisses after 2.5s. Shows ⌘Z hint.
//

import SwiftUI

struct SubgraphCommitToast: View {
    @Bindable var store: LiveEditorStore
    let commit: SubgraphCommit

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack.fill.badge.plus")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Grouped \(commit.memberIDs.count) nodes into “\(commit.title)”")
                    .font(.system(size: 11, weight: .semibold))
                Text("⌘Z to undo")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassChrome(.hud, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityIdentifier(A11yID.Visual.subgraphToast)
        .task(id: commit) {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                if store.lastSubgraphCommit == commit {
                    store.dismissSubgraphToast()
                }
            }
        }
    }
}
