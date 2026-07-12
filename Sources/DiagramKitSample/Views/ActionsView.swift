//
//  ActionsView.swift
//  DiagramPlayground
//
//  Export, copy, and share action buttons. Extracted from ActionsPanel
//  so the UI is reusable. Export file-dialog triggers are coordinated
//  by the parent (ActionsPanel) via callbacks.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DiagramKitSampleDesignSystem

struct ActionsView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    /// Called when the user taps "Export PNG" (parent triggers fileExporter).
    let onExportPNG: () -> Void
    /// Called when the user taps "Export SVG" (parent triggers fileExporter).
    let onExportSVG: () -> Void
    /// Called when the user taps "Full-Window Preview".
    let onFullWindowPreview: () -> Void
    /// Called when the user taps "Share State".
    let onShareState: () -> Void
    /// Called when the user taps "View History".
    let onShowHistory: () -> Void
    /// Called when the user picks a target format to convert into.
    let onConvertSource: (SourceFormat) -> Void

    @SwiftUI.State private var showingCopyFeedback = false
    @SwiftUI.State private var copyFeedbackMessage = ""

    // History save state
    @SwiftUI.State private var saveLabel: String = ""

    // Loader state
    @SwiftUI.State private var gistURLString: String = ""
    @SwiftUI.State private var codeURLString: String = ""
    @SwiftUI.State private var configURLString: String = ""
    @SwiftUI.State private var loaderError: String?
    @SwiftUI.State private var isLoading: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xl) {
                // Export section
                sectionHeader("Export")
                exportSection

                divider

                // Convert section
                sectionHeader("Convert Source")
                convertSection

                divider

                // Copy section
                sectionHeader("Copy to Clipboard")
                copySection

                divider

                // View section
                sectionHeader("View")
                viewSection

                divider

                // Share section
                sectionHeader("Share")
                shareSection

                divider

                // History section
                sectionHeader("History")
                historySection

                divider

                // Load section
                sectionHeader("Load")
                loadSection

                // Copy feedback toast
                if showingCopyFeedback {
                    DSGlassSurface(role: .popover) {
                        HStack(spacing: DSTokens.Spacing.xs) {
                            DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
                            Text(copyFeedbackMessage)
                                .dsFont(.badge)
                                .foregroundStyle(environment.theme.colors.textPrimary.color)
                        }
                        .padding(.horizontal, DSTokens.Spacing.md)
                        .padding(.vertical, DSTokens.Spacing.xs)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(DSTokens.Spacing.lg)
        }
        .background(environment.theme.colors.panelBackground.color)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        DSSectionHeader(title)
    }

    // MARK: - Export section

    private var exportSection: some View {
        VStack(spacing: DSTokens.Spacing.xs) {
            // PNG sizing picker
            pngSizingPicker

            actionButton(
                label: "Export PNG",
                icon: .image,
                subtitle: pngSubtitle
            ) {
                onExportPNG()
            }

            actionButton(
                label: "Export SVG",
                icon: .export,
                subtitle: "Vector graphics"
            ) {
                onExportSVG()
            }
        }
    }

    private var pngSizingPicker: some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            Picker("Sizing", selection: Binding(
                get: { store.exportOptions.sizing },
                set: { store.exportOptions.sizing = $0 }
            )) {
                Text("Auto (2×)").tag(ExportOptions.Sizing.auto)
                Text("Fixed size").tag(ExportOptions.Sizing.fixed(
                    store.exportOptions.sizing.fixedSize ?? CGSize(width: 800, height: 600)
                ))
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 140)

            if case .fixed = store.exportOptions.sizing {
                HStack(spacing: DSTokens.Spacing.xxs) {
                    Text("W:")
                        .dsFont(.caption2)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                    TextField("Width", value: Binding(
                        get: { Double(store.exportOptions.sizing.fixedSize?.width ?? 800) },
                        set: { w in
                            let h = store.exportOptions.sizing.fixedSize?.height ?? 600
                            store.exportOptions.sizing = .fixed(CGSize(width: max(1, CGFloat(w)), height: h))
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .dsFont(.caption2)

                    Text("H:")
                        .dsFont(.caption2)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                    TextField("Height", value: Binding(
                        get: { Double(store.exportOptions.sizing.fixedSize?.height ?? 600) },
                        set: { h in
                            let w = store.exportOptions.sizing.fixedSize?.width ?? 800
                            store.exportOptions.sizing = .fixed(CGSize(width: w, height: max(1, CGFloat(h))))
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .dsFont(.caption2)
                }
            }

            if case .auto = store.exportOptions.sizing {
                HStack(spacing: DSTokens.Spacing.xxs) {
                    Text("Scale:")
                        .dsFont(.caption2)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                    Picker("", selection: Binding(
                        get: { store.exportOptions.scale },
                        set: { store.exportOptions.scale = $0 }
                    )) {
                        Text("1×").tag(CGFloat(1.0))
                        Text("2×").tag(CGFloat(2.0))
                        Text("3×").tag(CGFloat(3.0))
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }
        }
        .padding(.vertical, DSTokens.Spacing.xxs)
        .padding(.horizontal, DSTokens.Spacing.smMd)
        .background { DSSurface(role: .card) { Color.clear } }
    }

    private var pngSubtitle: String {
        switch store.exportOptions.sizing {
        case .auto:
            return "Raster image at \(Int(store.exportOptions.scale))× scale"
        case .fixed(let size):
            return "Raster image at \(Int(size.width))×\(Int(size.height))"
        }
    }

    // MARK: - Convert section

    /// Per-target buttons that parse the current source through `DiagramLoader`
    /// and dispatch to the format's exporter. Unsupported diagram families
    /// for a given target surface as `.unsupported` diagnostics in the
    /// returned `DiagramExportResult` rather than being gated up-front.
    private var convertSection: some View {
        VStack(spacing: DSTokens.Spacing.xs) {
            ForEach(SourceFormat.allCases.filter { $0 != store.state.sourceFormat }) { target in
                actionButton(
                    label: "Convert to \(target.displayName)",
                    icon: .convert,
                    subtitle: "Re-export current diagram as \(target.shortName)"
                ) {
                    onConvertSource(target)
                }
            }
        }
    }

    // MARK: - Copy section

    private var copySection: some View {
        VStack(spacing: DSTokens.Spacing.xs) {
            actionButton(
                label: "Copy Source",
                icon: .copy,
                subtitle: "\(store.state.sourceFormat.displayName) source text"
            ) {
                if store.copySource() {
                    showCopyFeedback("Source copied")
                }
            }

            actionButton(
                label: "Copy Config",
                icon: .settings,
                subtitle: "Config JSON"
            ) {
                if store.copyConfig() {
                    showCopyFeedback("Config copied")
                }
            }

            actionButton(
                label: "Copy SVG",
                icon: .copy,
                subtitle: "Vector markup"
            ) {
                Task {
                    do {
                        try await store.copySVG()
                        showCopyFeedback("SVG copied")
                    } catch {
                        showCopyFeedback("Copy failed")
                    }
                }
            }

            actionButton(
                label: "Copy PNG Image",
                icon: .image,
                subtitle: "Raster image"
            ) {
                Task {
                    do {
                        try await store.copyPNGImage(options: store.exportOptions)
                        showCopyFeedback("PNG copied")
                    } catch {
                        showCopyFeedback("Copy failed")
                    }
                }
            }
        }
    }

    // MARK: - View section

    private var viewSection: some View {
        VStack(spacing: DSTokens.Spacing.xs) {
            actionButton(
                label: "Full-Window Preview",
                icon: .diagram,
                subtitle: "Preview-only window"
            ) {
                onFullWindowPreview()
            }
        }
    }

    // MARK: - Share section

    private var shareSection: some View {
        VStack(spacing: DSTokens.Spacing.xs) {
            actionButton(
                label: "Share State",
                icon: .export,
                subtitle: "Copy serialized editor state"
            ) {
                onShareState()
            }
        }
    }

    // MARK: - History section

    private var historySection: some View {
        VStack(spacing: DSTokens.Spacing.xs) {
            // Save State with inline label field
            HStack(spacing: DSTokens.Spacing.xs) {
                DSField("Snapshot name", text: $saveLabel, prompt: "Snapshot name…")

                Button("Save", action: saveButtonTapped)
                    .disabled(saveLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.ds(role: .primary, size: .compact))
            }
            .padding(.vertical, DSTokens.Spacing.xxxs)

            actionButton(
                label: "View History",
                icon: .history,
                subtitle: "Browse saved states (\(store.historyStore.entries.count))"
            ) {
                onShowHistory()
            }
        }
    }

    // MARK: - Load section

    private var loadSection: some View {
        DSSurface(role: .card) {
            VStack(spacing: DSTokens.Spacing.sm) {
                // Gist URL field
                VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
                    Text("Load from Gist")
                        .dsFont(.badge)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)

                    HStack(spacing: DSTokens.Spacing.xs) {
                        DSField("Gist URL", text: $gistURLString, prompt: "https://gist.github.com/…")

                        Button {
                            loadFromGist()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(environment.theme.colors.accent.color)
                            } else {
                                Text("Load")
                            }
                        }
                        .disabled(gistURLString.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                        .buttonStyle(.ds(role: .secondary, size: .compact))
                    }
                }

                // Raw URL fields
                VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
                    Text("Load from URL")
                        .dsFont(.badge)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)

                    DSField("Code URL", text: $codeURLString, prompt: "Raw diagram URL")

                    DSField("Config URL", text: $configURLString, prompt: "Optional JSON config URL")

                    HStack {
                        Spacer()

                        Button {
                            loadFromRawURL()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(environment.theme.colors.accent.color)
                            } else {
                                Text("Load")
                            }
                        }
                        .disabled(Self.isRawURLLoadDisabled(
                            codeURLString: codeURLString,
                            configURLString: configURLString,
                            isLoading: isLoading
                        ))
                        .buttonStyle(.ds(role: .secondary, size: .compact))
                    }
                }

                // Loader error display
                if let loaderError {
                    HStack(alignment: .top, spacing: DSTokens.Spacing.xs) {
                        DSStatusIndicator(.error, label: "Load failed")
                        Text(loaderError)
                            .dsFont(.caption)
                            .foregroundStyle(environment.theme.colors.error.color)
                    }
                    .padding(DSTokens.Spacing.sm)
                    .background(
                        environment.theme.colors.value("error.background").color,
                        in: RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
                    )
                }
            }
            .padding(DSTokens.Spacing.sm)
        }
    }

    // MARK: - Loader actions

    private func loadFromGist() {
        guard let url = URL(string: gistURLString.trimmingCharacters(in: .whitespaces)) else {
            loaderError = "Invalid URL."
            return
        }

        isLoading = true
        loaderError = nil

        Task {
            do {
                try await store.loadFromGist(url: url)
                await MainActor.run {
                    isLoading = false
                    gistURLString = ""
                    showCopyFeedback("Gist loaded")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    loaderError = error.localizedDescription
                }
            }
        }
    }

    private func loadFromRawURL() {
        let codeURL = URL(string: codeURLString.trimmingCharacters(in: .whitespaces))
        let configURL = configURLString.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil
            : URL(string: configURLString.trimmingCharacters(in: .whitespaces))

        guard codeURL != nil || configURL != nil else {
            loaderError = "At least one valid URL is required."
            return
        }

        isLoading = true
        loaderError = nil

        Task {
            do {
                try await store.loadFromRawURL(codeURL: codeURL, configURL: configURL)
                await MainActor.run {
                    isLoading = false
                    codeURLString = ""
                    configURLString = ""
                    showCopyFeedback("URL loaded")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    loaderError = error.localizedDescription
                }
            }
        }
    }

    private func saveButtonTapped() {
        let label = saveLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        store.saveHistoryEntry(label: label)
        saveLabel = ""
        showCopyFeedback("Saved: \(label)")
    }

    nonisolated static func isRawURLLoadDisabled(
        codeURLString: String,
        configURLString: String,
        isLoading: Bool
    ) -> Bool {
        if isLoading { return true }
        return codeURLString.trimmingCharacters(in: .whitespaces).isEmpty
            && configURLString.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Action button

    private func actionButton(
        label: String,
        icon: DSIcon,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DSTokens.Spacing.smMd) {
                DSIconView(icon, size: DSTokens.Icon.xs)

                VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                    Text(label)
                        .dsFont(.badge)
                        .foregroundStyle(environment.theme.colors.textPrimary.color)
                    Text(subtitle)
                        .dsFont(.caption2)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.ds(role: .secondary, size: .regular))
    }

    // MARK: - Feedback

    private func showCopyFeedback(_ message: String) {
        copyFeedbackMessage = message
        withAnimation(feedbackAnimation) {
            showingCopyFeedback = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(feedbackAnimation) {
                    showingCopyFeedback = false
                }
            }
        }
    }

    private var feedbackAnimation: Animation? {
        guard environment.motion == .standard else { return nil }
        return .easeOut(
            duration: environment.motion.duration(
                milliseconds: DSTokens.DurationMilliseconds.quick
            )
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(height: DSTokens.Stroke.hairline)
            .accessibilityHidden(true)
    }
}

// MARK: - ExportOptions.Sizing helpers

extension ExportOptions.Sizing {
    /// Return the fixed size if this is a `.fixed` case, else nil.
    var fixedSize: CGSize? {
        if case .fixed(let size) = self { return size }
        return nil
    }
}
