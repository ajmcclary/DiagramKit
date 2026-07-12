//
//  ValuePill.swift
//  DiagramPlayground
//
//  Inspector value pill: optional icon + label + chevron (transcription §3.1 "Shape").
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct ValuePill: View {
    let label: String
    var systemImage: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: DSTokens.Spacing.xs) {
                if systemImage != nil { DSIconView(.node, size: DSTokens.Icon.micro) }
                Text(label).dsFont(.caption)
                DSIconView(.disclosureDown, size: DSTokens.Icon.micro, colorRole: .muted)
            }
        }.buttonStyle(.ds(role: .secondary, size: .compact))
    }
}
