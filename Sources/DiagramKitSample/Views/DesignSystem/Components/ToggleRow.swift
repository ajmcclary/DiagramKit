//
//  ToggleRow.swift
//  DiagramPlayground
//
//  Settings row: title (+ optional description) left, a pill switch right.
//  Matches the editor-redesign comp (transcription §1.4).
//

import SwiftUI

struct ToggleRow: View {
    let title: String
    var description: String? = nil
    @Binding var isOn: Bool
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                if let description {
                    Text(description).font(PlaygroundFont.caption).foregroundStyle(tokens.palette.textFaint)
                }
            }
            Spacer(minLength: PlaygroundSpacing.md)
            PillSwitch(isOn: $isOn)
        }
        .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
    }
}

/// 40×24 pill switch. ON: accent track + white knob right; OFF: track bg + muted knob left.
struct PillSwitch: View {
    @Binding var isOn: Bool
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        Capsule().fill(isOn ? tokens.palette.accent : tokens.palette.bgTrack)
            .frame(width: 40, height: 24)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(isOn ? .white : tokens.palette.fg3).frame(width: 20, height: 20).padding(2)
            }
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() } }
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isOn ? "on" : "off")
    }
}
