//
//  SourcePanel.swift
//  DiagramPlayground
//
//  Activity-rail Source panel: the live source with a line gutter and active-line
//  highlight tracking the selection (transcription §6.4).
//

import SwiftUI

struct SourcePanel: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.playgroundTokens) private var tokens

    private var lines: [String] { store.state.source.components(separatedBy: "\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Source · \(store.state.sourceFormat.rawValue.uppercased())") {
                Image(systemName: "doc.on.doc").font(.system(size: 12)).foregroundStyle(tokens.palette.fg3)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                        HStack(alignment: .top, spacing: 0) {
                            Text("\(i + 1)").font(PlaygroundFont.mono(12)).foregroundStyle(tokens.palette.gutter)
                                .frame(width: 30, alignment: .trailing).padding(.trailing, 10)
                            Text(line.isEmpty ? " " : line).font(PlaygroundFont.mono(12))
                                .foregroundStyle(tokens.palette.fg2)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 1.5)
                        .background((store.state.biSelLine == i + 1) ? tokens.palette.accentTint08 : .clear)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(tokens.palette.bgField)
            .overlay(alignment: .bottom) {
                HStack(spacing: 8) {
                    Circle().fill(tokens.palette.statusSuccess).frame(width: 6, height: 6)
                    Text("synced · \(lines.count) lines").font(PlaygroundFont.mono(11)).foregroundStyle(tokens.palette.textFaint)
                    Spacer()
                }
                .padding(.horizontal, 15).frame(height: 30)
                .background(tokens.palette.bgPanel)
                .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5), alignment: .top)
            }
        }
    }
}
