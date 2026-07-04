//
//  SettingsTabHeader.swift
//  DiagramPlayground
//
//  Shared H1 + subtitle for a settings tab, and the uppercase section caption
//  (transcription §4/§5.1).
//

import SwiftUI

struct SettingsTabHeader: View {
    let title: String
    let subtitle: String
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(PlaygroundFont.sans(16, weight: .semibold)).foregroundStyle(tokens.palette.fg1)
            Text(subtitle).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg3)
        }.padding(.bottom, 13)
    }
}

struct SettingsSectionCaption: View {
    let text: String
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        Text(text.uppercased()).font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
            .foregroundStyle(tokens.palette.fg3).padding(.top, 4).padding(.bottom, 9)
    }
}
