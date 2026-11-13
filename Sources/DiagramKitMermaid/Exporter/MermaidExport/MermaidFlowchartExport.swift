import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid flowchart source from a `ParsedGraphModel`.
///
/// `DiagramEditor` writes this output back as the document text after every
/// canvas edit, so the emission is lossless for everything the Mermaid
/// parser models: parsing the output gives back the same node order,
/// subgraph tree and membership, shapes, edges (style, arrowheads, labels,
/// ids, metadata), `linkStyle` (indexed and `default`), `classDef` /
/// `class` / `style`, `click`, and accessibility text. Output is
/// deterministic: every dictionary is written in sorted key order.
///
/// Membership needs care because the parser only adds a node to a subgraph
/// when the node is *declared* inside the block (a bare reference to an
/// already-declared node is not membership). The usual form declares each
/// member inside its block, at the position that keeps the model's node
/// order. When no such position exists (a node in two subgraphs, or a
/// group whose members are interleaved with outside nodes), every node is
/// declared first at top level in model order and each block re-declares
/// its members.
enum MermaidFlowchartExport {

    static func emit(_ model: ParsedGraphModel) throws -> DiagramExportResult {
        var context = Context(model: model)
        var lines: [String] = []
        lines.append(header(for: model))
        if let title = model.accTitle, !title.isEmpty {
            lines.append("  accTitle: \(singleLine(title))")
        }
        if let descr = model.accDescr, !descr.isEmpty {
            let parts = descr.components(separatedBy: "\n")
            if parts.count == 1 {
                lines.append("  accDescr: \(descr)")
            } else {
                lines.append("  accDescr {")
                lines.append(contentsOf: parts.map { "    \($0)" })
                lines.append("  }")
            }
        }

        lines.append(contentsOf: context.nodesAndSubgraphs())
        lines.append(contentsOf: context.edges())
        lines.append(contentsOf: context.styling())
        lines.append(contentsOf: context.interactions())

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: context.diagnostics)
    }

    private static func header(for model: ParsedGraphModel) -> String {
        let direction: String
        switch model.direction {
        case .TD: direction = "TD"
        case .TB: direction = "TB"
        case .LR: direction = "LR"
        case .BT: direction = "BT"
        case .RL: direction = "RL"
        }
        return model.rendererType == "elk" ? "flowchart-elk \(direction)" : "graph \(direction)"
    }

    static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    // MARK: - Emission state

    struct Context {
        let model: ParsedGraphModel
        var diagnostics: [DiagramDiagnostic] = []
        /// One alias per raw id. Nodes and subgraphs share the namespace (an
        /// edge may target either), and two subgraphs that share an id keep
        /// sharing it, so the export parses back to the same model.
        var aliasMap: [String: String] = [:]
        var usedAliases: Set<String> = []
        let nodesById: [String: original_src_types.MermaidNode]
        /// Ids used by a subgraph. A bare mention of one is not a node
        /// declaration, so a node sharing the id is always written with a shape.
        let subgraphIDs: Set<String>

        init(model: ParsedGraphModel) {
            self.model = model
            var byId: [String: original_src_types.MermaidNode] = [:]
            for entry in model.nodesInOrder where byId[entry.id] == nil {
                byId[entry.id] = entry.node
            }
            self.nodesById = byId
            var ids: Set<String> = []
            func collect(_ subgraphs: [original_src_types.MermaidSubgraph]) {
                for subgraph in subgraphs {
                    ids.insert(subgraph.id)
                    collect(subgraph.children)
                }
            }
            collect(model.subgraphs)
            self.subgraphIDs = ids
        }

        mutating func alias(for raw: String, isSubgraph: Bool = false) -> String {
            if let existing = aliasMap[raw] { return existing }
            let alias: String
            if MermaidFlowchartSyntax.isVerbatimIdentifier(raw, subgraph: isSubgraph), !usedAliases.contains(raw) {
                usedAliases.insert(raw)
                alias = raw
            } else {
                let (sanitized, diags) = MermaidExportHelpers.sanitizeIdentifier(raw, usedAliases: &usedAliases)
                diagnostics.append(contentsOf: diags)
                alias = sanitized
            }
            aliasMap[raw] = alias
            return alias
        }

        // MARK: Nodes and subgraphs

        mutating func nodesAndSubgraphs() -> [String] {
            // Aliases are assigned in a fixed order (nodes, then subgraphs in
            // tree order) so both emission forms name things identically.
            for entry in model.nodesInOrder { _ = alias(for: entry.id) }
            func reserve(_ subgraphs: [original_src_types.MermaidSubgraph]) {
                for subgraph in subgraphs {
                    _ = alias(for: subgraph.id, isSubgraph: true)
                    reserve(subgraph.children)
                }
            }
            reserve(model.subgraphs)

            if let nested = nestedForm() { return nested }
            return flatForm()
        }

        /// Members declared inside their blocks. Returns nil when that form
        /// cannot reproduce the model's node order and membership.
        mutating func nestedForm() -> [String]? {
            var owner: [String: [Int]] = [:]
            var memberLists: [[Int]: [String]] = [:]
            var multiplyOwned = false
            func index(_ subgraphs: [original_src_types.MermaidSubgraph], _ prefix: [Int]) {
                for (i, subgraph) in subgraphs.enumerated() {
                    let path = prefix + [i]
                    memberLists[path] = subgraph.nodeIds
                    for nodeId in subgraph.nodeIds {
                        if owner[nodeId] != nil { multiplyOwned = true }
                        owner[nodeId] = path
                    }
                    index(subgraph.children, path)
                }
            }
            index(model.subgraphs, [])
            if multiplyOwned { return nil }
            // Every member must be a node, listed in model order.
            let order = Dictionary(model.nodesInOrder.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
            for (_, members) in memberLists {
                guard members.allSatisfy({ order[$0] != nil }) else { return nil }
                let positions = members.compactMap { order[$0] }
                if positions != positions.sorted() { return nil }
            }

            var lines: [String] = []
            var declared: [String] = []
            let nodes = model.nodesInOrder
            func emitLevel(
                children: [original_src_types.MermaidSubgraph],
                path: [Int],
                depth: Int,
                context: inout Context
            ) {
                var emittedChildren = 0
                func emitChild(_ i: Int, context: inout Context) {
                    let child = children[i]
                    let childPath = path + [i]
                    lines.append(contentsOf: context.subgraphHeader(child, depth: depth))
                    emitLevel(children: child.children, path: childPath, depth: depth + 1, context: &context)
                    lines.append("\(String(repeating: "  ", count: depth + 1))end")
                }
                for entry in nodes {
                    let nodePath = owner[entry.id] ?? []
                    guard nodePath.starts(with: path) else { continue }
                    if nodePath == path {
                        declared.append(entry.id)
                        lines.append(String(repeating: "  ", count: depth + 1)
                            + context.declaration(for: entry.node, id: entry.id, forceBracket: false))
                    } else {
                        let childIndex = nodePath[path.count]
                        while emittedChildren <= childIndex {
                            emitChild(emittedChildren, context: &context)
                            emittedChildren += 1
                        }
                    }
                }
                while emittedChildren < children.count {
                    emitChild(emittedChildren, context: &context)
                    emittedChildren += 1
                }
            }
            var scratch = self
            emitLevel(children: model.subgraphs, path: [], depth: 0, context: &scratch)
            guard declared == model.nodesInOrder.map(\.id) else { return nil }
            self = scratch
            return lines
        }

        /// Every node declared at top level in model order, then each block
        /// re-declaring its members (a re-declaration with a shape is what
        /// the parser records as membership).
        mutating func flatForm() -> [String] {
            var lines: [String] = []
            for entry in model.nodesInOrder {
                lines.append("  " + declaration(for: entry.node, id: entry.id, forceBracket: false))
            }
            func emitBlock(_ subgraph: original_src_types.MermaidSubgraph, depth: Int, context: inout Context) {
                lines.append(contentsOf: context.subgraphHeader(subgraph, depth: depth))
                for nodeId in subgraph.nodeIds {
                    guard let node = context.nodesById[nodeId] else {
                        context.diagnostics.append(.lossyTransform(
                            .subgraphFlatten,
                            message: "[Flowchart] subgraph \"\(subgraph.id)\" lists unknown node \"\(nodeId)\"; membership dropped"
                        ))
                        continue
                    }
                    lines.append(String(repeating: "  ", count: depth + 2)
                        + context.declaration(for: node, id: nodeId, forceBracket: true))
                }
                for child in subgraph.children { emitBlock(child, depth: depth + 1, context: &context) }
                lines.append("\(String(repeating: "  ", count: depth + 1))end")
            }
            for subgraph in model.subgraphs { emitBlock(subgraph, depth: 0, context: &self) }
            return lines
        }

        mutating func subgraphHeader(_ subgraph: original_src_types.MermaidSubgraph, depth: Int) -> [String] {
            let pad = String(repeating: "  ", count: depth + 1)
            var out: [String] = []
            let alias = alias(for: subgraph.id, isSubgraph: true)
            // `subgraph X` alone reads as id X and label X. Anonymous
            // subgraphs keep their generated id explicitly: a bare
            // `subgraph` would be renumbered by position.
            if subgraph.label == alias, MermaidFlowchartSyntax.isWord(alias) {
                out.append("\(pad)subgraph \(alias)")
            } else {
                out.append("\(pad)subgraph \(alias) [\(MermaidFlowchartSyntax.subgraphLabel(subgraph.label))]")
            }
            if let dir = subgraph.direction {
                out.append("\(pad)  direction \(dir.rawValue)")
            }
            return out
        }

        mutating func declaration(
            for node: original_src_types.MermaidNode,
            id: String,
            forceBracket: Bool
        ) -> String {
            let alias = alias(for: id)
            let (text, diags) = MermaidFlowchartSyntax.nodeDeclaration(
                node, alias: alias, forceBracket: forceBracket || subgraphIDs.contains(id)
            )
            diagnostics.append(contentsOf: diags)
            return text
        }

        // MARK: Edges

        mutating func edges() -> [String] {
            var lines: [String] = []
            // Standalone `eN@{ … }` metadata applies to edges declared after
            // it, so write it before the edges when an edge carries exactly
            // those properties, and after them otherwise.
            var early: Set<String> = []
            var late: [String] = []
            for (edgeId, props) in model.edgeProperties.sorted(by: { $0.key < $1.key }) {
                let applies = model.edges.contains { $0.id == edgeId && MermaidFlowchartSyntax.sameProperties($0.properties, props) }
                let line = "  \(edgeId)@{ \(MermaidFlowchartSyntax.edgeMetadataPairs(props).joined(separator: ", ")) }"
                if applies {
                    early.insert(edgeId)
                    lines.append(line)
                } else {
                    late.append(line)
                }
            }
            for edge in model.edges {
                let source = alias(for: edge.source)
                let target = alias(for: edge.target)
                var inline: original_src_types.NodeProperties? = edge.properties
                if let edgeId = edge.id, early.contains(edgeId) { inline = nil }
                let (op, diags) = MermaidFlowchartSyntax.edgeOperator(edge, inlineProperties: inline)
                diagnostics.append(contentsOf: diags)
                var idPrefix = ""
                if let edgeId = edge.id {
                    if MermaidFlowchartSyntax.isEdgeID(edgeId) {
                        idPrefix = "\(edgeId)@"
                    } else {
                        diagnostics.append(.lossyTransform(
                            .idSanitization,
                            message: "[Flowchart] edge id '\(edgeId)' is not of the form eN; dropped"
                        ))
                    }
                }
                lines.append("  \(source) \(idPrefix)\(op) \(target)")
            }
            lines.append(contentsOf: late)
            return lines
        }

        // MARK: Styles and classes

        mutating func styling() -> [String] {
            var lines: [String] = []
            for (index, styles) in model.linkStyles.sorted(by: { $0.key < $1.key }) where !styles.isEmpty {
                let target = index < 0 ? "default" : String(index)
                lines.append("  linkStyle \(target) \(MermaidFlowchartSyntax.css(styles))")
            }
            if let defaults = model.defaultClassDef, !defaults.isEmpty {
                lines.append("  classDef default \(MermaidFlowchartSyntax.css(defaults))")
            }
            for (name, styles) in model.classDefs.sorted(by: { $0.key < $1.key }) {
                lines.append("  classDef \(name) \(MermaidFlowchartSyntax.css(styles))")
            }
            for (nodeId, classNames) in model.classAssignments.sorted(by: { $0.key < $1.key }) {
                let alias = alias(for: nodeId)
                for className in classNames {
                    lines.append("  class \(alias) \(className)")
                }
            }
            for (edgeId, className) in model.edgeClassAssignments.sorted(by: { $0.key < $1.key }) {
                lines.append("  class \(edgeId) \(className)")
            }
            for (nodeId, styles) in model.nodeStyles.sorted(by: { $0.key < $1.key }) where !styles.isEmpty {
                lines.append("  style \(alias(for: nodeId)) \(MermaidFlowchartSyntax.css(styles))")
            }
            return lines
        }

        // MARK: click

        mutating func interactions() -> [String] {
            var lines: [String] = []
            for (nodeId, interaction) in model.nodeInteractions.sorted(by: { $0.key < $1.key }) {
                let alias = alias(for: nodeId)
                let (text, diags) = MermaidFlowchartSyntax.click(interaction, nodeID: nodeId)
                diagnostics.append(contentsOf: diags)
                if let text { lines.append("  click \(alias) \(text)") }
            }
            return lines
        }
    }
}
