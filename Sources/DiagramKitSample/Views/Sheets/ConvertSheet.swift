//
//  ConvertSheet.swift
//  DiagramPlayground
//
//  Phase 7 / Task 7.2 — Mermaid → target diff. Two-pane layout
//  (current source on the left, exported target on the right) with
//  target-format chips at the top and a typed loss list at the
//  bottom (each row pairs a DiagnosticCategory with the export
//  diagnostic message).
//

import SwiftUI
import DiagramKit
import DiagramKitCommon
import DiagramKitExport
import DesignKitThemes

struct ConvertSheet: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var convertedSource: String = ""
    @SwiftUI.State private var diagnostics: [DiagramDiagnostic] = []
    @SwiftUI.State private var lastError: String?
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            chips
            separator
            twoPane
                .frame(maxHeight: .infinity)
            separator
            lossList
                .frame(height: 132)
        }
        .frame(width: 880, height: 580)
        .background(theme.colors.surfaceBackground.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Sheets.convertSheet)
        .task(id: store.state.convertSheet.target) { await refresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            DSIconView(.convert)
            Text("Convert")
                .dsFont(.headline)
                .foregroundStyle(theme.colors.textPrimary.color)
            Text("· \(store.state.sourceFormat.shortName) → \(store.state.convertSheet.target.shortName)")
                .dsFont(.caption2)
                .foregroundStyle(theme.colors.textSecondary.color)
            Spacer()
            DSIconButton(.close, label: "Close conversion") {
                store.closeConvertSheet()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.sm)
    }

    // MARK: - Chips

    private var chips: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Text("Target")
                .dsFont(.overline)
                .foregroundStyle(theme.colors.textSecondary.color)
            ForEach(SourceFormat.allCases) { format in
                chip(format)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.xs)
    }

    private func chip(_ format: SourceFormat) -> some View {
        let isOn = store.state.convertSheet.target == format
        return DSChip(isSelected: isOn) {
            store.setConvertTarget(format)
        } label: {
            Text(format.shortName).dsFont(.badge)
        }
        .a11yToggle(
            label: LocalizedStringKey(format.displayName),
            isOn: isOn,
            id: A11yID.Sheets.convertTarget(format.rawValue)
        )
    }

    // MARK: - Two-pane diff

    private var twoPane: some View {
        HStack(spacing: 0) {
            paneColumn(
                title: "Source · \(store.state.sourceFormat.shortName)",
                content: store.state.source,
                tone: .muted
            )
            Divider()
            paneColumn(
                title: "Converted · \(store.state.convertSheet.target.shortName)",
                content: convertedSource.isEmpty ? (lastError ?? "(generating …)") : convertedSource,
                tone: convertedSource.isEmpty ? .error : .accent
            )
        }
    }

    private func paneColumn(title: String, content: String, tone: PaneTone) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .dsFont(.overline)
                    .foregroundStyle(tone.color(in: theme))
                Spacer()
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(theme.colors.element.color)
            ScrollView([.horizontal, .vertical]) {
                Text(content)
                    .dsFont(.code)
                    .foregroundStyle(theme.colors.editorForeground.color)
                    .textSelection(.enabled)
                    .padding(Tokens.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: - Loss list

    private var lossList: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack {
                Text("Losses")
                    .dsFont(.overline)
                    .foregroundStyle(theme.colors.textSecondary.color)
                if !losses.isEmpty {
                    Text("· \(losses.count)")
                        .dsFont(.metric)
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .padding(.top, Tokens.Spacing.xs)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                    if losses.isEmpty {
                        HStack(spacing: Tokens.Spacing.xs) {
                            DSIconView(.success, size: Tokens.Size.Icon.micro, colorRole: .success)
                            Text("No typed losses recorded for this conversion")
                                .dsFont(.caption2)
                                .foregroundStyle(theme.colors.success.color)
                        }
                        .padding(.horizontal, Tokens.Spacing.md)
                        .padding(.vertical, Tokens.Spacing.xxs)
                    } else {
                        ForEach(Array(losses.enumerated()), id: \.offset) { _, loss in
                            lossRow(loss)
                        }
                    }
                }
                .padding(.bottom, Tokens.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.panelBackground.color)
        .accessibilityIdentifier(A11yID.Sheets.convertLossList)
    }

    private var losses: [DiagramDiagnostic] {
        diagnostics.filter { $0.severity == .warning || $0.severity == .unsupported }
    }

    private func lossRow(_ d: DiagramDiagnostic) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.sm) {
            DSIconView(severityIcon(d), size: Tokens.Size.Icon.micro, colorRole: severityRole(d))
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                if let cat = d.category {
                    Text(".\(cat.rawValue)")
                        .dsFont(.code)
                        .foregroundStyle(theme.colors.accent.color)
                }
                Text(d.message)
                    .dsFont(.caption2)
                    .foregroundStyle(theme.colors.textPrimary.color)
                if let line = d.location?.line {
                    Text("source line \(line)")
                        .dsFont(.metric)
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .padding(.vertical, Tokens.Spacing.xxs)
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

    private var separator: some View {
        Rectangle()
            .fill(theme.colors.borderVariant.color)
            .frame(height: Tokens.Shape.strokeHairline)
    }

    // MARK: - Refresh

    @MainActor
    private func refresh() async {
        let target = store.state.convertSheet.target
        let result: DiagramExportResult
        do {
            result = try await store.exportSourcePreview(to: target)
        } catch {
            convertedSource = ""
            diagnostics = []
            lastError = "Conversion failed · \(error.localizedDescription)"
            return
        }
        convertedSource = result.source
        diagnostics = result.diagnostics
        lastError = result.source.isEmpty ? "Empty output — target may not support this family" : nil
    }
}

private enum PaneTone {
    case muted
    case accent
    case error

    func color(in theme: Theme) -> Color {
        switch self {
        case .muted: theme.colors.textSecondary.color
        case .accent: theme.colors.accent.color
        case .error: theme.colors.error.color
        }
    }
}
