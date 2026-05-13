//
//  SidebarView.swift
//  DiagramPlayground
//
//  Sample library sidebar. Hosts the searchable, categorized sample
//  diagram picker. Theme and view options live in the window toolbar.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import UniformTypeIdentifiers

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SidebarView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        SampleDiagramPanel(store: store)
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
