//
//  StatusRow.swift
//  DiagramPlayground
//
//  Settings row: title (+desc) left; a colored status dot + word right, or a
//  plain/mono readout value (dotColor: nil).
//

import SwiftUI

struct StatusRow: View {
    let title: String
    var description: String? = nil
    let value: String
    var valueColor: Color? = nil
    var dotColor: Color? = nil
    var monospaced: Bool = false
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                if let description {
                    Text(description).font(monospaced ? PlaygroundFont.mono(11) : PlaygroundFont.caption)
                        .foregroundStyle(tokens.palette.textFaint)
                }
            }
            Spacer(minLength: PlaygroundSpacing.md)
            HStack(spacing: 6) {
                if let dotColor { Circle().fill(dotColor).frame(width: 7, height: 7) }
                Text(value).font(monospaced ? PlaygroundFont.mono(12) : PlaygroundFont.sans(12))
                    .foregroundStyle(valueColor ?? tokens.palette.fg2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
