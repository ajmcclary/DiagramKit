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
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                Text(title).dsFont(.body).foregroundStyle(environment.theme.colors.textPrimary.color)
                if let description {
                    Text(description).dsFont(.caption).foregroundStyle(environment.theme.colors.textSecondary.color)
                }
            }
            Spacer(minLength: DSTokens.Spacing.md)
            stepper
        }.padding(.horizontal, DSTokens.Spacing.lg).padding(.vertical, DSTokens.Spacing.md)
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            button("−") { value = max(range.lowerBound, value - step) }
            Text("\(value)\(unit.isEmpty ? "" : " \(unit)")").dsFont(.metric)
                .foregroundStyle(environment.theme.colors.textPrimary.color).padding(.horizontal, DSTokens.Spacing.smMd)
                .overlay(Rectangle().fill(environment.theme.colors.borderVariant.color).frame(width: DSTokens.Stroke.hairline), alignment: .leading)
                .overlay(Rectangle().fill(environment.theme.colors.borderVariant.color).frame(width: DSTokens.Stroke.hairline), alignment: .trailing)
            button("+") { value = min(range.upperBound, value + step) }
        }
        .overlay(RoundedRectangle(cornerRadius: DSTokens.Radius.sm).stroke(environment.theme.colors.borderVariant.color, lineWidth: DSTokens.Stroke.thin))
        .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.sm))
    }

    private func button(_ glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).dsFont(.metric).foregroundStyle(environment.theme.colors.textSecondary.color)
        }.buttonStyle(.ds(role: .ghost, size: .compact))
    }
}
