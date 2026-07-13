//
//  ThemeSwatchCard.swift
//  DiagramPlayground
//
//  Theme-picker card for the Zed Trek family, rendered from a DSThemeSpecimen so
//  it matches the design project's theme-family preview exactly: the theme name
//  in its signature color, a row of five accent swatches, and a `let n = 42`
//  mono sample — all over the theme's own background. Self-contained: it paints
//  in the theme's own colors, not the currently-active chrome tokens.
//

import SwiftUI
import DesignKitThemes

struct ThemeSwatchCard: View {
    let name: String
    let specimen: DSThemeSpecimen
    var isStarred: Bool = false
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                HStack(spacing: Tokens.Spacing.xxs) {
                    Text(name)
                        .dsFont(.badge)
                        .foregroundStyle(specimen.nameColor)
                    if isStarred {
                        DSIconView(.favorite, size: Tokens.Size.Icon.micro)
                    }
                    Spacer(minLength: 0)
                    if isActive {
                        DSIconView(.success, size: Tokens.Size.Icon.micro, colorRole: .success)
                    }
                }
                HStack(spacing: Tokens.Spacing.xxs) {
                    ForEach(Array(specimen.accents.enumerated()), id: \.offset) { _, c in
                        RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS, style: .continuous)
                            .fill(c)
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS, style: .continuous)
                                .stroke(specimen.textColor.opacity(Tokens.Opacity.tint), lineWidth: Tokens.Shape.strokeHairline))
                    }
                }
                Text("let n = 42")
                    .dsFont(.code)
                    .foregroundStyle(specimen.textColor.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Spacing.md).padding(.vertical, Tokens.Spacing.smMd)
            .frame(minHeight: 82, alignment: .top)
            .background(specimen.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Shape.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Shape.radiusMD, style: .continuous)
                    .stroke(isActive ? (specimen.accents.first ?? specimen.nameColor)
                                     : specimen.textColor.opacity(0.14),
                            lineWidth: isActive ? Tokens.Shape.strokeMedLight : Tokens.Shape.strokeHairline)
            )
        }
        .buttonStyle(.ds(role: isActive ? .secondary : .ghost, size: .compact))
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
