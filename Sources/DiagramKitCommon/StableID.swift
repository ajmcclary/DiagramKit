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

// MARK: - Unique ids for exported tree nodes

/// Ids for every node of a tree (or forest) being written to a format that
/// names nodes, keyed by the node's child-index path from its root
/// (`[0]`, `[0, 2]`, …). Each node gets `base(node)`; a repeat gets `_2`,
/// `_3`, … appended, in pre-order. Exporters used the display name as the id,
/// so two entries named `index.ts` became one node with two parents, and a
/// directory holding a same-named entry became a self-loop.
public func _uniqueTreeIDs<Node>(
    roots: [Node],
    children: (Node) -> [Node],
    base: (Node) -> String
) -> [[Int]: String] {
    var used: Set<String> = []
    var ids: [[Int]: String] = [:]
    func visit(_ node: Node, _ path: [Int]) {
        let stem = base(node)
        var candidate = stem
        var counter = 2
        while used.contains(candidate) {
            candidate = "\(stem)_\(counter)"
            counter += 1
        }
        used.insert(candidate)
        ids[path] = candidate
        for (i, child) in children(node).enumerated() { visit(child, path + [i]) }
    }
    for (i, root) in roots.enumerated() { visit(root, [i]) }
    return ids
}
