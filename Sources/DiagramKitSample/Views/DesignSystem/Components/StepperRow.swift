//
//  StepperRow.swift
//  DiagramPlayground
//
//  Settings row with a −/value/+ stepper; value shown monospace with a unit.
//

import SwiftUI
import DesignKitThemes

struct StepperRow: View {
    let title: String
    var description: String? = nil
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    var step: Int = 1
    var unit: String = ""
    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                Text(title).dsFont(.body).foregroundStyle(theme.colors.textPrimary.color)
                if let description {
                    Text(description).dsFont(.caption).foregroundStyle(theme.colors.textSecondary.color)
                }
            }
            Spacer(minLength: Tokens.Spacing.md)
            stepper
        }.padding(.horizontal, Tokens.Spacing.lg).padding(.vertical, Tokens.Spacing.md)
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            button("−") { value = max(range.lowerBound, value - step) }
            Text("\(value)\(unit.isEmpty ? "" : " \(unit)")").dsFont(.metric)
                .foregroundStyle(theme.colors.textPrimary.color).padding(.horizontal, Tokens.Spacing.smMd)
                .overlay(Rectangle().fill(theme.colors.borderVariant.color).frame(width: Tokens.Shape.strokeHairline), alignment: .leading)
                .overlay(Rectangle().fill(theme.colors.borderVariant.color).frame(width: Tokens.Shape.strokeHairline), alignment: .trailing)
            button("+") { value = min(range.upperBound, value + step) }
        }
        .overlay(RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM).stroke(theme.colors.borderVariant.color, lineWidth: Tokens.Shape.strokeThin))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM))
    }

    private func button(_ glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).dsFont(.metric).foregroundStyle(theme.colors.textSecondary.color)
        }.buttonStyle(.ds(role: .ghost, size: .compact))
    }
}
