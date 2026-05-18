//
//  LiveHistoryStore.swift
//  DiagramPlayground
//
//  Persists and manages history entries for the live editor.
//  Supports manual saves, auto timeline (30-entry cap, 60s debounce),
//  loader revisions, and JSON export/import.
//
//  Storage: Application Support/DiagramPlayground/History/history.json
//  (with one-shot migration from the legacy MermaidPlayground location).
//

import Foundation
import IssueReporting

// MARK: - LiveHistoryStore

/// Manages the history of editor states.
///
/// All mutations update the in-memory array immediately and persist
/// to disk asynchronously. The store is `@MainActor` for safe UI binding.
@MainActor
@available(iOS 26.0, macOS 26.0, *)
public final class LiveHistoryStore: @unchecked Sendable {

    // MARK: - Published state

    /// All history entries, newest first.
    public private(set) var entries: [LiveHistoryEntry] = []

    // MARK: - Filtered views

    /// Manual save entries only.
    public var manualEntries: [LiveHistoryEntry] {
        entries.filter { $0.origin == .manual }
    }

    /// Auto timeline entries only.
    public var autoEntries: [LiveHistoryEntry] {
        entries.filter { $0.origin == .auto }
    }

    /// Loader entries only.
    public var loaderEntries: [LiveHistoryEntry] {
        entries.filter { $0.origin == .loader }
    }

    // MARK: - Configuration

    /// Maximum number of auto entries to retain.
    private let maxAutoEntries = 30

    /// Minimum interval between auto saves, in seconds.
    private let autoSaveInterval: TimeInterval = 60

    // MARK: - Private state

    /// Timestamp of the most recent auto save.
    private var lastAutoSaveTime: Date?

    /// Serialized state of the most recent auto entry (for dedup).
    private var lastAutoSaveStateKey: String?

    /// File URL for persistence.
    private let storageURL: URL

    /// Serial queue for disk writes (fire-and-forget, never blocks MainActor).
    private let writeQueue = DispatchQueue(label: "com.diagramkit.history.write")

    // MARK: - Init

    /// Create a history store, loading existing entries from disk.
    ///
    /// - Parameter storageURL: Custom storage location (defaults to
    ///   Application Support/DiagramPlayground/History/history.json).
    public init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            self.storageURL = Self.defaultStorageURL()
            Self.migrateLegacyStorageIfNeeded(to: self.storageURL)
        }
        loadFromDisk()
        // Set lastAutoSaveTime from the most recent auto entry, if any
        if let latestAuto = autoEntries.first {
            lastAutoSaveTime = latestAuto.timestamp
            lastAutoSaveStateKey = Self.serializedKey(for: latestAuto.state)
        }
    }

    // MARK: - Manual save

    /// Save the current state as a manually-named snapshot.
    ///
    /// - Parameters:
    ///   - state: The editor state to snapshot.
    ///   - label: A user-provided name for this entry.
    /// - Returns: The newly created entry.
    @discardableResult
    public func save(state: LiveEditorState, label: String) -> LiveHistoryEntry {
        let entry = LiveHistoryEntry(
            label: label,
            origin: .manual,
            state: state
        )
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    // MARK: - Auto save

    /// Automatically save state to the timeline, if conditions are met.
    ///
    /// Guards:
    /// - At least `autoSaveInterval` seconds since the last auto save.
    /// - The serialized state differs from the most recent auto entry.
    /// - The state is non-empty (empty source diagrams are not saved).
    ///
    /// - Parameter state: Current editor state to snapshot.
    public func autoSaveIfNeeded(state: LiveEditorState) {
        // Don't save empty states
        guard !state.source.isEmpty else { return }

        let now = Date()

        // Debounce: only save at most once per minute
        if let lastAutoSaveTime, now.timeIntervalSince(lastAutoSaveTime) < autoSaveInterval {
            return
        }

        // Dedup: don't save if state is identical to the last auto entry
        let stateKey = Self.serializedKey(for: state)
        if lastAutoSaveStateKey == stateKey {
            return
        }

        // Create entry
        let entry = LiveHistoryEntry(
            timestamp: now,
            origin: .auto,
            state: state
        )
        entries.insert(entry, at: 0)

        // Update tracking
        lastAutoSaveTime = now
        lastAutoSaveStateKey = stateKey

        // Evict oldest auto entries if over cap
        evictOldAutoEntries()

        persist()
    }

    // MARK: - Restore

    /// Return the state stored in a history entry for restoration.
    ///
    /// - Parameter entry: The history entry to restore from.
    /// - Returns: The editor state snapshot.
    public func restore(_ entry: LiveHistoryEntry) -> LiveEditorState {
        entry.state
    }

    // MARK: - Loader entry

    /// Save a loader entry (Gist or raw URL result).
    ///
    /// Loader entries bypass auto dedup and are always saved.
    ///
    /// - Parameters:
    ///   - state: The editor state after applying the loaded content.
    ///   - label: Display label for the entry.
    ///   - sourceURL: The URL that was loaded.
    /// - Returns: The newly created entry.
    @discardableResult
    public func saveLoaderEntry(
        state: LiveEditorState,
        label: String,
        sourceURL: URL
    ) -> LiveHistoryEntry {
        let entry = LiveHistoryEntry(
            label: label,
            origin: .loader,
            state: state,
            sourceURL: sourceURL
        )
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    // MARK: - Delete

    /// Delete a specific history entry.
    ///
    /// - Parameter entry: The entry to remove. Auto/loader entries
    ///   can be deleted but the UI may choose to hide the button.
    public func delete(_ entry: LiveHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    /// Remove all history entries.
    public func clearAll() {
        entries.removeAll()
        lastAutoSaveTime = nil
        lastAutoSaveStateKey = nil
        persist()
    }

    // MARK: - Export

    /// Export all history entries as JSON data.
    ///
    /// - Throws: Encoding errors.
    /// - Returns: UTF-8 JSON data of the entries array.
    public func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    // MARK: - Import

    /// Import history entries from JSON data, merging with existing entries.
    ///
    /// - Parameter data: JSON data produced by `exportData()`.
    /// - Throws: Decoding errors.
    /// - Returns: The number of new entries imported (excluding duplicates).
    @discardableResult
    public func importData(_ data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([LiveHistoryEntry].self, from: data)

        let existingIDs = Set(entries.map(\.id))
        let newEntries = imported.filter { !existingIDs.contains($0.id) }

        if !newEntries.isEmpty {
            entries = (entries + newEntries)
                .sorted { $0.timestamp > $1.timestamp }
            persist()
        }

        return newEntries.count
    }

    // MARK: - Persistence

    /// Load entries from the JSON file on disk.
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([LiveHistoryEntry].self, from: data)
                .sorted { $0.timestamp > $1.timestamp }
        } catch {
            reportIssue(error, "Failed to load history from \(storageURL.path)")
        }
    }

    /// Write entries to disk asynchronously.
    private func persist() {
        let snapshot = entries
        let url = storageURL

        writeQueue.async { [weak self] in
            guard self != nil else { return }

            // Ensure directory exists
            let directory = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                DispatchQueue.main.async {
                    reportIssue(error, "Failed to persist history to \(url.path)")
                }
            }
        }
    }

    /// Remove oldest auto entries until the count is within `maxAutoEntries`.
    private func evictOldAutoEntries() {
        let autoIndices = entries.indices.filter { entries[$0].origin == .auto }
        let excess = autoIndices.count - maxAutoEntries
        guard excess > 0 else { return }

        // Remove the oldest entries (highest indices, since array is newest-first)
        let toRemove = autoIndices.suffix(excess)
        for index in toRemove.sorted(by: >) {
            entries.remove(at: index)
        }
    }

    // MARK: - Helpers

    /// Compute a stable serialized key for dedup comparison.
    private static func serializedKey(for state: LiveEditorState) -> String {
        LiveEditorStateCodec.encode(state)
    }

    /// Default storage location in Application Support.
    private static func defaultStorageURL() -> URL {
        appSupportURL()
            .appendingPathComponent("DiagramPlayground", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
            .appendingPathComponent("history.json", isDirectory: false)
    }

    /// Pre-rename storage location, used only for one-shot data migration.
    private static func legacyStorageURL() -> URL {
        appSupportURL()
            .appendingPathComponent("MermaidPlayground", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
            .appendingPathComponent("history.json", isDirectory: false)
    }

    private static func appSupportURL() -> URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
    }

    /// If a legacy MermaidPlayground/History/history.json exists and the new
    /// location does not, copy it over so existing users keep their snapshots
    /// after the directory rename.
    private static func migrateLegacyStorageIfNeeded(to newURL: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: newURL.path) else { return }
        let legacyURL = legacyStorageURL()
        guard fm.fileExists(atPath: legacyURL.path) else { return }

        let newDir = newURL.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: newDir, withIntermediateDirectories: true)
            try fm.copyItem(at: legacyURL, to: newURL)
        } catch {
            reportIssue(error, "Failed to migrate legacy history from \(legacyURL.path)")
        }
    }
}
