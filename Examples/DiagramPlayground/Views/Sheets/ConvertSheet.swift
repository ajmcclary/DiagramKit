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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct ConvertSheet: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var convertedSource: String = ""
    @SwiftUI.State private var diagnostics: [DiagramDiagnostic] = []
    @SwiftUI.State private var lastError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            chips
            Divider()
            twoPane
                .frame(maxHeight: .infinity)
            Divider()
            lossList
                .frame(height: 132)
        }
        .frame(width: 880, height: 580)
        .background(.regularMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Sheets.convertSheet)
        .task(id: store.state.convertSheet.target) { await refresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .foregroundStyle(.tint)
            Text("Convert")
                .font(.system(size: 13, weight: .semibold))
            Text("· \(store.state.sourceFormat.shortName) → \(store.state.convertSheet.target.shortName)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                store.closeConvertSheet()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Chips

    private var chips: some View {
        HStack(spacing: 6) {
            Text("Target")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(SourceFormat.allCases) { format in
                chip(format)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func chip(_ format: SourceFormat) -> some View {
        let isOn = store.state.convertSheet.target == format
        return Button {
            store.setConvertTarget(format)
        } label: {
            Text(format.shortName)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(isOn ? Color.accentColor.opacity(0.22) : Color.gray.opacity(0.12))
                )
                .foregroundStyle(isOn ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
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
                accent: .secondary
            )
            Divider()
            paneColumn(
                title: "Converted · \(store.state.convertSheet.target.shortName)",
                content: convertedSource.isEmpty ? (lastError ?? "(generating …)") : convertedSource,
                accent: convertedSource.isEmpty ? .red : Color.accentColor
            )
        }
    }

    private func paneColumn(title: String, content: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.06))
            ScrollView([.horizontal, .vertical]) {
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: - Loss list

    private var lossList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Losses")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                if !losses.isEmpty {
                    Text("· \(losses.count)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if losses.isEmpty {
                        Text("✓ No typed losses recorded for this conversion")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(losses.enumerated()), id: \.offset) { _, loss in
                            lossRow(loss)
                        }
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.04))
        .accessibilityIdentifier(A11yID.Sheets.convertLossList)
    }

    private var losses: [DiagramDiagnostic] {
        diagnostics.filter { $0.severity == .warning || $0.severity == .unsupported }
    }

    private func lossRow(_ d: DiagramDiagnostic) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: severityIcon(d))
                .foregroundStyle(severityColor(d))
                .font(.system(size: 10, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                if let cat = d.category {
                    Text(".\(cat.rawValue)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                }
                Text(d.message)
                    .font(.system(size: 11))
                if let line = d.location?.line {
                    Text("source line \(line)")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func severityIcon(_ d: DiagramDiagnostic) -> String {
        switch d.severity {
        case .warning:     return "exclamationmark.triangle.fill"
        case .info:        return "info.circle.fill"
        case .unsupported: return "xmark.octagon.fill"
        }
    }

    private func severityColor(_ d: DiagramDiagnostic) -> Color {
        switch d.severity {
        case .warning:     return .orange
        case .info:        return .blue
        case .unsupported: return .red
        }
    }

    // MARK: - Refresh

    @MainActor
    private func refresh() async {
        let target = store.state.convertSheet.target
        guard let result = await store.exportSourcePreview(to: target) else {
            convertedSource = ""
            diagnostics = []
            lastError = "Conversion failed"
            return
        }
        convertedSource = result.source
        diagnostics = result.diagnostics
        lastError = result.source.isEmpty ? "Empty output — target may not support this family" : nil
    }
}
