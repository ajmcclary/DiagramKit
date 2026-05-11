//
//  ConfigSanitizer.swift
//  MermaidPlayground
//
//  Audits a config JSON tree for keys that pose security or correctness
//  risks in the native rendering context. Mirrors the mermaid-live-editor
//  `sanitizeConfig` / `getUnsafePaths` logic, adapted for native constraints.
//

import Foundation
import SwiftUI
import DiagramKitModel

// MARK: - ConfigSanitizer

/// Audits a ``JSONValue`` config tree for unsafe or unsupported keys.
///
/// The native app never executes embedded HTML/JS, so the risk profile
/// is narrower than the web editor. Still, some keys indicate user intent
/// that the native renderer cannot fulfill (e.g. `htmlLabels`, `securityLevel`).
///
/// The sanitizer is read-only by default — it produces ``Warning`` values
/// that the UI can display. For imported state (Phase 5 loaders), the
/// ``stripUnsafe(from:)`` method produces a cleaned tree.
public enum ConfigSanitizer {

    // MARK: - Warning

    /// A diagnostic about a potentially unsafe or unsupported config key.
    public struct Warning: Sendable, Equatable, Identifiable {
        /// Severity level.
        public enum Level: Sendable, Equatable {
            /// Definitely will not work as expected with native renderers.
            case unsupported
            /// Potentially indicates an intent the user should review.
            case caution
            /// Informational — no action required.
            case info
        }

        public var id: String { keyPath }

        /// Dotted key path in the config tree (e.g. `"securityLevel"`).
        public let keyPath: String

        /// The value at this path (for display).
        public let value: String

        /// Severity level.
        public let level: Level

        /// Human-readable explanation.
        public let message: String

        public init(keyPath: String, value: String, level: Level, message: String) {
            self.keyPath = keyPath
            self.value = value
            self.level = level
            self.message = message
        }
    }

    // MARK: - Keys that are unsafe/unsupported in native context

    /// Keys whose non-default values should produce warnings.
    private static let auditedKeys: [(keyPath: [String], defaultValues: Set<String>, level: Warning.Level, message: String)] = [
        // securityLevel — loose/antiscript enable script execution (web-only concern)
        (
            keyPath: ["securityLevel"],
            defaultValues: ["strict", "sandbox"],
            level: .unsupported,
            message: "securityLevel 'loose' or 'antiscript' enables script execution in the web editor. The native renderer ignores this setting."
        ),
        // htmlLabels — native renderers don't support HTML labels
        (
            keyPath: ["htmlLabels"],
            defaultValues: [],
            level: .unsupported,
            message: "HTML labels are not supported by the native renderer. Text will be rendered as plain text."
        ),
        // If htmlLabels is explicitly set to false, no warning needed
        // but we handle that by checking below
    ]

    // MARK: - Audit

    /// Audit a config tree and return all warnings.
    ///
    /// - Parameter tree: The parsed JSON config tree.
    /// - Returns: Array of warnings, empty if the config is clean.
    public static func audit(_ tree: JSONValue?) -> [Warning] {
        guard let tree else { return [] }
        var warnings: [Warning] = []

        // Check audited keys
        for entry in auditedKeys {
            if let value = tree[entry.keyPath] {
                let valueString = String(describing: value)
                // Skip if value matches a safe default
                if entry.defaultValues.contains(valueString) { continue }
                // Special case: htmlLabels = false is safe
                if entry.keyPath == ["htmlLabels"], case .bool(false) = value { continue }
                warnings.append(Warning(
                    keyPath: entry.keyPath.joined(separator: "."),
                    value: valueString,
                    level: entry.level,
                    message: entry.message
                ))
            }
        }

        // Check for prototype-pollution patterns (__ prefixed keys)
        if let protoWarnings = checkPrototypePollution(tree) {
            warnings.append(contentsOf: protoWarnings)
        }

        // Check for XSS vectors in string values (<, >, url(data:))
        if let xssWarnings = checkXSSVectors(tree) {
            warnings.append(contentsOf: xssWarnings)
        }

        return warnings
    }

    // MARK: - Strip unsafe keys

    /// Remove web-only unsafe keys from a config tree, returning a cleaned copy.
    ///
    /// Used when importing external state (Phase 5 loaders). DiagramKit now
    /// understands shared Mermaid settings such as `htmlLabels` and
    /// `securityLevel`, so those values are preserved and only prototype-style
    /// keys are stripped.
    public static func stripUnsafe(from tree: JSONValue) -> JSONValue {
        guard case .object(var dict) = tree else { return tree }

        // Strip __ proto keys recursively
        dict = stripProtoKeys(from: dict)

        return .object(dict)
    }

    // MARK: - Private checks

    private static func checkPrototypePollution(_ tree: JSONValue) -> [Warning]? {
        let flat = tree.flattened()
        let protoPaths = flat.filter { path, _ in
            path.last?.hasPrefix("__") == true
        }

        guard !protoPaths.isEmpty else { return nil }

        return protoPaths.map { path, value in
            Warning(
                keyPath: path.joined(separator: "."),
                value: String(describing: value),
                level: .info,
                message: "Double-underscore ('__') prefixed keys are a web-specific prototype pollution concern and are ignored in the native app."
            )
        }
    }

    private static func checkXSSVectors(_ tree: JSONValue) -> [Warning]? {
        let flat = tree.flattened()
        let xssPaths = flat.filter { _, value in
            if case .string(let str) = value {
                return str.contains("<") || str.contains(">") || str.contains("url(data:")
            }
            return false
        }

        guard !xssPaths.isEmpty else { return nil }

        return xssPaths.map { path, value in
            Warning(
                keyPath: path.joined(separator: "."),
                value: String(describing: value),
                level: .caution,
                message: "This value contains angle brackets or 'url(data:' patterns. These are XSS vectors in web contexts; the native renderer will treat them as plain text."
            )
        }
    }

    private static func stripProtoKeys(from dict: [String: JSONValue]) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for (key, value) in dict {
            if key.hasPrefix("__") { continue }
            if case .object(let subDict) = value {
                result[key] = .object(stripProtoKeys(from: subDict))
            } else {
                result[key] = value
            }
        }
        return result
    }
}

// MARK: - Warning level UI helpers

extension ConfigSanitizer.Warning.Level {
    /// SF Symbol name for this warning level.
    public var iconName: String {
        switch self {
        case .unsupported: return "xmark.octagon.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    /// Color for this warning level.
    public var color: Color {
        switch self {
        case .unsupported: return .red
        case .caution: return .orange
        case .info: return .blue
        }
    }
}
