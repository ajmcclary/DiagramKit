//
//  SettingsPlatformParityTab.swift
//  DiagramPlayground
//
//  Settings ▸ Platform Parity (transcription §5.5).
//

import SwiftUI
import DesignKitThemes

struct SettingsPlatformParityTab: View {
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Platform Parity", subtitle: "Feature coverage across build targets.")
            ParityTable(columns: PlatformParityMatrix.columns, rows: PlatformParityMatrix.rows).padding(.bottom, Tokens.Spacing.lg)
            legend
            Spacer(minLength: 0)
        }
    }

    private var legend: some View {
        HStack(spacing: Tokens.Spacing.lg) {
            HStack(spacing: Tokens.Spacing.xs) {
                DSIconView(.success, size: Tokens.Size.Icon.micro, colorRole: .success)
                Text("Full")
            }
            HStack(spacing: Tokens.Spacing.xs) {
                DSIconView(.warning, size: Tokens.Size.Icon.micro, colorRole: .warning)
                Text("Partial")
            }
            HStack(spacing: Tokens.Spacing.xs) {
                DSIconView(.error, size: Tokens.Size.Icon.micro, colorRole: .disabled)
                Text("Unsupported")
            }
            Spacer()
            Text("src_text_metrics.swift").dsFont(.code).foregroundStyle(theme.colors.textPlaceholder.color)
        }
        .dsFont(.caption2)
        .foregroundStyle(theme.colors.textSecondary.color)
        .padding(.horizontal, Tokens.Spacing.xxxs)
    }
}
