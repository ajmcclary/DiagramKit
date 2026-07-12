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
import DiagramKitSampleDesignSystem
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var store: LiveEditorStore

    /// When set, a Settings row is shown (used on iPhone-compact where there is
    /// no activity rail / ⌘, to reach Settings). The closure is responsible for
    /// dismissing the controls sheet before presenting Settings.
    var onOpenSettings: (() -> Void)? = nil

    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.md) {
            browseSection
            Rectangle()
                .fill(environment.theme.colors.borderVariant.color)
                .frame(height: DSTokens.Stroke.hairline)
                .padding(.horizontal, -DSTokens.Spacing.sm)
            SampleDiagramPanel(store: store)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, DSTokens.Spacing.md)
        .padding(.top, DSTokens.Spacing.md)
        .background(environment.theme.colors.panelBackground.color)
    }

    // MARK: - Browse section

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            DSSectionHeader("Browse")
                .padding(.top, DSTokens.Spacing.xxxs)
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
            HStack(spacing: DSTokens.Spacing.sm) {
                DSIconView(.settings, size: DSTokens.Icon.micro, colorRole: .muted)
                Text("Settings")
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                Spacer(minLength: DSTokens.Spacing.xs)
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
            HStack(spacing: DSTokens.Spacing.sm) {
                DSIconView(
                    icon,
                    size: DSTokens.Icon.micro,
                    colorRole: isOn ? .primary : .muted
                )
                Text(label)
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                Spacer(minLength: DSTokens.Spacing.xs)
                if let trailing {
                    Text(trailing)
                        .dsFont(.badge)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
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
