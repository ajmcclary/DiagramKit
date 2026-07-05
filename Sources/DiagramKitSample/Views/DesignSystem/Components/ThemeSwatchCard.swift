//
//  ThemeSwatchCard.swift
//  DiagramPlayground
//
//  Theme-picker card for the Zed Trek family, rendered from a ZedTrekSpecimen so
//  it matches the design project's theme-family preview exactly: the theme name
//  in its signature color, a row of five accent swatches, and a `let n = 42`
//  mono sample — all over the theme's own background. Self-contained: it paints
//  in the theme's own colors, not the currently-active chrome tokens.
//

import SwiftUI

struct ThemeSwatchCard: View {
    let name: String
    let specimen: ZedTrekSpecimen
    var isStarred: Bool = false
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(PlaygroundFont.sans(11.5, weight: .bold))
                        .foregroundStyle(specimen.nameColor)
                    if isStarred {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(specimen.nameColor)
                    }
                    Spacer(minLength: 0)
                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(specimen.accents.first ?? specimen.nameColor)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(Array(specimen.accents.enumerated()), id: \.offset) { _, c in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(c)
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(specimen.textColor.opacity(0.10), lineWidth: 0.5))
                    }
                }
                Text("let n = 42")
                    .font(PlaygroundFont.mono(10))
                    .foregroundStyle(specimen.textColor.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minHeight: 82, alignment: .top)
            .background(specimen.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: PlaygroundRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PlaygroundRadius.md, style: .continuous)
                    .stroke(isActive ? (specimen.accents.first ?? specimen.nameColor)
                                     : specimen.textColor.opacity(0.14),
                            lineWidth: isActive ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
