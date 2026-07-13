//
//  SubgraphCommitToast.swift
//  DiagramPlayground
//
//  Phase 5 / Task 5.2 — bottom-trailing toast confirming a subgraph
//  was committed; auto-dismisses after 2.5s. Shows ⌘Z hint.
//

import SwiftUI
import DesignKitThemes

struct SubgraphCommitToast: View {
    @Bindable var store: LiveEditorStore
    let commit: SubgraphCommit
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSGlassSurface(role: .popover) {
        HStack(spacing: DSTokens.Spacing.sm) {
            DSIconView(.subgraph, colorRole: .info)
            VStack(alignment: .leading, spacing: DSTokens.Stroke.thin) {
                Text("Grouped \(commit.memberIDs.count) nodes into “\(commit.title)”")
                    .dsFont(.headline)
                Text("⌘Z to undo")
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            }
        }
        .padding(.horizontal, DSTokens.Spacing.md)
        .padding(.vertical, DSTokens.Spacing.sm)
        }
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
