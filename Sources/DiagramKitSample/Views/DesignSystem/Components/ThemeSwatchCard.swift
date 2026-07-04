//
//  ThemeSwatchCard.swift
//  DiagramPlayground
//
//  Theme-tab swatch card: a 3-bar preview over the theme bg + footer name.
//  Active card gets a 1.5px accent border + check (transcription §5.4).
//

import SwiftUI

struct ThemeSwatchCard: View {
    let name: String
    let background: Color
    let bars: [Color]
    let isActive: Bool
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    if bars.count > 0 { bar(bars[0], 0.55, 5) }
                    if bars.count > 1 { bar(bars[1], 0.82, 4) }
                    if bars.count > 2 { bar(bars[2], 0.44, 4) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 9).frame(height: 60).background(background)
                HStack {
                    Text(name).font(PlaygroundFont.sans(11.5))
                        .foregroundStyle(isActive ? tokens.palette.fg1 : tokens.palette.fg2)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tokens.palette.accent)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 7).frame(maxWidth: .infinity)
                .background(tokens.palette.bgCard)
                .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5), alignment: .top)
            }
            .clipShape(RoundedRectangle(cornerRadius: PlaygroundRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: PlaygroundRadius.md)
                    .stroke(isActive ? tokens.palette.accent : tokens.palette.borderHairline,
                            lineWidth: isActive ? 1.5 : 0.5)
            )
        }.buttonStyle(.plain)
    }

    private func bar(_ color: Color, _ frac: CGFloat, _ h: CGFloat) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: geo.size.width * frac, height: h)
        }.frame(height: h)
    }
}
