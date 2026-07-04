//
//  MenuRow.swift
//  DiagramPlayground
//
//  Settings row: title (+desc) left; a menu value + chevron right.
//

import SwiftUI

struct MenuRow<Menu: View>: View {
    let title: String
    var description: String? = nil
    let value: String
    var leadingSwatch: AnyView? = nil
    @ViewBuilder var content: () -> Menu
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                if let description {
                    Text(description).font(PlaygroundFont.caption).foregroundStyle(tokens.palette.textFaint)
                }
            }
            Spacer(minLength: PlaygroundSpacing.md)
            SwiftUI.Menu {
                content()
            } label: {
                HStack(spacing: 6) {
                    if let leadingSwatch { leadingSwatch }
                    Text(value).font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.fg2)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(tokens.palette.fg3)
                }
            }
            .menuStyle(.button).buttonStyle(.plain).fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
