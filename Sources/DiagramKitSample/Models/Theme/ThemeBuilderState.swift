//
//  ThemeBuilderState.swift
//  DiagramPlayground
//
//  Phase 10 / Task 10.1 — sub-state for the ThemeBuilder Inspector
//  card. Stores per-token color overrides as hex strings (so the
//  type stays Codable without dragging in BMColor) and a dirty flag
//  the card uses to surface "unsaved overrides".
//

import Foundation

public struct ThemeBuilderState: Codable, Equatable, Sendable {

    /// Token names the card surfaces. Order matches the design's row
    /// stack; `.success` / `.warning` / `.error` are flagged as
    /// semantic ("sem") in the UI.
    public enum Token: String, Codable, CaseIterable, Sendable, Hashable {
        case bg
        case fg
        case surface
        case border
        case line
        case accent
        case muted
        case noteBkg
        case noteBorder
        case success
        case warning
        case error

        public var label: String {
            switch self {
            case .bg:         return "Background"
            case .fg:         return "Foreground"
            case .surface:    return "Surface"
            case .border:     return "Border"
            case .line:       return "Line"
            case .accent:     return "Accent"
            case .muted:      return "Muted"
            case .noteBkg:    return "Note bg"
            case .noteBorder: return "Note border"
            case .success:    return "Success"
            case .warning:    return "Warning"
            case .error:      return "Error"
            }
        }

        public var isSemantic: Bool {
            switch self {
            case .success, .warning, .error: return true
            default:                         return false
            }
        }
    }

    /// Token → 6-char hex color (without `#`). Empty when no overrides
    /// are pending.
    public var overrides: [String: String]

    public var dirty: Bool { !overrides.isEmpty }

    public init(overrides: [String: String] = [:]) {
        self.overrides = overrides
    }

    public static let `default` = ThemeBuilderState()

    public mutating func setOverride(_ token: Token, hex: String?) {
        if let hex, !hex.isEmpty {
            overrides[token.rawValue] = hex
        } else {
            overrides.removeValue(forKey: token.rawValue)
        }
    }

    public func override(for token: Token) -> String? {
        overrides[token.rawValue]
    }

    public mutating func reset() {
        overrides.removeAll()
    }
}
