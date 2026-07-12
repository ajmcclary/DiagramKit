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
import DiagramKitSampleDesignSystem

struct HeaderCloseButton: View {
    let action: () -> Void

    var body: some View {
        DSIconButton(.close, label: "Close", action: action)
        .keyboardShortcut(.cancelAction)
    }
}
