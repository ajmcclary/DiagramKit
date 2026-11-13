import Foundation

// Writing flattened frontmatter settings back as YAML. The reader is
// `FrontmatterDocumentParser.flatten`; `yamlLines(for:)` produces text that
// it flattens back to exactly the entries it was given (after
// `canonicalized`), so an exporter can round-trip settings it does not model.

extension DiagramFrontmatterEntry {

    /// Paths the document models itself (`DiagramDocument.title`,
    /// `DiagramDocumentFrontmatter.theme` / `.layout`); never preserved.
    public static let modelledPaths: Set<String> = ["title", "config.title", "config.theme", "config.layout"]

    /// Canonical order for a set of entries: one entry per path (the last
    /// value wins, as when the bindings apply them in order), grouped the way
    /// YAML nests them — every `config.…` entry first, then the other roots,
    /// each subtree in the order its first entry appeared. Writing these with
    /// `yamlLines(for:)` and flattening the text gives back the same list.
    public static func canonicalized(_ entries: [DiagramFrontmatterEntry]) -> [DiagramFrontmatterEntry] {
        var tree = _FrontmatterTree()
        for entry in entries { tree.insert(entry) }
        tree.moveRootToFront("config")
        return tree.flattened()
    }

    /// YAML lines (no `---` fences) that `FrontmatterDocumentParser.flatten`
    /// reads back as `canonicalized(entries)`.
    public static func yamlLines(for entries: [DiagramFrontmatterEntry]) -> [String] {
        var tree = _FrontmatterTree()
        for entry in entries { tree.insert(entry) }
        return tree.yamlLines()
    }

    /// `value` as a YAML scalar: plain when that is unambiguous (so numbers
    /// and booleans stay numbers and booleans for other YAML readers),
    /// double-quoted otherwise. `flatten` unquotes either form back to
    /// `value`.
    static func yamlScalar(_ value: String) -> String {
        let flat = value.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        if _isPlainYAMLScalar(flat) { return flat }
        let escaped = flat.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// A key as written before `:`. `flatten` strips one pair of surrounding
    /// quotes from a key and splits the line at its first `:`.
    static func yamlKey(_ key: String) -> String {
        if key.contains(":") || key.hasPrefix("#") || key.hasPrefix("'") || key.hasPrefix("\"")
            || key != key.trimmingCharacters(in: .whitespaces) {
            return "\"\(key.replacingOccurrences(of: "\"", with: "'"))\""
        }
        return key
    }

    private static func _isPlainYAMLScalar(_ value: String) -> Bool {
        guard let first = value.first, value == value.trimmingCharacters(in: .whitespaces) else { return false }
        let indicators: Set<Character> = ["\"", "'", "#", "&", "*", "!", "|", ">", "%", "@", "{", "}", "[", "]", ",", "?", ":", "`"]
        if indicators.contains(first) { return false }
        if first == "-", !(value.dropFirst().first?.isNumber ?? false) { return false }
        if value.contains(": ") || value.contains(" #") || value.contains("\t") || value.hasSuffix(":") { return false }
        return true
    }
}

/// An insertion-ordered tree of frontmatter keys.
private struct _FrontmatterTree {
    final class Node {
        var value: String?
        var childOrder: [String] = []
        var children: [String: Node] = [:]

        func child(_ key: String) -> Node {
            if let existing = children[key] { return existing }
            let node = Node()
            children[key] = node
            childOrder.append(key)
            return node
        }
    }

    let root = Node()

    func insert(_ entry: DiagramFrontmatterEntry) {
        let keys = entry.path.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        var node = root
        for key in keys { node = node.child(key) }
        node.value = entry.value
    }

    func moveRootToFront(_ key: String) {
        guard let index = root.childOrder.firstIndex(of: key), index > 0 else { return }
        root.childOrder.remove(at: index)
        root.childOrder.insert(key, at: 0)
    }

    func flattened() -> [DiagramFrontmatterEntry] {
        var out: [DiagramFrontmatterEntry] = []
        func walk(_ node: Node, _ path: [String]) {
            for key in node.childOrder {
                guard let child = node.children[key] else { continue }
                let childPath = path + [key]
                if let value = child.value {
                    out.append(DiagramFrontmatterEntry(path: childPath.joined(separator: "."), value: value))
                }
                walk(child, childPath)
            }
        }
        walk(root, [])
        return out
    }

    func yamlLines() -> [String] {
        var out: [String] = []
        func walk(_ node: Node, _ depth: Int) {
            let pad = String(repeating: "  ", count: depth)
            for key in node.childOrder {
                guard let child = node.children[key] else { continue }
                let name = DiagramFrontmatterEntry.yamlKey(key)
                if let value = child.value {
                    out.append("\(pad)\(name): \(DiagramFrontmatterEntry.yamlScalar(value))")
                }
                if !child.childOrder.isEmpty {
                    out.append("\(pad)\(name):")
                    walk(child, depth + 1)
                }
            }
        }
        walk(root, 0)
        return out
    }
}
