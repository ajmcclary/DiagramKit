//
//  SwatchTile.swift
//  DiagramPlayground
//
//  Small theme card used by the inspector THEME section: title +
//  mini palette swatch column, selected highlight ring.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SwatchTile: View {
    var title: String
    var background: Color
    var swatches: [Color]
    var isSelected: Bool
    var action: () -> Void

    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: DSTokens.Radius.md, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSTokens.Radius.md, style: .continuous)
                            .stroke(
                                isSelected ? environment.theme.colors.borderSelected.color : environment.theme.colors.borderVariant.color,
                                lineWidth: isSelected ? DSTokens.Stroke.mediumLight : DSTokens.Stroke.hairline
                            )
                    )

                Text(title)
                    .dsFont(.badge)
                    .foregroundStyle(textColor(on: background))
                    .padding(.leading, DSTokens.Spacing.sm)
                    .padding(.bottom, DSTokens.Spacing.xs)

                VStack(spacing: DSTokens.Spacing.xxxs) {
                    ForEach(Array(swatches.enumerated()), id: \.offset) { _, swatch in
                        RoundedRectangle(cornerRadius: DSTokens.Radius.xs, style: .continuous)
                            .fill(swatch)
                            .frame(width: 12, height: 6)
                    }
                }
                .padding(.trailing, DSTokens.Spacing.sm)
                .padding(.top, DSTokens.Spacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(width: 72, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: isSelected ? .secondary : .ghost, size: .compact))
    }

    // Simple contrast: light backgrounds get dark text; dark backgrounds get
    // light text, judged from the tile's own background luminance.
    private func textColor(on background: Color) -> Color {
        background.dsIsLightSwatch ? .black.opacity(0.85) : .white.opacity(0.9)
    }
}
