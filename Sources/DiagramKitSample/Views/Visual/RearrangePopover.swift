//
//  RearrangePopover.swift
//  DiagramPlayground
//
//  Rearrange picker (visual editor plan 6): Hierarchical vs Adaptive
//  layout preset cards. Selection persists via frontmatter.
//

import SwiftUI
import DiagramKitInteractive

struct RearrangePopover: View {
    @Bindable var store: LiveEditorStore
    let dismiss: () -> Void

    private var current: LayoutPreset {
        store.editor?.document.frontmatter?.layout == "adaptive" ? .adaptive : .hierarchical
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rearrange layout")
                .font(.system(size: 12, weight: .semibold))
            card(
                preset: .hierarchical,
                title: "Hierarchical",
                detail: "Top-down tree structure. Best for org charts and decision trees.",
                symbol: "square.grid.3x1.below.line.grid.1x2"
            )
            card(
                preset: .adaptive,
                title: "Adaptive",
                detail: "Arranges by connections. Best for complex, dense flows.",
                symbol: "point.3.connected.trianglepath.dotted"
            )
        }
        .padding(12)
        .frame(width: 280)
    }

    private func card(preset: LayoutPreset, title: String, detail: String, symbol: String) -> some View {
        Button {
            dismiss()
            Task { await store.applyLayoutPreset(preset) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .medium))
                    Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if current == preset {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(current == preset ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.Visual.rearrangeOption(preset.rawValue))
    }
}
