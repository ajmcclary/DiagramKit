//
//  ColorDotPicker.swift
//  DiagramPlayground
//
//  Row of round color dots; selected dot gets a double-ring (transcription §3.1).
//

import SwiftUI

struct ColorDotPicker: View {
    let colors: [Color]
    @Binding var selectedIndex: Int?
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(spacing: 9) {
            ForEach(Array(colors.enumerated()), id: \.offset) { i, color in
                Circle().fill(color).frame(width: 26, height: 26)
                    .overlay {
                        if selectedIndex == i {
                            Circle().stroke(tokens.palette.accent, lineWidth: 2).padding(-3.5)
                        }
                    }
                    .onTapGesture { selectedIndex = i }
            }
        }
    }
}
