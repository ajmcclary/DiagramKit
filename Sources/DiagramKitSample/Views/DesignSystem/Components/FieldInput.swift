//
//  FieldInput.swift
//  DiagramPlayground
//
//  Focus-ring text field used by the selection card and search
//  inputs. Mirrors the v2 mockup field treatment (sunken bg,
//  hairline border, accent ring on focus).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct FieldInput: View {
    var placeholder: String
    @Binding var text: String
    var systemImage: String?
    var trailingHint: String?
    var onSubmit: (() -> Void)?

    @Environment(\.dsEnvironment) private var environment
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: DSTokens.Spacing.xs) {
            if let systemImage {
                DSIconView(icon(for: systemImage), size: DSTokens.Icon.micro, colorRole: .muted)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .dsFont(.body)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
                .focused($focused)
                .onSubmit { onSubmit?() }
            if let trailingHint {
                Text(trailingHint)
                    .dsFont(.badge)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                    .padding(.horizontal, DSTokens.Spacing.xs)
                    .padding(.vertical, DSTokens.Spacing.xxxs)
                    .background(
                        RoundedRectangle(cornerRadius: DSTokens.Radius.xs, style: .continuous)
                            .stroke(environment.theme.colors.borderVariant.color, lineWidth: DSTokens.Stroke.hairline)
                    )
            }
        }
        .padding(.horizontal, DSTokens.Spacing.sm)
        .padding(.vertical, DSTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
                .fill(environment.theme.colors.editorBackground.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
                .stroke(
                    focused ? environment.theme.colors.borderFocused.color : environment.theme.colors.borderVariant.color,
                    lineWidth: focused ? DSTokens.Stroke.thin : DSTokens.Stroke.hairline
                )
        )
        .background(
            RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
                .stroke(focused ? environment.theme.colors.borderFocused.color.opacity(DSTokens.Opacity.glassHighlight) : .clear, lineWidth: DSTokens.Stroke.thick)
        )
    }

    private func icon(for systemImage: String) -> DSIcon {
        systemImage == "magnifyingglass" ? .search : .info
    }
}
