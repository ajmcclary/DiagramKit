//
//  VersionSecurityPanel.swift
//  DiagramPlayground
//
//  Version information and privacy/security disclosure.
//  Mirrors the Live Editor's VersionSecurityToolbar: shows the
//  DiagramKit version and explains the native, offline execution model.
//

import SwiftUI
import DiagramKit
import DiagramKitSampleDesignSystem

struct VersionSecurityPanel: View {
    @SwiftUI.State private var showingPrivacySheet = false
    @Environment(\.dsEnvironment) private var environment

    /// The DiagramKit version string reported by the public renderer API.
    nonisolated static var diagramKitVersion: String {
        DiagramEngine.version
    }

    private var diagramKitVersion: String {
        Self.diagramKitVersion
    }

    var body: some View {
        DSSurface(role: .panel) {
            ScrollView {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.lg) {
                // Header
                HStack(spacing: DSTokens.Spacing.smMd) {
                    DSIconView(.diagram, size: DSTokens.Icon.md)
                    VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                        Text("DiagramKit Playground")
                            .dsFont(.subheadline)
                        Text("Native multi-format diagram editor")
                            .dsFont(.caption)
                            .foregroundStyle(environment.theme.colors.textSecondary.color)
                    }
                }
                .padding(.bottom, DSTokens.Spacing.xxs)

                Divider()

                // Version
                infoRow(
                    icon: .info,
                    label: "Version",
                    value: diagramKitVersion
                )

                infoRow(
                    icon: .settings,
                    label: "Platform",
                    value: platformDescription
                )

                infoRow(
                    icon: .code,
                    label: "Language",
                    value: "Swift 6"
                )

                Divider()

                // Privacy & Security
                privacySection

                Divider()

                // Links
                linksSection
            }
            .padding(DSTokens.Spacing.lg)
            }
        }
        .sheet(isPresented: $showingPrivacySheet) {
            privacyDetailSheet
        }
    }

    // MARK: - Info row

    private func infoRow(icon: DSIcon, label: String, value: String) -> some View {
        HStack(spacing: DSTokens.Spacing.smMd) {
            DSIconView(icon, size: DSTokens.Icon.micro, colorRole: .muted)
                .frame(width: DSTokens.Spacing.xl)

            Text(label)
                .dsFont(.footnote)

            Spacer()

            Text(value)
                .dsFont(.caption)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Platform description

    private var platformDescription: String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #else
        return "Apple Platform"
        #endif
    }

    // MARK: - Privacy section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            HStack(spacing: DSTokens.Spacing.smMd) {
                DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
                    .frame(width: DSTokens.Spacing.xl)

                Text("Privacy & Security")
                    .dsFont(.footnote)
            }

            Text("This app runs entirely on your device. No diagram content, configuration, or usage data is collected, transmitted, or stored externally. Rendering, parsing, and layout are performed natively using the DiagramKit engine — no JavaScript, no remote servers, no telemetry.")
                .dsFont(.caption)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .lineSpacing(DSTokens.Spacing.xxxs)

            Button {
                showingPrivacySheet = true
            } label: {
                Text("Learn more about privacy...")
                    .dsFont(.badge)
                    .foregroundStyle(environment.theme.colors.accent.color)
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
        }
    }

    // MARK: - Privacy detail sheet

    private var privacyDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSTokens.Spacing.lg) {
                    privacyBullet(
                        title: "100% Local Execution",
                        detail: "All diagram parsing, layout, and rendering happens on your device using native Swift code. No source text ever leaves your machine."
                    )

                    privacyBullet(
                        title: "No Network Requests",
                        detail: "The DiagramKit engine makes no network calls. The playground app only connects to the network when you explicitly load a diagram from a URL or Gist."
                    )

                    privacyBullet(
                        title: "No Analytics or Tracking",
                        detail: "There are no analytics frameworks, crash reporters, or usage trackers in this app. Your work is your own."
                    )

                    privacyBullet(
                        title: "Native Renderers",
                        detail: "Diagrams are rendered using Core Graphics (CG) on Apple platforms and a native SVG renderer. No browser engine or JavaScript runtime is involved."
                    )

                    privacyBullet(
                        title: "DiagramKit Package",
                        detail: "This playground app exercises the \(diagramKitVersion) release of the DiagramKit Swift package. All rendering paths are exercised through the public API."
                    )
                }
                .padding(DSTokens.Spacing.lg)
            }
            .navigationTitle("Privacy & Security")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingPrivacySheet = false
                    }
                    .a11yIdentifier(A11yID.Panels.versionInfoDone)
                }
            }
        }
    }

    private func privacyBullet(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
            Text(title)
                .dsFont(.headline)
            Text(detail)
                .dsFont(.caption)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .lineSpacing(DSTokens.Spacing.xxxs)
        }
    }

    // MARK: - Links section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            HStack(spacing: DSTokens.Spacing.smMd) {
                DSIconView(.copy, size: DSTokens.Icon.micro, colorRole: .muted)
                    .frame(width: DSTokens.Spacing.xl)

                Text("Links")
                    .dsFont(.footnote)
            }

            Link(destination: URL(string: "https://github.com/ajmcclary/mermaid-swift")!) {
                HStack {
                    DSIconView(.export, size: DSTokens.Icon.indicator)
                    Text("DiagramKit on GitHub")
                        .dsFont(.caption)
                }
                .foregroundStyle(environment.theme.colors.accent.color)
            }

            Link(destination: URL(string: "https://mermaid.js.org")!) {
                HStack {
                    DSIconView(.export, size: DSTokens.Icon.indicator)
                    Text("Mermaid.js Documentation")
                        .dsFont(.caption)
                }
                .foregroundStyle(environment.theme.colors.accent.color)
            }
        }
    }
}

#if DEBUG && !DIAGRAMKIT_SWIFTPM
#Preview {
    VersionSecurityPanel()
        .frame(width: 320, height: 280)
}
#endif
