//
//  SliderRow.swift
//  DiagramPlayground
//
//  Inspector "Node spacing" slider row with a mono value readout (transcription §3.1).
//

import SwiftUI

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg3)
                Spacer()
                Text("\(Int(value))").font(PlaygroundFont.mono(12)).foregroundStyle(tokens.palette.accentSecondary)
            }
            Slider(value: $value, in: range).tint(tokens.palette.accent)
        }
    }
}
