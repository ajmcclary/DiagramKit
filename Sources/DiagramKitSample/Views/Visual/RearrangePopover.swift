//
//  RearrangePopover.swift
//  DiagramPlayground
//
//  Rearrange picker (visual editor plan 6): Hierarchical vs Adaptive
//  layout preset cards. Selection persists via frontmatter.
//

import SwiftUI
import DiagramKitInteractive
import DesignKitThemes

struct RearrangePopover: View {
    @Bindable var store: LiveEditorStore
    let dismiss: () -> Void
    @Environment(\.designTheme) private var theme

    private var current: LayoutPreset {
        store.editor?.document.frontmatter?.layout == "adaptive" ? .adaptive : .hierarchical
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.smMd) {
            Text("Rearrange layout")
                .dsFont(.headline)
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
            HStack(spacing: Tokens.Spacing.smMd) {
                Label(title, systemImage: symbol)
                    .labelStyle(.iconOnly)
                    .dsFont(.headline)
                    .frame(width: Tokens.Size.Control.rowCompact)
                VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                    Text(title).dsFont(.body)
                    Text(detail)
                        .dsFont(.caption2)
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
                Spacer()
                if current == preset {
                    DSIconView(.success, size: Tokens.Size.Icon.micro, colorRole: .success)
                }
            }
            .padding(Tokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
                    .fill(
                        current == preset
                            ? theme.colors.elementSelected.color
                            : theme.colors.element.color
                    )
            )
        }
        .buttonStyle(.ds(role: current == preset ? .secondary : .ghost, size: .compact))
        .accessibilityIdentifier(A11yID.Visual.rearrangeOption(preset.rawValue))
    }
}
