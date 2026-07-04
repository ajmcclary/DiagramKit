//
//  SettingsPlatformParityTab.swift
//  DiagramPlayground
//
//  Settings ▸ Platform Parity (transcription §5.5).
//

import SwiftUI

struct SettingsPlatformParityTab: View {
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Platform Parity", subtitle: "Feature coverage across build targets.")
            ParityTable(columns: PlatformParityMatrix.columns, rows: PlatformParityMatrix.rows).padding(.bottom, 14)
            legend
            Spacer(minLength: 0)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(tokens.palette.statusSuccess)
                Text("Full")
            }
            HStack(spacing: 5) {
                Circle().fill(tokens.palette.statusWarning).frame(width: 8, height: 8)
                Text("Partial")
            }
            HStack(spacing: 5) {
                Text("—").foregroundStyle(tokens.palette.textFaintest)
                Text("Unsupported")
            }
            Spacer()
            Text("src_text_metrics.swift").font(PlaygroundFont.mono(11)).foregroundStyle(tokens.palette.textFaint)
        }
        .font(PlaygroundFont.sans(11)).foregroundStyle(tokens.palette.textFaint).padding(.horizontal, 2)
    }
}
