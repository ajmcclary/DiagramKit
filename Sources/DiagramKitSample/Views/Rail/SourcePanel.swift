//
//  SourcePanel.swift
//  DiagramPlayground
//
//  Activity-rail Source panel: the live source with a line gutter and active-line
//  highlight tracking the selection (transcription §6.4).
//

import SwiftUI
import DesignKitThemes

struct SourcePanel: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    private var lines: [String] { store.state.source.components(separatedBy: "\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Source · \(store.state.sourceFormat.rawValue.uppercased())") {
                DSIconView(.copy, size: Tokens.Size.Icon.micro, colorRole: .muted)
            }
            DSSurface(role: .sunken) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                            HStack(alignment: .top, spacing: 0) {
                                Text("\(i + 1)")
                                    .dsFont(.code)
                                    .foregroundStyle(theme.colors.textDisabled.color)
                                    .frame(width: Tokens.Spacing.xxxl, alignment: .trailing)
                                    .padding(.trailing, Tokens.Spacing.smMd)
                                Text(line.isEmpty ? " " : line)
                                    .dsFont(.code)
                                    .foregroundStyle(theme.colors.editorForeground.color)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, Tokens.Shape.strokeMedLight)
                            .background(
                                store.state.biSelLine == i + 1
                                    ? theme.colors.elementSelected.color
                                    : .clear
                            )
                        }
                    }
                    .padding(.vertical, Tokens.Spacing.sm)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    DSSurface(role: .statusBar) {
                        HStack(spacing: Tokens.Spacing.sm) {
                            DSStatusIndicator(.success, label: "Source synced")
                            Text("synced · \(lines.count) lines")
                                .dsFont(.code)
                                .foregroundStyle(theme.colors.textSecondary.color)
                            Spacer()
                        }
                        .padding(.horizontal, Tokens.Spacing.lg)
                        .frame(minHeight: Tokens.Size.Control.statusBar)
                    }
                }
            }
        }
    }
}
