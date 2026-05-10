//
//  LiveHistoryEntry.swift
//  MermaidPlayground
//
//  Serializable snapshot of editor state at a point in time.
//  Each entry carries a full LiveEditorState plus metadata
//  (origin, label, source URL). Used by LiveHistoryStore for
//  manual saves, auto timeline, and loader revisions.
//

import Foundation

// MARK: - LiveHistoryOrigin

/// Where a history entry came from.
public enum LiveHistoryOrigin: String, Codable, Sendable, CaseIterable {
    /// User explicitly saved a named snapshot.
    case manual
    /// Automatically saved by the editor timeline.
    case auto
    /// Created when loading from a Gist or raw URL.
    case loader
}

// MARK: - LiveHistoryEntry

/// A single history snapshot with full editor state and metadata.
///
/// Entries are identified by UUID. The `label` is nil for auto entries
/// (displayed with a relative timestamp instead). `sourceURL` is non-nil
/// for loader entries, preserving the origin URL for display.
public struct LiveHistoryEntry: Codable, Sendable, Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for this entry.
    public let id: UUID

    /// When this snapshot was created.
    public let timestamp: Date

    /// Human-readable label (nil for auto entries, named for manual saves,
    /// author+version for loader entries).
    public let label: String?

    /// Where this entry originated.
    public let origin: LiveHistoryOrigin

    /// Full serializable editor state at snapshot time.
    public let state: LiveEditorState

    /// Source URL for loader entries (Gist URL or raw code URL).
    public let sourceURL: URL?

    // MARK: - Computed

    /// Auto and loader entries cannot be deleted or renamed by the user.
    public var isReadOnly: Bool {
        origin == .auto || origin == .loader
    }

    /// Short display label: explicit label, or "Auto — {relative time}", or "Loader — {label}".
    public var displayLabel: String {
        if let label, !label.isEmpty {
            return label
        }
        switch origin {
        case .auto:
            return "Auto — \(timestamp.relativeDisplay)"
        case .loader:
            return "Loaded — \(timestamp.relativeDisplay)"
        case .manual:
            return "Saved — \(timestamp.relativeDisplay)"
        }
    }

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        label: String? = nil,
        origin: LiveHistoryOrigin,
        state: LiveEditorState,
        sourceURL: URL? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.label = label
        self.origin = origin
        self.state = state
        self.sourceURL = sourceURL
    }

    // MARK: - Equatable

    /// Two entries are equal if they share the same id.
    public static func == (lhs: LiveHistoryEntry, rhs: LiveHistoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Date helpers

extension Date {
    /// Human-readable relative time string (e.g. "2 min ago", "yesterday", "Mar 15").
    fileprivate var relativeDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
