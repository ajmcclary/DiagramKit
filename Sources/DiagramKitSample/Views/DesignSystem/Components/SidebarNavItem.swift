//
//  SidebarNavItem.swift
//  DiagramPlayground
//
//  Settings-sheet sidebar nav row (transcription §1.4).
//

import SwiftUI

struct SidebarNavItem: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isActive ? tokens.palette.accent : tokens.palette.fg3)
                    .frame(width: 15)
                Text(title).font(PlaygroundFont.sans(12.5, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? tokens.palette.accentSecondary : tokens.palette.fg2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(isActive ? tokens.palette.accentTint16 : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }.buttonStyle(.playground)
    }
}
