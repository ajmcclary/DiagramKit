//
//  DestructiveButton.swift
//  DiagramPlayground
//
//  Destructive action button (transcription §1.4 / §5.1 "Reset All Settings").
//

import SwiftUI

struct DestructiveButton: View {
    let title: String
    var systemImage: String = "arrow.counterclockwise"
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .medium))
                Text(title).font(PlaygroundFont.sans(12.5))
            }
            .foregroundStyle(tokens.palette.statusError)
            .padding(.horizontal, 14).frame(height: 34)
            .background(tokens.palette.bgTrack)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.palette.borderDestructive, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
}
