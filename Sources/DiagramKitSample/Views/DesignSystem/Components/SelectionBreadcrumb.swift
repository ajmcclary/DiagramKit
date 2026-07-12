//
//  SelectionBreadcrumb.swift
//  DiagramPlayground
//
//  Canvas selection breadcrumb pill, e.g. `flowchart:node:A` (transcription §3.1).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SelectionBreadcrumb: View {
    let text: String
    var systemImage: String = "rectangle"
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack(spacing: DSTokens.Spacing.xs) {
            DSIconView(.node, size: DSTokens.Icon.micro)
            Text(text).dsFont(.code)
        }
        .foregroundStyle(environment.theme.colors.accent.color)
        .padding(.horizontal, DSTokens.Spacing.smMd).padding(.vertical, DSTokens.Spacing.xs)
        .background(environment.theme.colors.elementSelected.color)
        .overlay(RoundedRectangle(cornerRadius: DSTokens.Radius.chip).stroke(environment.theme.colors.borderSelected.color, lineWidth: DSTokens.Stroke.hairline))
        .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.chip))
    }
}
