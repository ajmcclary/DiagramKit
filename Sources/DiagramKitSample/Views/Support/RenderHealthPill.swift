//
//  RenderHealthPill.swift
//  DiagramPlayground
//
//  Preview-header pill summarising the most recent render. Adopts
//  the v2.1 chrome tokens so the .ok / .slow / .failed states line
//  up with the rest of the canvas toolbar.
//

import SwiftUI
import DesignKitThemes

enum RenderHealthState {
    case ok(layoutMs: Int, paintMs: Int)
    case slow(layoutMs: Int, paintMs: Int)
    case failed(error: String)
}

struct RenderHealthPill: View {
    let state: RenderHealthState

    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSGlassSurface(role: .toolbar) {
            HStack(spacing: DSTokens.Spacing.xs) {
                Circle()
                    .fill(tint)
                    .frame(width: DSTokens.Icon.indicator, height: DSTokens.Icon.indicator)
                Text(label)
                    .dsFont(.metric)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
            }
            .padding(.horizontal, DSTokens.Spacing.smMd)
            .padding(.vertical, DSTokens.Spacing.xs)
        }
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
        case .ok:     return environment.theme.colors.success.color
        case .slow:   return environment.theme.colors.warning.color
        case .failed: return environment.theme.colors.error.color
        }
    }
}
