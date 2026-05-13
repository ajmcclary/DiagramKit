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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct ActionsView: View {
    @Bindable var store: LiveEditorStore

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
            VStack(alignment: .leading, spacing: 20) {
                // Export section
                sectionHeader("Export")
                exportSection

                Divider()

                // Convert section
                sectionHeader("Convert Source")
                convertSection

                Divider()

                // Copy section
                sectionHeader("Copy to Clipboard")
                copySection

                Divider()

                // View section
                sectionHeader("View")
                viewSection

                Divider()

                // Share section
                sectionHeader("Share")
                shareSection

                Divider()

                // History section
                sectionHeader("History")
                historySection

                Divider()

                // Load section
                sectionHeader("Load")
                loadSection

                // Copy feedback toast
                if showingCopyFeedback {
                    Text(copyFeedbackMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.85))
                        )
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(16)
        }
        .background(Color(store.theme.background))
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(store.theme.effectiveMuted()))
            .textCase(.uppercase)
    }

    // MARK: - Export section

    private var exportSection: some View {
        VStack(spacing: 6) {
            // PNG sizing picker
            pngSizingPicker

            actionButton(
                label: "Export PNG",
                icon: "photo",
                subtitle: pngSubtitle
            ) {
                onExportPNG()
            }

            actionButton(
                label: "Export SVG",
                icon: "doc.text",
                subtitle: "Vector graphics"
            ) {
                onExportSVG()
            }
        }
    }

    private var pngSizingPicker: some View {
        HStack(spacing: 8) {
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
                HStack(spacing: 4) {
                    Text("W:")
                        .font(.system(size: 10))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                    TextField("Width", value: Binding(
                        get: { Double(store.exportOptions.sizing.fixedSize?.width ?? 800) },
                        set: { w in
                            let h = store.exportOptions.sizing.fixedSize?.height ?? 600
                            store.exportOptions.sizing = .fixed(CGSize(width: max(1, CGFloat(w)), height: h))
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .font(.system(size: 11))

                    Text("H:")
                        .font(.system(size: 10))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                    TextField("Height", value: Binding(
                        get: { Double(store.exportOptions.sizing.fixedSize?.height ?? 600) },
                        set: { h in
                            let w = store.exportOptions.sizing.fixedSize?.width ?? 800
                            store.exportOptions.sizing = .fixed(CGSize(width: w, height: max(1, CGFloat(h))))
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .font(.system(size: 11))
                }
            }

            if case .auto = store.exportOptions.sizing {
                HStack(spacing: 4) {
                    Text("Scale:")
                        .font(.system(size: 10))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
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
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(store.theme.foreground).opacity(0.04))
        )
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
    /// and dispatch to the format's exporter. Graphviz is shown with a
    /// disabled subtitle because no DOT exporter is registered yet.
    private var convertSection: some View {
        VStack(spacing: 6) {
            ForEach(SourceFormat.allCases.filter { $0 != store.state.sourceFormat }) { target in
                actionButton(
                    label: "Convert to \(target.displayName)",
                    icon: target.hasExporter ? "arrow.left.arrow.right" : "exclamationmark.triangle",
                    subtitle: target.hasExporter
                        ? "Re-export current diagram as \(target.shortName)"
                        : "No exporter registered yet"
                ) {
                    guard target.hasExporter else {
                        showCopyFeedback("\(target.displayName) exporter unavailable")
                        return
                    }
                    onConvertSource(target)
                }
            }
        }
    }

    // MARK: - Copy section

    private var copySection: some View {
        VStack(spacing: 6) {
            actionButton(
                label: "Copy Source",
                icon: "doc.on.clipboard",
                subtitle: "\(store.state.sourceFormat.displayName) source text"
            ) {
                if store.copySource() {
                    showCopyFeedback("Source copied")
                }
            }

            actionButton(
                label: "Copy Config",
                icon: "gearshape",
                subtitle: "Config JSON"
            ) {
                if store.copyConfig() {
                    showCopyFeedback("Config copied")
                }
            }

            actionButton(
                label: "Copy SVG",
                icon: "doc.richtext",
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
                icon: "photo.on.rectangle",
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
        VStack(spacing: 6) {
            actionButton(
                label: "Full-Window Preview",
                icon: "rectangle.inset.filled",
                subtitle: "Preview-only window"
            ) {
                onFullWindowPreview()
            }
        }
    }

    // MARK: - Share section

    private var shareSection: some View {
        VStack(spacing: 6) {
            actionButton(
                label: "Share State",
                icon: "square.and.arrow.up",
                subtitle: "Copy serialized editor state"
            ) {
                onShareState()
            }
        }
    }

    // MARK: - History section

    private var historySection: some View {
        VStack(spacing: 6) {
            // Save State with inline label field
            HStack(spacing: 6) {
                TextField("Snapshot name...", text: $saveLabel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .foregroundColor(Color(store.theme.foreground))

                Button {
                    let label = saveLabel.trimmingCharacters(in: .whitespaces)
                    guard !label.isEmpty else { return }
                    store.saveHistoryEntry(label: label)
                    saveLabel = ""
                    showCopyFeedback("Saved: \(label)")
                } label: {
                    Text("Save")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(store.theme.effectiveAccent()))
                        )
                }
                .disabled(saveLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)

            actionButton(
                label: "View History",
                icon: "clock.arrow.circlepath",
                subtitle: "Browse saved states (\(store.historyStore.entries.count))"
            ) {
                onShowHistory()
            }
        }
    }

    // MARK: - Load section

    private var loadSection: some View {
        VStack(spacing: 8) {
            // Gist URL field
            VStack(alignment: .leading, spacing: 4) {
                Text("Load from Gist")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(store.theme.effectiveMuted()))

                HStack(spacing: 6) {
                    TextField("https://gist.github.com/...", text: $gistURLString)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .foregroundColor(Color(store.theme.foreground))

                    Button {
                        loadFromGist()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 20, height: 20)
                        } else {
                            Text("Load")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .disabled(gistURLString.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .buttonStyle(.plain)
                    .foregroundColor(Color(store.theme.effectiveAccent()))
                }
            }

            // Raw URL fields
            VStack(alignment: .leading, spacing: 4) {
                Text("Load from URL")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(store.theme.effectiveMuted()))

                TextField("Code URL (e.g. raw .mmd file)", text: $codeURLString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .foregroundColor(Color(store.theme.foreground))

                TextField("Config URL (optional JSON)", text: $configURLString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .foregroundColor(Color(store.theme.foreground))

                HStack {
                    Spacer()

                    Button {
                        loadFromRawURL()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 20, height: 20)
                        } else {
                            Text("Load")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .disabled(Self.isRawURLLoadDisabled(
                        codeURLString: codeURLString,
                        configURLString: configURLString,
                        isLoading: isLoading
                    ))
                    .buttonStyle(.plain)
                    .foregroundColor(Color(store.theme.effectiveAccent()))
                }
            }

            // Loader error display
            if let loaderError {
                Text(loaderError)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red.opacity(0.08))
                    )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(store.theme.foreground).opacity(0.02))
        )
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
        icon: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                    .foregroundColor(Color(store.theme.effectiveAccent()))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(store.theme.foreground))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(store.theme.foreground).opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feedback

    private func showCopyFeedback(_ message: String) {
        copyFeedbackMessage = message
        withAnimation(.easeOut(duration: 0.2)) {
            showingCopyFeedback = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showingCopyFeedback = false
                }
            }
        }
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
