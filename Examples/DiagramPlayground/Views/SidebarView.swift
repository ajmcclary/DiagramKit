//
//  SidebarView.swift
//  DiagramPlayground
//
//  v2 PlaygroundShell sidebar — brand row, format chips, search,
//  and the existing categorized SampleDiagramPanel as the tree.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import UniformTypeIdentifiers

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SidebarView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            brandRow
            searchField
            formatChips
            fullScreenLinks
            Divider().padding(.horizontal, -8)
            SampleDiagramPanel(store: store)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .background(Color(store.theme.background))
    }

    // MARK: - Full-screen surface launchers (Phase 8 / Task 8.1)

    private var fullScreenLinks: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Browse")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 2)
            link(.coverage, label: "Coverage matrix · 28×5")
            link(.corpus, label: "Corpus · \(TestDiagrams.all.count)")
            link(.crossFormat, label: "Cross-format")
            link(.probe, label: "Importer probe")
            link(.snippets, label: "Snippets library")
        }
    }

    private func link(_ surface: FullScreenSurface, label: String) -> some View {
        let isOn = store.state.fullScreen == surface
        return Button {
            store.setFullScreen(isOn ? .none : surface)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: surface.sfSymbol)
                    .frame(width: 14)
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                Text(label)
                    .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Color.accentColor : .primary)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(isOn ? Color.accentColor.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .a11yToggle(
            label: LocalizedStringKey(label),
            isOn: isOn,
            id: "sidebar.fullscreen.\(surface.rawValue)"
        )
    }

    // MARK: - Brand row

    private var brandRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group.fill")
                .foregroundStyle(.tint)
            Text("DiagramKit")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Filter samples", text: $store.state.sidebarSearch)
                .textFieldStyle(.plain)
                .a11yIdentifier(A11yID.Sidebar.search)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(store.theme.foreground).opacity(0.06))
        )
    }

    // MARK: - Format chips

    private var formatChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SourceFormat.allCases) { format in
                    chip(for: format)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(for format: SourceFormat) -> some View {
        let isOn = store.state.sidebarFormatFilter == format
        return Button {
            if isOn {
                store.state.sidebarFormatFilter = nil
            } else {
                store.state.sidebarFormatFilter = format
            }
        } label: {
            Text(format.shortName)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isOn ? Color.accentColor.opacity(0.22) : Color.gray.opacity(0.12))
                )
                .foregroundStyle(isOn ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .a11yToggle(
            label: LocalizedStringKey(format.displayName),
            isOn: isOn,
            id: A11yID.Sidebar.formatChip(format.rawValue)
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
