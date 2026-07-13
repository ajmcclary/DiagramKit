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
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            ForEach(Array(colors.enumerated()), id: \.offset) { i, color in
                Button { selectedIndex = i } label: {
                Circle().fill(color).frame(width: DSTokens.Control.chip, height: DSTokens.Control.chip)
                    .overlay {
                        if selectedIndex == i {
                            Circle().stroke(environment.theme.colors.borderSelected.color, lineWidth: DSTokens.Stroke.medium)
                                .padding(-DSTokens.Spacing.xxs)
                        }
                    }
                }
                .buttonStyle(.ds(role: .ghost, size: .compact))
            }
        }
    }
}
