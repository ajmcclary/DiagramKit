//
//  SettingsFontsTab.swift
//  DiagramPlayground
//
//  Settings ▸ Fonts (transcription §5.7).
//

import SwiftUI
import DiagramKit

struct SettingsFontsTab: View {
    @AppStorage(PlaygroundSettingsKeys.uiTextSize) private var uiTextSize = 13
    @Environment(\.playgroundTokens) private var tokens
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
            }.padding(.bottom, 16)
            InfoCallout(text: "Bundled Noto fonts neutralize system-font drift — the same source renders the same glyph positions across macOS and iOS versions.")
            Spacer(minLength: 0)
        }
    }

    private func bundledRow(title: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(tokens.palette.statusSuccess)
                Text("Bundled").font(PlaygroundFont.sans(11)).foregroundStyle(tokens.palette.statusSuccess)
                Text(value).font(mono ? PlaygroundFont.mono(12) : PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.fg2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
