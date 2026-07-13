//
//  SettingsTabHeader.swift
//  DiagramPlayground
//
//  Shared H1 + subtitle for a settings tab, and the uppercase section caption
//  (transcription §4/§5.1).
//

import SwiftUI
import DesignKitThemes

struct SettingsTabHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
            Text(title).dsFont(.title)
            Text(subtitle).dsFont(.caption)
        }.padding(.bottom, Tokens.Spacing.md)
    }
}

struct SettingsSectionCaption: View {
    let text: String
    var body: some View {
        DSSectionHeader(text)
            .padding(.top, Tokens.Spacing.xxs)
            .padding(.bottom, Tokens.Spacing.sm)
    }
}
