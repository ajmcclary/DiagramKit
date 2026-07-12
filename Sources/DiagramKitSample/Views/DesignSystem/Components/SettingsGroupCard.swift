//
//  SettingsGroupCard.swift
//  DiagramPlayground
//
//  Card container that auto-inserts 0.5px dividers between its child rows,
//  matching the grouped settings cards in the comp (transcription §1.4).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SettingsGroupCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        _VariadicView.Tree(DividedRows(divider: environment.theme.colors.borderVariant.color)) {
            content()
        }
        .background { DSSurface(role: .card) { Color.clear } }
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
                    Rectangle().fill(divider).frame(height: DSTokens.Stroke.hairline)
                }
            }
        }
    }
}
