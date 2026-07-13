//
//  SliderRow.swift
//  DiagramPlayground
//
//  Inspector "Node spacing" slider row with a mono value readout (transcription §3.1).
//

import SwiftUI
import DesignKitThemes

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            HStack {
                Text(title).dsFont(.caption).foregroundStyle(theme.colors.textSecondary.color)
                Spacer()
                Text("\(Int(value))").dsFont(.metric).foregroundStyle(theme.colors.accent.color)
            }
            Slider(value: $value, in: range).tint(theme.colors.accent.color)
        }
    }
}
