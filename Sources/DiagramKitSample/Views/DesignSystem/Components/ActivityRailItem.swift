//
//  ActivityRailItem.swift
//  DiagramPlayground
//
//  A single 38×38 tile in the far-left activity rail; active tile gets an accent
//  tint + a left marker bar (transcription §1.4 / §3.1).
//

import SwiftUI

struct ActivityRailItem: View {
    let systemImage: String
    let isActive: Bool
    let help: String
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 18))
                .foregroundStyle(isActive ? tokens.palette.accent : tokens.palette.fg3)
                .frame(width: 38, height: 38)
                .background(tileBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(alignment: .leading) {
                    if isActive {
                        RoundedRectangle(cornerRadius: 2).fill(tokens.palette.accent)
                            .frame(width: 2.5).padding(.vertical, 9).offset(x: -10)
                    }
                }
        }
        .buttonStyle(.playground)
        .onHover { isHovering = $0 }
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .help(help)
    }

    private var tileBackground: Color {
        if isActive { return tokens.palette.accentTint16 }
        if isHovering { return tokens.palette.rowHover }
        return .clear
    }
}
