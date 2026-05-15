//
//  Snippet.swift
//  DiagramPlayground
//
//  Phase 9 / Task 9.3 — paste-ready snippet model. One per family
//  is registered in SnippetLibrary.
//

import Foundation
import DiagramKitModel

public struct Snippet: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let family: DiagramType
    public let format: SourceFormat
    public let body: String

    public init(
        id: String,
        title: String,
        family: DiagramType,
        format: SourceFormat = .mermaid,
        body: String
    ) {
        self.id = id
        self.title = title
        self.family = family
        self.format = format
        self.body = body
    }
}
