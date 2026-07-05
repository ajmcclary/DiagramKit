//
//  SegmentedFormatControl.swift
//  DiagramPlayground
//
//  Generic segmented control matching the settings/format style (transcription §1.4).
//

import SwiftUI

struct SegmentedFormatControl<Value: Hashable>: View {
    struct Segment: Identifiable {
        let value: Value
        let label: String
        var systemImage: String? = nil
        var monospaced: Bool = false
        var id: Value { value }
    }
    let segments: [Segment]
    @Binding var selection: Value
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(spacing: 3) {
            ForEach(segments) { seg in
                let active = seg.value == selection
                Button { selection = seg.value } label: {
                    HStack(spacing: 6) {
                        if let img = seg.systemImage {
                            Image(systemName: img).font(.system(size: 12, weight: .medium))
                        }
                        Text(seg.label).font(seg.monospaced
                            ? PlaygroundFont.mono(12.5, weight: active ? .semibold : .regular)
                            : PlaygroundFont.sans(12.5, weight: active ? .semibold : .regular))
                    }
                    .foregroundStyle(active ? tokens.palette.onAccent : tokens.palette.fg3)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(active ? tokens.palette.accent : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.playground)
            }
        }
        .padding(3).background(tokens.palette.bgTrack)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
