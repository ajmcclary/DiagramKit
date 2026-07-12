//
//  SettingsPlatformParityTab.swift
//  DiagramPlayground
//
//  Settings ▸ Platform Parity (transcription §5.5).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SettingsPlatformParityTab: View {
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Platform Parity", subtitle: "Feature coverage across build targets.")
            ParityTable(columns: PlatformParityMatrix.columns, rows: PlatformParityMatrix.rows).padding(.bottom, DSTokens.Spacing.lg)
            legend
            Spacer(minLength: 0)
        }
    }

    private var legend: some View {
        HStack(spacing: DSTokens.Spacing.lg) {
            HStack(spacing: DSTokens.Spacing.xs) {
                DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
                Text("Full")
            }
            HStack(spacing: DSTokens.Spacing.xs) {
                DSIconView(.warning, size: DSTokens.Icon.micro, colorRole: .warning)
                Text("Partial")
            }
            HStack(spacing: DSTokens.Spacing.xs) {
                DSIconView(.error, size: DSTokens.Icon.micro, colorRole: .disabled)
                Text("Unsupported")
            }
            Spacer()
            Text("src_text_metrics.swift").dsFont(.code).foregroundStyle(environment.theme.colors.textPlaceholder.color)
        }
        .dsFont(.caption2)
        .foregroundStyle(environment.theme.colors.textSecondary.color)
        .padding(.horizontal, DSTokens.Spacing.xxxs)
    }
}
