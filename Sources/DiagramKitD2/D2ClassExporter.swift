import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Detects whether a `D2Document` describes a class diagram.
///
/// A D2 document is treated as a class diagram when at least one container
/// (`id: { … }`) contains a `shape: class` statement among its inner
/// definitions. Caller is responsible for routing to `D2ClassMapper.map(_:)`
/// when this returns `true`.
enum D2ClassProbe {

    static func detectsClassDiagram(_ document: D2Document) -> Bool {
        var depth = 0
        var sawClass = false
        var currentDepthIsClass = false
        for stmt in document.statements {
            switch stmt {
            case .containerOpen:
                depth += 1
                currentDepthIsClass = false
            case .containerClose:
                if currentDepthIsClass { sawClass = true }
                depth -= 1
                currentDepthIsClass = false
            case .nodeDefinition(let def):
                if depth > 0 && def.id == "shape" && (def.label?.lowercased() == "class") {
                    currentDepthIsClass = true
                }
            default:
                break
            }
        }
        return sawClass
    }
}

/// Builds a `ClassDiagram` payload from a `D2Document` whose containers carry
/// `shape: class` markers. Members inside each container are recognised by
/// visibility prefix (`+` / `-` / `#` / `~`); `()` in the body marks a method.
struct D2ClassMapper {

    func map(_ document: D2Document) -> (ClassDiagram, [DiagramDiagnostic]) {
        var classes: [ClassNode] = []
        var classOrderByID: [String: Int] = [:]
        var relationships: [ClassRelationship] = []
        let diagnostics: [DiagramDiagnostic] = []

        var stack: [PartialClass] = []

        for stmt in document.statements {
            switch stmt {
            case .containerOpen(let open):
                stack.append(PartialClass(id: open.id, label: open.label ?? open.id))

            case .containerClose:
                guard !stack.isEmpty else { break }
                let partial = stack.removeLast()
                if partial.isClass {
                    let node = partial.makeClassNode()
                    classOrderByID[node.id] = classes.count
                    classes.append(node)
                }

            case .nodeDefinition(let def):
                if !stack.isEmpty {
                    let topIdx = stack.count - 1
                    if def.id == "shape" && (def.label?.lowercased() == "class") {
                        stack[topIdx].isClass = true
                        continue
                    }
                    if stack[topIdx].isClass {
                        stack[topIdx].appendMember(rawKey: def.id, rawValue: def.label)
                        continue
                    }
                }

            case .edgeDefinition(let edge):
                let source = edge.source.trimmingCharacters(in: .whitespaces)
                let target = edge.target.trimmingCharacters(in: .whitespaces)
                guard !source.isEmpty, !target.isEmpty else { continue }
                let endpoint = ClassRelationEndpoint(
                    type1: ClassRelationType.none.rawValue,
                    type2: ClassRelationType.none.rawValue,
                    lineType: ClassLineType.solid.rawValue
                )
                relationships.append(ClassRelationship(
                    id1: source,
                    id2: target,
                    relationTitle1: "",
                    relationTitle2: "",
                    title: edge.label ?? "",
                    text: "",
                    style: [],
                    relation: endpoint
                ))

            default:
                break
            }
        }

        let classMap = Dictionary(uniqueKeysWithValues: classes.map { ($0.id, $0) })
        let diagram = ClassDiagram(
            classes: classes,
            classMap: classMap,
            relationships: relationships
        )
        return (diagram, diagnostics)
    }
}

private struct PartialClass {
    var id: String
    var label: String
    var isClass: Bool = false
    var attributes: [ClassMember] = []
    var methods: [ClassMember] = []

    mutating func appendMember(rawKey: String, rawValue: String?) {
        let (visibility, body) = stripVisibility(rawKey)
        let isMethod = body.contains("(") || (rawValue ?? "").contains("(")
        let type = rawValue?.trimmingCharacters(in: .whitespaces) ?? ""
        if isMethod {
            let bodyTrimmed = body.trimmingCharacters(in: .whitespaces)
            let nameAndParams = bodyTrimmed
            let methodName: String
            let params: String
            if let lp = nameAndParams.firstIndex(of: "("),
               let rp = nameAndParams.lastIndex(of: ")") {
                methodName = String(nameAndParams[..<lp])
                params = String(nameAndParams[nameAndParams.index(after: lp)..<rp])
            } else {
                methodName = nameAndParams
                params = ""
            }
            methods.append(ClassMember(
                id: methodName,
                visibility: visibility,
                memberType: .method,
                parameters: params,
                returnType: type
            ))
        } else {
            attributes.append(ClassMember(
                id: body.trimmingCharacters(in: .whitespaces),
                visibility: visibility,
                memberType: .attribute,
                returnType: type
            ))
        }
    }

    func makeClassNode() -> ClassNode {
        ClassNode(
            id: id,
            label: label,
            attributes: attributes,
            methods: methods
        )
    }

    private func stripVisibility(_ raw: String) -> (vis: String, body: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return ("", trimmed) }
        switch first {
        case "+", "-", "#", "~":
            let body = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return (String(first), body)
        default:
            return ("", trimmed)
        }
    }
}

/// Emits D2 source for the `.classDiagram` payload using D2's `shape: class`
/// block form. Stereotypes (carried on `ClassNode.annotations`) are dropped
/// with a paired `.classStereotypeDrop` diagnostic.
enum D2ClassExport {

    static func emit(_ diagram: ClassDiagram, title: String? = nil) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        if let title = title, !title.isEmpty {
            lines.append("# title: \(title.replacingOccurrences(of: "\n", with: " "))")
        }

        for c in diagram.classes {
            for stereotype in c.annotations where !stereotype.isEmpty {
                diagnostics.append(.lossyTransform(
                    .classStereotypeDrop,
                    message: "D2 has no native stereotype concept; dropping '<<\(stereotype)>>' on class '\(c.id)'"
                ))
            }
            lines.append("\(D2ClassExport.sanitizeID(c.id)): {")
            lines.append("  shape: class")
            for attr in c.attributes {
                let prefix = attr.visibility
                let typeValue = attr.returnType.isEmpty ? "\"\"" : attr.returnType
                lines.append("  \(prefix)\(attr.id): \(typeValue)")
            }
            for method in c.methods {
                let prefix = method.visibility
                let params = method.parameters
                let returnValue = method.returnType.isEmpty ? "\"\"" : method.returnType
                lines.append("  \(prefix)\(method.id)(\(params)): \(returnValue)")
            }
            lines.append("}")
            lines.append("")
        }

        for rel in diagram.relationships {
            let label = rel.title
            let src = D2ClassExport.sanitizeID(rel.id1)
            let tgt = D2ClassExport.sanitizeID(rel.id2)
            if !label.isEmpty {
                lines.append("\(src) -> \(tgt): \(label)")
            } else {
                lines.append("\(src) -> \(tgt)")
            }
        }

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    static func sanitizeID(_ raw: String) -> String {
        var result = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { result.append("_") }
                result.append(ch)
            case " ", "-", ".":
                result.append("_")
            default: break
            }
        }
        return result.isEmpty ? "node" : result
    }
}
