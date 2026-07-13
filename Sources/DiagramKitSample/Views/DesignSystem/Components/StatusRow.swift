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
    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                Text(title).dsFont(.body).foregroundStyle(theme.colors.textPrimary.color)
                if let description {
                    Text(description).dsFont(monospaced ? .code : .caption)
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
            }
            Spacer(minLength: Tokens.Spacing.md)
            HStack(spacing: Tokens.Spacing.xs) {
                if let dotColor { Circle().fill(dotColor).frame(width: Tokens.Size.Icon.indicator, height: Tokens.Size.Icon.indicator) }
                Text(value).dsFont(monospaced ? .metric : .caption)
                    .foregroundStyle(valueColor ?? theme.colors.textSecondary.color)
            }
        }
        .padding(.horizontal, Tokens.Spacing.lg).padding(.vertical, Tokens.Spacing.md)
    }
}
