import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid class diagram source from a `ClassDiagram`.
enum MermaidClassExport {

    static func emit(_ model: ClassDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        // Collision-aware identifier emission shared across namespaces,
        // classes, notes, and relationships. Namespaces and classes
        // occupy the same id namespace in Mermaid's class diagram, so
        // one shared `usedAliases` set and one shared `aliasMap` cover
        // both. Notes and relationship endpoints look up via `aliasMap`
        // with a plain-sanitize fallback for references not in the
        // namespace/class set.
        var usedAliases: Set<String> = []
        var aliasMap: [String: String] = [:]

        lines.append("classDiagram")

        // Direction
        if model.direction != .TB {
            lines.append("  direction \(model.direction.rawValue)")
        }

        // Title / accessibility
        if let title = model.diagramTitle {
            let (q, _) = MermaidExportHelpers.quote(title)
            lines.append("  title: \(q)")
        }
        if let accTitle = model.accTitle {
            let (q, _) = MermaidExportHelpers.quote(accTitle)
            lines.append("  accTitle: \(q)")
        }
        if let accDescr = model.accDescription {
            lines.append("  accDescr {")
            for descLine in accDescr.split(separator: "\n") {
                lines.append("    \(descLine)")
            }
            lines.append("  }")
        }

        // Namespaces. Classes whose (qualified) id appears in a namespace's
        // classIds emit INSIDE that namespace block under their local id —
        // Mermaid resolves `namespace NS { class Foo {} }` to the qualified
        // id `NS.Foo`, which is what the parser stores.
        var namespacedClassIDs: Set<String> = []
        func collectNamespacedIDs(_ ns: ClassNamespace) {
            for cid in ns.classIds { namespacedClassIDs.insert(cid) }
            for child in ns.children { collectNamespacedIDs(child) }
        }
        for ns in model.namespaces { collectNamespacedIDs(ns) }

        for ns in model.namespaces.sorted(by: { $0.id < $1.id }) {
            emitNamespace(
                ns,
                indent: 1,
                qualifiedPath: ns.id,
                classesByID: model.classMap,
                usedAliases: &usedAliases,
                aliasMap: &aliasMap,
                lines: &lines,
                diagnostics: &diagnostics
            )
        }

        // Classes
        for cls in model.classes where !namespacedClassIDs.contains(cls.id) {
            emitClassBody(
                cls,
                indent: 1,
                emitID: cls.id,
                usedAliases: &usedAliases,
                aliasMap: &aliasMap,
                lines: &lines,
                diagnostics: &diagnostics
            )
        }

        // Notes
        for note in model.notes {
            let (qText, nd) = MermaidExportHelpers.quote(note.text)
            diagnostics.append(contentsOf: nd)

            if let classId = note.class_ {
                let sanitizedClassId = aliasMap[classId] ?? MermaidExportHelpers.sanitizeIdentifier(classId).sanitized
                lines.append("  note for \(sanitizedClassId) \(qText)")
            } else {
                lines.append("  note \(qText)")
            }
        }

        // Relationships
        for rel in model.relationships {
            let (sanitized1, d1): (String, [DiagramDiagnostic]) = aliasMap[rel.id1].map { ($0, []) }
                ?? MermaidExportHelpers.sanitizeIdentifier(rel.id1)
            let (sanitized2, d2): (String, [DiagramDiagnostic]) = aliasMap[rel.id2].map { ($0, []) }
                ?? MermaidExportHelpers.sanitizeIdentifier(rel.id2)
            diagnostics.append(contentsOf: d1)
            diagnostics.append(contentsOf: d2)

            let arrow = classArrow(rel.relation)
            var relLine = "  \(sanitized1) \(arrow) \(sanitized2)"

            if !rel.relationTitle1.isEmpty {
                let (q, _) = MermaidExportHelpers.quote(rel.relationTitle1)
                relLine = "  \(sanitized1) \(q) \(arrow) \(sanitized2)"
            }
            if !rel.relationTitle2.isEmpty {
                let (q, _) = MermaidExportHelpers.quote(rel.relationTitle2)
                relLine += " \(q)"
            }

            if !rel.title.isEmpty {
                let (q, _) = MermaidExportHelpers.quote(rel.title)
                relLine += " : \(q)"
            }

            lines.append(relLine)
        }

        // Style classes (classDef)
        for styleClass in model.styleClasses {
            let joinedStyles = styleClass.styles.joined(separator: ",")
            lines.append("  classDef \(styleClass.id) \(joinedStyles)")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - Namespace emission

    private static func emitNamespace(
        _ ns: ClassNamespace,
        indent: Int,
        qualifiedPath: String,
        classesByID: [String: ClassNode],
        usedAliases: inout Set<String>,
        aliasMap: inout [String: String],
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let pad = String(repeating: "  ", count: indent)
        let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(
            ns.id,
            usedAliases: &usedAliases
        )
        diagnostics.append(contentsOf: idDiags)
        aliasMap[ns.id] = sanitizedId

        if ns.label.isEmpty || ns.label == ns.id {
            lines.append("\(pad)namespace \(sanitizedId) {")
        } else {
            let (ql, _) = MermaidExportHelpers.quote(ns.label)
            lines.append("\(pad)namespace \(sanitizedId)[\(ql)] {")
        }

        // Member classes — classIds hold the class's LOCAL id (the class
        // map keys by local id); emit the local id so the parser re-derives
        // the same membership.
        for classID in ns.classIds {
            guard let cls = classesByID[classID] else { continue }
            emitClassBody(
                cls,
                indent: indent + 1,
                emitID: classID,
                usedAliases: &usedAliases,
                aliasMap: &aliasMap,
                lines: &lines,
                diagnostics: &diagnostics
            )
        }

        for child in ns.children {
            emitNamespace(
                child,
                indent: indent + 1,
                qualifiedPath: "\(qualifiedPath).\(child.id)",
                classesByID: classesByID,
                usedAliases: &usedAliases,
                aliasMap: &aliasMap,
                lines: &lines,
                diagnostics: &diagnostics
            )
        }

        lines.append("\(pad)}")
    }

    // MARK: - Class body emission

    /// Emits one class body at `indent`. `emitID` is the id to declare —
    /// the qualified id at top level, the local id inside a namespace
    /// block (the `usedAliases`/`aliasMap` books stay keyed by the
    /// model-level id).
    private static func emitClassBody(
        _ cls: ClassNode,
        indent: Int,
        emitID: String,
        usedAliases: inout Set<String>,
        aliasMap: inout [String: String],
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let pad = String(repeating: "  ", count: indent)
        let memberPad = String(repeating: "  ", count: indent + 1)
        let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(
            emitID,
            usedAliases: &usedAliases
        )
        diagnostics.append(contentsOf: idDiags)
        aliasMap[cls.id] = sanitizedId

        // Annotations are emitted bare: Mermaid expects
        // `<<interface>> Foo`, not `<<"interface">> Foo`.
        for annotation in cls.annotations {
            lines.append("\(pad)<<\(annotation)>> \(sanitizedId)")
        }

        // Class declaration. `cls.label == emitID` (the local id inside a
        // namespace) means "no authored label" — the parser stores the local
        // id as label while cls.id stays qualified.
        var classLine = ""
        if cls.type != nil {
            classLine = "\(pad)class \(sanitizedId)~\(cls.type!)~"
        } else if cls.label != cls.id && cls.label != emitID && !cls.label.isEmpty {
            let (escapedLabel, ld) = MermaidExportHelpers.escapeBracketLabel(cls.label)
            diagnostics.append(contentsOf: ld)
            classLine = "\(pad)class \(sanitizedId)[\(escapedLabel)]"
        } else {
            classLine = "\(pad)class \(sanitizedId)"
        }

        // Style class
        let cssClasses = cls.cssClasses.trimmingCharacters(in: .whitespaces)
        if cssClasses != "default" && !cssClasses.isEmpty {
            let uniqueClasses = Set(cssClasses.split(separator: " ").map(String.init))
                .filter { !$0.isEmpty }
                .sorted()
            if !uniqueClasses.isEmpty {
                // Mermaid syntax is `class Foo:::cssClass` (no
                // whitespace between `:::` and the class name).
                classLine += ":::\(uniqueClasses.joined(separator: ","))"
            }
        }

        let hasMembers = !cls.attributes.isEmpty || !cls.methods.isEmpty
        if hasMembers {
            classLine += " {"
        }
        lines.append(classLine)

        // Members
        for attr in cls.attributes {
            lines.append("\(memberPad)\(formatMember(attr))")
        }
        for method in cls.methods {
            lines.append("\(memberPad)\(formatMember(method))")
        }

        if hasMembers {
            lines.append("\(pad)}")
        }
    }

    // MARK: - Member formatting

    private static func formatMember(_ member: ClassMember) -> String {
        let vis = member.visibility
        if member.memberType == .method {
            let params = member.parameters
            let ret = member.returnType.isEmpty ? "" : " \(member.returnType)"
            return "\(vis)\(member.id)(\(params))\(ret)"
        } else {
            return "\(vis)\(member.id) \(member.returnType)"
        }
    }

    // MARK: - Arrow conversion

    private static func classArrow(_ endpoint: ClassRelationEndpoint) -> String {
        let t1 = endpoint.type1
        let t2 = endpoint.type2
        let line = endpoint.lineType

        var left = ""
        var right = ""

        switch t1 {
        case 0: left = "o"    // aggregation
        case 1: left = "<|"   // inheritance
        case 2: left = "*"    // composition
        case 3: left = "<"    // dependency
        case 4: left = "()"   // lollipop
        default: break
        }

        switch t2 {
        case 0: right = "o"
        case 1: right = "|>"
        case 2: right = "*"
        case 3: right = ">"
        case 4: right = "()"
        default: break
        }

        let mid = line == 1 ? ".." : "--"

        if t1 == -1 {
            // Right-pointing only
            return "\(mid)\(right)"
        } else if t2 == -1 {
            return "\(left)\(mid)"
        } else {
            return "\(left)\(mid)\(right)"
        }
    }
}
