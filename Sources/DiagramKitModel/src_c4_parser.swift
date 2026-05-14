import Foundation
import DiagramKitCommon

// MARK: - C4 Parser (Line-oriented macro parser)

/// Parse a C4 diagram from source lines.
/// - Parameters:
///   - lines: Raw lines of the diagram source (after frontmatter stripping)
///   - frontmatter: Optional frontmatter with C4 config overrides
/// - Returns: A parsed `C4Diagram`
public func parseC4Diagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> C4Diagram {
    let (diagram, _) = try _parseC4DiagramWithDiagnostics(lines, frontmatter: frontmatter)
    return diagram
}

/// SPI variant of `parseC4Diagram` that also returns the diagnostics produced
/// during the parse pass. Used by registry call sites that route diagnostics
/// upward, and by tests that assert on the warning surface.
public func _parseC4DiagramWithDiagnostics(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> (C4Diagram, [DiagramDiagnostic]) {
    var diagram = C4Diagram()
    if let fm = frontmatter {
        if let cfg = fm.c4Config { diagram.config = cfg }
        if diagram.title == nil, let fmTitle = fm.diagramTitle { diagram.title = fmTitle }
    }

    var diagnostics: [DiagramDiagnostic] = []
    var shapes: [C4Shape] = []
    var boundaries: [C4Boundary] = [
        C4Boundary(alias: "global", label: "global", type: "global", parentBoundary: "")
    ]
    var relationships: [C4Relationship] = []

    var currentBoundaryParse = "global"
    var boundaryParseStack: [String] = [""]
    var parentBoundaryParse = ""

    let wrapEnabled = diagram.config.wrap
    var c4ShapeInRow = diagram.config.c4ShapeInRow
    var c4BoundaryInRow = diagram.config.c4BoundaryInRow

    var inAccDescrBlock = false
    var accDescrLines: [String] = []

    // Find header line
    var i = 0
    var foundHeader = false
    while i < lines.count {
        let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("%%") {
            i += 1
            continue
        }
        // Check for C4 header
        if trimmed == "C4Context" { diagram.kind = .context; foundHeader = true; break }
        if trimmed == "C4Container" { diagram.kind = .container; foundHeader = true; break }
        if trimmed == "C4Component" { diagram.kind = .component; foundHeader = true; break }
        if trimmed == "C4Dynamic" { diagram.kind = .dynamic; foundHeader = true; break }
        if trimmed == "C4Deployment" { diagram.kind = .deployment; foundHeader = true; break }
        break
    }
    if !foundHeader && i < lines.count {
        // Skip first non-empty, non-comment line if it doesn't match a known header
        // (try to continue anyway — maybe the header is on the next line)
    }
    i += 1

    // Process body lines
    while i < lines.count {
        let rawLine = lines[i]
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle multiline accDescr
        if inAccDescrBlock {
            if trimmed == "}" {
                diagram.accDescr = accDescrLines.joined(separator: "\n")
                inAccDescrBlock = false
                accDescrLines = []
                i += 1
                continue
            }
            accDescrLines.append(trimmed)
            i += 1
            continue
        }

        // Skip empty lines and comments
        if trimmed.isEmpty { i += 1; continue }
        if trimmed.hasPrefix("%%") { i += 1; continue }

        // Metadata statements
        if let title = _parseC4Title(trimmed) {
            diagram.title = title
            i += 1; continue
        }
        if let accDescr = _parseC4AccDescription(trimmed) {
            diagram.accDescr = accDescr
            i += 1; continue
        }
        if let accDescrSingle = _parseC4AccDescrLine(trimmed) {
            diagram.accDescr = accDescrSingle
            i += 1; continue
        }
        // accTitle: routes to title (Mermaid quirk)
        if let accTitle = _parseC4AccTitle(trimmed) {
            diagram.title = accTitle
            i += 1; continue
        }
        // accDescr { ... } multiline start
        if trimmed == "accDescr {" {
            inAccDescrBlock = true
            i += 1; continue
        }
        // Direction directives (stored but not used in layout)
        if _parseC4Direction(trimmed) != nil {
            i += 1; continue
        }

        // Boundary close
        if trimmed == "}" && boundaryParseStack.count > 1 {
            currentBoundaryParse = parentBoundaryParse
            boundaryParseStack.removeLast()
            parentBoundaryParse = boundaryParseStack.last ?? ""
            i += 1; continue
        }

        // Macro detection
        guard let macroName = _detectMacroName(trimmed) else {
            i += 1; continue
        }

        // Extract arguments between ( and )
        guard let openParen = trimmed.firstIndex(of: "("),
              let closeParen = _findMatchingParen(trimmed, from: openParen) else {
            i += 1; continue
        }

        let argsString = String(trimmed[trimmed.index(after: openParen)..<closeParen])
        let (positional, named) = parseMacroArguments(argsString)

        // Check for { boundary opening
        var hasBrace = false
        var braceLine: String? = nil
        let afterParen = String(trimmed[closeParen...].dropFirst()).trimmingCharacters(in: .whitespaces)
        if afterParen == "{" {
            hasBrace = true
        } else if i + 1 < lines.count && lines[i + 1].trimmingCharacters(in: .whitespacesAndNewlines) == "{" {
            hasBrace = true
            braceLine = "{"
        }

        switch macroName {
        // Person/System family
        case "Person":
            _addPersonOrSystem(type: .person, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", descr: positional.safe(2), sprite: positional.safe(3), tags: positional.safe(4), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "Person_Ext":
            _addPersonOrSystem(type: .external_person, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", descr: positional.safe(2), sprite: positional.safe(3), tags: positional.safe(4), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "System":
            _addPersonOrSystem(type: .system, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", descr: positional.safe(2), sprite: positional.safe(3), tags: positional.safe(4), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "SystemDb":
            _addPersonOrSystem(type: .system_db, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", descr: positional.safe(2), sprite: positional.safe(3), tags: positional.safe(4), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "SystemQueue":
            _addPersonOrSystem(type: .system_queue, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", descr: positional.safe(2), sprite: positional.safe(3), tags: positional.safe(4), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "System_Ext":
            _addPersonOrSystem(type: .external_system, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", descr: positional.safe(2), sprite: positional.safe(3), tags: positional.safe(4), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "SystemDb_Ext":
            _addPersonOrSystem(type: .external_system_db, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", descr: positional.safe(2), sprite: positional.safe(3), tags: positional.safe(4), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "SystemQueue_Ext":
            _addPersonOrSystem(type: .external_system_queue, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", descr: positional.safe(2), sprite: positional.safe(3), tags: positional.safe(4), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)

        // Container family
        case "Container":
            _addContainerOrComponent(type: .container, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "ContainerDb":
            _addContainerOrComponent(type: .container_db, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "ContainerQueue":
            _addContainerOrComponent(type: .container_queue, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "Container_Ext":
            _addContainerOrComponent(type: .external_container, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "ContainerDb_Ext":
            _addContainerOrComponent(type: .external_container_db, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "ContainerQueue_Ext":
            _addContainerOrComponent(type: .external_container_queue, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)

        // Component family
        case "Component":
            _addContainerOrComponent(type: .component, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "ComponentDb":
            _addContainerOrComponent(type: .component_db, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "ComponentQueue":
            _addContainerOrComponent(type: .component_queue, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "Component_Ext":
            _addContainerOrComponent(type: .external_component, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "ComponentDb_Ext":
            _addContainerOrComponent(type: .external_component_db, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)
        case "ComponentQueue_Ext":
            _addContainerOrComponent(type: .external_component_queue, alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", techn: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, shapes: &shapes, currentBoundary: currentBoundaryParse, wrap: wrapEnabled)

        // Boundaries
        case "Boundary":
            _addBoundary(alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", type: positional.safe(2) ?? "system", tags: positional.safe(3), named: named, nodeType: nil, boundaries: &boundaries, currentBoundary: &currentBoundaryParse, parentBoundary: &parentBoundaryParse, stack: &boundaryParseStack, wrap: wrapEnabled)
            if hasBrace { if braceLine != nil { i += 1 } }
        case "Enterprise_Boundary":
            _addBoundary(alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", type: "ENTERPRISE", tags: positional.safe(2), named: named, nodeType: nil, boundaries: &boundaries, currentBoundary: &currentBoundaryParse, parentBoundary: &parentBoundaryParse, stack: &boundaryParseStack, wrap: wrapEnabled)
            if hasBrace { if braceLine != nil { i += 1 } }
        case "System_Boundary":
            _addBoundary(alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", type: "SYSTEM", tags: positional.safe(2), named: named, nodeType: nil, boundaries: &boundaries, currentBoundary: &currentBoundaryParse, parentBoundary: &parentBoundaryParse, stack: &boundaryParseStack, wrap: wrapEnabled)
            if hasBrace { if braceLine != nil { i += 1 } }
        case "Container_Boundary":
            _addBoundary(alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", type: "CONTAINER", tags: positional.safe(2), named: named, nodeType: nil, boundaries: &boundaries, currentBoundary: &currentBoundaryParse, parentBoundary: &parentBoundaryParse, stack: &boundaryParseStack, wrap: wrapEnabled)
            if hasBrace { if braceLine != nil { i += 1 } }

        // Deployment nodes
        case "Deployment_Node":
            _addDeploymentNode(nodeType: "node", alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", type: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, boundaries: &boundaries, currentBoundary: &currentBoundaryParse, parentBoundary: &parentBoundaryParse, stack: &boundaryParseStack, wrap: wrapEnabled)
            if hasBrace { if braceLine != nil { i += 1 } }
        case "Node":
            _addDeploymentNode(nodeType: "node", alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", type: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, boundaries: &boundaries, currentBoundary: &currentBoundaryParse, parentBoundary: &parentBoundaryParse, stack: &boundaryParseStack, wrap: wrapEnabled)
            if hasBrace { if braceLine != nil { i += 1 } }
        case "Node_L":
            _addDeploymentNode(nodeType: "nodeL", alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", type: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, boundaries: &boundaries, currentBoundary: &currentBoundaryParse, parentBoundary: &parentBoundaryParse, stack: &boundaryParseStack, wrap: wrapEnabled)
            if hasBrace { if braceLine != nil { i += 1 } }
        case "Node_R":
            _addDeploymentNode(nodeType: "nodeR", alias: positional.safe(0) ?? "", label: positional.safe(1) ?? "", type: positional.safe(2), descr: positional.safe(3), sprite: positional.safe(4), tags: positional.safe(5), named: named, boundaries: &boundaries, currentBoundary: &currentBoundaryParse, parentBoundary: &parentBoundaryParse, stack: &boundaryParseStack, wrap: wrapEnabled)
            if hasBrace { if braceLine != nil { i += 1 } }

        // Relationships
        case "Rel":
            _addRel(kind: .rel, from: positional.safe(0) ?? "", to: positional.safe(1) ?? "", label: positional.safe(2) ?? "", techn: positional.safe(3), descr: positional.safe(4), sprite: positional.safe(5), tags: positional.safe(6), named: named, relationships: &relationships, wrap: wrapEnabled)
        case "BiRel":
            _addRel(kind: .birel, from: positional.safe(0) ?? "", to: positional.safe(1) ?? "", label: positional.safe(2) ?? "", techn: positional.safe(3), descr: positional.safe(4), sprite: positional.safe(5), tags: positional.safe(6), named: named, relationships: &relationships, wrap: wrapEnabled)
        case "Rel_Up", "Rel_U":
            _addRel(kind: .rel_u, from: positional.safe(0) ?? "", to: positional.safe(1) ?? "", label: positional.safe(2) ?? "", techn: positional.safe(3), descr: positional.safe(4), sprite: positional.safe(5), tags: positional.safe(6), named: named, relationships: &relationships, wrap: wrapEnabled)
        case "Rel_Down", "Rel_D":
            _addRel(kind: .rel_d, from: positional.safe(0) ?? "", to: positional.safe(1) ?? "", label: positional.safe(2) ?? "", techn: positional.safe(3), descr: positional.safe(4), sprite: positional.safe(5), tags: positional.safe(6), named: named, relationships: &relationships, wrap: wrapEnabled)
        case "Rel_Left", "Rel_L":
            _addRel(kind: .rel_l, from: positional.safe(0) ?? "", to: positional.safe(1) ?? "", label: positional.safe(2) ?? "", techn: positional.safe(3), descr: positional.safe(4), sprite: positional.safe(5), tags: positional.safe(6), named: named, relationships: &relationships, wrap: wrapEnabled)
        case "Rel_Right", "Rel_R":
            _addRel(kind: .rel_r, from: positional.safe(0) ?? "", to: positional.safe(1) ?? "", label: positional.safe(2) ?? "", techn: positional.safe(3), descr: positional.safe(4), sprite: positional.safe(5), tags: positional.safe(6), named: named, relationships: &relationships, wrap: wrapEnabled)
        case "Rel_Back":
            _addRel(kind: .rel_b, from: positional.safe(0) ?? "", to: positional.safe(1) ?? "", label: positional.safe(2) ?? "", techn: positional.safe(3), descr: positional.safe(4), sprite: positional.safe(5), tags: positional.safe(6), named: named, relationships: &relationships, wrap: wrapEnabled)
        case "RelIndex":
            // Discard first argument (index), treat as normal Rel
            _addRel(kind: .rel, from: positional.safe(1) ?? "", to: positional.safe(2) ?? "", label: positional.safe(3) ?? "", techn: positional.safe(4), descr: positional.safe(5), sprite: positional.safe(6), tags: positional.safe(7), named: named, relationships: &relationships, wrap: wrapEnabled)

        // Style/Config updates
        case "UpdateElementStyle":
            _updateElementStyle(elementName: positional.safe(0) ?? "", bgColor: positional.safe(1), fontColor: positional.safe(2), borderColor: positional.safe(3), shadowing: positional.safe(4), shape: positional.safe(5), sprite: positional.safe(6), techn: positional.safe(7), legendText: positional.safe(8), legendSprite: positional.safe(9), named: named, shapes: &shapes, boundaries: &boundaries)
        case "UpdateRelStyle":
            _updateRelStyle(from: positional.safe(0) ?? "", to: positional.safe(1) ?? "", textColor: positional.safe(2), lineColor: positional.safe(3), offsetX: positional.safe(4), offsetY: positional.safe(5), named: named, relationships: &relationships)
        case "UpdateLayoutConfig":
            if let shapeInRow = Int(positional.safe(0) ?? ""), shapeInRow >= 1 { c4ShapeInRow = shapeInRow }
            else if let shapeInRowStr = named["c4ShapeInRow"], let v = Int(shapeInRowStr), v >= 1 { c4ShapeInRow = v }
            if let boundaryInRow = Int(positional.safe(1) ?? ""), boundaryInRow >= 1 { c4BoundaryInRow = boundaryInRow }
            else if let boundaryInRowStr = named["c4BoundaryInRow"], let v = Int(boundaryInRowStr), v >= 1 { c4BoundaryInRow = v }

        default:
            break
        }

        // Handle brace on next line
        if hasBrace && braceLine != nil {
            // Already advanced i above
        }
        i += 1
    }

    // Update config with any in-diagram changes
    diagram.config.c4ShapeInRow = c4ShapeInRow
    diagram.config.c4BoundaryInRow = c4BoundaryInRow
    diagram.config.wrap = wrapEnabled
    diagram.shapes = shapes
    diagram.boundaries = boundaries
    diagram.relationships = relationships

    return (diagram, diagnostics)
}

// MARK: - Argument Parsing

/// Parse macro arguments from a string between parens.
/// Handles quoted strings, named $key=value arguments, and empty arguments.
public func parseMacroArguments(_ argsString: String) -> (positional: [String], named: [String: String]) {
    var positional: [String] = []
    var named: [String: String] = [:]

    let tokens = _splitC4Args(argsString)
    for token in tokens {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            positional.append("")
            continue
        }
        if trimmed.hasPrefix("$") {
            let kv = String(trimmed.dropFirst())
            if let eq = kv.firstIndex(of: "=") {
                let key = String(kv[..<eq]).trimmingCharacters(in: .whitespaces)
                let value = _stripC4Quotes(String(kv[kv.index(after: eq)...]).trimmingCharacters(in: .whitespaces))
                named[key] = value
            }
        } else {
            positional.append(_stripC4Quotes(trimmed))
        }
    }

    return (positional, named)
}

private func _stripC4Quotes(_ s: String) -> String {
    if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
        return String(s.dropFirst().dropLast())
    }
    if s.hasPrefix("'") && s.hasSuffix("'") && s.count >= 2 {
        return String(s.dropFirst().dropLast())
    }
    return s
}

private func _splitC4Args(_ s: String) -> [String] {
    var result: [String] = []
    var current = ""
    var inQuote = false
    var quoteChar: Character?
    for ch in s {
        if inQuote {
            current.append(ch)
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            }
        } else {
            if ch == "," {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
                if ch == "\"" || ch == "'" {
                    inQuote = true
                    quoteChar = ch
                }
            }
        }
    }
    if !current.isEmpty || s.hasSuffix(",") {
        result.append(current)
    }
    return result
}

// MARK: - Macro Name Detection

private func _detectMacroName(_ line: String) -> String? {
    let macroNames = [
        "Person_Ext", "Person",
        "SystemQueue_Ext", "SystemDb_Ext", "System_Ext",
        "SystemQueue", "SystemDb", "System",
        "Boundary", "Enterprise_Boundary", "System_Boundary", "Container_Boundary",
        "ContainerQueue_Ext", "ContainerDb_Ext", "Container_Ext",
        "ContainerQueue", "ContainerDb", "Container",
        "ComponentQueue_Ext", "ComponentDb_Ext", "Component_Ext",
        "ComponentQueue", "ComponentDb", "Component",
        "Deployment_Node", "Node_L", "Node_R", "Node",
        "RelIndex", "Rel_Back", "Rel_Up", "Rel_U", "Rel_Down", "Rel_D",
        "Rel_Left", "Rel_L", "Rel_Right", "Rel_R", "BiRel", "Rel",
        "UpdateElementStyle", "UpdateRelStyle", "UpdateLayoutConfig"
    ]
    for name in macroNames {
        if line.hasPrefix(name) {
            let after = line.dropFirst(name.count)
            if after.first?.isWhitespace == true || after.first == "(" {
                return name
            }
        }
    }
    return nil
}

// MARK: - Metadata Parsing

private func _parseC4Title(_ line: String) -> String? {
    guard line.hasPrefix("title ") else { return nil }
    return String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
}

private func _parseC4AccDescription(_ line: String) -> String? {
    guard line.hasPrefix("accDescription ") else { return nil }
    return String(line.dropFirst(15)).trimmingCharacters(in: .whitespaces)
}

private func _parseC4AccDescrLine(_ line: String) -> String? {
    guard let range = line.range(of: #"^accDescr\s*:\s*"#, options: .regularExpression) else { return nil }
    return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
}

private func _parseC4AccTitle(_ line: String) -> String? {
    guard let range = line.range(of: #"^accTitle\s*:\s*"#, options: .regularExpression) else { return nil }
    // Mermaid routes accTitle to setTitle (quirk — replicate)
    return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
}

private func _parseC4Direction(_ line: String) -> String? {
    let dirs = ["TB", "BT", "RL", "LR"]
    for d in dirs {
        if line.range(of: "direction\\s+\(d)", options: .regularExpression) != nil {
            return d
        }
    }
    return nil
}

// MARK: - Helper: Find matching closing paren

private func _findMatchingParen(_ s: String, from start: String.Index) -> String.Index? {
    var depth = 0
    var inQuote = false
    var quoteChar: Character?
    var idx = start
    while idx < s.endIndex {
        let ch = s[idx]
        if inQuote {
            if ch == quoteChar { inQuote = false; quoteChar = nil }
        } else {
            if ch == "\"" || ch == "'" { inQuote = true; quoteChar = ch }
            else if ch == "(" { depth += 1 }
            else if ch == ")" {
                depth -= 1
                if depth == 0 { return idx }
            }
        }
        idx = s.index(after: idx)
    }
    return nil
}

// MARK: - Boundary resolution helpers

/// Resolve the effective parent boundary for a C4 macro, preferring the
/// `$boundary=` (shapes) or `$parent=` (boundaries / deployment nodes)
/// named arg over the lexical-stack value. Emits a `.warning` when the
/// named arg conflicts with a non-`global` enclosing scope.
private func _resolveParentBoundary(
    named: [String: String],
    lexical: String,
    key: String,
    macroName: String,
    alias: String,
    diagnostics: inout [DiagramDiagnostic]
) -> String {
    guard let namedValue = named[key], !namedValue.isEmpty else {
        return lexical
    }
    if lexical != "global" && lexical != namedValue {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Mermaid C4 \(macroName)(\(alias)) named arg \(key)=\(namedValue) overrides enclosing \(lexical) — using named value"
        ))
    }
    return namedValue
}

/// Walk the fully-populated shapes and boundaries arrays and emit a
/// `.warning` for any `parentBoundary` value that doesn't resolve to a
/// known boundary alias. `"global"` and `""` are the documented sentinels
/// for the synthetic root.
private func _validateBoundaryReferences(
    shapes: [C4Shape],
    boundaries: [C4Boundary],
    diagnostics: inout [DiagramDiagnostic]
) {
    let known: Set<String> = Set(boundaries.map(\.alias)).union(["global", ""])
    for s in shapes where !known.contains(s.parentBoundary) {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Mermaid C4 shape '\(s.alias)' parentBoundary=\(s.parentBoundary) references undefined boundary"
        ))
    }
    for b in boundaries where !known.contains(b.parentBoundary) {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Mermaid C4 boundary '\(b.alias)' parentBoundary=\(b.parentBoundary) references undefined boundary"
        ))
    }
}

// MARK: - DB Functions

private func _addPersonOrSystem(
    type: C4ShapeType,
    alias: String,
    label: String,
    descr: String?,
    sprite: String?,
    tags: String?,
    named: [String: String],
    shapes: inout [C4Shape],
    currentBoundary: String,
    wrap: Bool
) {
    guard !alias.isEmpty else { return }
    guard !label.isEmpty else { return }

    let link = named["link"]
    let resolvedTags = tags ?? named["tags"]
    let resolvedSprite = sprite ?? named["sprite"]

    if let idx = shapes.firstIndex(where: { $0.alias == alias }) {
        // Update existing
        var shape = shapes[idx]
        shape.label = label
        if let d = descr { shape.description = d }
        if let s = resolvedSprite { shape.sprite = s }
        if let t = resolvedTags { shape.tags = t }
        if let l = link { shape.link = l }
        shape.parentBoundary = currentBoundary
        shape.wrap = wrap
        shapes[idx] = shape
    } else {
        shapes.append(C4Shape(
            alias: alias,
            label: label,
            typeC4Shape: type,
            description: descr,
            sprite: resolvedSprite,
            tags: resolvedTags,
            link: link,
            parentBoundary: currentBoundary,
            wrap: wrap
        ))
    }
}

private func _addContainerOrComponent(
    type: C4ShapeType,
    alias: String,
    label: String,
    techn: String?,
    descr: String?,
    sprite: String?,
    tags: String?,
    named: [String: String],
    shapes: inout [C4Shape],
    currentBoundary: String,
    wrap: Bool
) {
    guard !alias.isEmpty else { return }
    guard !label.isEmpty else { return }

    let link = named["link"]
    let resolvedTags = tags ?? named["tags"]
    let resolvedSprite = sprite ?? named["sprite"]

    if let idx = shapes.firstIndex(where: { $0.alias == alias }) {
        var shape = shapes[idx]
        shape.label = label
        shape.technology = techn
        if let d = descr { shape.description = d }
        if let s = resolvedSprite { shape.sprite = s }
        if let t = resolvedTags { shape.tags = t }
        if let l = link { shape.link = l }
        shape.parentBoundary = currentBoundary
        shape.wrap = wrap
        shapes[idx] = shape
    } else {
        shapes.append(C4Shape(
            alias: alias,
            label: label,
            typeC4Shape: type,
            technology: techn,
            description: descr,
            sprite: resolvedSprite,
            tags: resolvedTags,
            link: link,
            parentBoundary: currentBoundary,
            wrap: wrap
        ))
    }
}

private func _addBoundary(
    alias: String,
    label: String,
    type: String,
    tags: String?,
    named: [String: String],
    nodeType: String?,
    boundaries: inout [C4Boundary],
    currentBoundary: inout String,
    parentBoundary: inout String,
    stack: inout [String],
    wrap: Bool
) {
    guard !alias.isEmpty else { return }
    guard !label.isEmpty else { return }

    let link = named["link"]
    let resolvedTags = tags ?? named["tags"]

    if let idx = boundaries.firstIndex(where: { $0.alias == alias }) {
        var boundary = boundaries[idx]
        boundary.label = label
        boundary.type = type
        if let t = resolvedTags { boundary.tags = t }
        if let l = link { boundary.link = l }
        boundary.parentBoundary = currentBoundary
        boundary.wrap = wrap
        boundaries[idx] = boundary
    } else {
        boundaries.append(C4Boundary(
            alias: alias,
            label: label,
            type: type,
            tags: resolvedTags,
            link: link,
            parentBoundary: currentBoundary,
            nodeType: nodeType,
            wrap: wrap
        ))
    }

    parentBoundary = currentBoundary
    currentBoundary = alias
    stack.append(parentBoundary)
}

private func _addDeploymentNode(
    nodeType: String,
    alias: String,
    label: String,
    type: String?,
    descr: String?,
    sprite: String?,
    tags: String?,
    named: [String: String],
    boundaries: inout [C4Boundary],
    currentBoundary: inout String,
    parentBoundary: inout String,
    stack: inout [String],
    wrap: Bool
) {
    guard !alias.isEmpty else { return }
    guard !label.isEmpty else { return }

    let link = named["link"]
    let resolvedTags = tags ?? named["tags"]
    let resolvedType = type ?? "node"

    if let idx = boundaries.firstIndex(where: { $0.alias == alias }) {
        var boundary = boundaries[idx]
        boundary.label = label
        boundary.type = resolvedType
        if let d = descr { boundary.description = d }
        if let t = resolvedTags { boundary.tags = t }
        if let l = link { boundary.link = l }
        boundary.nodeType = nodeType
        boundary.parentBoundary = currentBoundary
        boundary.wrap = wrap
        boundaries[idx] = boundary
    } else {
        boundaries.append(C4Boundary(
            alias: alias,
            label: label,
            type: resolvedType,
            description: descr,
            tags: resolvedTags,
            link: link,
            parentBoundary: currentBoundary,
            nodeType: nodeType,
            wrap: wrap
        ))
    }

    parentBoundary = currentBoundary
    currentBoundary = alias
    stack.append(parentBoundary)
}

private func _addRel(
    kind: C4RelationshipKind,
    from: String,
    to: String,
    label: String,
    techn: String?,
    descr: String?,
    sprite: String?,
    tags: String?,
    named: [String: String],
    relationships: inout [C4Relationship],
    wrap: Bool
) {
    guard !from.isEmpty else { return }
    guard !to.isEmpty else { return }
    guard !label.isEmpty else { return }

    let link = named["link"]
    let resolvedTags = tags ?? named["tags"]
    let resolvedSprite = sprite ?? named["sprite"]

    if let idx = relationships.firstIndex(where: { $0.from == from && $0.to == to && $0.kind == kind }) {
        var rel = relationships[idx]
        rel.label = label
        rel.kind = kind
        if let t = techn { rel.technology = t }
        if let d = descr { rel.description = d }
        if let s = resolvedSprite { rel.sprite = s }
        if let t = resolvedTags { rel.tags = t }
        if let l = link { rel.link = l }
        rel.wrap = wrap
        relationships[idx] = rel
    } else {
        relationships.append(C4Relationship(
            kind: kind,
            from: from,
            to: to,
            label: label,
            technology: techn,
            description: descr,
            sprite: resolvedSprite,
            tags: resolvedTags,
            link: link,
            wrap: wrap
        ))
    }
}

private func _updateElementStyle(
    elementName: String,
    bgColor: String?,
    fontColor: String?,
    borderColor: String?,
    shadowing: String?,
    shape: String?,
    sprite: String?,
    techn: String?,
    legendText: String?,
    legendSprite: String?,
    named: [String: String],
    shapes: inout [C4Shape],
    boundaries: inout [C4Boundary]
) {
    let resolvedBgColor = bgColor ?? named["bgColor"]
    let resolvedFontColor = fontColor ?? named["fontColor"]
    let resolvedBorderColor = borderColor ?? named["borderColor"]
    let resolvedShadowing = shadowing ?? named["shadowing"]
    let resolvedShape = shape ?? named["shape"]
    let resolvedSprite = sprite ?? named["sprite"]
    let resolvedTechn = techn ?? named["techn"]
    let resolvedLegendText = legendText ?? named["legendText"]
    let resolvedLegendSprite = legendSprite ?? named["legendSprite"]

    if let idx = shapes.firstIndex(where: { $0.alias == elementName }) {
        var s = shapes[idx]
        if let c = resolvedBgColor { s.bgColor = c }
        if let c = resolvedFontColor { s.fontColor = c }
        if let c = resolvedBorderColor { s.borderColor = c }
        if let sh = resolvedShadowing { s.shadowing = sh }
        if let sp = resolvedShape { s.shapeOverride = sp }
        if let sp = resolvedSprite { s.sprite = sp }
        if let t = resolvedTechn { s.techn = t }
        if let lt = resolvedLegendText { s.legendText = lt }
        if let ls = resolvedLegendSprite { s.legendSprite = ls }
        shapes[idx] = s
        return
    }

    if let idx = boundaries.firstIndex(where: { $0.alias == elementName }) {
        var b = boundaries[idx]
        if let c = resolvedBgColor { b.bgColor = c }
        if let c = resolvedFontColor { b.fontColor = c }
        if let c = resolvedBorderColor { b.borderColor = c }
        boundaries[idx] = b
    }
}

private func _updateRelStyle(
    from: String,
    to: String,
    textColor: String?,
    lineColor: String?,
    offsetX: String?,
    offsetY: String?,
    named: [String: String],
    relationships: inout [C4Relationship]
) {
    guard let idx = relationships.firstIndex(where: { $0.from == from && $0.to == to }) else { return }

    let resolvedTextColor = textColor ?? named["textColor"]
    let resolvedLineColor = lineColor ?? named["lineColor"]
    let resolvedOffsetX = offsetX ?? named["offsetX"]
    let resolvedOffsetY = offsetY ?? named["offsetY"]

    var rel = relationships[idx]
    if let c = resolvedTextColor { rel.textColor = c }
    if let c = resolvedLineColor { rel.lineColor = c }
    if let ox = resolvedOffsetX, let v = Int(ox) { rel.offsetX = v }
    if let oy = resolvedOffsetY, let v = Int(oy) { rel.offsetY = v }
    relationships[idx] = rel
}

// MARK: - Array safe subscript

private extension Array {
    func safe(_ index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
