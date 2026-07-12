//
//  DotPicker.swift
//  DiagramPlayground
//
//  Row of color dots used by the inspector THEME section for accent
//  selection. Selected dot wears a ring matching the chrome accent.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct DotPicker: View {
    var options: [Color]
    @Binding var selection: Color

    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, color in
                let isSelected = sameColor(color, selection)
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: DSTokens.Icon.sm, height: DSTokens.Icon.sm)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? environment.theme.colors.borderSelected.color : .clear, lineWidth: DSTokens.Stroke.mediumLight)
                                .padding(-DSTokens.Spacing.xxxs)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.ds(role: .ghost, size: .compact))
            }
        }
    }

    // Color isn't Equatable on the public API; compare via Hashable.
    private func sameColor(_ a: Color, _ b: Color) -> Bool {
        a.hashValue == b.hashValue
    }
}
