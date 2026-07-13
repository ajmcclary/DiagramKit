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
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                Text(title).dsFont(.body).foregroundStyle(environment.theme.colors.textPrimary.color)
                if let description {
                    Text(description).dsFont(.caption).foregroundStyle(environment.theme.colors.textSecondary.color)
                }
            }
            Spacer(minLength: DSTokens.Spacing.md)
            SwiftUI.Menu {
                content()
            } label: {
                HStack(spacing: DSTokens.Spacing.xs) {
                    if let leadingSwatch { leadingSwatch }
                    Text(value).dsFont(.caption).foregroundStyle(environment.theme.colors.textSecondary.color)
                    DSIconView(.disclosureDown, size: DSTokens.Icon.micro, colorRole: .muted)
                }
            }
            .menuStyle(.button).buttonStyle(.ds(role: .ghost, size: .compact)).fixedSize()
        }
        .padding(.horizontal, DSTokens.Spacing.lg).padding(.vertical, DSTokens.Spacing.md)
    }
}
