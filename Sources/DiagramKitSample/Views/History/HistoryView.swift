//
//  HistoryView.swift
//  DiagramPlayground
//
//  Displays the editor history timeline with filtering by origin,
//  restore/delete actions, and JSON import/export.
//

import SwiftUI
import DiagramKit
import DesignKitThemes
import UniformTypeIdentifiers

struct HistoryView: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var filterOrigin: LiveHistoryOrigin? = nil
    @SwiftUI.State private var showingClearConfirmation = false
    @SwiftUI.State private var showingExportSheet = false
    @SwiftUI.State private var showingImportSheet = false
    @SwiftUI.State private var exportedData: Data?
    @SwiftUI.State private var importResult: String?
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSSurface(role: .panel) {
            VStack(spacing: 0) {
            // Filter segmented control
            filterBar
                .padding(.horizontal, DSTokens.Spacing.md)
                .padding(.top, DSTokens.Spacing.md)
                .padding(.bottom, DSTokens.Spacing.sm)

            // Entry list
            if filteredEntries.isEmpty {
                emptyState
            } else {
                entryList
            }

            // Bottom bar
            bottomBar
                .padding(.horizontal, DSTokens.Spacing.md)
                .padding(.vertical, DSTokens.Spacing.sm)
                .background { DSSurface(role: .statusBar) { Color.clear } }
            }
        }
        .alert("Clear All History", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                store.historyStore.clearAll()
            }
        } message: {
            Text("This will permanently delete all history entries. This action cannot be undone.")
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: exportedData.map { HistoryDocument(data: $0) },
            contentType: .json,
            defaultFilename: "mermaid-history-\(dateStamp).json"
        ) { result in
            if case .failure = result {
                importResult = "Export failed."
            }
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .overlay(alignment: .bottom) {
            if let importResult {
                resultToast(importResult)
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            await MainActor.run {
                                withAnimation { self.importResult = nil }
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Filtered entries

    private var filteredEntries: [LiveHistoryEntry] {
        if let filterOrigin {
            store.historyStore.entries.filter { $0.origin == filterOrigin }
        } else {
            store.historyStore.entries
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: DSTokens.Stroke.thin) {
            ForEach(filterOptions, id: \.0) { label, origin in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        filterOrigin = origin
                    }
                } label: {
                    Text(label)
                        .dsFont(.badge)
                }
                .buttonStyle(.ds(
                    role: filterOrigin == origin ? .secondary : .ghost,
                    size: .compact
                ))
            }
        }
        .padding(DSTokens.Stroke.medium)
        .background { DSSurface(role: .sunken) { Color.clear } }
    }

    private var filterOptions: [(String, LiveHistoryOrigin?)] {
        [
            ("All (\(store.historyStore.entries.count))", nil),
            ("Manual (\(store.historyStore.manualEntries.count))", .manual),
            ("Auto (\(store.historyStore.autoEntries.count))", .auto),
            ("Loader (\(store.historyStore.loaderEntries.count))", .loader)
        ]
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DSTokens.Spacing.sm) {
            DSIconView(.history, size: DSTokens.Icon.lg, colorRole: .muted)
            Text("No history entries")
                .dsFont(.headline)
            Text("Manual saves, auto timeline snapshots, and loaded diagrams will appear here.")
                .dsFont(.caption)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .multilineTextAlignment(.center)
        }
        .padding(DSTokens.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Entry list

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: DSTokens.Spacing.xxxs) {
                ForEach(filteredEntries) { entry in
                    entryRow(entry)
                }
            }
            .padding(.horizontal, DSTokens.Spacing.md)
            .padding(.bottom, DSTokens.Spacing.sm)
        }
    }

    private func entryRow(_ entry: LiveHistoryEntry) -> some View {
        HStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
                HStack(spacing: DSTokens.Spacing.xs) {
                    // Origin icon
                    DSIconView(
                        entry.origin.dsIcon,
                        size: DSTokens.Icon.indicator,
                        colorRole: entry.origin.dsIconColorRole
                    )

                    // Label
                    Text(entry.displayLabel)
                        .dsFont(.badge)
                        .foregroundStyle(environment.theme.colors.textPrimary.color)
                        .lineLimit(1)

                    Spacer()

                    // Theme chip
                    DSCodeBadge(entry.state.selectedThemeName)
                }

                // Source preview
                Text(sourcePreview(entry.state.source))
                    .dsFont(.code)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                    .lineLimit(2)

                // Timestamp + URL
                HStack(spacing: DSTokens.Spacing.xs) {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .dsFont(.caption2)
                        .foregroundStyle(environment.theme.colors.textDisabled.color)

                    if let sourceURL = entry.sourceURL {
                        Text("•")
                            .foregroundStyle(environment.theme.colors.textDisabled.color)
                        Text(sourceURL.absoluteString)
                            .dsFont(.caption2)
                            .foregroundStyle(environment.theme.colors.textDisabled.color)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, DSTokens.Spacing.sm)
            .padding(.leading, DSTokens.Spacing.smMd)

            // Actions
            HStack(spacing: DSTokens.Spacing.xxs) {
                // Restore
                DSIconButton(.history, label: "Restore this state") {
                    store.restoreFromHistory(entry)
                }
                .help("Restore this state")

                // Delete (only for non-read-only entries)
                if !entry.isReadOnly {
                    DSIconButton(
                        .remove,
                        label: "Delete this entry",
                        role: .destructive
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            store.historyStore.delete(entry)
                        }
                    }
                    .help("Delete this entry")
                }
            }
            .padding(.trailing, DSTokens.Spacing.xs)
        }
        .background { DSSurface(role: .card) { Color.clear } }
        .contentShape(Rectangle())
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            // Import
            Button {
                showingImportSheet = true
            } label: {
                HStack(spacing: DSTokens.Spacing.xxs) {
                    DSIconView(.copy, size: DSTokens.Icon.micro, colorRole: .muted)
                    Text("Import")
                        .dsFont(.badge)
                }
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .help("Import history from JSON file")

            Spacer()

            // Entry count
            Text("\(filteredEntries.count) \(filteredEntries.count == 1 ? "entry" : "entries")")
                .dsFont(.caption2)
                .foregroundStyle(environment.theme.colors.textSecondary.color)

            Spacer()

            // Export
            Button {
                do {
                    exportedData = try store.historyStore.exportData()
                    showingExportSheet = true
                } catch {
                    importResult = "Export failed: \(error.localizedDescription)"
                }
            } label: {
                HStack(spacing: DSTokens.Spacing.xxs) {
                    DSIconView(.export, size: DSTokens.Icon.micro, colorRole: .muted)
                    Text("Export")
                        .dsFont(.badge)
                }
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .disabled(store.historyStore.entries.isEmpty)
            .help("Export history as JSON file")

            // Clear all
            DSIconButton(.remove, label: "Clear all history", role: .destructive) {
                showingClearConfirmation = true
            }
            .disabled(store.historyStore.entries.isEmpty)
            .help("Clear all history")
        }
    }

    // MARK: - Import handler

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                let count = try store.historyStore.importData(data)
                importResult = count > 0
                    ? "Imported \(count) \(count == 1 ? "entry" : "entries")."
                    : "No new entries (all duplicates)."
            } catch {
                importResult = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            importResult = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    /// Truncated source preview (first ~80 chars, first line only).
    private func sourcePreview(_ source: String) -> String {
        let firstLine = source.split(separator: "\n", omittingEmptySubsequences: false).first ?? ""
        let line = String(firstLine).trimmingCharacters(in: .whitespaces)
        if line.count <= 80 { return line }
        return String(line.prefix(77)) + "..."
    }

    /// ISO date stamp for export filename.
    private var dateStamp: String {
        let formatter = DateFormatter()
        // Fixed locale/calendar so the fixed `yyyy-MM-dd` pattern always
        // emits Gregorian ASCII digits regardless of the user's locale.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Toast

    private func resultToast(_ message: String) -> some View {
        DSGlassSurface(role: .popover) {
            HStack(spacing: DSTokens.Spacing.sm) {
                DSStatusIndicator(
                    message.hasPrefix("Import") || message.hasPrefix("Export")
                        ? .warning
                        : .success,
                    label: message
                )
                Text(message)
                    .dsFont(.badge)
            }
            .padding(.horizontal, DSTokens.Spacing.lg)
            .padding(.vertical, DSTokens.Spacing.sm)
        }
    }
}

// MARK: - HistoryDocument (for file export)

/// Wraps JSON history data for file export.
private struct HistoryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Origin UI helpers

extension LiveHistoryOrigin {
    var dsIcon: DSIcon {
        switch self {
        case .manual: .favorite
        case .auto: .history
        case .loader: .copy
        }
    }

    var dsIconColorRole: DSIconColorRole {
        switch self {
        case .manual: .info
        case .auto: .muted
        case .loader: .success
        }
    }
}

#if DEBUG && !DIAGRAMKIT_SWIFTPM
#Preview {
    let store = LiveEditorStore()
    // Pre-populate with sample entries
    _ = store.historyStore.save(state: LiveEditorState(source: "graph TD\n  A-->B"), label: "My diagram")
    _ = store.historyStore.save(state: LiveEditorState(source: "sequenceDiagram\n  A->>B: Hello"), label: "Sequence test")
    store.historyStore.autoSaveIfNeeded(state: LiveEditorState(source: "flowchart LR\n  X-->Y"))
    return HistoryView(store: store)
        .frame(width: 420, height: 520)
}
#endif
