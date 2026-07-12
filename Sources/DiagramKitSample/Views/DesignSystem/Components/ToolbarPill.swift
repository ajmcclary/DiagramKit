//
//  ToolbarPill.swift
//  DiagramPlayground
//
//  Floating glass pill used by the canvas top toolbar: optional
//  leading status dot + label + optional trailing metric.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct ToolbarPill: View {
    var label: String
    var dotColor: Color?
    var systemImage: String?
    var trailing: String?

    @Environment(\.dsEnvironment) private var environment

    init(
        label: String,
        dotColor: Color? = nil,
        systemImage: String? = nil,
        trailing: String? = nil
    ) {
        self.label = label
        self.dotColor = dotColor
        self.systemImage = systemImage
        self.trailing = trailing
    }

    var body: some View {
        DSGlassSurface(role: .popover) {
        HStack(spacing: DSTokens.Spacing.xs) {
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: DSTokens.Icon.indicator, height: DSTokens.Icon.indicator)
            }
            if let systemImage {
                DSIconView(systemImage == "magnifyingglass" ? .search : .info, size: DSTokens.Icon.micro, colorRole: .muted)
            }
            Text(label)
                .dsFont(.badge)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
            if let trailing {
                Text(trailing)
                    .dsFont(.metric)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            }
        }
        .padding(.horizontal, DSTokens.Spacing.smMd)
        .padding(.vertical, DSTokens.Spacing.xs)
        }
    }
}
