//
//  CodeChip.swift
//  DiagramPlayground
//
//  Inline monospaced code badge, e.g. `DiagramEditor.perform(.setLabel)`.
//

import SwiftUI

struct CodeChip: View {
    var text: String
    var tone: KPillTone

    @Environment(\.playgroundTokens) private var tokens

    init(_ text: String, tone: KPillTone = .neutral) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .font(PlaygroundFont.codeChip)
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: PlaygroundRadius.xs, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: PlaygroundRadius.xs, style: .continuous)
                            .stroke(border, lineWidth: 0.5)
                    )
            )
    }

    private var foreground: Color {
        switch tone {
        case .ok:      return tokens.palette.statusSuccess
        case .warn:    return tokens.palette.statusWarning
        case .info:    return tokens.palette.statusInfo
        case .accent:  return tokens.palette.accent
        case .neutral: return tokens.palette.fg1
        }
    }

    private var background: Color {
        switch tone {
        case .ok:      return tokens.palette.statusSuccess.opacity(0.12)
        case .warn:    return tokens.palette.statusWarning.opacity(0.12)
        case .info:    return tokens.palette.statusInfo.opacity(0.12)
        case .accent:  return tokens.palette.accent15
        case .neutral: return tokens.palette.bgSurface.opacity(0.6)
        }
    }

    private var border: Color {
        switch tone {
        case .ok:      return tokens.palette.statusSuccess.opacity(0.35)
        case .warn:    return tokens.palette.statusWarning.opacity(0.35)
        case .info:    return tokens.palette.statusInfo.opacity(0.35)
        case .accent:  return tokens.palette.accent.opacity(0.35)
        case .neutral: return tokens.palette.borderHairline
        }
    }
}
