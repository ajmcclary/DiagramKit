//
//  DiagnosticsDrawerState.swift
//  DiagramPlayground
//
//  Phase 6 / Task 6.1 — sub-state for the bottom diagnostics drawer.
//  Carries the four facet filters (severity, category, tier, paired)
//  plus the isOpen flag and the Explain-popover target.
//

import Foundation
import DiagramKitCommon

public struct DiagnosticsDrawerState: Codable, Equatable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case isOpen, severity, categoryRaw, tier, paired
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.isOpen = try c.decodeIfPresent(Bool.self, forKey: .isOpen) ?? false
        self.severity = try c.decodeIfPresent(SeverityFilter.self, forKey: .severity) ?? .all
        if let raw = try c.decodeIfPresent(String.self, forKey: .categoryRaw) {
            self.category = DiagnosticCategory(rawValue: raw)
        } else {
            self.category = nil
        }
        self.tier = try c.decodeIfPresent(TierFilter.self, forKey: .tier) ?? .all
        self.paired = try c.decodeIfPresent(PairedFilter.self, forKey: .paired) ?? .all
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(isOpen, forKey: .isOpen)
        try c.encode(severity, forKey: .severity)
        try c.encodeIfPresent(category?.rawValue, forKey: .categoryRaw)
        try c.encode(tier, forKey: .tier)
        try c.encode(paired, forKey: .paired)
    }

    // MARK: - Facets

    public enum SeverityFilter: String, Codable, CaseIterable, Sendable, Hashable {
        case all
        case warning
        case info
        case unsupported

        public var label: String {
            switch self {
            case .all:         return "All"
            case .warning:     return "Warning"
            case .info:        return "Info"
            case .unsupported: return "Unsupported"
            }
        }
    }

    /// Tier in the pipeline that emitted the diagnostic.
    public enum TierFilter: String, Codable, CaseIterable, Sendable, Hashable {
        case all
        case `import`
        case layout
        case config

        public var label: String {
            switch self {
            case .all:    return "All"
            case .import: return "Import"
            case .layout: return "Layout"
            case .config: return "Config"
            }
        }
    }

    /// Whether the row is paired with a known RoundTripLoss (UI cue).
    public enum PairedFilter: String, Codable, CaseIterable, Sendable, Hashable {
        case all
        case paired
        case unpaired

        public var label: String {
            switch self {
            case .all:      return "All"
            case .paired:   return "Paired"
            case .unpaired: return "Unpaired"
            }
        }
    }

    // MARK: - Properties

    public var isOpen: Bool
    public var severity: SeverityFilter
    public var category: DiagnosticCategory?
    public var tier: TierFilter
    public var paired: PairedFilter

    public init(
        isOpen: Bool = false,
        severity: SeverityFilter = .all,
        category: DiagnosticCategory? = nil,
        tier: TierFilter = .all,
        paired: PairedFilter = .all
    ) {
        self.isOpen = isOpen
        self.severity = severity
        self.category = category
        self.tier = tier
        self.paired = paired
    }

    public static let `default` = DiagnosticsDrawerState()
}
