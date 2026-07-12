//
//  InfoCallout.swift
//  DiagramPlayground
//
//  Muted info callout with a cyan info glyph (transcription §5.7).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct InfoCallout: View {
    let text: String
    var systemImage: String = "info.circle"
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack(alignment: .top, spacing: DSTokens.Spacing.sm) {
            DSIconView(.info, colorRole: .info)
            Text(text).dsFont(.caption2).lineSpacing(DSTokens.Spacing.xxxs)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSTokens.Spacing.lg).padding(.vertical, DSTokens.Spacing.md)
        .background { DSSurface(role: .panel) { Color.clear } }
    }
}
