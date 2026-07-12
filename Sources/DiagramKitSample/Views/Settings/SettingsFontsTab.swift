//
//  SettingsFontsTab.swift
//  DiagramPlayground
//
//  Settings ▸ Fonts (transcription §5.7).
//

import SwiftUI
import DiagramKit
import DiagramKitSampleDesignSystem

struct SettingsFontsTab: View {
    @AppStorage(PlaygroundSettingsKeys.uiTextSize) private var uiTextSize = 13
    @Environment(\.dsEnvironment) private var environment
    private var diagramFonts: [String] { DiagramFontRegistry.registeredFontNames }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Fonts", subtitle: "Bundled and system typefaces.")
            SettingsGroupCard {
                MenuRow(title: "UI font", value: "SF Pro Text") { Button("SF Pro Text") {} }
                MenuRow(title: "Mono font", description: "Web fallback: JetBrains Mono", value: "SF Mono") { Button("SF Mono") {} }
                bundledRow(title: "Diagram font", value: diagramFonts.first ?? "Noto Sans")
                bundledRow(title: "Diagram mono", value: diagramFonts.count > 1 ? diagramFonts[1] : "Noto Sans Mono", mono: true)
                StepperRow(title: "UI text size", value: $uiTextSize, range: 10...20, unit: "pt")
            }.padding(.bottom, DSTokens.Spacing.lg)
            InfoCallout(text: "Bundled Noto fonts neutralize system-font drift — the same source renders the same glyph positions across macOS and iOS versions.")
            Spacer(minLength: 0)
        }
    }

    private func bundledRow(title: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(title).dsFont(.body).foregroundStyle(environment.theme.colors.textPrimary.color)
            Spacer()
            HStack(spacing: DSTokens.Spacing.xs) {
                DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
                Text("Bundled").dsFont(.badge).foregroundStyle(environment.theme.colors.success.color)
                Text(value).dsFont(mono ? .code : .caption).foregroundStyle(environment.theme.colors.textSecondary.color)
            }
        }
        .padding(.horizontal, DSTokens.Spacing.lg).padding(.vertical, DSTokens.Spacing.md)
    }
}
