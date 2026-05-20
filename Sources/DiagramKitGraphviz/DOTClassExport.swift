import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Detects whether a `DOTDocument` describes a class diagram.
///
/// A DOT document is treated as a class diagram when at least one node has
/// `shape=record` AND its `label` opens with `{` (the canonical DOT record
/// label syntax for class-style boxes). To disambiguate ER record nodes from
/// class record nodes, the probe requires the label to contain at least one
/// member with a visibility marker (`+`, `-`, `#`, `~`) — ER labels do not
/// carry visibility markers.
enum DOTClassProbe {

    static func detectsClassDiagram(_ document: DOTDocument) -> Bool {
        for stmt in document.statements {
            if case .nodeStatement(let node) = stmt {
                if isClassRecordNode(node) { return true }
            }
        }
        return false
    }

    static func isClassRecordNode(_ node: DOTNodeStatement) -> Bool {
        let attrs = Dictionary(uniqueKeysWithValues: node.attributes.map { ($0.key, $0.value) })
        guard attrs["shape"] == "record" else { return false }
        guard let label = attrs["label"], label.hasPrefix("{") else { return false }
        return labelLooksLikeClassRecord(label)
    }

    static func labelLooksLikeClassRecord(_ raw: String) -> Bool {
        for ch in raw {
            if ch == "+" || ch == "-" || ch == "#" || ch == "~" {
                return true
            }
        }
        return false
    }

    static func parseRecordLabel(_ raw: String) -> (header: String, attributes: [String], methods: [String]) {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("{") { s = String(s.dropFirst()) }
        if s.hasSuffix("}") { s = String(s.dropLast()) }
        let sections = s.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        let header = sections.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let attrLines = sections.count > 1 ? splitRecordSection(sections[1]) : []
        let methodLines = sections.count > 2 ? splitRecordSection(sections[2]) : []
        return (header, attrLines, methodLines)
    }

    private static func splitRecordSection(_ s: String) -> [String] {
        s.replacingOccurrences(of: "\\n", with: "\n")
         .replacingOccurrences(of: "\\n", with: "\n")
         .split(separator: "\n")
         .map { $0.trimmingCharacters(in: .whitespaces) }
         .filter { !$0.isEmpty }
    }
}

/// Builds a `ClassDiagram` from a `DOTDocument` whose record-shaped nodes
/// carry class-style labels (`{Header|+attr|+method()}`).
struct DOTClassMapper {

    func map(_ document: DOTDocument) -> (ClassDiagram, [DiagramDiagnostic]) {
        var classes: [ClassNode] = []
        var relationships: [ClassRelationship] = []
        let diagnostics: [DiagramDiagnostic] = []

        let nodeByID: [String: DOTNodeStatement] = Dictionary(
            uniqueKeysWithValues: document.statements.compactMap { stmt -> (String, DOTNodeStatement)? in
                if case .nodeStatement(let node) = stmt, DOTClassProbe.isClassRecordNode(node) {
                    return (node.id, node)
                }
                return nil
            }
        )

        for stmt in document.statements {
            switch stmt {
            case .nodeStatement(let node):
                guard let n = nodeByID[node.id] else { continue }
                let attrs = Dictionary(uniqueKeysWithValues: n.attributes.map { ($0.key, $0.value) })
                guard let label = attrs["label"] else { continue }
                let parsed = DOTClassProbe.parseRecordLabel(label)
                let attributes = parsed.attributes.map { makeMember($0, isMethod: false) }
                let methods = parsed.methods.map { makeMember($0, isMethod: true) }
                let displayLabel = parsed.header.isEmpty ? node.id : parsed.header
                let routed = Self.routeClassAttributes(attrs)
                classes.append(ClassNode(
                    id: node.id,
                    label: displayLabel,
                    attributes: attributes,
                    methods: methods,
                    styles: routed.styles,
                    link: routed.link,
                    tooltip: routed.tooltip
                ))

            case .edgeStatement(let edge):
                guard nodeByID[edge.source] != nil, nodeByID[edge.target] != nil else { continue }
                let endpoint = ClassRelationEndpoint(
                    type1: ClassRelationType.none.rawValue,
                    type2: ClassRelationType.none.rawValue,
                    lineType: ClassLineType.solid.rawValue
                )
                let edgeAttrs = Dictionary(uniqueKeysWithValues: edge.attributes.map { ($0.key, $0.value) })
                let label = edgeAttrs["label"] ?? ""
                relationships.append(ClassRelationship(
                    id1: edge.source,
                    id2: edge.target,
                    relationTitle1: "",
                    relationTitle2: "",
                    title: label,
                    text: "",
                    style: [],
                    relation: endpoint
                ))

            default:
                break
            }
        }

        let classMap = Dictionary(uniqueKeysWithValues: classes.map { ($0.id, $0) })
        return (
            ClassDiagram(classes: classes, classMap: classMap, relationships: relationships),
            diagnostics
        )
    }

    /// Routes node-level attributes that have typed Mermaid landing slots
    /// (`URL`/`href` → link, `tooltip` → tooltip, `style`/`color`/`fillcolor`/
    /// `fontcolor` → styles[]) so they don't drop silently.
    static func routeClassAttributes(_ attrs: [String: String]) -> (link: String?, tooltip: String?, styles: [String]) {
        var link: String?
        var tooltip: String?
        var styles: [String] = []
        for (key, value) in attrs {
            let unquoted = stripQuotes(value)
            switch key.lowercased() {
            case "url", "href":
                link = unquoted
            case "tooltip":
                tooltip = unquoted
            case "style":
                styles.append("style:\(unquoted)")
            case "color":
                styles.append("stroke:\(unquoted)")
            case "fillcolor":
                styles.append("fill:\(unquoted)")
            case "fontcolor":
                styles.append("color:\(unquoted)")
            default:
                break
            }
        }
        return (link, tooltip, styles)
    }

    private static func stripQuotes(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private func makeMember(_ raw: String, isMethod: Bool) -> ClassMember {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        var visibility = ""
        var body = trimmed
        if let first = trimmed.first, ["+", "-", "#", "~"].contains(first) {
            visibility = String(first)
            body = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        let isMethodActual = isMethod || body.contains("(")
        if isMethodActual {
            let nameAndRest: (name: String, params: String, returnType: String)
            if let lp = body.firstIndex(of: "("), let rp = body.lastIndex(of: ")") {
                let name = String(body[..<lp]).trimmingCharacters(in: .whitespaces)
                let params = String(body[body.index(after: lp)..<rp]).trimmingCharacters(in: .whitespaces)
                let after = String(body[body.index(after: rp)...]).trimmingCharacters(in: .whitespaces)
                let ret: String
                if after.hasPrefix(":") {
                    ret = String(after.dropFirst()).trimmingCharacters(in: .whitespaces)
                } else {
                    ret = after
                }
                nameAndRest = (name, params, ret)
            } else {
                nameAndRest = (body, "", "")
            }
            return ClassMember(
                id: nameAndRest.name,
                visibility: visibility,
                memberType: .method,
                parameters: nameAndRest.params,
                returnType: nameAndRest.returnType
            )
        } else {
            let parts = body.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            let name = parts.first ?? body
            let type = parts.count > 1 ? parts[1] : ""
            return ClassMember(
                id: name,
                visibility: visibility,
                memberType: .attribute,
                returnType: type
            )
        }
    }
}

/// Emits DOT source for the `.classDiagram` payload using DOT's record-shape
/// form. Stereotypes carried on `ClassNode.annotations` drop with a paired
/// `.classStereotypeDrop` diagnostic.
enum DOTClassExport {

    static func emit(_ diagram: ClassDiagram, title: String? = nil) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        let graphName = title.flatMap { sanitizeDOTID($0) } ?? "ClassDiagram"
        lines.append("digraph \(graphName) {")
        if let title = title, !title.isEmpty {
            lines.append("  labelloc=\"t\";")
            lines.append("  label=\(quoted(singleLineTitle(title)));")
        }

        for c in diagram.classes {
            let attrLines = c.attributes.map { renderMember($0, isMethod: false) }
            let methodLines = c.methods.map { renderMember($0, isMethod: true) }
            let header = c.label.isEmpty ? c.id : c.label
            let attrsSection = attrLines.joined(separator: "\\n") + (attrLines.isEmpty ? "" : "\\n")
            let methodsSection = methodLines.joined(separator: "\\n") + (methodLines.isEmpty ? "" : "\\n")
            let labelBody = "{\(header)|\(attrsSection)|\(methodsSection)}"
            lines.append("  \(sanitizeDOTID(c.id)) [shape=record, label=\(quoted(labelBody))];")
            for stereotype in c.annotations where !stereotype.isEmpty {
                lines.append("  " + DOTRecoveryMarker.emitClassStereotype(className: c.id, stereotype: stereotype))
            }
        }

        for rel in diagram.relationships {
            let src = sanitizeDOTID(rel.id1)
            let tgt = sanitizeDOTID(rel.id2)
            if !rel.title.isEmpty {
                lines.append("  \(src) -> \(tgt) [label=\(quoted(rel.title))];")
            } else {
                lines.append("  \(src) -> \(tgt);")
            }
        }

        lines.append("}")
        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func renderMember(_ m: ClassMember, isMethod: Bool) -> String {
        let vis = m.visibility.isEmpty ? "" : m.visibility
        if isMethod || m.memberType == .method {
            let ret = m.returnType.isEmpty ? "" : ": \(m.returnType)"
            return "\(vis) \(m.id)(\(m.parameters))\(ret)"
        } else {
            let ret = m.returnType.isEmpty ? "" : ": \(m.returnType)"
            return "\(vis) \(m.id)\(ret)"
        }
    }

    static func sanitizeDOTID(_ id: String) -> String {
        let allowedFirst = CharacterSet.letters.union(CharacterSet(charactersIn: "_"))
        let allowedTail = allowedFirst.union(.decimalDigits)
        guard let first = id.unicodeScalars.first,
              allowedFirst.contains(first),
              id.unicodeScalars.dropFirst().allSatisfy({ allowedTail.contains($0) }) else {
            return quoted(id)
        }
        return id
    }

    static func quoted(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func singleLineTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "\n", with: " ")
             .replacingOccurrences(of: "\r", with: " ")
    }
}
