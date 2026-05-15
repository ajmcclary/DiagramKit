//
//  ActionsPanel.swift
//  DiagramPlayground
//
//  Export, copy, and share action groupings.
//  Shown as a popover (macOS) or sheet (iOS) from the toolbar actions button.
//
//  Phase 4: thin shell around ActionsView. Owns fileExporter triggers
//  and error alerts; delegates button rendering and copy actions to ActionsView.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import UniformTypeIdentifiers
import IssueReporting

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct ActionsPanel: View {
    @Bindable var store: LiveEditorStore
    @Binding var showingFullWindowPreview: Bool

    @SwiftUI.State private var showExportError = false
    @SwiftUI.State private var exportErrorMessage = ""
    @SwiftUI.State private var exportedFileURL: URL?
    @SwiftUI.State private var showingPNGExporter = false
    @SwiftUI.State private var showingSVGExporter = false
    @SwiftUI.State private var showingShareSheet = false
    @SwiftUI.State private var showingHistory = false

    var body: some View {
        ActionsView(
            store: store,
            onExportPNG: { Task { await exportPNG() } },
            onExportSVG: { Task { await exportSVGToFile() } },
            onFullWindowPreview: { showingFullWindowPreview = true },
            onShareState: { showingShareSheet = true },
            onShowHistory: { showingHistory = true },
            onConvertSource: { target in Task { await convertSource(to: target) } }
        )
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .fileExporter(
            isPresented: $showingPNGExporter,
            document: exportedFileURL.map { PNGDocument(url: $0) },
            contentType: .png,
            defaultFilename: "diagram.png"
        ) { result in
            handleExportResult(result)
        }
        .fileExporter(
            isPresented: $showingSVGExporter,
            document: exportedFileURL.map { PlainTextDocument(url: $0) },
            contentType: .svg,
            defaultFilename: "diagram.svg"
        ) { result in
            handleExportResult(result)
        }
        .sheet(isPresented: $showingShareSheet) {
            #if os(iOS)
            NavigationStack {
                ShareView(store: store)
                    .navigationTitle("Share State")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingShareSheet = false }
                                .a11yIdentifier(A11yID.Panels.actionsShareDone)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            #else
            ShareView(store: store)
                .frame(width: 440, height: 520)
            #endif
        }
        .sheet(isPresented: $showingHistory) {
            #if os(iOS)
            NavigationStack {
                HistoryView(store: store)
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingHistory = false }
                                .a11yIdentifier(A11yID.Panels.actionsHistoryDone)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            #else
            HistoryView(store: store)
                .frame(width: 460, height: 560)
            #endif
        }
    }

    // MARK: - Export PNG

    @MainActor
    private func exportPNG() async {
        do {
            let tempURL = try await store.exportPNG(options: store.exportOptions)
            exportedFileURL = tempURL
            showingPNGExporter = true
        } catch {
            reportIssue(error)
            showError(error.localizedDescription)
        }
    }

    // MARK: - Export SVG

    private func exportSVGToFile() async {
        do {
            let svgString = try await store.exportSVG()

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "diagram-\(Int(Date().timeIntervalSince1970)).svg"
            let tempURL = tempDir.appendingPathComponent(fileName)

            try svgString.write(to: tempURL, atomically: true, encoding: .utf8)

            exportedFileURL = tempURL
            showingSVGExporter = true
        } catch {
            reportIssue(error)
            showError(error.localizedDescription)
        }
    }

    // MARK: - Convert source

    /// Re-export the current diagram as `target` and copy the result to the
    /// pasteboard. We use the clipboard rather than a file exporter here
    /// because the unfamiliar formats don't have well-known UTTypes everywhere
    /// (e.g. `.d2`, `.dsl`). Diagnostics from the exporter are surfaced via
    /// the same error alert as PNG/SVG.
    @MainActor
    private func convertSource(to target: SourceFormat) async {
        do {
            let result = try await store.exportSource(to: target)

            // Treat any unsupported-severity diagnostic as a hard error for
            // user feedback so the action panel doesn't silently no-op.
            if result.source.isEmpty {
                let message = result.diagnostics.first?.message
                    ?? "Conversion to \(target.displayName) produced no output."
                showError(message)
                return
            }

            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            _ = pasteboard.setString(result.source, forType: .string)
            #elseif os(iOS)
            UIPasteboard.general.string = result.source
            #endif
        } catch {
            reportIssue(error)
            showError(error.localizedDescription)
        }
    }

    // MARK: - Export result handler

    private func handleExportResult(_ result: Result<URL, Error>) {
        if case let .failure(error) = result {
            reportIssue(error)
            showError(error.localizedDescription)
        }
        // Clean up temp file
        if let url = exportedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        exportedFileURL = nil
    }

    // MARK: - Error

    private func showError(_ message: String) {
        exportErrorMessage = message
        showExportError = true
    }
}

// MARK: - PlainTextDocument (for SVG export)

struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.svg, .plainText] }

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        url = URL(fileURLWithPath: "")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

#if DEBUG
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
#Preview {
    @Previewable @SwiftUI.State var showingFull: Bool = false
    let store = LiveEditorStore()
    ActionsPanel(store: store, showingFullWindowPreview: $showingFull)
        .frame(width: 340, height: 520)
}
#endif
