//
//  ExportOptions.swift
//  MermaidPlayground
//
//  Configures PNG export parameters (sizing and scale).
//  Stored on LiveEditorStore and modifiable by the export UI.
//

import Foundation

// MARK: - ExportOptions

/// Parameters for PNG image export.
///
/// The store holds a default instance; the UI can mutate it before
/// calling `store.exportPNG(options:)`.
public struct ExportOptions: Equatable, Sendable {

    // MARK: - Sizing

    /// How the exported image should be sized.
    public enum Sizing: Equatable, Sendable {
        /// Render at the diagram's natural bounds, scaled by ``scale``.
        case auto
        /// Render at exact pixel dimensions.
        case fixed(CGSize)
    }

    // MARK: - Properties

    /// Sizing strategy (default: `.auto`).
    public var sizing: Sizing = .auto

    /// Scale factor for `.auto` sizing (default: 2.0 for Retina).
    /// Ignored when `sizing` is `.fixed`.
    public var scale: CGFloat = 2.0

    // MARK: - Init

    public init(sizing: Sizing = .auto, scale: CGFloat = 2.0) {
        self.sizing = sizing
        self.scale = scale
    }
}

// MARK: - Sizing Hashable (for Picker .tag)

extension ExportOptions.Sizing: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .auto:
            hasher.combine(0)
        case .fixed(let size):
            hasher.combine(1)
            hasher.combine(size.width)
            hasher.combine(size.height)
        }
    }
}
