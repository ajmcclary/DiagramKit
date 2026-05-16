//
//  FieldInput.swift
//  DiagramPlayground
//
//  Focus-ring text field used by the selection card and search
//  inputs. Mirrors the v2 mockup field treatment (sunken bg,
//  hairline border, accent ring on focus).
//

import SwiftUI

struct FieldInput: View {
    var placeholder: String
    @Binding var text: String
    var systemImage: String?
    var trailingHint: String?
    var onSubmit: (() -> Void)?

    @Environment(\.playgroundTokens) private var tokens
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: PlaygroundSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tokens.palette.fg3)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(PlaygroundFont.body)
                .foregroundStyle(tokens.palette.fg1)
                .focused($focused)
                .onSubmit { onSubmit?() }
            if let trailingHint {
                Text(trailingHint)
                    .font(PlaygroundFont.badge)
                    .foregroundStyle(tokens.palette.fg3)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, PlaygroundSpacing.sm)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: PlaygroundRadius.sm, style: .continuous)
                .fill(tokens.palette.bgSunken.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PlaygroundRadius.sm, style: .continuous)
                .stroke(
                    focused ? tokens.palette.accent : tokens.palette.borderHairline,
                    lineWidth: focused ? 1 : 0.5
                )
        )
        .background(
            RoundedRectangle(cornerRadius: PlaygroundRadius.sm, style: .continuous)
                .stroke(focused ? tokens.palette.accent15 : .clear, lineWidth: 3)
        )
    }
}
