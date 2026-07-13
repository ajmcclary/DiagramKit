//
//  ColorDotPicker.swift
//  DiagramPlayground
//
//  Row of round color dots; selected dot gets a double-ring (transcription §3.1).
//

import SwiftUI
import DesignKitThemes

struct ColorDotPicker: View {
    let colors: [Color]
    @Binding var selectedIndex: Int?
    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            ForEach(Array(colors.enumerated()), id: \.offset) { i, color in
                Button { selectedIndex = i } label: {
                Circle().fill(color).frame(width: Tokens.Size.Control.chip, height: Tokens.Size.Control.chip)
                    .overlay {
                        if selectedIndex == i {
                            Circle().stroke(theme.colors.borderSelected.color, lineWidth: Tokens.Shape.strokeMedium)
                                .padding(-Tokens.Spacing.xxs)
                        }
                    }
                }
                .buttonStyle(.ds(role: .ghost, size: .compact))
            }
        }
    }
}
