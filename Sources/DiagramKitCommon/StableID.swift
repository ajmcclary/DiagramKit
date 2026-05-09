// Deterministic ID derivation for snapshot-stable SVG output.
//
// Several SVG renderers (gantt, gitgraph, treemap, wardley, block) embed an
// `id` attribute in their root <svg> element to disambiguate IDs when multiple
// diagrams render on the same page. Historically this was `UUID().uuidString`,
// which produced a fresh ID on every call and made snapshot baselines drift.
//
// `StableID.derive(from:)` produces the same UUID-format string for the same
// source seed across runs and processes. This keeps SVG snapshots stable while
// still preventing ID collisions between different diagrams (different sources
// hash to different IDs).

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public enum StableID {
    /// Returns a UUID-format string deterministically derived from `seed`.
    /// Same seed → same string, every call, every process.
    public static func derive(from seed: String) -> String {
        let digest = SHA256.hash(data: Data(seed.utf8))
        let bytes = Array(digest).prefix(16)
        // Format as 8-4-4-4-12 uppercase UUID.
        let hex = bytes.map { String(format: "%02X", $0) }.joined()
        let parts = [
            hex.prefix(8),
            hex.dropFirst(8).prefix(4),
            hex.dropFirst(12).prefix(4),
            hex.dropFirst(16).prefix(4),
            hex.dropFirst(20).prefix(12),
        ]
        return parts.map(String.init).joined(separator: "-")
    }
}
