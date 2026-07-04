//
//  SettingsGroupCard.swift
//  DiagramPlayground
//
//  Card container that auto-inserts 0.5px dividers between its child rows,
//  matching the grouped settings cards in the comp (transcription §1.4).
//

import SwiftUI

struct SettingsGroupCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        _VariadicView.Tree(DividedRows(divider: tokens.palette.borderHairline)) {
            content()
        }
        .background(tokens.palette.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: PlaygroundRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: PlaygroundRadius.md)
                .stroke(tokens.palette.borderHairline, lineWidth: 0.5)
        )
    }
}

private struct DividedRows: _VariadicView_MultiViewRoot {
    let divider: Color
    @ViewBuilder func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        VStack(spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != last {
                    Rectangle().fill(divider).frame(height: 0.5)
                }
            }
        }
    }
}
