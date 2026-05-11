//
//  SidebarView.swift
//  MermaidPlayground
//
//  Inspector-style controls for the live editor: sample browser,
//  theme picker, view toggles. Plain ScrollView + VStack so the
//  sidebar always honors its column width without macOS sidebar
//  list-style auto-collapsing sections.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import UniformTypeIdentifiers

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SidebarView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section(title: "Sample") {
                    sampleMenu
                }
                section(title: "Theme") {
                    themeSection
                }
                section(title: "View") {
                    Toggle(isOn: $store.state.gridEnabled) {
                        Label("Grid overlay", systemImage: "square.grid.3x3")
                            .labelStyle(.titleAndIcon)
                    }
                    Toggle(isOn: $store.state.panZoomEnabled) {
                        Label("Pan & zoom", systemImage: "hand.draw")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sample menu

    private var sampleMenu: some View {
        Menu {
            ForEach(TestDiagrams.orderedCategories) { category in
                let diagrams = TestDiagrams.diagrams(for: category.id)
                if !diagrams.isEmpty {
                    Menu(category.title) {
                        ForEach(diagrams) { diagram in
                            Button {
                                store.setSource(diagram.source, origin: .system)
                            } label: {
                                Text(diagram.name)
                            }
                        }
                    }
                }
            }
        } label: {
            Label("Browse samples", systemImage: "square.grid.2x2")
                .labelStyle(.titleAndIcon)
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Theme section

    private var themeSection: some View {
        Picker("", selection: themeBinding) {
            ForEach(DiagramTheme.allThemes, id: \.name) { name, _ in
                Text(name).tag(name)
            }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    private var themeBinding: Binding<String> {
        Binding(
            get: { store.state.selectedThemeName },
            set: { store.setTheme(named: $0) }
        )
    }
}

// MARK: - PNG Document for FileExporter

/// Reusable PNG file document for `.fileExporter`.
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
