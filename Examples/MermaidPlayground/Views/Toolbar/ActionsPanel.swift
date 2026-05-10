//
//  ActionsPanel.swift
//  MermaidPlayground
//
//  Export, copy, and share action groupings.
//  Shown as a popover (macOS) or sheet (iOS) from the toolbar actions button.
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
    @SwiftUI.State private var showingCopyFeedback = false
    @SwiftUI.State private var copyFeedbackMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Export section
                sectionHeader("Export")
                exportButtons

                Divider()

                // Copy section
                sectionHeader("Copy to Clipboard")
                copyButtons

                Divider()

                // View section
                sectionHeader("View")
                viewButtons

                Divider()

                // Share section (Phase 4 placeholder)
                sectionHeader("Share")
                sharePlaceholder

                // Copy feedback toast
                if showingCopyFeedback {
                    Text(copyFeedbackMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.85))
                        )
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(16)
        }
        .background(Color(store.theme.background))
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .fileExporter(
            isPresented: $showingPNGExporter,
            document: exportedFileURL.map { PNGDocument(url: $0) },
            contentType: .png,
            defaultFilename: "mermaid-diagram.png"
        ) { result in
            handleExportResult(result)
        }
        .fileExporter(
            isPresented: $showingSVGExporter,
            document: exportedFileURL.map { PlainTextDocument(url: $0) },
            contentType: .svg,
            defaultFilename: "mermaid-diagram.svg"
        ) { result in
            handleExportResult(result)
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(store.theme.effectiveMuted()))
            .textCase(.uppercase)
    }

    // MARK: - Export buttons

    private var exportButtons: some View {
        VStack(spacing: 6) {
            actionButton(
                label: "Export PNG",
                icon: "photo",
                subtitle: "Raster image at 2× scale"
            ) {
                Task { await exportPNG() }
            }

            actionButton(
                label: "Export SVG",
                icon: "doc.text",
                subtitle: "Vector graphics"
            ) {
                Task { await exportSVGToFile() }
            }
        }
    }

    // MARK: - Copy buttons

    private var copyButtons: some View {
        VStack(spacing: 6) {
            actionButton(
                label: "Copy Source",
                icon: "doc.on.clipboard",
                subtitle: "Mermaid diagram text"
            ) {
                copyToClipboard(store.state.source, label: "Source copied")
            }

            actionButton(
                label: "Copy Config",
                icon: "gearshape",
                subtitle: "Config JSON"
            ) {
                copyToClipboard(store.state.configJSON, label: "Config copied")
            }

            actionButton(
                label: "Copy SVG",
                icon: "doc.richtext",
                subtitle: "Vector markup"
            ) {
                Task { await copySVG() }
            }

            actionButton(
                label: "Copy PNG Image",
                icon: "photo.on.rectangle",
                subtitle: "Raster image"
            ) {
                Task { await copyPNGImage() }
            }
        }
    }

    // MARK: - View buttons

    private var viewButtons: some View {
        VStack(spacing: 6) {
            actionButton(
                label: "Full-Window Preview",
                icon: "rectangle.inset.filled",
                subtitle: "Preview-only window"
            ) {
                showingFullWindowPreview = true
            }
        }
    }

    // MARK: - Share placeholder

    private var sharePlaceholder: some View {
        VStack(spacing: 6) {
            actionButton(
                label: "Share State",
                icon: "square.and.arrow.up",
                subtitle: "Serialized editor state (Phase 4)"
            ) {
                // Placeholder — will serialize state in Phase 4
                copyToClipboard("Share coming in Phase 4", label: "Coming soon")
            }
        }
    }

    // MARK: - Action button

    private func actionButton(
        label: String,
        icon: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                    .foregroundColor(Color(store.theme.effectiveAccent()))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(store.theme.foreground))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(store.theme.foreground).opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export PNG

    @MainActor
    private func exportPNG() async {
        do {
            let renderer = MermaidImageRenderer(theme: store.theme)
            guard let image = try await renderer.renderImage(from: store.state.source, scale: 2.0) else {
                showError("Failed to render diagram")
                return
            }

            // Convert to PNG data
            guard let pngData = platformPNGData(from: image) else {
                showError("Failed to create PNG data")
                return
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "mermaid-diagram-\(Int(Date().timeIntervalSince1970)).png"
            let tempURL = tempDir.appendingPathComponent(fileName)

            try pngData.write(to: tempURL)

            exportedFileURL = tempURL
            showingPNGExporter = true

        } catch {
            reportIssue(error)
            showError(error.localizedDescription)
        }
    }

    private func platformPNGData(from image: BMImage) -> Data? {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return image.pngData()
        #elseif canImport(AppKit)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }

    // MARK: - Export SVG

    private func exportSVGToFile() async {
        do {
            let svgString = try await MermaidRenderer.renderSVG(source: store.state.source, theme: store.theme)

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "mermaid-diagram-\(Int(Date().timeIntervalSince1970)).svg"
            let tempURL = tempDir.appendingPathComponent(fileName)

            try svgString.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)

            exportedFileURL = tempURL
            showingSVGExporter = true
        } catch {
            reportIssue(error)
            showError(error.localizedDescription)
        }
    }

    // MARK: - Copy actions

    private func copyToClipboard(_ text: String, label: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
        showCopyFeedback(label)
    }

    @MainActor
    private func copySVG() async {
        do {
            let svgString = try await MermaidRenderer.renderSVG(source: store.state.source, theme: store.theme)
            copyToClipboard(svgString, label: "SVG copied")
        } catch {
            reportIssue(error)
            showError(error.localizedDescription)
        }
    }

    @MainActor
    private func copyPNGImage() async {
        do {
            let renderer = MermaidImageRenderer(theme: store.theme)
            guard let image = try await renderer.renderImage(from: store.state.source, scale: 2.0) else {
                showError("Failed to render diagram")
                return
            }

            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            #elseif os(iOS)
            UIPasteboard.general.image = image
            #endif
            showCopyFeedback("PNG copied")
        } catch {
            reportIssue(error)
            showError(error.localizedDescription)
        }
    }

    // MARK: - Feedback

    private func showCopyFeedback(_ message: String) {
        copyFeedbackMessage = message
        withAnimation(.easeOut(duration: 0.2)) {
            showingCopyFeedback = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showingCopyFeedback = false
                }
            }
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
        .frame(width: 300, height: 420)
}
#endif
