//
//  HistoryView.swift
//  DiagramPlayground
//
//  Displays the editor history timeline with filtering by origin,
//  restore/delete actions, and JSON import/export.
//

import SwiftUI
import DiagramKit
import UniformTypeIdentifiers

struct HistoryView: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var filterOrigin: LiveHistoryOrigin? = nil
    @SwiftUI.State private var showingClearConfirmation = false
    @SwiftUI.State private var showingExportSheet = false
    @SwiftUI.State private var showingImportSheet = false
    @SwiftUI.State private var exportedData: Data?
    @SwiftUI.State private var importResult: String?

    var body: some View {
        VStack(spacing: 0) {
            // Filter segmented control
            filterBar
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Entry list
            if filteredEntries.isEmpty {
                emptyState
            } else {
                entryList
            }

            // Bottom bar
            bottomBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Color(store.theme.foreground).opacity(0.03)
                )
        }
        .background(Color(store.theme.background))
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
        HStack(spacing: 0) {
            ForEach(filterOptions, id: \.0) { label, origin in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        filterOrigin = origin
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(filterOrigin == origin
                            ? .white
                            : Color(store.theme.effectiveMuted()))
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(filterOrigin == origin
                                    ? Color(store.theme.effectiveAccent())
                                    : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(store.theme.foreground).opacity(0.06))
        )
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
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundColor(Color(store.theme.effectiveMuted()).opacity(0.5))

            Text("No history entries")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(store.theme.effectiveMuted()))

            Text("Manual saves, auto timeline snapshots, and loaded diagrams will appear here.")
                .font(.system(size: 12))
                .foregroundColor(Color(store.theme.effectiveMuted()).opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Entry list

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredEntries) { entry in
                    entryRow(entry)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private func entryRow(_ entry: LiveHistoryEntry) -> some View {
        HStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // Origin icon
                    Image(systemName: entry.origin.iconName)
                        .font(.system(size: 10))
                        .foregroundColor(entry.origin.color)

                    // Label
                    Text(entry.displayLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(store.theme.foreground))
                        .lineLimit(1)

                    Spacer()

                    // Theme chip
                    Text(entry.state.selectedThemeName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(store.theme.foreground).opacity(0.06))
                        )
                }

                // Source preview
                Text(sourcePreview(entry.state.source))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
                    .lineLimit(2)

                // Timestamp + URL
                HStack(spacing: 6) {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundColor(Color(store.theme.effectiveMuted()).opacity(0.7))

                    if let sourceURL = entry.sourceURL {
                        Text("•")
                            .foregroundColor(Color(store.theme.effectiveMuted()).opacity(0.4))
                        Text(sourceURL.absoluteString)
                            .font(.system(size: 10))
                            .foregroundColor(Color(store.theme.effectiveMuted()).opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.leading, 10)

            // Actions
            HStack(spacing: 4) {
                // Restore
                Button {
                    store.restoreFromHistory(entry)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(store.theme.effectiveAccent()))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Restore this state")

                // Delete (only for non-read-only entries)
                if !entry.isReadOnly {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            store.historyStore.delete(entry)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.7))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Delete this entry")
                }
            }
            .padding(.trailing, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(store.theme.foreground).opacity(0.02))
        )
        .contentShape(Rectangle())
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 8) {
            // Import
            Button {
                showingImportSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11))
                    Text("Import")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(store.theme.effectiveMuted()))
            }
            .buttonStyle(.plain)
            .help("Import history from JSON file")

            Spacer()

            // Entry count
            Text("\(filteredEntries.count) \(filteredEntries.count == 1 ? "entry" : "entries")")
                .font(.system(size: 10))
                .foregroundColor(Color(store.theme.effectiveMuted()).opacity(0.6))

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
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                    Text("Export")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(store.theme.effectiveMuted()))
            }
            .buttonStyle(.plain)
            .disabled(store.historyStore.entries.isEmpty)
            .help("Export history as JSON file")

            // Clear all
            Button {
                showingClearConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
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
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(message.hasPrefix("Import") || message.hasPrefix("Export")
                        ? Color.orange.opacity(0.9)
                        : Color.green.opacity(0.9))
            )
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
    var iconName: String {
        switch self {
        case .manual: return "bookmark.fill"
        case .auto: return "clock.fill"
        case .loader: return "icloud.and.arrow.down.fill"
        }
    }

    var color: Color {
        switch self {
        case .manual: return .blue
        case .auto: return .gray
        case .loader: return .green
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
