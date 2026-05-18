//
//  ConvertSheetState.swift
//  DiagramPlayground
//
//  Phase 7 / Task 7.2 — sub-state for the v2 Convert sheet (Mermaid
//  → target diff with RoundTripLoss callouts).
//

import Foundation

public struct ConvertSheetState: Codable, Equatable, Sendable {
    public var isOpen: Bool
    public var target: SourceFormat

    public init(
        isOpen: Bool = false,
        target: SourceFormat = .d2
    ) {
        self.isOpen = isOpen
        self.target = target
    }

    public static let `default` = ConvertSheetState()
}
