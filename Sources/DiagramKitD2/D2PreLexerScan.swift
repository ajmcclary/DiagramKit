import Foundation
import DiagramKitCommon

public struct D2PreLexerScanResult: Sendable, Equatable {
    public struct ContainerDeclaration: Sendable, Equatable, HasLineNumber {
        public let id: String
        public let lineNumber: Int
    }

    public struct EdgeDeclaration: Sendable, Equatable, HasLineNumber {
        public let source: String
        public let target: String
        public let lineNumber: Int
    }

    public let classDeclarations: [ContainerDeclaration]
    public let stateDeclarations: [ContainerDeclaration]
    public let edgeDeclarations: [EdgeDeclaration]
}

/// Walks `source` once and indexes class containers (lines like `Order: {`
/// followed by a `shape: class` line within 3 lines), state containers
/// (lines like `Active: {` without `shape: class`), and edges (lines like
/// `User -> Order` or `User -> Order: places`).
public func scanD2PreLexer(_ source: String) -> D2PreLexerScanResult {
    var classDecls: [D2PreLexerScanResult.ContainerDeclaration] = []
    var stateDecls: [D2PreLexerScanResult.ContainerDeclaration] = []
    var edges: [D2PreLexerScanResult.EdgeDeclaration] = []

    let lines = source.components(separatedBy: "\n")
    var lineNumber = 0
    while lineNumber < lines.count {
        let rawLine = lines[lineNumber]
        let currentLine1Based = lineNumber + 1
        defer { lineNumber += 1 }
        var trimmed = rawLine
        while let first = trimmed.first, first == " " || first == "\t" {
            trimmed.removeFirst()
        }
        if trimmed.hasPrefix("#") { continue }

        // Container open: "ID: {"
        if let colonIdx = trimmed.firstIndex(of: ":") {
            let after = trimmed[trimmed.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)
            if after.hasPrefix("{") {
                let id = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                if !id.isEmpty {
                    var isClass = false
                    for lookahead in 1...3 where lineNumber + lookahead < lines.count {
                        let next = lines[lineNumber + lookahead].trimmingCharacters(in: .whitespaces)
                        if next.hasPrefix("shape: class") {
                            isClass = true
                            break
                        }
                        if next.hasPrefix("}") { break }
                    }
                    let decl = D2PreLexerScanResult.ContainerDeclaration(id: id, lineNumber: currentLine1Based)
                    if isClass {
                        classDecls.append(decl)
                    } else {
                        stateDecls.append(decl)
                    }
                    continue
                }
            }
        }

        // Edge: "A -> B" or "A -> B: label"
        if let arrowRange = trimmed.range(of: "->") {
            let sourcePart = String(trimmed[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var rest = String(trimmed[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let labelColon = rest.firstIndex(of: ":") {
                rest = String(rest[..<labelColon])
            }
            let targetPart = rest.trimmingCharacters(in: .whitespaces)
            guard !sourcePart.isEmpty, !targetPart.isEmpty else { continue }
            edges.append(.init(source: sourcePart, target: targetPart, lineNumber: currentLine1Based))
        }
    }

    return D2PreLexerScanResult(
        classDeclarations: classDecls,
        stateDeclarations: stateDecls,
        edgeDeclarations: edges
    )
}
