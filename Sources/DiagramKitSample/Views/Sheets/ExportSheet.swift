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
import DesignKitThemes
import UniformTypeIdentifiers

struct ExportSheet: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var sourcePreview: String = ""
    @SwiftUI.State private var sourceDiagnostics: [DiagramDiagnostic] = []
    @SwiftUI.State private var rtSummary: RoundTripSummary?
    @SwiftUI.State private var copyFeedback = false
    @SwiftUI.State private var saveFeedback: SaveFeedback?
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            HStack(spacing: 0) {
                targetList
                    .frame(width: 220)
                verticalSeparator
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            separator
            footer
        }
        .frame(width: 820, height: 540)
        .background(theme.colors.surfaceBackground.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Sheets.exportSheet)
        .task(id: store.state.exportSheet.target) { await refreshPreview() }
        .task(id: store.state.exportSheet.rtCheck) { await refreshRoundTrip() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            DSIconView(.export)
            Text("Export")
                .dsFont(.headline)
                .foregroundStyle(theme.colors.textPrimary.color)
            Spacer()
            DSIconButton(.close, label: "Close") { store.closeExportSheet() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.sm)
    }

    // MARK: - Target list

    private var targetList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                section(title: "Render", targets: ExportTarget.allCases.filter { $0.groupLabel == "Render" })
                section(title: "Source", targets: ExportTarget.allCases.filter { $0.groupLabel == "Source" })
            }
            .padding(.vertical, Tokens.Spacing.xs)
        }
    }

    private func section(title: String, targets: [ExportTarget]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
            Text(title)
                .dsFont(.overline)
                .foregroundStyle(theme.colors.textSecondary.color)
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.vertical, Tokens.Spacing.xxs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.colors.element.color)
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
            HStack(spacing: Tokens.Spacing.sm) {
                DSIconView(icon(for: target), size: Tokens.Size.Icon.xs, colorRole: isOn ? .primary : .muted)
                Text(target.label)
                    .dsFont(.caption)
                Spacer()
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: isOn ? .secondary : .ghost, size: .compact))
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
                .dsFont(.code)
                .foregroundStyle(theme.colors.editorForeground.color)
                .padding(Tokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(theme.colors.editorBackground.color)
    }

    private var sourcePreviewView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                Text(sourcePreview.isEmpty ? "(generating …)" : sourcePreview)
                    .dsFont(.code)
                    .foregroundStyle(theme.colors.editorForeground.color)
                    .textSelection(.enabled)
                if !sourceDiagnostics.isEmpty {
                    diagnosticsList
                }
            }
            .padding(Tokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(theme.colors.editorBackground.color)
    }

    private var diagnosticsList: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            Text("Export diagnostics")
                .dsFont(.overline)
                .foregroundStyle(theme.colors.textSecondary.color)
            ForEach(Array(sourceDiagnostics.enumerated()), id: \.offset) { _, d in
                HStack(spacing: Tokens.Spacing.xxs) {
                    DSIconView(severityIcon(d), size: Tokens.Size.Icon.micro, colorRole: severityRole(d))
                    Text(d.message)
                        .dsFont(.caption2)
                        .foregroundStyle(theme.colors.textPrimary.color)
                }
            }
        }
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

    private var footer: some View {
        HStack(spacing: Tokens.Spacing.md) {
            Toggle("Round-trip check", isOn: Binding(
                get: { store.state.exportSheet.rtCheck },
                set: { store.setExportRoundTripCheck($0) }
            ))
            .toggleStyle(.ds)
            .a11yIdentifier(A11yID.Sheets.exportRoundTripToggle)

            if store.state.exportSheet.rtCheck, let summary = rtSummary {
                rtBadge(summary)
            }

            Spacer()

            Button("Copy") { copyToClipboard() }
                .buttonStyle(.ds(role: .secondary, size: .compact))
                .keyboardShortcut("c", modifiers: .command)
                .a11yIdentifier(A11yID.Sheets.exportCopyButton)
            Button("Save…") { Task { await save() } }
                .buttonStyle(.ds(role: .primary, size: .compact))
                .keyboardShortcut("s", modifiers: .command)
                .a11yIdentifier(A11yID.Sheets.exportSaveButton)

            if copyFeedback {
                Text("Copied")
                    .dsFont(.badge)
                    .foregroundStyle(theme.colors.success.color)
                    .transition(.opacity)
            }

            if let feedback = saveFeedback {
                Text(feedback.label)
                    .dsFont(.badge)
                    .foregroundStyle(statusColor(feedback.status))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.sm)
    }

    private func rtBadge(_ summary: RoundTripSummary) -> some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            DSIconView(
                summary.lossCount == 0 ? .success : .warning,
                size: Tokens.Size.Icon.micro,
                colorRole: summary.lossCount == 0 ? .success : .warning
            )
            Text(summary.label)
                .dsFont(.badge)
        }
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xxxs)
        .background(statusColor(summary.status).opacity(Tokens.Opacity.light), in: Capsule())
        .foregroundStyle(statusColor(summary.status))
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
               let result = try? await store.exportSourcePreview(to: format) {
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
            rtSummary = RoundTripSummary(lossCount: 0, categories: [], status: .success, label: "Render target — no round-trip")
            return
        }
        let result: DiagramExportResult
        do {
            result = try await store.exportSourcePreview(to: format)
        } catch {
            rtSummary = RoundTripSummary(
                lossCount: 0, categories: [], status: .error,
                label: "Export failed · \(error.localizedDescription)"
            )
            return
        }
        let categories = result.diagnostics.compactMap(\.category).map(\.rawValue)
        let lossCount = result.diagnostics.filter {
            $0.severity == .warning || $0.severity == .unsupported
        }.count
        if lossCount == 0 {
            rtSummary = RoundTripSummary(lossCount: 0, categories: [], status: .success, label: "✓ paired")
        } else {
            let preview = categories.prefix(3).map { ".\($0)" }.joined(separator: ", ")
            rtSummary = RoundTripSummary(
                lossCount: lossCount,
                categories: categories,
                status: .warning,
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
            let (payload, diagnostics) = try await buildPayload(for: target)
            try writePayload(payload, target: target)
            let ext = target.fileExtension.uppercased()
            if diagnostics.isEmpty {
                flashSave(.success("Saved · \(ext)"))
            } else {
                // The file was written but the exporter reported lossy /
                // unsupported diagnostics — say so rather than a bare success.
                let n = diagnostics.count
                flashSave(.success("Saved · \(ext) — \(n) diagnostic\(n == 1 ? "" : "s")"))
            }
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

    private enum SaveError: Swift.Error, LocalizedError {
        case cancelled
        case noWindow
        case writeFailed
        case unsupportedPlatform
        case emptyExport(String)

        var errorDescription: String? {
            switch self {
            case .cancelled:          return "Save cancelled."
            case .noWindow:           return "No window available to present the save panel."
            case .writeFailed:        return "Could not write the file."
            case .unsupportedPlatform: return "Export is not supported on this platform."
            case .emptyExport(let detail): return detail
            }
        }
    }

    /// Build the bytes to write plus any exporter diagnostics the caller
    /// should surface. Throws `.emptyExport` when a format conversion yields
    /// nothing — writing a 0-byte file and reporting "Saved" hides the fact
    /// that the target can't represent this diagram family.
    @MainActor
    private func buildPayload(for target: ExportTarget) async throws -> (Payload, [DiagramDiagnostic]) {
        switch target {
        case .svg:
            return (.text(try await store.exportSVG()), [])
        case .ascii:
            return (.text(try await store.exportASCII()), [])
        case .mermaid, .d2, .dot, .structurizr, .plantuml:
            guard let format = target.sourceFormat else { return (.text(""), []) }
            let result = try await store.exportSource(to: format)
            if result.source.isEmpty {
                let detail = result.diagnostics.first?.message
                    ?? "The \(target.fileExtension.uppercased()) exporter can't represent this diagram."
                throw SaveError.emptyExport(detail)
            }
            return (.text(result.source), result.diagnostics)
        case .png1x, .png2x, .png3x:
            let scale: CGFloat = {
                switch target {
                case .png2x: return 2
                case .png3x: return 3
                default:     return 1
                }
            }()
            let options = ExportOptions(sizing: store.exportOptions.sizing, scale: scale)
            return (.data(try await store.exportPNGData(options: options)), [])
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

    private func icon(for target: ExportTarget) -> DSIcon {
        switch target {
        case .png1x, .png2x, .png3x: .image
        case .svg, .ascii, .mermaid, .d2, .dot, .structurizr, .plantuml: .code
        }
    }

    private func statusColor(_ status: DSStatusKind) -> Color {
        switch status {
        case .success: theme.colors.success.color
        case .warning, .unsupported: theme.colors.warning.color
        case .error: theme.colors.error.color
        case .info: theme.colors.info.color
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(theme.colors.borderVariant.color)
            .frame(height: Tokens.Shape.strokeHairline)
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(theme.colors.borderVariant.color)
            .frame(width: Tokens.Shape.strokeHairline)
    }
}
