//
//  HeaderCloseButton.swift
//  DiagramPlayground
//
//  Reusable close-button used by sheet and full-window headers
//  (CorpusBrowserView, ImporterProbeView, ExportSheet). Centralizes
//  the xmark glyph styling, accessibility label, and Esc-key shortcut
//  so close affordances stay visually and behaviorally consistent.
//

import SwiftUI

struct HeaderCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Close")
    }
}
