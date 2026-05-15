//
//  RenderHealthPill.swift
//  DiagramPlayground
//
//  Phase 2 / Task 2.4 — preview-header pill that summarises the most
//  recent render. Phase 2 only ships the `.ok` flavor; `.slow` and
//  `.failed` land in Phase 10 with the full health surface.
//

import SwiftUI

enum RenderHealthState {
    case ok(layoutMs: Int, paintMs: Int)
    case slow(layoutMs: Int, paintMs: Int)
    case failed(error: String)
}

struct RenderHealthPill: View {
    let state: RenderHealthState

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.18)))
        .foregroundStyle(tint)
        .accessibilityIdentifier("preview.renderHealth")
    }

    private var icon: String {
        switch state {
        case .ok:     return "checkmark.circle.fill"
        case .slow:   return "hare.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
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
        case .ok:     return .green
        case .slow:   return .orange
        case .failed: return .red
        }
    }
}
