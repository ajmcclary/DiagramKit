//
//  CodeChip.swift
//  DiagramPlayground
//
//  Inline monospaced code badge, e.g. `DiagramEditor.perform(.setLabel)`.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct CodeChip: View {
    var text: String
    var tone: KPillTone

    @Environment(\.dsEnvironment) private var environment

    init(_ text: String, tone: KPillTone = .neutral) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .dsFont(.code)
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: DSTokens.Radius.xs, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSTokens.Radius.xs, style: .continuous)
                            .stroke(border, lineWidth: DSTokens.Stroke.hairline)
                    )
            )
    }

    private var foreground: Color {
        switch tone {
        case .ok:      return environment.theme.colors.success.color
        case .warn:    return environment.theme.colors.warning.color
        case .info:    return environment.theme.colors.info.color
        case .accent:  return environment.theme.colors.accent.color
        case .neutral: return environment.theme.colors.textPrimary.color
        }
    }

    private var background: Color {
        switch tone {
        case .ok:      return environment.theme.colors.success.color.opacity(DSTokens.Opacity.glassFill)
        case .warn:    return environment.theme.colors.warning.color.opacity(DSTokens.Opacity.glassFill)
        case .info:    return environment.theme.colors.info.color.opacity(DSTokens.Opacity.glassFill)
        case .accent:  return environment.theme.colors.accent.color.opacity(DSTokens.Opacity.glassHighlight)
        case .neutral: return environment.theme.colors.element.color
        }
    }

    private var border: Color {
        switch tone {
        case .ok:      return environment.theme.colors.success.color.opacity(DSTokens.Opacity.disabled)
        case .warn:    return environment.theme.colors.warning.color.opacity(DSTokens.Opacity.disabled)
        case .info:    return environment.theme.colors.info.color.opacity(DSTokens.Opacity.disabled)
        case .accent:  return environment.theme.colors.accent.color.opacity(DSTokens.Opacity.disabled)
        case .neutral: return environment.theme.colors.borderVariant.color
        }
    }
}
