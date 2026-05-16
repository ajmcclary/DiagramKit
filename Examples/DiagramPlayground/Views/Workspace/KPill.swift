//
//  KPill.swift
//  DiagramPlayground
//
//  Minimal pill primitive used by the v2 Inspector, Statusbar, and
//  floating health/diagnostic surfaces. Colors come from the chrome
//  tokens (`@Environment(\.playgroundTokens)`) so every pill follows
//  the current appearance.
//

import SwiftUI

enum KPillTone {
    case ok, warn, info, accent, neutral
}

struct KPill: View {
    let text: String
    var systemImage: String?
    var dot: Bool = false
    var tone: KPillTone = .neutral

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(spacing: 4) {
            if dot {
                Circle()
                    .fill(foreground)
                    .frame(width: 6, height: 6)
            }
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(PlaygroundFont.label)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(background))
        .foregroundStyle(foreground)
    }

    private var foreground: Color {
        switch tone {
        case .ok:      return tokens.palette.statusSuccess
        case .warn:    return tokens.palette.statusWarning
        case .info:    return tokens.palette.statusInfo
        case .accent:  return tokens.palette.accent
        case .neutral: return tokens.palette.fg2
        }
    }

    private var background: Color {
        switch tone {
        case .ok:      return tokens.palette.statusSuccess.opacity(0.16)
        case .warn:    return tokens.palette.statusWarning.opacity(0.16)
        case .info:    return tokens.palette.statusInfo.opacity(0.16)
        case .accent:  return tokens.palette.accent15
        case .neutral: return tokens.palette.bgSurface.opacity(0.6)
        }
    }
}
