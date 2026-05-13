//
//  LoaderResult.swift
//  DiagramPlayground
//
//  Result type shared by GistLoader and RawFileLoader.
//  Carries the loaded source/config, origin URL, display label,
//  and optional revision history (Gist only).
//

import Foundation

// MARK: - LoaderResult

/// The result of loading diagram source from an external URL.
public struct LoaderResult: Sendable {

    /// Diagram source text.
    public let source: String

    /// Config JSON string (nil if no config was found).
    public let configJSON: String?

    /// Display label for the loaded content (e.g. "Gist by ajmcclary vabc1234").
    public let label: String

    /// The URL that was loaded (for display and history metadata).
    public let sourceURL: URL

    /// Source format sniffed from the origin (file extension or path).
    /// `nil` when the loader could not determine the format and the caller
    /// should leave its current format hint alone.
    public let sourceFormat: SourceFormat?

    /// Revision history from a Gist (nil for raw URL loads).
    /// Each revision represents a prior version of the Gist content.
    public let revisions: [LoaderRevision]?

    public init(
        source: String,
        configJSON: String?,
        label: String,
        sourceURL: URL,
        sourceFormat: SourceFormat? = nil,
        revisions: [LoaderRevision]? = nil
    ) {
        self.source = source
        self.configJSON = configJSON
        self.label = label
        self.sourceURL = sourceURL
        self.sourceFormat = sourceFormat
        self.revisions = revisions
    }
}

// MARK: - LoaderRevision

/// A single revision in a Gist's history.
public struct LoaderRevision: Sendable, Equatable {

    /// Short commit SHA (7 characters).
    public let version: String

    /// When this revision was committed.
    public let committedAt: Date

    /// GitHub username of the author.
    public let author: String

    /// Mermaid source at this revision.
    public let source: String

    /// Config JSON at this revision (nil if none).
    public let configJSON: String?

    /// Direct URL to this revision.
    public let url: URL

    public init(
        version: String,
        committedAt: Date,
        author: String,
        source: String,
        configJSON: String?,
        url: URL
    ) {
        self.version = version
        self.committedAt = committedAt
        self.author = author
        self.source = source
        self.configJSON = configJSON
        self.url = url
    }
}
