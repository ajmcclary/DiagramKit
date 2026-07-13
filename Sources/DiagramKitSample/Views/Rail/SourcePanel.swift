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
    @Environment(\.dsEnvironment) private var environment

    private var lines: [String] { store.state.source.components(separatedBy: "\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Source · \(store.state.sourceFormat.rawValue.uppercased())") {
                DSIconView(.copy, size: DSTokens.Icon.micro, colorRole: .muted)
            }
            DSSurface(role: .sunken) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                            HStack(alignment: .top, spacing: 0) {
                                Text("\(i + 1)")
                                    .dsFont(.code)
                                    .foregroundStyle(environment.theme.colors.textDisabled.color)
                                    .frame(width: DSTokens.Spacing.xxxl, alignment: .trailing)
                                    .padding(.trailing, DSTokens.Spacing.smMd)
                                Text(line.isEmpty ? " " : line)
                                    .dsFont(.code)
                                    .foregroundStyle(environment.theme.colors.editorForeground.color)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, DSTokens.Stroke.mediumLight)
                            .background(
                                store.state.biSelLine == i + 1
                                    ? environment.theme.colors.elementSelected.color
                                    : .clear
                            )
                        }
                    }
                    .padding(.vertical, DSTokens.Spacing.sm)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    DSSurface(role: .statusBar) {
                        HStack(spacing: DSTokens.Spacing.sm) {
                            DSStatusIndicator(.success, label: "Source synced")
                            Text("synced · \(lines.count) lines")
                                .dsFont(.code)
                                .foregroundStyle(environment.theme.colors.textSecondary.color)
                            Spacer()
                        }
                        .padding(.horizontal, DSTokens.Spacing.lg)
                        .frame(minHeight: DSTokens.Control.statusBar)
                    }
                }
            }
        }
    }
}
