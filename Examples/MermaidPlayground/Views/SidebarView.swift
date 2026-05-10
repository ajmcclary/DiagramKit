//
//  SidebarView.swift
//  MermaidPlayground
//
//  Controls panel with diagram selector, theme picker, and export button.
//  The source editor has moved to EditorPane.
//

import SwiftUI
import DiagramKit
import IssueReporting
import UniformTypeIdentifiers

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SidebarView: View {
    let store: LiveEditorStore

    @SwiftUI.State private var selectedDiagramName: String = "Select Test Diagram..."
    @SwiftUI.State private var showExportError = false
    @SwiftUI.State private var exportErrorMessage = ""
    @SwiftUI.State private var exportedFileURL: URL?
    @SwiftUI.State private var showingExporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Test Diagrams Section
                sectionHeader("Test Diagrams")
                testDiagramPicker
                    .padding(.top, -10)

                // Theme Section
                sectionHeader("Theme")
                ThemePicker(store: store)
                    .padding(.top, -10)

                // Export Button
                exportButton
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
            isPresented: $showingExporter,
            document: exportedFileURL.map { PNGDocument(url: $0) },
            contentType: .png,
            defaultFilename: "mermaid-diagram.png"
        ) { result in
            if case let .failure(error) = result {
                reportIssue(error)
                showError(error.localizedDescription)
            }
            // Clean up temp file after export
            if let url = exportedFileURL {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    reportIssue(error)
                }
            }
            exportedFileURL = nil
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color(store.theme.foreground))
    }

    // MARK: - Test Diagram Picker

    private var testDiagramPicker: some View {
        Menu {
            ForEach(TestDiagrams.orderedCategories) { category in
                let diagrams = TestDiagrams.diagrams(for: category.id)
                if !diagrams.isEmpty {
                    Menu(category.title) {
                        ForEach(diagrams) { diagram in
                            Button {
                                selectedDiagramName = diagram.name
                                store.setSource(diagram.source, origin: .system)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(diagram.name)
                                    Text(diagram.id)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedDiagramName)
                    .foregroundColor(Color(store.theme.effectiveAccent()))
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(Color(store.theme.effectiveAccent()))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            Task {
                await exportPNG()
            }
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export PNG")
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(store.theme.effectiveLine()), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(store.theme.foreground))
    }

    // MARK: - Export Logic

    @MainActor
    private func exportPNG() async {
        do {
            let renderer = MermaidImageRenderer(theme: store.theme)
            guard let image = try await renderer.renderImage(from: store.state.source, scale: 2.0) else {
                reportIssue("PNG export returned no image.")
                showError("Failed to render diagram")
                return
            }

            // Convert to PNG data
            #if targetEnvironment(macCatalyst) || canImport(UIKit)
            guard let pngData = image.pngData() else {
                reportIssue("PNG export could not create PNG data.")
                showError("Failed to create PNG data")
                return
            }
            #elseif canImport(AppKit)
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                reportIssue("PNG export could not create PNG data.")
                showError("Failed to create PNG data")
                return
            }
            #endif

            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "mermaid-diagram-\(Int(Date().timeIntervalSince1970)).png"
            let tempURL = tempDir.appendingPathComponent(fileName)

            try pngData.write(to: tempURL)

            // Show file exporter
            exportedFileURL = tempURL
            showingExporter = true

        } catch {
            reportIssue(error)
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        exportErrorMessage = message
        showExportError = true
    }
}

// MARK: - PNG Document for FileExporter

struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        // Not used for export
        url = URL(fileURLWithPath: "")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}
