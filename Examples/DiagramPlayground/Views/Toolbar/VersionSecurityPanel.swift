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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct VersionSecurityPanel: View {
    @SwiftUI.State private var showingPrivacySheet = false

    /// The DiagramKit version string reported by the public renderer API.
    nonisolated static var diagramKitVersion: String {
        DiagramEngine.version
    }

    private var diagramKitVersion: String {
        Self.diagramKitVersion
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DiagramKit Playground")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Native multi-format diagram editor")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // Version
                infoRow(
                    icon: "number",
                    label: "Version",
                    value: diagramKitVersion
                )

                infoRow(
                    icon: "cpu",
                    label: "Platform",
                    value: platformDescription
                )

                infoRow(
                    icon: "swift",
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
            .padding(16)
        }
        .sheet(isPresented: $showingPrivacySheet) {
            privacyDetailSheet
        }
    }

    // MARK: - Info row

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(label)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                Text("Privacy & Security")
                    .font(.system(size: 13, weight: .semibold))
            }

            Text("This app runs entirely on your device. No diagram content, configuration, or usage data is collected, transmitted, or stored externally. Rendering, parsing, and layout are performed natively using the DiagramKit engine — no JavaScript, no remote servers, no telemetry.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(2)

            Button {
                showingPrivacySheet = true
            } label: {
                Text("Learn more about privacy...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Privacy detail sheet

    private var privacyDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding(16)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
    }

    // MARK: - Links section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                Text("Links")
                    .font(.system(size: 13, weight: .semibold))
            }

            Link(destination: URL(string: "https://github.com/ajmcclary/mermaid-swift")!) {
                HStack {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .accessibilityHidden(true)
                    Text("DiagramKit on GitHub")
                        .font(.system(size: 12))
                }
                .foregroundColor(.accentColor)
            }

            Link(destination: URL(string: "https://mermaid.js.org")!) {
                HStack {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .accessibilityHidden(true)
                    Text("Mermaid.js Documentation")
                        .font(.system(size: 12))
                }
                .foregroundColor(.accentColor)
            }
        }
    }
}

#if DEBUG && !DIAGRAMKIT_SWIFTPM
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
#Preview {
    VersionSecurityPanel()
        .frame(width: 320, height: 280)
}
#endif
