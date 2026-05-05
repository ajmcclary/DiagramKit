//
//  PlaygroundConfiguration.swift
//  MermaidPlayground
//
//  Configuration state for the playground
//

import SwiftUI
import BeautifulMermaid

/// Singleton configuration for the playground
@Observable
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
@MainActor
public class PlaygroundConfiguration {
    public static let shared = PlaygroundConfiguration()

    // MARK: - Default Diagram

    private static let defaultDiagram = """
    graph TD
      A[Start] --> B[Process] --> C[End]
    """

    // MARK: - Diagram Source

    public var source: String = PlaygroundConfiguration.defaultDiagram

    // MARK: - Theme

    public var theme: DiagramTheme = .default

    private init() {}
}
