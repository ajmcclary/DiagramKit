//
//  SidebarView.swift
//  DiagramPlayground
//
//  v2 PlaygroundShell sidebar — brand row, search, format chips, and
//  the categorized SampleDiagramPanel as the tree. Adopts the v2.1
//  design tokens + primitives (Surface, SectionHeader, FieldInput).
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: PlaygroundSpacing.md) {
            browseSection
            Divider()
                .overlay(tokens.palette.borderHairline)
                .padding(.horizontal, -PlaygroundSpacing.sm)
            SampleDiagramPanel(store: store)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, PlaygroundSpacing.md)
        .padding(.top, PlaygroundSpacing.md)
        .background(tokens.palette.bgApp)
    }

    // MARK: - Browse section

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader("Browse")
                .padding(.top, 2)
            link(.coverage, label: "Coverage matrix", trailing: "28×5", icon: "square.grid.3x3")
            link(.corpus, label: "Corpus", trailing: "\(TestDiagrams.all.count)", icon: "tray.full")
            link(.crossFormat, label: "Cross-format", trailing: nil, icon: "rectangle.split.3x1")
            link(.probe, label: "Importer probe", trailing: nil, icon: "magnifyingglass.circle")
            link(.snippets, label: "Snippets library", trailing: nil, icon: "doc.text")
        }
    }

    private func link(
        _ surface: FullScreenSurface,
        label: String,
        trailing: String?,
        icon: String
    ) -> some View {
        let isOn = store.state.fullScreen == surface
        return Button {
            store.setFullScreen(isOn ? .none : surface)
        } label: {
            HStack(spacing: PlaygroundSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(isOn ? tokens.palette.accent : tokens.palette.fg2)
                Text(label)
                    .font(PlaygroundFont.body)
                    .foregroundStyle(isOn ? tokens.palette.fg1 : tokens.palette.fg1)
                Spacer(minLength: PlaygroundSpacing.xs)
                if let trailing {
                    Text(trailing)
                        .font(PlaygroundFont.badge)
                        .foregroundStyle(tokens.palette.fg3)
                }
            }
            .padding(.horizontal, PlaygroundSpacing.xs)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: PlaygroundRadius.sm, style: .continuous)
                    .fill(isOn ? tokens.palette.rowSelected : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .a11yToggle(
            label: LocalizedStringKey(label),
            isOn: isOn,
            id: "sidebar.fullscreen.\(surface.rawValue)"
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
