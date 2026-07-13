//
//  StatusRow.swift
//  DiagramPlayground
//
//  Settings row: title (+desc) left; a colored status dot + word right, or a
//  plain/mono readout value (dotColor: nil).
//

import SwiftUI
import DesignKitThemes

struct StatusRow: View {
    let title: String
    var description: String? = nil
    let value: String
    var valueColor: Color? = nil
    var dotColor: Color? = nil
    var monospaced: Bool = false
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                Text(title).dsFont(.body).foregroundStyle(environment.theme.colors.textPrimary.color)
                if let description {
                    Text(description).dsFont(monospaced ? .code : .caption)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                }
            }
            Spacer(minLength: DSTokens.Spacing.md)
            HStack(spacing: DSTokens.Spacing.xs) {
                if let dotColor { Circle().fill(dotColor).frame(width: DSTokens.Icon.indicator, height: DSTokens.Icon.indicator) }
                Text(value).dsFont(monospaced ? .metric : .caption)
                    .foregroundStyle(valueColor ?? environment.theme.colors.textSecondary.color)
            }
        }
        .padding(.horizontal, DSTokens.Spacing.lg).padding(.vertical, DSTokens.Spacing.md)
    }
}
