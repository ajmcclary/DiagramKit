//
//  SwatchTile.swift
//  DiagramPlayground
//
//  Small theme card used by the inspector THEME section: title +
//  mini palette swatch column, selected highlight ring.
//

import SwiftUI
import DesignKitThemes

struct SwatchTile: View {
    var title: String
    var background: Color
    var swatches: [Color]
    var isSelected: Bool
    var action: () -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: Tokens.Shape.radiusMD, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Shape.radiusMD, style: .continuous)
                            .stroke(
                                isSelected ? theme.colors.borderSelected.color : theme.colors.borderVariant.color,
                                lineWidth: isSelected ? Tokens.Shape.strokeMedLight : Tokens.Shape.strokeHairline
                            )
                    )

                Text(title)
                    .dsFont(.badge)
                    .foregroundStyle(textColor(on: background))
                    .padding(.leading, Tokens.Spacing.sm)
                    .padding(.bottom, Tokens.Spacing.xs)

                VStack(spacing: Tokens.Spacing.xxxs) {
                    ForEach(Array(swatches.enumerated()), id: \.offset) { _, swatch in
                        RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS, style: .continuous)
                            .fill(swatch)
                            .frame(width: 12, height: 6)
                    }
                }
                .padding(.trailing, Tokens.Spacing.sm)
                .padding(.top, Tokens.Spacing.sm)
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
