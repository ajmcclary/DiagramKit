//
//  StepperRow.swift
//  DiagramPlayground
//
//  Settings row with a −/value/+ stepper; value shown monospace with a unit.
//

import SwiftUI

struct StepperRow: View {
    let title: String
    var description: String? = nil
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    var step: Int = 1
    var unit: String = ""
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                if let description {
                    Text(description).font(PlaygroundFont.caption).foregroundStyle(tokens.palette.textFaint)
                }
            }
            Spacer(minLength: PlaygroundSpacing.md)
            stepper
        }.padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            button("−") { value = max(range.lowerBound, value - step) }
            Text("\(value)\(unit.isEmpty ? "" : " \(unit)")").font(PlaygroundFont.mono(12))
                .foregroundStyle(tokens.palette.fg1).padding(.horizontal, 10).padding(.vertical, 5)
                .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(width: 0.5), alignment: .leading)
                .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(width: 0.5), alignment: .trailing)
            button("+") { value = min(range.upperBound, value + step) }
        }
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func button(_ glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(PlaygroundFont.mono(12)).foregroundStyle(tokens.palette.fg3)
                .padding(.horizontal, 10).padding(.vertical, 5)
        }.buttonStyle(.plain)
    }
}
