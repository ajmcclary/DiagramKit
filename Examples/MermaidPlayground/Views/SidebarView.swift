//
//  SidebarView.swift
//  MermaidPlayground
//
//  Controls panel with diagram selector and theme picker.
//  PNG export moved to store/actions panel in Phase 4.
//

import SwiftUI
import DiagramKit
import UniformTypeIdentifiers

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SidebarView: View {
    let store: LiveEditorStore

    @SwiftUI.State private var selectedDiagramName: String = "Select Test Diagram..."

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
            }
            .padding(16)
        }
        .background(Color(store.theme.background))
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
}

// MARK: - PNG Document for FileExporter

/// Reusable PNG file document for `.fileExporter`.
/// Used by both SidebarView (legacy) and ActionsPanel.
struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

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
