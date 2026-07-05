//
//  DotPicker.swift
//  DiagramPlayground
//
//  Row of color dots used by the inspector THEME section for accent
//  selection. Selected dot wears a ring matching the chrome accent.
//

import SwiftUI

struct DotPicker: View {
    var options: [Color]
    @Binding var selection: Color

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(spacing: PlaygroundSpacing.sm) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, color in
                let isSelected = sameColor(color, selection)
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? tokens.palette.fg1 : .clear, lineWidth: 1.5)
                                .padding(-3)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.playground)
            }
        }
    }

    // Color isn't Equatable on the public API; compare via Hashable.
    private func sameColor(_ a: Color, _ b: Color) -> Bool {
        a.hashValue == b.hashValue
    }
}
