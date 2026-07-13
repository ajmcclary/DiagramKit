//
//  SettingsFontsTab.swift
//  DiagramPlayground
//
//  Settings ▸ Fonts (transcription §5.7).
//

import SwiftUI
import DiagramKit
import DesignKitThemes

struct SettingsFontsTab: View {
    @AppStorage(PlaygroundSettingsKeys.uiTextSize) private var uiTextSize = 13
    @Environment(\.designTheme) private var theme
    private var diagramFonts: [String] { DiagramFontRegistry.registeredFontNames }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Fonts", subtitle: "Bundled and system typefaces.")
            DSSettingGroup {
                MenuRow(title: "UI font", value: "SF Pro Text") { Button("SF Pro Text") {} }
                MenuRow(title: "Mono font", description: "Web fallback: JetBrains Mono", value: "SF Mono") { Button("SF Mono") {} }
                bundledRow(title: "Diagram font", value: diagramFonts.first ?? "Noto Sans")
                bundledRow(title: "Diagram mono", value: diagramFonts.count > 1 ? diagramFonts[1] : "Noto Sans Mono", mono: true)
                StepperRow(title: "UI text size", value: $uiTextSize, range: 10...20, unit: "pt")
            }.padding(.bottom, Tokens.Spacing.lg)
            infoCallout
            Spacer(minLength: 0)
        }
    }

    private var infoCallout: some View {
        DSSurface(role: .panel) {
            HStack(alignment: .top, spacing: Tokens.Spacing.sm) {
                DSIconView(.info, colorRole: .info)
                Text("Bundled Noto fonts neutralize system-font drift — the same source renders the same glyph positions across macOS and iOS versions.")
                    .dsFont(.caption2)
                    .lineSpacing(Tokens.Spacing.xxxs)
                    .foregroundStyle(theme.colors.textSecondary.color)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Tokens.Spacing.lg)
            .padding(.vertical, Tokens.Spacing.md)
        }
    }

    private func bundledRow(title: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(title).dsFont(.body).foregroundStyle(theme.colors.textPrimary.color)
            Spacer()
            HStack(spacing: Tokens.Spacing.xs) {
                DSIconView(.success, size: Tokens.Size.Icon.micro, colorRole: .success)
                Text("Bundled").dsFont(.badge).foregroundStyle(theme.colors.success.color)
                Text(value).dsFont(mono ? .code : .caption).foregroundStyle(theme.colors.textSecondary.color)
            }
        }
        .padding(.horizontal, Tokens.Spacing.lg).padding(.vertical, Tokens.Spacing.md)
    }
}
