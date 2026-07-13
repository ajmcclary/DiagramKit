#if os(macOS)
import AppKit
import DesignKitThemes
import SnapshotTesting
import SwiftUI
import Testing

@Suite("Design-system SwiftUI snapshots")
@MainActor
struct DSSnapshotTests {
    @Test("representative application surfaces", arguments: [
        DSThemeVariant.lcarsDark,
        .lcarsLight,
        .blackAlertDark,
        .redAlertDark,
        .borgCubeDark,
    ])
    func applicationSurface(variant: DSThemeVariant) {
        assertViewSnapshot(
            DSApplicationSurfaceBoard(theme: variant.theme)
                .dsTheme(family: variant.family, mode: variant.mode),
            size: CGSize(width: 960, height: 640),
            named: "application-\(snapshotName(variant))"
        )
    }

    @Test("all theme specimen cards", arguments: DSThemeVariant.allCases)
    func themeSpecimen(variant: DSThemeVariant) {
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

    private func snapshotName(_ variant: DSThemeVariant) -> String {
        variant.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

@MainActor
private struct DSApplicationSurfaceBoard: View {
    let theme: DSTheme

    var body: some View {
        VStack(spacing: 0) {
            chromeHeader
            HStack(spacing: DSTokens.Spacing.md) {
                VStack(spacing: DSTokens.Spacing.md) {
                    panel("Editor tabs", icon: .code) { editorTabs }
                    panel("Diagnostics", icon: .diagnostics) { diagnostics }
                    panel("Visual overlay", icon: .node) { visualOverlay }
                }
                VStack(spacing: DSTokens.Spacing.md) {
                    panel("Export", icon: .export) { exportPanel }
                    panel("Settings", icon: .settings) { settings }
                }
                panel("Corpus", icon: .diagram) { corpus }
            }
            .padding(DSTokens.Spacing.lg)
        }
        .background(theme.colors.windowBackground.color)
    }

    private var chromeHeader: some View {
        DSSurface(role: .titleBar) {
            HStack(spacing: DSTokens.Spacing.sm) {
                DSIconView(.diagram)
                Text("DiagramKit Sample")
                    .dsFont(.headline)
                DSStatusIndicator(.success, label: "Rendered")
                Spacer()
                DSIconButton(.search, label: "Search") {}
                DSIconButton(.settings, label: "Settings") {}
            }
            .padding(.horizontal, DSTokens.Spacing.lg)
            .frame(height: DSTokens.Control.titleBar)
        }
    }

    private var editorTabs: some View {
        HStack(spacing: DSTokens.Spacing.xxs) {
            DSChip(isSelected: true, action: {}) { Text("Flowchart") }
            DSChip(action: {}) { Text("Sequence") }
            DSIconButton(.add, label: "New tab") {}
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            statusRow(.warning, "Unsupported arrow style")
            statusRow(.error, "Line 8: missing node")
            statusRow(.info, "Converted with one note")
        }
    }

    private func statusRow(_ kind: DSStatusKind, _ label: String) -> some View {
        HStack(spacing: DSTokens.Spacing.xs) {
            DSStatusIndicator(kind, label: label)
            Text(label).dsFont(.caption)
        }
    }

    private var visualOverlay: some View {
        DSGlassSurface(role: .popover) {
            HStack(spacing: DSTokens.Spacing.xs) {
                DSIconView(.node, colorRole: .info)
                VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                    Text("node: Checkout")
                        .dsFont(.badge)
                    Text("3 connected edges")
                        .dsFont(.caption2)
                }
            }
            .padding(DSTokens.Spacing.sm)
        }
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
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
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
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
                    .padding(DSTokens.Spacing.sm)
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
            VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSIconView(icon, size: DSTokens.Icon.xs, colorRole: .muted)
                    DSSectionHeader(title)
                }
                content()
                Spacer(minLength: 0)
            }
            .padding(DSTokens.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

@MainActor
private struct DSThemeSpecimenCard: View {
    let theme: DSTheme

    var body: some View {
        DSSurface(role: .card) {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                        Text(theme.name).dsFont(.title)
                        Text("\(theme.family.displayName) · \(theme.mode.rawValue)")
                            .dsFont(.caption)
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                    Spacer()
                    DSIconView(.theme, colorRole: .info)
                }
                HStack(spacing: DSTokens.Spacing.xs) {
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
            .padding(DSTokens.Spacing.lg)
        }
        .padding(DSTokens.Spacing.lg)
        .background(theme.colors.windowBackground.color)
    }

    private func color(_ value: DSColorValue) -> some View {
        value.color
            .frame(maxWidth: .infinity)
            .frame(height: DSTokens.Spacing.lg)
            .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.xs))
    }
}
#endif
