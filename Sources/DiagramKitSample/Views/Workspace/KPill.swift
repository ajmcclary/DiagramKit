//
//  KPill.swift
//  DiagramPlayground
//
//  Minimal pill primitive used by the v2 Inspector, Statusbar, and
//  floating health/diagnostic surfaces. Colors come from the chrome
//  semantic theme roles (`@Environment(\.designTheme)`) so every pill follows
//  the current appearance.
//

import SwiftUI
import DesignKitThemes

enum KPillTone {
    case ok, warn, info, accent, neutral
}

struct KPill: View {
    let text: String
    var icon: DSIcon?
    var dot: Bool = false
    var tone: KPillTone = .neutral

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            if dot {
                Circle()
                    .fill(foreground)
                    .frame(width: Tokens.Shape.radiusSM, height: Tokens.Shape.radiusSM)
            }
            if let icon {
                DSIconView(icon, size: Tokens.Size.Icon.indicator, colorRole: iconColorRole)
            }
            Text(text)
                .dsFont(.badge)
        }
        .padding(.horizontal, Tokens.Spacing.xs)
        .padding(.vertical, Tokens.Shape.strokeMedium)
        .background(Capsule().fill(background))
        .foregroundStyle(foreground)
    }

    private var foreground: Color {
        switch tone {
        case .ok:      return theme.colors.success.color
        case .warn:    return theme.colors.warning.color
        case .info:    return theme.colors.info.color
        case .accent:  return theme.colors.accent.color
        case .neutral: return theme.colors.textSecondary.color
        }
    }

    private var background: Color {
        switch tone {
        case .ok:      return theme.colors.value("success.background").color
        case .warn:    return theme.colors.value("warning.background").color
        case .info:    return theme.colors.value("info.background").color
        case .accent:  return theme.colors.accent.color.opacity(Tokens.Opacity.glassHighlight)
        case .neutral: return theme.colors.surfaceBackground.color.opacity(Tokens.Opacity.strong)
        }
    }

    private var iconColorRole: DSIconColorRole {
        switch tone {
        case .ok: .success
        case .warn: .warning
        case .info: .info
        case .accent: .primary
        case .neutral: .muted
        }
    }
}
