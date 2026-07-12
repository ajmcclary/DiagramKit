//
//  ThreeFormatView.swift
//  DiagramPlayground
//
//  Phase 9 / Task 9.1 — full-window cross-format triptych. Three
//  columns (Mermaid / D2 / DOT) each driven by the live store
//  source: header pill, exported source, and per-format
//  diagnostics list. Footer shows a round-trip pill summarising
//  whether all three formats share the same loss surface.
//

import SwiftUI
import DiagramKit
import DiagramKitCommon
import DiagramKitExport
import DiagramKitModel
import DiagramKitSampleDesignSystem

struct ThreeFormatView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    @SwiftUI.State private var columns: [FormatPane] = []

    private struct FormatPane: Identifiable {
        let format: SourceFormat
        let result: DiagramExportResult?
        let error: String?
        var id: String { format.rawValue }
    }

    private let targets: [SourceFormat] = [.mermaid, .d2, .graphviz]

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            triptych
                .frame(maxHeight: .infinity)
            separator
            footer
        }
        .background(environment.theme.colors.windowBackground.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("crossformat.view")
        .task(id: refreshKey) { await refresh() }
    }

    private var refreshKey: String {
        // Re-export whenever the active source or format changes.
        "\(store.state.sourceFormat.rawValue)·\(store.state.source.hashValue)"
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            DSIconView(.convert)
            Text("Cross-format")
                .dsFont(.headline)
            Text("· Mermaid / D2 / DOT")
                .dsFont(.caption2)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
            Spacer()
            HStack { DSIconView(.success, colorRole: .success); DSCodeBadge("parse → export · paired") }
            DSIconButton(.close, label: "Close cross-format view") {
                store.dismissFullScreen()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, DSTokens.Spacing.lg)
        .padding(.vertical, DSTokens.Spacing.sm)
    }

    // MARK: - Triptych

    private var triptych: some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.element.id) { index, pane in
                column(pane)
                if index < columns.count - 1 {
                    Rectangle().fill(environment.theme.colors.borderVariant.color).frame(width: DSTokens.Stroke.hairline)
                }
            }
        }
    }

    private func column(_ pane: FormatPane) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DSTokens.Spacing.xs) {
                DSCodeBadge(pane.format.shortName)
                Text(".\(pane.format.fileExtension)")
                    .dsFont(.code)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                Spacer()
            }
            .padding(.horizontal, DSTokens.Spacing.smMd)
            .padding(.vertical, DSTokens.Spacing.xs)
            .background(environment.theme.colors.element.color)

            ScrollView([.horizontal, .vertical]) {
                Text(textPayload(for: pane))
                    .dsFont(.code)
                    .foregroundStyle(environment.theme.colors.editorForeground.color)
                    .textSelection(.enabled)
                    .padding(DSTokens.Spacing.smMd)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(environment.theme.colors.editorBackground.color)

            separator

            diagnosticsList(for: pane)
                .frame(height: 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("crossformat.column.\(pane.format.rawValue)")
    }

    private func textPayload(for pane: FormatPane) -> String {
        if let error = pane.error {
            return "(error) \(error)"
        }
        if let result = pane.result, !result.source.isEmpty {
            return result.source
        }
        return "(generating …)"
    }

    private func diagnosticsList(for pane: FormatPane) -> some View {
        let diags = pane.result?.diagnostics ?? []
        return VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
            HStack {
                Text("Diagnostics")
                    .dsFont(.overline)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                if !diags.isEmpty {
                    Text("· \(diags.count)")
                        .dsFont(.metric)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            ScrollView {
                if diags.isEmpty {
                    HStack { DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success); Text("No typed losses").dsFont(.caption2) }
                        .foregroundStyle(environment.theme.colors.success.color)
                        .padding(.horizontal, DSTokens.Spacing.smMd)
                        .padding(.vertical, DSTokens.Spacing.xxxs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                        ForEach(Array(diags.enumerated()), id: \.offset) { _, d in
                            HStack(spacing: DSTokens.Spacing.xxs) {
                                DSIconView(severityIcon(d), size: DSTokens.Icon.micro, colorRole: severityRole(d))
                                if let cat = d.category {
                                    Text(".\(cat.rawValue)")
                                        .dsFont(.code)
                                        .foregroundStyle(environment.theme.colors.accent.color)
                                }
                                Text(d.message)
                                    .dsFont(.caption2)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                }
            }
        }
        .background(environment.theme.colors.panelBackground.color)
    }

    private func severityIcon(_ d: DiagramDiagnostic) -> DSIcon {
        switch d.severity {
        case .warning:     return .warning
        case .info:        return .info
        case .unsupported: return .error
        }
    }

    private func severityRole(_ d: DiagramDiagnostic) -> DSIconColorRole {
        switch d.severity {
        case .warning:     return .warning
        case .info:        return .info
        case .unsupported: return .error
        }
    }

    // MARK: - Footer

    private var totalLossCount: Int {
        var count = 0
        for pane in columns {
            guard let diagnostics = pane.result?.diagnostics else { continue }
            for diagnostic in diagnostics
            where diagnostic.severity == .warning || diagnostic.severity == .unsupported {
                count += 1
            }
        }
        return count
    }

    private var footer: some View {
        let totalLosses = totalLossCount
        return HStack {
            if totalLosses == 0 {
                HStack { DSIconView(.success, colorRole: .success); DSCodeBadge("round-trip · paired") }
            } else {
                HStack { DSIconView(.warning, colorRole: .warning); DSCodeBadge("round-trip · \(totalLosses) typed losses") }
            }
            Spacer()
            Text("Source format: \(store.state.sourceFormat.shortName)")
                .dsFont(.caption2)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
        }
        .padding(.horizontal, DSTokens.Spacing.lg)
        .padding(.vertical, DSTokens.Spacing.xs)
    }

    // MARK: - Refresh

    @MainActor
    private func refresh() async {
        var built: [FormatPane] = []
        for target in targets {
            do {
                let result = try await store.exportSource(to: target)
                built.append(FormatPane(format: target, result: result, error: nil))
            } catch {
                built.append(FormatPane(format: target, result: nil, error: error.localizedDescription))
            }
        }
        columns = built
    }

    private var separator: some View {
        Rectangle().fill(environment.theme.colors.borderVariant.color).frame(height: DSTokens.Stroke.hairline)
    }
}
