//
//  RenderHealthPill.swift
//  DiagramPlayground
//
//  Preview-header pill summarising the most recent render. Adopts
//  the v2.1 chrome tokens so the .ok / .slow / .failed states line
//  up with the rest of the canvas toolbar.
//

import SwiftUI

enum RenderHealthState {
    case ok(layoutMs: Int, paintMs: Int)
    case slow(layoutMs: Int, paintMs: Int)
    case failed(error: String)
}

struct RenderHealthPill: View {
    let state: RenderHealthState

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(label)
                .font(PlaygroundFont.metric)
                .foregroundStyle(tokens.palette.fg1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassChrome(.toolbar, in: Capsule())
        .accessibilityIdentifier("preview.renderHealth")
    }

    private var label: String {
        switch state {
        case let .ok(layoutMs, paintMs):
            return "ok · L \(layoutMs)ms · P \(paintMs)ms"
        case let .slow(layoutMs, paintMs):
            return "slow · L \(layoutMs)ms · P \(paintMs)ms"
        case let .failed(error):
            return "failed · \(error)"
        }
    }

    private var tint: Color {
        switch state {
        case .ok:     return tokens.palette.statusSuccess
        case .slow:   return tokens.palette.statusWarning
        case .failed: return tokens.palette.statusError
        }
    }
}
