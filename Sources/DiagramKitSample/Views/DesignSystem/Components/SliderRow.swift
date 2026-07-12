//
//  SliderRow.swift
//  DiagramPlayground
//
//  Inspector "Node spacing" slider row with a mono value readout (transcription §3.1).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            HStack {
                Text(title).dsFont(.caption).foregroundStyle(environment.theme.colors.textSecondary.color)
                Spacer()
                Text("\(Int(value))").dsFont(.metric).foregroundStyle(environment.theme.colors.accent.color)
            }
            Slider(value: $value, in: range).tint(environment.theme.colors.accent.color)
        }
    }
}
