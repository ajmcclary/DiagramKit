//
//  MenuRow.swift
//  DiagramPlayground
//
//  Settings row: title (+desc) left; a menu value + chevron right.
//

import SwiftUI
import DesignKitThemes

struct MenuRow<Menu: View>: View {
    let title: String
    var description: String? = nil
    let value: String
    var leadingSwatch: AnyView? = nil
    @ViewBuilder var content: () -> Menu
    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                Text(title).dsFont(.body).foregroundStyle(theme.colors.textPrimary.color)
                if let description {
                    Text(description).dsFont(.caption).foregroundStyle(theme.colors.textSecondary.color)
                }
            }
            Spacer(minLength: Tokens.Spacing.md)
            SwiftUI.Menu {
                content()
            } label: {
                HStack(spacing: Tokens.Spacing.xs) {
                    if let leadingSwatch { leadingSwatch }
                    Text(value).dsFont(.caption).foregroundStyle(theme.colors.textSecondary.color)
                    DSIconView(.disclosureDown, size: Tokens.Size.Icon.micro, colorRole: .muted)
                }
            }
            .menuStyle(.button).buttonStyle(.ds(role: .ghost, size: .compact)).fixedSize()
        }
        .padding(.horizontal, Tokens.Spacing.lg).padding(.vertical, Tokens.Spacing.md)
    }
}
