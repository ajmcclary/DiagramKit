#if os(macOS)
import AppKit
import DesignKitThemes
@testable import DiagramKitSample
import SnapshotTesting
import SwiftUI
import Testing

/// Replaces the retired generated `DSThemeVariant`: same 20 variants
/// (10 Zed Trek families × dark/light), same snapshot names.
struct SnapshotVariant: Sendable, Hashable, CustomStringConvertible {
    let family: Theme.Family
    let appearance: Theme.Appearance

    var theme: Theme { family.theme(for: appearance) }
    var mode: DSThemeMode { appearance == .dark ? .dark : .light }
    var rawValue: String { theme.name }
    var description: String { theme.name }

    static let lcarsDark = SnapshotVariant(family: .lcars, appearance: .dark)
    static let lcarsLight = SnapshotVariant(family: .lcars, appearance: .light)
    static let blackAlertDark = SnapshotVariant(family: .blackAlert, appearance: .dark)
    static let redAlertDark = SnapshotVariant(family: .redAlert, appearance: .dark)
    static let borgCubeDark = SnapshotVariant(family: .borgCube, appearance: .dark)

    static var allCases: [SnapshotVariant] {
        ZedTrekTheme.allCases.flatMap { zed in
            [Theme.Appearance.dark, .light].map {
                SnapshotVariant(family: zed.dsFamily, appearance: $0)
            }
        }
    }
}

@Suite("Design-system SwiftUI snapshots")
@MainActor
struct DSSnapshotTests {
    @Test("representative application surfaces", arguments: [
        SnapshotVariant.lcarsDark,
        .lcarsLight,
        .blackAlertDark,
        .redAlertDark,
        .borgCubeDark,
    ])
    func applicationSurface(variant: SnapshotVariant) {
        assertViewSnapshot(
            DSApplicationSurfaceBoard(theme: variant.theme)
                .dsTheme(family: variant.family, mode: variant.mode),
            size: CGSize(width: 960, height: 640),
            named: "application-\(snapshotName(variant))"
        )
    }

    @Test("all theme specimen cards", arguments: SnapshotVariant.allCases)
    func themeSpecimen(variant: SnapshotVariant) {
        assertViewSnapshot(
            DSThemeSpecimenCard(theme: variant.theme)
                .dsTheme(family: variant.family, mode: variant.mode),
            size: CGSize(width: 420, height: 260),
            named: "theme-\(snapshotName(variant))"
        )
    }

    private func assertViewSnapshot<Content: View>(
        _ content: Content,
        size: CGSize,
        named name: String
    ) {
        let hosting = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        assertSnapshot(
            of: hosting,
            as: .image(
                precision: snapshotPixelPrecision(),
                perceptualPrecision: snapshotPerceptualPrecision()
            ),
            named: name
        )
    }

    private func snapshotName(_ variant: SnapshotVariant) -> String {
        variant.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

@MainActor
private struct DSApplicationSurfaceBoard: View {
    let theme: Theme

    var body: some View {
        VStack(spacing: 0) {
            chromeHeader
            HStack(spacing: Tokens.Spacing.md) {
                VStack(spacing: Tokens.Spacing.md) {
                    panel("Editor tabs", icon: .code) { editorTabs }
                    panel("Diagnostics", icon: .diagnostics) { diagnostics }
                    panel("Visual overlay", icon: .node) { visualOverlay }
                }
                VStack(spacing: Tokens.Spacing.md) {
                    panel("Export", icon: .export) { exportPanel }
                    panel("Settings", icon: .settings) { settings }
                }
                panel("Corpus", icon: .diagram) { corpus }
            }
            .padding(Tokens.Spacing.lg)
        }
        .background(theme.colors.windowBackground.color)
    }

    private var chromeHeader: some View {
        DSSurface(role: .titleBar) {
            HStack(spacing: Tokens.Spacing.sm) {
                DSIconView(.diagram)
                Text("DiagramKit Sample")
                    .dsFont(.headline)
                DSStatusIndicator(.success, label: "Rendered")
                Spacer()
                DSIconButton(.search, label: "Search") {}
                DSIconButton(.settings, label: "Settings") {}
            }
            .padding(.horizontal, Tokens.Spacing.lg)
            .frame(height: Tokens.Size.Control.titleBar)
        }
    }

    private var editorTabs: some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            DSChip(isSelected: true, action: {}) { Text("Flowchart") }
            DSChip(action: {}) { Text("Sequence") }
            DSIconButton(.add, label: "New tab") {}
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            statusRow(.warning, "Unsupported arrow style")
            statusRow(.error, "Line 8: missing node")
            statusRow(.info, "Converted with one note")
        }
    }

    private func statusRow(_ kind: DSStatusKind, _ label: String) -> some View {
        HStack(spacing: Tokens.Spacing.xs) {
            DSStatusIndicator(kind, label: label)
            Text(label).dsFont(.caption)
        }
    }

    private var visualOverlay: some View {
        DSGlassSurface(role: .popover) {
            HStack(spacing: Tokens.Spacing.xs) {
                DSIconView(.node, colorRole: .info)
                VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                    Text("node: Checkout")
                        .dsFont(.badge)
                    Text("3 connected edges")
                        .dsFont(.caption2)
                }
            }
            .padding(Tokens.Spacing.sm)
        }
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            DSChipGroup {
                DSChip(isSelected: true, action: {}) { Text("SVG") }
                DSChip(action: {}) { Text("PNG") }
                DSChip(action: {}) { Text("Source") }
            }
            HStack {
                Button("Copy", action: {}).buttonStyle(.ds(role: .secondary, size: .compact))
                Button("Export", action: {}).buttonStyle(.ds(role: .primary, size: .compact))
            }
        }
    }

    private var settings: some View {
        DSSettingGroup("Editor") {
            Toggle("Line numbers", isOn: .constant(true))
                .toggleStyle(.ds)
            Toggle("Minimap", isOn: .constant(false))
                .toggleStyle(.ds)
        }
    }

    private var corpus: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            DSField("Search corpus", text: .constant("flowchart"))
            ForEach(["Basic flow", "Subgraph", "Decision tree"], id: \.self) { title in
                DSSurface(role: .sunken) {
                    HStack {
                        DSIconView(.diagram, colorRole: .muted)
                        VStack(alignment: .leading) {
                            Text(title).dsFont(.body)
                            Text("Mermaid · snapshot ready").dsFont(.caption2)
                        }
                        Spacer()
                    }
                    .padding(Tokens.Spacing.sm)
                }
            }
            Spacer()
        }
    }

    private func panel<Content: View>(
        _ title: String,
        icon: DSIcon,
        @ViewBuilder content: () -> Content
    ) -> some View {
        DSSurface(role: .panel) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                HStack(spacing: Tokens.Spacing.xs) {
                    DSIconView(icon, size: Tokens.Size.Icon.xs, colorRole: .muted)
                    DSSectionHeader(title)
                }
                content()
                Spacer(minLength: 0)
            }
            .padding(Tokens.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

@MainActor
private struct DSThemeSpecimenCard: View {
    let theme: Theme

    /// Family display name (theme name minus the appearance suffix) — keeps
    /// the card label identical to the retired DSThemeVariant rendering.
    private var familyName: String {
        theme.name
            .replacingOccurrences(of: " Dark", with: "")
            .replacingOccurrences(of: " Light", with: "")
    }

    var body: some View {
        DSSurface(role: .card) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                        Text(theme.name).dsFont(.title)
                        Text("\(familyName) · \(theme.appearance.rawValue)")
                            .dsFont(.caption)
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                    Spacer()
                    DSIconView(.theme, colorRole: .info)
                }
                HStack(spacing: Tokens.Spacing.xs) {
                    color(theme.colors.accent)
                    color(theme.colors.success)
                    color(theme.colors.warning)
                    color(theme.colors.error)
                    color(theme.colors.info)
                }
                Text("The quick brown fox renders Mermaid, D2, DOT, Structurizr, and PlantUML.")
                    .dsFont(.body)
                    .foregroundStyle(theme.colors.textPrimary.color)
                HStack {
                    DSChip(isSelected: true, action: {}) { Text("Selected") }
                    DSChip(action: {}) { Text("Default") }
                    Spacer()
                    Button("Continue", action: {}).buttonStyle(.ds(role: .primary, size: .compact))
                }
            }
            .padding(Tokens.Spacing.lg)
        }
        .padding(Tokens.Spacing.lg)
        .background(theme.colors.windowBackground.color)
    }

    private func color(_ value: Tokens.Color) -> some View {
        value.color
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Spacing.lg)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS))
    }
}
#endif
