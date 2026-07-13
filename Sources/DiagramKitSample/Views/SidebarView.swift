//
//  SidebarView.swift
//  DiagramPlayground
//
//  v2 PlaygroundShell sidebar — brand row, search, format chips, and
//  the categorized SampleDiagramPanel as the tree. Uses the generated
//  design-system tokens and primitives.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DesignKitThemes
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var store: LiveEditorStore

    /// When set, a Settings row is shown (used on iPhone-compact where there is
    /// no activity rail / ⌘, to reach Settings). The closure is responsible for
    /// dismissing the controls sheet before presenting Settings.
    var onOpenSettings: (() -> Void)? = nil

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            browseSection
            Rectangle()
                .fill(theme.colors.borderVariant.color)
                .frame(height: Tokens.Shape.strokeHairline)
                .padding(.horizontal, -Tokens.Spacing.sm)
            SampleDiagramPanel(store: store)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .padding(.top, Tokens.Spacing.md)
        .background(theme.colors.panelBackground.color)
    }

    // MARK: - Browse section

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            DSSectionHeader("Browse")
                .padding(.top, Tokens.Spacing.xxxs)
            link(.coverage, label: "Coverage matrix", trailing: "28×5", icon: .diagram)
            link(.corpus, label: "Corpus", trailing: "\(TestDiagrams.all.count)", icon: .image)
            link(.crossFormat, label: "Cross-format", trailing: nil, icon: .convert)
            link(.probe, label: "Importer probe", trailing: nil, icon: .search)
            link(.snippets, label: "Snippets library", trailing: nil, icon: .code)
            if let onOpenSettings {
                settingsRow(onOpenSettings)
            }
        }
    }

    private func settingsRow(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.sm) {
                DSIconView(.settings, size: Tokens.Size.Icon.micro, colorRole: .muted)
                Text("Settings")
                    .dsFont(.body)
                    .foregroundStyle(theme.colors.textPrimary.color)
                Spacer(minLength: Tokens.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
    }

    private func link(
        _ surface: FullScreenSurface,
        label: String,
        trailing: String?,
        icon: DSIcon
    ) -> some View {
        let isOn = store.state.fullScreen == surface
        return Button {
            store.setFullScreen(isOn ? .none : surface)
        } label: {
            HStack(spacing: Tokens.Spacing.sm) {
                DSIconView(
                    icon,
                    size: Tokens.Size.Icon.micro,
                    colorRole: isOn ? .primary : .muted
                )
                Text(label)
                    .dsFont(.body)
                    .foregroundStyle(theme.colors.textPrimary.color)
                Spacer(minLength: Tokens.Spacing.xs)
                if let trailing {
                    Text(trailing)
                        .dsFont(.badge)
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: isOn ? .secondary : .ghost, size: .compact))
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
