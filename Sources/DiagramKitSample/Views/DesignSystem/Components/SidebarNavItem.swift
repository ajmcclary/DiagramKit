//
//  SidebarNavItem.swift
//  DiagramPlayground
//
//  Settings-sheet sidebar nav row (transcription §1.4).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SidebarNavItem: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: DSTokens.Spacing.sm) {
                DSIconView(icon, size: DSTokens.Icon.micro, colorRole: isActive ? .primary : .muted)
                Text(title).dsFont(.caption)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DSTokens.Spacing.smMd)
            .contentShape(Rectangle())
        }.buttonStyle(.ds(role: isActive ? .secondary : .ghost, size: .regular))
    }

    private var icon: DSIcon {
        switch systemImage {
        case "chevron.left.forwardslash.chevron.right": .code
        case "paintpalette": .theme
        case "rectangle.on.rectangle", "rectangle.split.2x1": .diagram
        case "textformat": .info
        case "number": .rearrange
        default: .settings
        }
    }
}
