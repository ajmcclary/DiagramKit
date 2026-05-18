//
//  SwatchTile.swift
//  DiagramPlayground
//
//  Small theme card used by the inspector THEME section: title +
//  mini palette swatch column, selected highlight ring.
//

import SwiftUI

struct SwatchTile: View {
    var title: String
    var background: Color
    var swatches: [Color]
    var isSelected: Bool
    var action: () -> Void

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: PlaygroundRadius.md, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: PlaygroundRadius.md, style: .continuous)
                            .stroke(
                                isSelected ? tokens.palette.accent : tokens.palette.borderHairline,
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )

                Text(title)
                    .font(PlaygroundFont.label)
                    .foregroundStyle(textColor(on: background))
                    .padding(.leading, 8)
                    .padding(.bottom, 6)

                VStack(spacing: 3) {
                    ForEach(Array(swatches.enumerated()), id: \.offset) { _, swatch in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(swatch)
                            .frame(width: 12, height: 6)
                    }
                }
                .padding(.trailing, 8)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(width: 72, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Simple contrast: light backgrounds get fg1 in dark; dark backgrounds get fg1 in light.
    private func textColor(on background: Color) -> Color {
        // Approximation: use white over visibly dark backgrounds.
        // For the four built-in themes this is correct.
        switch tokens.appearance {
        case .light, .neutral: return .black.opacity(0.85)
        case .dark, .forest: return .white.opacity(0.9)
        }
    }
}
