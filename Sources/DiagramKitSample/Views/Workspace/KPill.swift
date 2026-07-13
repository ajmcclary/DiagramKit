//
//  KPill.swift
//  DiagramPlayground
//
//  Minimal pill primitive used by the v2 Inspector, Statusbar, and
//  floating health/diagnostic surfaces. Colors come from the chrome
//  semantic theme roles (`@Environment(\.dsEnvironment)`) so every pill follows
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

    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack(spacing: DSTokens.Spacing.xxs) {
            if dot {
                Circle()
                    .fill(foreground)
                    .frame(width: DSTokens.Radius.sm, height: DSTokens.Radius.sm)
            }
            if let icon {
                DSIconView(icon, size: DSTokens.Icon.indicator, colorRole: iconColorRole)
            }
            Text(text)
                .dsFont(.badge)
        }
        .padding(.horizontal, DSTokens.Spacing.xs)
        .padding(.vertical, DSTokens.Stroke.medium)
        .background(Capsule().fill(background))
        .foregroundStyle(foreground)
    }

    private var foreground: Color {
        switch tone {
        case .ok:      return environment.theme.colors.success.color
        case .warn:    return environment.theme.colors.warning.color
        case .info:    return environment.theme.colors.info.color
        case .accent:  return environment.theme.colors.accent.color
        case .neutral: return environment.theme.colors.textSecondary.color
        }
    }

    private var background: Color {
        switch tone {
        case .ok:      return environment.theme.colors.value("success.background").color
        case .warn:    return environment.theme.colors.value("warning.background").color
        case .info:    return environment.theme.colors.value("info.background").color
        case .accent:  return environment.theme.colors.accent.color.opacity(DSTokens.Opacity.glassHighlight)
        case .neutral: return environment.theme.colors.surfaceBackground.color.opacity(DSTokens.Opacity.strong)
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
