//
//  DestructiveButton.swift
//  DiagramPlayground
//
//  Destructive action button (transcription §1.4 / §5.1 "Reset All Settings").
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct DestructiveButton: View {
    let title: String
    var systemImage: String = "arrow.counterclockwise"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: DSTokens.Spacing.sm) {
                DSIconView(.reset, size: DSTokens.Icon.micro, colorRole: .error)
                Text(title).dsFont(.caption)
            }
        }.buttonStyle(.ds(role: .destructive, size: .regular))
    }
}
