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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SidebarView: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: PlaygroundSpacing.md) {
            brandRow
            searchField
            formatChips
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

    // MARK: - Brand row

    private var brandRow: some View {
        HStack(spacing: PlaygroundSpacing.sm) {
            brandMark
            VStack(alignment: .leading, spacing: 1) {
                Text("DiagramKit")
                    .font(PlaygroundFont.title)
                    .foregroundStyle(tokens.palette.fg1)
                Text("v\(DiagramEngine.version) · \(DiagramEngine.supportedDiagramTypes.count) families")
                    .font(PlaygroundFont.badge)
                    .foregroundStyle(tokens.palette.fg2)
            }
            Spacer()
        }
    }

    private var brandMark: some View {
        // 4×4 grid mark from the design.
        VStack(spacing: 2) {
            ForEach(0..<2) { _ in
                HStack(spacing: 2) {
                    ForEach(0..<2) { _ in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(tokens.palette.accent)
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .frame(width: 18, height: 18)
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: PlaygroundRadius.sm, style: .continuous)
                .fill(tokens.palette.accent15)
        )
    }

    // MARK: - Search

    private var searchField: some View {
        FieldInput(
            placeholder: "Search · format · family · diagnostic state",
            text: $store.state.sidebarSearch,
            systemImage: "magnifyingglass",
            trailingHint: "⌘K"
        )
        .a11yIdentifier(A11yID.Sidebar.search)
    }

    // MARK: - Format chips

    private var formatChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(SourceFormat.allCases) { format in
                    chip(for: format)
                }
            }
        }
    }

    private func chip(for format: SourceFormat) -> some View {
        let isOn = store.state.sidebarFormatFilter == format
        return Button {
            store.state.sidebarFormatFilter = isOn ? nil : format
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(formatDotColor(format))
                    .frame(width: 6, height: 6)
                Text(format.shortName)
                    .font(PlaygroundFont.label)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(isOn ? tokens.palette.fg1 : tokens.palette.fg2)
            .background(
                Capsule()
                    .fill(isOn ? tokens.palette.rowSelected : Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(
                                isOn ? tokens.palette.accent.opacity(0.4) : tokens.palette.borderHairline,
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .a11yToggle(
            label: LocalizedStringKey(format.displayName),
            isOn: isOn,
            id: A11yID.Sidebar.formatChip(format.rawValue)
        )
    }

    // Per-format accent dot matching the design palette.
    private func formatDotColor(_ format: SourceFormat) -> Color {
        switch format {
        case .mermaid:    return tokens.palette.statusInfo
        case .d2:         return Color(hex: 0x5E5CE6)
        case .graphviz:   return Color(hex: 0xBF5AF2)
        case .structurizr: return Color(hex: 0x64D2FF)
        case .plantuml:   return Color(hex: 0xFF9F0A)
        }
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
