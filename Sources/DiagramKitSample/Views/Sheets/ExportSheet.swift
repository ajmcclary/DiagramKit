//
//  ExportSheet.swift
//  DiagramPlayground
//
//  Phase 7 / Task 7.1 — full-bleed export sheet. Left aside lists 10
//  targets grouped by Render / Source. Right pane shows a live
//  preview switching on target. Footer hosts a round-trip toggle +
//  Copy / Save actions. Close via × or ⌘. .
//

import SwiftUI
import DiagramKit
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import UniformTypeIdentifiers

struct ExportSheet: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var sourcePreview: String = ""
    @SwiftUI.State private var sourceDiagnostics: [DiagramDiagnostic] = []
    @SwiftUI.State private var rtSummary: RoundTripSummary?
    @SwiftUI.State private var copyFeedback = false
    @SwiftUI.State private var saveFeedback: SaveFeedback?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                targetList
                    .frame(width: 220)
                Divider()
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 820, height: 540)
        .background(.regularMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Sheets.exportSheet)
        .task(id: store.state.exportSheet.target) { await refreshPreview() }
        .task(id: store.state.exportSheet.rtCheck) { await refreshRoundTrip() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.tint)
            Text("Export")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                store.closeExportSheet()
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

    // MARK: - Target list

    private var targetList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                section(title: "Render", targets: ExportTarget.allCases.filter { $0.groupLabel == "Render" })
                section(title: "Source", targets: ExportTarget.allCases.filter { $0.groupLabel == "Source" })
            }
            .padding(.vertical, 6)
        }
    }

    private func section(title: String, targets: [ExportTarget]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.08))
            ForEach(targets) { target in
                targetButton(target)
            }
        }
    }

    private func targetButton(_ target: ExportTarget) -> some View {
        let isOn = store.state.exportSheet.target == target
        return Button {
            store.setExportTarget(target)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: target.sfSymbol)
                    .frame(width: 16)
                Text(target.label)
                    .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isOn ? Color.accentColor.opacity(0.16) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .a11yToggle(
            label: LocalizedStringKey(target.label),
            isOn: isOn,
            id: A11yID.Sheets.exportTarget(target.rawValue)
        )
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        switch store.state.exportSheet.target {
        case .svg, .png1x, .png2x, .png3x:
            // Reuse PreviewCanvas — diagram surface is already wired.
            PreviewCanvas(store: store, onFullWindowPreview: nil)
        case .ascii:
            asciiPreview
        case .mermaid, .d2, .dot, .structurizr, .plantuml:
            sourcePreviewView
        }
    }

    private var asciiPreview: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(sourcePreview.isEmpty ? "(rendering …)" : sourcePreview)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(store.theme.background))
    }

    private var sourcePreviewView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 8) {
                Text(sourcePreview.isEmpty ? "(generating …)" : sourcePreview)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                if !sourceDiagnostics.isEmpty {
                    diagnosticsList
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(store.theme.background))
    }

    private var diagnosticsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Export diagnostics")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(sourceDiagnostics.enumerated()), id: \.offset) { _, d in
                HStack(spacing: 4) {
                    Image(systemName: severityIcon(d))
                        .foregroundStyle(severityColor(d))
                        .font(.system(size: 9, weight: .semibold))
                    Text(d.message)
                        .font(.system(size: 10))
                }
            }
        }
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

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle("Round-trip check", isOn: Binding(
                get: { store.state.exportSheet.rtCheck },
                set: { store.setExportRoundTripCheck($0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .a11yIdentifier(A11yID.Sheets.exportRoundTripToggle)

            if store.state.exportSheet.rtCheck, let summary = rtSummary {
                rtBadge(summary)
            }

            Spacer()

            Button("Copy") { copyToClipboard() }
                .buttonStyle(.bordered)
                .keyboardShortcut("c", modifiers: .command)
                .a11yIdentifier(A11yID.Sheets.exportCopyButton)
            Button("Save…") { Task { await save() } }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .a11yIdentifier(A11yID.Sheets.exportSaveButton)

            if copyFeedback {
                Text("Copied")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.green)
                    .transition(.opacity)
            }

            if let feedback = saveFeedback {
                Text(feedback.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(feedback.tone)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func rtBadge(_ summary: RoundTripSummary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: summary.lossCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(summary.label)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(summary.tone.opacity(0.18)))
        .foregroundStyle(summary.tone)
        .accessibilityIdentifier(A11yID.Sheets.exportRoundTripFooter)
    }

    // MARK: - Refresh

    @MainActor
    private func refreshPreview() async {
        let target = store.state.exportSheet.target
        switch target {
        case .ascii:
            sourcePreview = (try? await store.exportASCII()) ?? ""
            sourceDiagnostics = []
        case .mermaid, .d2, .dot, .structurizr, .plantuml:
            if let format = target.sourceFormat,
               let result = await store.exportSourcePreview(to: format) {
                sourcePreview = result.source
                sourceDiagnostics = result.diagnostics
            } else {
                sourcePreview = ""
                sourceDiagnostics = []
            }
        case .svg, .png1x, .png2x, .png3x:
            // PreviewCanvas drives itself; nothing to fetch.
            sourcePreview = ""
            sourceDiagnostics = []
        }
    }

    @MainActor
    private func refreshRoundTrip() async {
        guard store.state.exportSheet.rtCheck else {
            rtSummary = nil
            return
        }
        let target = store.state.exportSheet.target
        guard let format = target.sourceFormat else {
            // Render targets have no round-trip — just mark paired.
            rtSummary = RoundTripSummary(lossCount: 0, categories: [], tone: .green, label: "Render target — no round-trip")
            return
        }
        guard let result = await store.exportSourcePreview(to: format) else {
            rtSummary = RoundTripSummary(lossCount: 0, categories: [], tone: .red, label: "Export failed")
            return
        }
        let categories = result.diagnostics.compactMap(\.category).map(\.rawValue)
        let lossCount = result.diagnostics.filter {
            $0.severity == .warning || $0.severity == .unsupported
        }.count
        if lossCount == 0 {
            rtSummary = RoundTripSummary(lossCount: 0, categories: [], tone: .green, label: "✓ paired")
        } else {
            let preview = categories.prefix(3).map { ".\($0)" }.joined(separator: ", ")
            rtSummary = RoundTripSummary(
                lossCount: lossCount,
                categories: categories,
                tone: .orange,
                label: "▲ \(lossCount) loss\(lossCount == 1 ? "" : "es") (\(preview))"
            )
        }
    }

    // MARK: - Actions

    private func copyToClipboard() {
        let payload: String
        switch store.state.exportSheet.target {
        case .svg, .png1x, .png2x, .png3x:
            // Render targets: copy the source-format equivalent if
            // the user wants the underlying mermaid; for raster PNGs
            // we'd want NSPasteboard image copy — out of scope for v2.
            payload = store.state.source
        case .ascii, .mermaid, .d2, .dot, .structurizr, .plantuml:
            payload = sourcePreview
        }
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        #endif
        withAnimation { copyFeedback = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { withAnimation { copyFeedback = false } }
        }
    }

    @MainActor
    private func save() async {
        let target = store.state.exportSheet.target
        do {
            let payload = try await buildPayload(for: target)
            try writePayload(payload, target: target)
            flashSave(.success("Saved · \(target.fileExtension.uppercased())"))
        } catch SaveError.cancelled {
            // User dismissed the panel — no feedback.
            return
        } catch {
            flashSave(.failure("Save failed · \(error.localizedDescription)"))
        }
    }

    // MARK: - Save helpers

    private enum Payload {
        case text(String)
        case data(Data)
    }

    private enum SaveError: Swift.Error {
        case cancelled
        case noWindow
        case writeFailed
        case unsupportedPlatform
    }

    @MainActor
    private func buildPayload(for target: ExportTarget) async throws -> Payload {
        switch target {
        case .svg:
            return .text(try await store.exportSVG())
        case .ascii:
            return .text(try await store.exportASCII())
        case .mermaid, .d2, .dot, .structurizr, .plantuml:
            if let format = target.sourceFormat {
                let result = try await store.exportSource(to: format)
                return .text(result.source)
            }
            return .text("")
        case .png1x, .png2x, .png3x:
            let scale: CGFloat = {
                switch target {
                case .png2x: return 2
                case .png3x: return 3
                default:     return 1
                }
            }()
            let options = ExportOptions(sizing: store.exportOptions.sizing, scale: scale)
            let url = try await store.exportPNG(options: options)
            return .data(try Data(contentsOf: url))
        }
    }

    @MainActor
    private func writePayload(_ payload: Payload, target: ExportTarget) throws {
        let suggestedName = "diagram.\(target.fileExtension)"

        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        if let utType = UTType(filenameExtension: target.fileExtension) {
            panel.allowedContentTypes = [utType]
        }
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { throw SaveError.cancelled }
        try writeData(payload, to: url)
        #else
        // iOS / iPadOS fallback: write to the user's Documents directory
        // so a follow-up Share / Files surface can pick it up. A real
        // UIDocumentPickerViewController flow is out of scope here.
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = documents.appendingPathComponent(suggestedName)
        try writeData(payload, to: url)
        #endif
    }

    private func writeData(_ payload: Payload, to url: URL) throws {
        switch payload {
        case .text(let string):
            guard let data = string.data(using: .utf8) else { throw SaveError.writeFailed }
            try data.write(to: url)
        case .data(let data):
            try data.write(to: url)
        }
    }

    @MainActor
    private func flashSave(_ feedback: SaveFeedback) {
        withAnimation { saveFeedback = feedback }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { withAnimation { saveFeedback = nil } }
        }
    }
}

// MARK: - RoundTripSummary

private struct RoundTripSummary: Equatable {
    let lossCount: Int
    let categories: [String]
    let tone: Color
    let label: String
}

// MARK: - SaveFeedback

private struct SaveFeedback: Equatable {
    let label: String
    let tone: Color

    static func success(_ message: String) -> SaveFeedback {
        SaveFeedback(label: message, tone: .green)
    }

    static func failure(_ message: String) -> SaveFeedback {
        SaveFeedback(label: message, tone: .red)
    }
}

