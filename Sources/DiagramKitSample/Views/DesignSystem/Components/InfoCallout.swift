//
//  InfoCallout.swift
//  DiagramPlayground
//
//  Muted info callout with a cyan info glyph (transcription §5.7).
//

import SwiftUI

struct InfoCallout: View {
    let text: String
    var systemImage: String = "info.circle"
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage).font(.system(size: 14, weight: .medium))
                .foregroundStyle(tokens.palette.catCyan)
            Text(text).font(PlaygroundFont.sans(11.5)).lineSpacing(3).foregroundStyle(tokens.palette.fg3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(tokens.palette.bgSidebarNav)
        .overlay(RoundedRectangle(cornerRadius: PlaygroundRadius.md).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: PlaygroundRadius.md))
    }
}
