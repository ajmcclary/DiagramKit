// Visual editor — deduplicated generated-classDef lifecycle.
// Style edits from the visual editor land as shared `vsN` classDefs:
// one class per unique style, reused across nodes, orphans removed.
// User-authored classDefs are never edited or GC'd.

import DiagramKitCommon
import DiagramKitModel

public enum StyleClassManager {

    /// A classDef name is "generated" iff it is `vs` followed by one
    /// or more digits. A user who hand-writes such a name opts into
    /// generated-class semantics (documented in the design spec).
    public static func isGeneratedClassName(_ name: String) -> Bool {
        guard name.hasPrefix("vs") else { return false }
        let digits = name.dropFirst(2)
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    /// Apply `spec` to `nodeID`: migrate any inline style, drop the
    /// node's previous generated-class assignment, find-or-create the
    /// class matching `spec`, and garbage-collect orphaned generated
    /// classes. Pure — returns the updated graph.
    public static func applyStyle(
        _ spec: NodeStyleSpec,
        toNode nodeID: String,
        in graph: original_src_types.MermaidGraph
    ) -> (graph: original_src_types.MermaidGraph, diagnostics: [DiagramDiagnostic]) {
        var graph = graph
        var diagnostics: [DiagramDiagnostic] = []

        if graph.nodeStyles[nodeID] != nil {
            graph.nodeStyles.removeValue(forKey: nodeID)
            diagnostics.append(.informational(
                .styleClassMigration,
                message: "Inline 'style \(nodeID) …' replaced by a generated classDef assignment"
            ))
        }

        var assignments = graph.classAssignments[nodeID] ?? []
        assignments.removeAll(where: isGeneratedClassName)

        let props = spec.classDefProperties
        if !props.isEmpty {
            let reusable = graph.classDefs
                .filter { isGeneratedClassName($0.key) && $0.value == props }
                .keys
                .sorted()
                .first
            let className: String
            if let reusable {
                className = reusable
            } else {
                var n = 1
                while graph.classDefs["vs\(n)"] != nil { n += 1 }
                className = "vs\(n)"
                graph.classDefs[className] = props
            }
            assignments.append(className)
        }

        if assignments.isEmpty {
            graph.classAssignments.removeValue(forKey: nodeID)
        } else {
            graph.classAssignments[nodeID] = assignments
        }

        let referenced = Set(graph.classAssignments.values.flatMap { $0 })
            .union(graph.edgeClassAssignments.values)
            .union(graph.edges.flatMap { $0.classes ?? [] })
        for name in graph.classDefs.keys where isGeneratedClassName(name) && !referenced.contains(name) {
            graph.classDefs.removeValue(forKey: name)
        }

        return (graph, diagnostics)
    }

    /// Resolve the node's effective style for seeding the node menu:
    /// default classDef → assigned classes in order (later wins,
    /// matching mermaid-js) → inline `style` overrides.
    public static func effectiveStyle(
        forNode nodeID: String,
        in graph: original_src_types.MermaidGraph
    ) -> NodeStyleSpec {
        var merged: [String: String] = graph.defaultClassDef ?? [:]
        for className in graph.classAssignments[nodeID] ?? [] {
            if let def = graph.classDefs[className] {
                merged.merge(def) { _, new in new }
            }
        }
        if let inline = graph.nodeStyles[nodeID] {
            merged.merge(inline) { _, new in new }
        }
        return NodeStyleSpec(classDefProperties: merged)
    }
}
