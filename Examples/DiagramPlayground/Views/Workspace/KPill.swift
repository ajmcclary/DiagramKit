//
//  KPill.swift
//  DiagramPlayground
//
//  Minimal pill primitive used by the v2 Inspector, Statusbar, and
//  upcoming health/diagnostic surfaces.
//

import SwiftUI

enum KPillTone {
    case ok, warn, info, accent, neutral

    var foreground: Color {
        switch self {
        case .ok:      return .green
        case .warn:    return .orange
        case .info:    return .blue
        case .accent:  return .accentColor
        case .neutral: return .secondary
        }
    }

    var background: Color {
        foreground.opacity(0.16)
    }
}

struct KPill: View {
    let text: String
    var systemImage: String?
    var tone: KPillTone = .neutral

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(tone.background))
        .foregroundStyle(tone.foreground)
    }
}
