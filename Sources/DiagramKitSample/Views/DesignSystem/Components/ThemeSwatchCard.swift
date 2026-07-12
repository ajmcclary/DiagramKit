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
import DiagramKitSampleDesignSystem

struct ThemeSwatchCard: View {
    let name: String
    let specimen: DSThemeSpecimen
    var isStarred: Bool = false
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xs) {
                HStack(spacing: DSTokens.Spacing.xxs) {
                    Text(name)
                        .dsFont(.badge)
                        .foregroundStyle(specimen.nameColor)
                    if isStarred {
                        DSIconView(.favorite, size: DSTokens.Icon.micro)
                    }
                    Spacer(minLength: 0)
                    if isActive {
                        DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
                    }
                }
                HStack(spacing: DSTokens.Spacing.xxs) {
                    ForEach(Array(specimen.accents.enumerated()), id: \.offset) { _, c in
                        RoundedRectangle(cornerRadius: DSTokens.Radius.xs, style: .continuous)
                            .fill(c)
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: DSTokens.Radius.xs, style: .continuous)
                                .stroke(specimen.textColor.opacity(DSTokens.Opacity.tint), lineWidth: DSTokens.Stroke.hairline))
                    }
                }
                Text("let n = 42")
                    .dsFont(.code)
                    .foregroundStyle(specimen.textColor.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSTokens.Spacing.md).padding(.vertical, DSTokens.Spacing.smMd)
            .frame(minHeight: 82, alignment: .top)
            .background(specimen.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSTokens.Radius.md, style: .continuous)
                    .stroke(isActive ? (specimen.accents.first ?? specimen.nameColor)
                                     : specimen.textColor.opacity(0.14),
                            lineWidth: isActive ? DSTokens.Stroke.mediumLight : DSTokens.Stroke.hairline)
            )
        }
        .buttonStyle(.ds(role: isActive ? .secondary : .ghost, size: .compact))
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
