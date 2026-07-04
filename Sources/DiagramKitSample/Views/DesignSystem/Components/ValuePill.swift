//
//  ValuePill.swift
//  DiagramPlayground
//
//  Inspector value pill: optional icon + label + chevron (transcription §3.1 "Shape").
//

import SwiftUI

struct ValuePill: View {
    let label: String
    var systemImage: String? = nil
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let img = systemImage { Image(systemName: img).font(.system(size: 11)) }
                Text(label).font(PlaygroundFont.sans(12))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tokens.palette.fg3)
            }
            .foregroundStyle(tokens.palette.fg1)
            .padding(.horizontal, 8).frame(height: 28)
            .background(tokens.palette.bgTrack)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain)
    }
}
