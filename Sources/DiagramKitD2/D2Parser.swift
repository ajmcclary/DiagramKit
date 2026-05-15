import Foundation
import DiagramKitModel
import DiagramKitImport

/// Line-oriented recursive-descent parser for d2 source.
/// Consumes raw source text, returns `(D2Document, [DiagramDiagnostic])`.
public struct D2Parser {

    public init() {}

    public func parse(_ source: String) throws -> (document: D2Document, diagnostics: [DiagramDiagnostic]) {
        let (preprocessed, preDiagnostics) = preprocess(source)
        let lines = preprocessed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var (document, diagnostics) = try parseLines(lines)
        diagnostics.insert(contentsOf: preDiagnostics, at: 0)
        return (document, diagnostics)
    }

    // MARK: - Preprocessing

    private func _stripInlineComment(_ line: String, marker: String) -> (stripped: String, wasStripped: Bool) {
        guard let r = line.range(of: marker) else { return (line, false) }
        let idx = line.distance(from: line.startIndex, to: r.lowerBound)
        if idx == 0 || line[line.index(before: r.lowerBound)] == " " {
            return (String(line[..<r.lowerBound]), true)
        }
        return (line, false)
    }

    private func preprocess(_ source: String) -> (cleaned: String, diagnostics: [DiagramDiagnostic]) {
        var result = ""
        var diagnostics: [DiagramDiagnostic] = []
        var inBlockComment = false
        var lineNo = 0
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            lineNo += 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inBlockComment {
                if trimmed.contains("\"\"\"") {
                    inBlockComment = false
                }
                continue
            }
            if trimmed.hasPrefix("\"\"\"") {
                if trimmed.dropFirst(3).contains("\"\"\"") {
                    // Single-line block comment
                    continue
                }
                inBlockComment = true
                continue
            }
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("//") {
                continue
            }
            // Strip inline comments. Both `#` and `//` are valid D2
            // inline-comment markers. Only strip when the marker is at
            // line-start or preceded by whitespace, so identifiers
            // containing `#`/`//` aren't truncated.
            var cleanLine = String(line)
            let hashResult = _stripInlineComment(cleanLine, marker: "#")
            cleanLine = hashResult.stripped
            let slashResult = _stripInlineComment(cleanLine, marker: "//")
            cleanLine = slashResult.stripped
            if hashResult.wasStripped || slashResult.wasStripped {
                diagnostics.append(.lossyTransform(
                    .d2InlineCommentStripped,
                    message: "D2 inline comment stripped from line \(lineNo); the comment value is not preserved in the parsed document.",
                    location: DiagramDiagnostic.SourceLocation(line: lineNo)
                ))
            }
            if !result.isEmpty { result.append("\n") }
            result.append(cleanLine)
        }
        return (result, diagnostics)
    }

    // MARK: - Parse

    private func parseLines(_ lines: [String]) throws -> (document: D2Document, diagnostics: [DiagramDiagnostic]) {
        var statements: [D2Statement] = []
        var diagnostics: [DiagramDiagnostic] = []
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                i += 1
                continue
            }

            // Container close
            if line == "}" {
                statements.append(.containerClose)
                i += 1
                continue
            }

            // Check for edge syntax: contains ->, <->, or --
            if let (edge, consumed) = try parseEdge(line, lineNumber: i + 1) {
                statements.append(.edgeDefinition(edge))
                i += consumed
                continue
            }

            // Check for container open: `id {` or `id: label {`
            if line.hasSuffix("{") {
                let open = try parseContainerOpen(line, lineNumber: i + 1)
                statements.append(.containerOpen(open))
                i += 1
                continue
            }

            // Check for node definition: `id: value` or `id.shape: value`
            if let statement = try parseNodeOrProperty(line, lineNumber: i + 1, diagnostics: &diagnostics) {
                statements.append(statement)
                // Property-only statements (like style.*, vars.*) already emitted as diagnostics
            }

            i += 1
        }

        // Validate balanced braces
        var depth = 0
        for stmt in statements {
            switch stmt {
            case .containerOpen: depth += 1
            case .containerClose: depth -= 1
            default: break
            }
            if depth < 0 {
                throw DiagramError.malformedSource(message: "Unbalanced braces in d2 source")
            }
        }
        if depth != 0 {
            throw DiagramError.malformedSource(message: "Unterminated block in d2 source")
        }

        return (D2Document(statements: statements), diagnostics)
    }

    // MARK: - Edge parsing

    private func parseEdge(_ line: String, lineNumber: Int) throws -> (D2EdgeDefinition, lines: Int)? {
        // Split by edge operators
        let operators = ["<->", "->", "--"]
        for op in operators {
            if let range = line.range(of: op) {
                let beforeOp = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let afterOp = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)

                // Parse source and target
                // Source might have `<` prefix
                var source = beforeOp
                var sourceArrow = false
                if source.hasPrefix("<") {
                    sourceArrow = true
                    source = String(source.dropFirst()).trimmingCharacters(in: .whitespaces)
                }

                // Target might have `>` suffix or `>` prefix for bidirectional annotations
                var target = afterOp
                var targetArrow = true // default for ->
                var label: String? = nil

                // Check for label after colon
                if let colonIndex = target.firstIndex(of: ":") {
                    label = String(target[target.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    // Unquote label
                    label = unquote(label!)
                    target = String(target[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                }

                // Handle `>` on target
                if target.hasSuffix(">") {
                    target = String(target.dropLast()).trimmingCharacters(in: .whitespaces)
                } else if target.hasPrefix(">") {
                    target = String(target.dropFirst()).trimmingCharacters(in: .whitespaces)
                }

                // Handle arrow configuration for <-> (bidirectional) and -- (undirected)
                let edgeKind: D2EdgeKind
                switch op {
                case "->": edgeKind = .directional
                case "<->":
                    edgeKind = .bidirectional
                    sourceArrow = true
                    targetArrow = true
                case "--":
                    edgeKind = .undirected
                    targetArrow = false
                default: edgeKind = .directional
                }

                return (D2EdgeDefinition(
                    source: source,
                    target: target,
                    label: label,
                    sourceArrow: sourceArrow,
                    targetArrow: targetArrow,
                    edgeKind: edgeKind
                ), lines: 1)
            }
        }
        return nil
    }

    // MARK: - Container open parsing

    private func parseContainerOpen(_ line: String, lineNumber: Int) throws -> D2ContainerOpen {
        // Strip trailing `{` and whitespace
        var body = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        if body.hasSuffix("{") {
            body = String(body.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        // Check for `id: label` format
        if let colonIndex = body.firstIndex(of: ":") {
            let id = String(body[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            var label = String(body[body.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            label = unquote(label)
            return D2ContainerOpen(id: id, label: label)
        }

        return D2ContainerOpen(id: body, label: nil)
    }

    // MARK: - Node/property parsing

    private func parseNodeOrProperty(_ line: String, lineNumber: Int, diagnostics: inout [DiagramDiagnostic]) throws -> D2Statement? {
        // Support both ':' and '=' as key-value separators
        let separatorIndex: String.Index?
        if let colonIdx = line.firstIndex(of: ":") {
            separatorIndex = colonIdx
        } else if let equalsIdx = line.firstIndex(of: "=") {
            separatorIndex = equalsIdx
        } else {
            separatorIndex = nil
        }

        guard let sepIdx = separatorIndex else {
            throw DiagramError.malformedSource(message: "D2 parser: unparseable line \(lineNumber): \(line)")
        }

        let key = String(line[..<sepIdx]).trimmingCharacters(in: .whitespaces)
        var value = String(line[line.index(after: sepIdx)...]).trimmingCharacters(in: .whitespaces)
        value = unquote(value)

        // Check for unsupported keywords
        if let diag = unsupportedDiagnostic(key: key, value: value, lineNumber: lineNumber) {
            diagnostics.append(diag)
            return nil
        }

        // Handle top-level `direction: <dir>` directive
        if key.lowercased() == "direction" {
            return .direction(value)
        }

        // Check if this is a property on the current node context
        // In this simple parser, we treat key.subkey as a property of key
        if key.contains(".") {
            let parts = key.split(separator: ".")
            let baseId = String(parts[0])
            let property = parts.dropFirst().joined(separator: ".")

            // For now, we store properties in the node definition if it's a single-level dot notation
            if parts.count == 2 {
                switch property {
                case "shape":
                    return .nodeDefinition(D2NodeDefinition(id: baseId, shape: value))
                case "direction":
                    return .nodeDefinition(D2NodeDefinition(id: baseId, direction: value))
                case "tooltip":
                    return .nodeDefinition(D2NodeDefinition(id: baseId, tooltip: value))
                case "link":
                    return .nodeDefinition(D2NodeDefinition(id: baseId, link: value))
                case "icon":
                    return .nodeDefinition(D2NodeDefinition(id: baseId, icon: value))
                case "width":
                    if let w = Double(value) {
                        return .nodeDefinition(D2NodeDefinition(id: baseId, width: w))
                    }
                case "height":
                    if let h = Double(value) {
                        return .nodeDefinition(D2NodeDefinition(id: baseId, height: h))
                    }
                default:
                    // Unknown property — store as label if value is non-empty
                    return .nodeDefinition(D2NodeDefinition(id: baseId, label: value))
                }
            }

            // Multi-level dot chain: treat as node definition with the full key as id
            return .nodeDefinition(D2NodeDefinition(id: key, label: value))
        }

        // Simple key: value — node definition
        return .nodeDefinition(D2NodeDefinition(id: key, label: value))
    }

    // MARK: - Unsupported diagnostics

    private func unsupportedDiagnostic(key: String, value: String, lineNumber: Int) -> DiagramDiagnostic? {
        let lowerKey = key.lowercased()

        if lowerKey.hasPrefix("style") {
            return .featureDropped(
                .slotUnsupported,
                message: "style blocks not yet supported for d2 import",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if lowerKey.hasPrefix("vars") {
            return .featureDropped(
                .slotUnsupported,
                message: "variable blocks not yet supported",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if lowerKey.hasPrefix("layers") || lowerKey.hasPrefix("scenarios") || lowerKey.hasPrefix("steps") {
            return .featureDropped(
                .slotUnsupported,
                message: "board layers not yet supported; map to subgraphs instead",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if lowerKey.hasPrefix("classes") {
            return .featureDropped(
                .slotUnsupported,
                message: "class definitions not yet supported",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if lowerKey.hasPrefix("constraint") {
            return .featureDropped(
                .slotUnsupported,
                message: "layout constraints not yet supported",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if lowerKey.hasPrefix("grid-rows") || lowerKey.hasPrefix("grid-columns") {
            return .featureDropped(
                .slotUnsupported,
                message: "grid layout not yet supported",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if lowerKey == "near" {
            return .featureDropped(
                .slotUnsupported,
                message: "near placement not yet supported",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if value.contains("$") || lowerKey.contains("$") {
            return .featureDropped(
                .slotUnsupported,
                message: "variable substitution not yet supported",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if lowerKey.contains("@import") || value.contains("@import") {
            return .featureDropped(
                .slotUnsupported,
                message: "imports not yet supported",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if lowerKey.contains("*") || value.contains("*") {
            return .featureDropped(
                .slotUnsupported,
                message: "glob patterns not yet supported",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        if lowerKey.contains("&") || value.contains("&") {
            return .featureDropped(
                .slotUnsupported,
                message: "filter selectors not yet supported",
                location: DiagramDiagnostic.SourceLocation(line: lineNumber)
            )
        }

        return nil
    }

    // MARK: - Helpers

    private func unquote(_ s: String) -> String {
        var result = s.trimmingCharacters(in: .whitespaces)
        var wasQuoted = false
        if result.hasPrefix("\"") && result.hasSuffix("\"") {
            result = String(result.dropFirst().dropLast())
            wasQuoted = true
        } else if result.hasPrefix("'") && result.hasSuffix("'") {
            result = String(result.dropFirst().dropLast())
            wasQuoted = true
        }
        return wasQuoted ? unescapeD2String(result) : result
    }

    private func unescapeD2String(_ s: String) -> String {
        var result = ""
        var index = s.startIndex

        while index < s.endIndex {
            let ch = s[index]
            if ch == "\\" {
                let nextIndex = s.index(after: index)
                guard nextIndex < s.endIndex else {
                    result.append(ch)
                    break
                }

                switch s[nextIndex] {
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default: result.append(s[nextIndex])
                }
                index = s.index(after: nextIndex)
            } else {
                result.append(ch)
                index = s.index(after: index)
            }
        }

        return result
    }
}
