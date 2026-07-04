//
//  SelectionBreadcrumb.swift
//  DiagramPlayground
//
//  Canvas selection breadcrumb pill, e.g. `flowchart:node:A` (transcription §3.1).
//

import SwiftUI

struct SelectionBreadcrumb: View {
    let text: String
    var systemImage: String = "rectangle"
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 11))
            Text(text).font(PlaygroundFont.mono(12))
        }
        .foregroundStyle(tokens.palette.accentSecondary)
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(tokens.palette.accentTint14)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.palette.accent.opacity(0.4), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
