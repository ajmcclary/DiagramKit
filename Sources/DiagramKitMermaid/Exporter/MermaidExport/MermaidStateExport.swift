import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `stateDiagram-v2` source from a `ParsedGraphModel`
/// (the `DiagramPayload.stateDiagram` payload).
///
/// The app edits state diagrams on the flowchart canvas and saves this
/// output as the document, so the emission reproduces the model: parsing it
/// gives back the same states (labels, descriptions, choice/fork/join,
/// notes with their side, floating notes), the same transitions with their
/// labels, the same composite tree with directions and concurrency regions,
/// and the same `classDef` / `class` / `style` / `click` / `linkStyle`,
/// accessibility and `hide empty description` / `scale` settings.
///
/// The parser names `[*]` by its scope (`root_start`, `Active_end`), adds a
/// state to the composite it is first *mentioned* in, and creates states in
/// the order they are mentioned. So statements are replayed in an order
/// derived from the model (states before the transition that first uses
/// them, plain states and pseudostates created by that transition), each in
/// the composite or concurrency region it belongs to: a transition touching
/// `Active_start` is written inside `Active`, one between two members of a
/// region inside that region, and any other at the top level.
enum MermaidStateExport {

    static func emit(_ model: ParsedGraphModel) throws -> DiagramExportResult {
        var builder = Builder(model: model)
        return builder.build()
    }

    // MARK: - Scopes

    /// A place a statement can be written: the top level, a composite, or
    /// one concurrency region of a composite.
    struct Scope: Hashable {
        var path: [String]          // composite ids, outermost first
        var region: Int?            // region index within the last composite
        static let root = Scope(path: [], region: nil)
    }

    enum Statement {
        case declare(String)        // a state that needs its own line
        case attributes(String)     // descriptions / <<type>> after implicit creation
        case transition(Int)        // edge index
        case note(String, Int)      // note node id, attachment edge index
        case floatingNote(String)
    }

    struct Builder {
        let model: ParsedGraphModel
        var diagnostics: [DiagramDiagnostic] = []
        var aliasMap: [String: String] = [:]
        var usedAliases: Set<String> = []

        var nodes: [String: original_src_types.MermaidNode] = [:]
        var nodeOrder: [String: Int] = [:]
        var home: [String: Scope] = [:]           // node id → scope it is a member of
        var compositeScope: [String: Scope] = [:]  // composite id → its own scope
        var compositeParent: [String: Scope] = [:] // composite id → scope that contains it
        var subgraphByID: [String: original_src_types.MermaidSubgraph] = [:]
        var pseudostates: Set<String> = []
        var notes: Set<String> = []
        var noteAttachment: [String: (target: String, side: String, edge: Int)] = [:]

        init(model: ParsedGraphModel) {
            self.model = model
            for (index, entry) in model.nodesInOrder.enumerated() where nodes[entry.id] == nil {
                nodes[entry.id] = entry.node
                nodeOrder[entry.id] = index
                switch entry.node.shape {
                case .stateStart, .stateEnd: pseudostates.insert(entry.id)
                case .stateNote: notes.insert(entry.id)
                default: break
                }
            }
            func index(_ subgraphs: [original_src_types.MermaidSubgraph], parent: Scope) {
                for subgraph in subgraphs {
                    let scope = Scope(path: parent.path + [subgraph.id], region: nil)
                    subgraphByID[subgraph.id] = subgraph
                    compositeScope[subgraph.id] = scope
                    compositeParent[subgraph.id] = parent
                    for nodeId in subgraph.nodeIds where home[nodeId] == nil { home[nodeId] = scope }
                    var regionIndex = 0
                    for child in subgraph.children {
                        if Self.isRegion(child, of: subgraph) {
                            let regionScope = Scope(path: scope.path, region: regionIndex)
                            for nodeId in child.nodeIds where home[nodeId] == nil { home[nodeId] = regionScope }
                            regionIndex += 1
                        }
                    }
                    index(subgraph.children.filter { !Self.isRegion($0, of: subgraph) }, parent: scope)
                }
            }
            index(model.subgraphs, parent: .root)
            for (i, edge) in model.edges.enumerated() where edge.style == .dotted {
                if notes.contains(edge.source), !notes.contains(edge.target) {
                    noteAttachment[edge.source] = (edge.target, "left", i)
                } else if notes.contains(edge.target), !notes.contains(edge.source) {
                    noteAttachment[edge.target] = (edge.source, "right", i)
                }
            }
        }

        static func isRegion(_ child: original_src_types.MermaidSubgraph, of parent: original_src_types.MermaidSubgraph) -> Bool {
            let prefix = "\(parent.id)_region_"
            return child.id.hasPrefix(prefix) && Int(child.id.dropFirst(prefix.count)) != nil
        }

        // MARK: Identifiers

        static let stateIDRegex = try? NSRegularExpression(pattern: #"^[^\s\-{}:>]+$"#)
        static let keywords: Set<String> = ["state", "note", "class", "classDef", "style", "click", "direction", "hide", "scale", "end", "left", "right", "of", "href", "[*]"]

        mutating func alias(_ raw: String) -> String {
            if let existing = aliasMap[raw] { return existing }
            let valid = Self.stateIDRegex.map { $0.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) != nil } ?? false
            let result: String
            if valid, !Self.keywords.contains(raw), !usedAliases.contains(raw) {
                result = raw
                usedAliases.insert(raw)
            } else {
                let (sanitized, diags) = MermaidExportHelpers.sanitizeIdentifier(raw, usedAliases: &usedAliases)
                diagnostics.append(contentsOf: diags)
                result = sanitized
            }
            aliasMap[raw] = result
            return result
        }

        func pseudostateScope(_ id: String) -> Scope? {
            guard pseudostates.contains(id) else { return nil }
            let owner = id.hasSuffix("_start") ? String(id.dropLast(6)) : String(id.dropLast(4))
            return compositeScope[owner] ?? .root
        }

        /// Where an endpoint "lives" for choosing a transition's scope: a
        /// state's composite or region, a composite's parent scope.
        func endpointScope(_ id: String) -> Scope {
            if let scope = home[id] { return scope }
            if let parent = compositeParent[id] { return parent }
            return .root
        }

        func edgeScope(_ index: Int) -> Scope {
            let edge = model.edges[index]
            let source = edge.source, target = edge.target
            for (pseudo, other) in [(source, target), (target, source)] {
                if var scope = pseudostateScope(pseudo) {
                    if let composite = scope.path.last, let subgraph = subgraphByID[composite],
                       subgraph.children.contains(where: { Self.isRegion($0, of: subgraph) }) {
                        let otherScope = endpointScope(other)
                        scope.region = otherScope.path == scope.path ? otherScope.region : endpointScope(pseudo).region
                    }
                    return scope
                }
            }
            let a = endpointScope(source), b = endpointScope(target)
            // Inside a composite only when both ends are direct members:
            // the parser adds every state a transition mentions to the
            // innermost open composite.
            if a == b, home[source] != nil, home[target] != nil { return a }
            return .root
        }

        /// True when the parser creates the state, exactly as the model has
        /// it, the first time a transition mentions it.
        func createdByTransition(_ id: String) -> Bool {
            if pseudostates.contains(id) { return true }
            guard let node = nodes[id], !notes.contains(id) else { return false }
            return node.shape == .rounded && node.label == id && node.descriptions.isEmpty
        }

        /// True when the state's extras — descriptions, a <<type>>, an `as`
        /// label — can be stated after a transition created it.
        func needsAttributes(_ id: String) -> Bool {
            guard let node = nodes[id] else { return false }
            if !node.descriptions.isEmpty || [.choice, .fork, .join].contains(node.shape) { return true }
            return node.shape == .rounded && node.label != id && !node.label.isEmpty
        }

        // MARK: Statement order

        func statementOrder() -> [Statement] {
            var out: [Statement] = []
            var created: Set<String> = []
            let ordered = model.nodesInOrder.map(\.id)
            var pointer = 0
            func declareUpTo(_ id: String) {
                guard let target = nodeOrder[id] else { return }
                while pointer < target {
                    let candidate = ordered[pointer]
                    pointer += 1
                    guard !created.contains(candidate), !pseudostates.contains(candidate) else { continue }
                    if notes.contains(candidate) {
                        if noteAttachment[candidate] == nil { out.append(.floatingNote(candidate)); created.insert(candidate) }
                        continue
                    }
                    out.append(.declare(candidate))
                    created.insert(candidate)
                }
            }
            for (index, edge) in model.edges.enumerated() {
                if edge.style == .dotted, let note = [edge.source, edge.target].first(where: { notes.contains($0) }),
                   let attachment = noteAttachment[note], attachment.edge == index {
                    let target = attachment.target
                    if !created.contains(target), nodes[target] != nil {
                        declareUpTo(target)
                        if !created.contains(target) {
                            // A note creates a plain target itself, as a
                            // transition does.
                            if !createdByTransition(target) { out.append(.declare(target)) }
                            created.insert(target)
                        }
                    }
                    declareUpTo(note)
                    out.append(.note(note, index))
                    created.insert(note)
                    continue
                }
                if edge.style == .dotted, notes.contains(edge.source) || notes.contains(edge.target) {
                    // A second attachment of the same note node: written as
                    // a note on the other side carrying the same text.
                    let note = notes.contains(edge.source) ? edge.source : edge.target
                    out.append(.note(note, index))
                    continue
                }
                var implicit: [String] = []
                for endpoint in [edge.source, edge.target] where nodes[endpoint] != nil && !created.contains(endpoint) {
                    declareUpTo(endpoint)
                    guard !created.contains(endpoint) else { continue }
                    // Plain states, pseudostates, and states whose only
                    // extra is a description or a <<type>> (both can be
                    // stated after creation) are created by the transition;
                    // an `as` label must come first, since the first
                    // mention fixes it.
                    // (A state described before any transition is a
                    // rectangle; one described after stays rounded. An `as`
                    // label after creation applies, as upstream.)
                    // A state that belongs to a composite but is first
                    // named by a transition outside it (`Start --> In2`
                    // with In2 inside `Comp`) is declared in its composite
                    // first: the transition would create it where it is
                    // written.
                    let elsewhere = !pseudostates.contains(endpoint) && compositeScope[endpoint] == nil
                        && home[endpoint] != nil && endpointScope(endpoint) != edgeScope(index)
                    if !elsewhere, createdByTransition(endpoint) || needsAttributes(endpoint) && nodes[endpoint]?.shape != .rectangle {
                        implicit.append(endpoint)
                    } else {
                        out.append(.declare(endpoint))
                    }
                    created.insert(endpoint)
                }
                out.append(.transition(index))
                for id in implicit where needsAttributes(id) { out.append(.attributes(id)) }
            }
            for id in ordered where !created.contains(id) && !pseudostates.contains(id) {
                if notes.contains(id) {
                    if noteAttachment[id] == nil { out.append(.floatingNote(id)) }
                    continue
                }
                out.append(.declare(id))
                created.insert(id)
            }
            return out
        }

        func scope(of statement: Statement) -> Scope {
            switch statement {
            case .declare(let id), .attributes(let id), .floatingNote(let id): return home[id] ?? .root
            case .note(let id, _): return home[id] ?? .root
            case .transition(let index): return edgeScope(index)
            }
        }

        // MARK: Lines

        mutating func lines(for statement: Statement, pad: String) -> [String] {
            switch statement {
            case .declare(let id):
                guard let node = nodes[id] else { return [] }
                let name = alias(id)
                switch node.shape {
                case .choice: return ["\(pad)state \(name) <<choice>>"]
                case .fork: return ["\(pad)state \(name) <<fork>>"]
                case .join: return ["\(pad)state \(name) <<join>>"]
                default: break
                }
                if !node.descriptions.isEmpty {
                    return node.descriptions.map { "\(pad)\(name) : \(text($0))" }
                }
                if node.label != id, !node.label.isEmpty {
                    if node.label.contains("\"") {
                        diagnostics.append(.lossyTransform(.labelNewlineEscape, message: "[State] label of '\(id)': '\"' written as \"'\""))
                    }
                    return ["\(pad)state \"\(text(node.label).replacingOccurrences(of: "\"", with: "'"))\" as \(name)"]
                }
                return ["\(pad)state \(name)"]
            case .attributes(let id):
                guard let node = nodes[id] else { return [] }
                let name = alias(id)
                switch node.shape {
                case .choice: return ["\(pad)state \(name) <<choice>>"]
                case .fork: return ["\(pad)state \(name) <<fork>>"]
                case .join: return ["\(pad)state \(name) <<join>>"]
                default:
                    if node.descriptions.isEmpty { return lines(for: .declare(id), pad: pad) }
                    return node.descriptions.map { "\(pad)\(name) : \(text($0))" }
                }
            case .transition(let index):
                let edge = model.edges[index]
                let source = endpointText(edge.source), target = endpointText(edge.target)
                if let label = edge.label, !label.isEmpty {
                    return ["\(pad)\(source) --> \(target) : \(text(label))"]
                }
                return ["\(pad)\(source) --> \(target)"]
            case .note(let id, let edgeIndex):
                guard let node = nodes[id] else { return [] }
                let edge = model.edges[edgeIndex]
                let side = edge.target == id ? "right" : "left"
                let target = alias(edge.target == id ? edge.source : edge.target)
                if node.label.contains("\n") {
                    return ["\(pad)note \(side) of \(target)"]
                        + node.label.components(separatedBy: "\n").map { "\(pad)  \($0)" }
                        + ["\(pad)end note"]
                }
                return ["\(pad)note \(side) of \(target) : \(node.label)"]
            case .floatingNote(let id):
                guard let node = nodes[id] else { return [] }
                return ["\(pad)note \"\(text(node.label).replacingOccurrences(of: "\"", with: "'"))\" as \(alias(id))"]
            }
        }

        mutating func endpointText(_ id: String) -> String {
            pseudostates.contains(id) ? "[*]" : alias(id)
        }

        func text(_ value: String) -> String {
            value.replacingOccurrences(of: "\r\n", with: "<br>")
                .replacingOccurrences(of: "\n", with: "<br>")
                .replacingOccurrences(of: "\r", with: "<br>")
        }

        // MARK: Assembly

        mutating func build() -> DiagramExportResult {
            var out: [String] = ["stateDiagram-v2"]
            if model.direction != .TD {
                out.append("  direction \(model.direction.rawValue)")
            }
            if let title = model.accTitle, !title.isEmpty { out.append("  accTitle: \(text(title))") }
            if let descr = model.accDescr, !descr.isEmpty { out.append("  accDescr: \(text(descr))") }
            if model.stateConfig.hideEmptyDescription { out.append("  hide empty description") }
            if let scale = model.stateConfig.scaleWidth { out.append("  scale \(scale) width") }

            // Reserve aliases in model order so names are stable.
            for (id, _) in model.nodesInOrder where !pseudostates.contains(id) { _ = alias(id) }
            for id in subgraphByID.keys.sorted() { _ = alias(id) }

            let statements = statementOrder()
            var byScope: [Scope: [Statement]] = [:]
            var firstUse: [Scope: Int] = [:]
            for (rank, statement) in statements.enumerated() {
                let scope = scope(of: statement)
                byScope[scope, default: []].append(statement)
                // A composite is opened where anything inside it is first used.
                var path = scope.path
                while !path.isEmpty {
                    let key = Scope(path: path, region: nil)
                    if firstUse[key] == nil { firstUse[key] = rank }
                    path.removeLast()
                }
            }

            out += emitScope(.root, depth: 1, byScope: byScope, firstUse: firstUse, statements: statements)

            out += styling()
            return DiagramExportResult(source: out.joined(separator: "\n") + "\n", diagnostics: diagnostics)
        }

        /// Lines for one scope: its statements in replay order, with each
        /// child composite opened at the position of its first statement
        /// (empty composites last). A composite with concurrency regions
        /// writes its regions in order, separated by `--`.
        mutating func emitScope(
            _ scope: Scope,
            depth: Int,
            byScope: [Scope: [Statement]],
            firstUse: [Scope: Int],
            statements: [Statement]
        ) -> [String] {
            let pad = String(repeating: "  ", count: depth)
            var lines: [String] = []
            let children: [original_src_types.MermaidSubgraph]
            if let id = scope.path.last, let subgraph = subgraphByID[id] {
                children = subgraph.children.filter { !Self.isRegion($0, of: subgraph) }
            } else if scope.path.isEmpty {
                children = model.subgraphs
            } else {
                children = []
            }
            let childScopes = children.map { Scope(path: scope.path + [$0.id], region: nil) }

            // Interleave own statements and child blocks by replay rank.
            let own = (byScope[scope] ?? [])
            let rankOf: (Statement) -> Int = { statement in
                statements.firstIndex(where: { Self.sameStatement($0, statement) }) ?? Int.max
            }
            var items: [(rank: Int, child: Int?, statement: Statement?)] = own.map { (rankOf($0), nil, $0) }
            for (i, childScope) in childScopes.enumerated() {
                items.append((firstUse[childScope] ?? Int.max - children.count + i, i, nil))
            }
            items.sort { $0.rank < $1.rank }
            for item in items {
                if let statement = item.statement {
                    lines += self.lines(for: statement, pad: pad)
                } else if let index = item.child {
                    lines += emitComposite(children[index], scope: childScopes[index], depth: depth, byScope: byScope, firstUse: firstUse, statements: statements)
                }
            }
            return lines
        }

        mutating func emitComposite(
            _ subgraph: original_src_types.MermaidSubgraph,
            scope: Scope,
            depth: Int,
            byScope: [Scope: [Statement]],
            firstUse: [Scope: Int],
            statements: [Statement]
        ) -> [String] {
            let pad = String(repeating: "  ", count: depth)
            let name = alias(subgraph.id)
            var lines: [String] = []
            if !subgraph.label.isEmpty, subgraph.label != subgraph.id {
                lines.append("\(pad)state \"\(text(subgraph.label).replacingOccurrences(of: "\"", with: "'"))\" as \(name) {")
            } else {
                lines.append("\(pad)state \(name) {")
            }
            if let direction = subgraph.direction {
                lines.append("\(pad)  direction \(direction.rawValue)")
            }
            let regionCount = subgraph.children.filter { Self.isRegion($0, of: subgraph) }.count
            if regionCount > 0 {
                for region in 0..<regionCount {
                    if region > 0 { lines.append("\(pad)  --") }
                    let regionScope = Scope(path: scope.path, region: region)
                    for statement in byScope[regionScope] ?? [] {
                        lines += self.lines(for: statement, pad: pad + "  ")
                    }
                }
            }
            lines += emitScope(scope, depth: depth + 1, byScope: byScope, firstUse: firstUse, statements: statements)
            lines.append("\(pad)}")
            return lines
        }

        static func sameStatement(_ a: Statement, _ b: Statement) -> Bool {
            switch (a, b) {
            case let (.declare(x), .declare(y)), let (.attributes(x), .attributes(y)), let (.floatingNote(x), .floatingNote(y)):
                return x == y
            case let (.transition(x), .transition(y)): return x == y
            case let (.note(x, i), .note(y, j)): return x == y && i == j
            default: return false
            }
        }

        // MARK: Styles, classes, links

        mutating func styling() -> [String] {
            var lines: [String] = []
            if let defaults = model.defaultClassDef, !defaults.isEmpty {
                lines.append("  classDef default \(MermaidFlowchartSyntax.css(defaults))")
            }
            for (name, styles) in model.classDefs.sorted(by: { $0.key < $1.key }) {
                lines.append("  classDef \(name) \(MermaidFlowchartSyntax.css(styles))")
            }
            for (id, classes) in model.classAssignments.sorted(by: { $0.key < $1.key }) {
                let target = pseudostates.contains(id) ? nil : alias(id)
                guard let target else {
                    diagnostics.append(.lossyTransform(.styleDrop, message: "[State] class on a [*] pseudostate has no syntax; dropped"))
                    continue
                }
                for cls in classes { lines.append("  class \(target) \(cls)") }
            }
            for (edgeId, cls) in model.edgeClassAssignments.sorted(by: { $0.key < $1.key }) {
                lines.append("  class \(edgeId) \(cls)")
            }
            for (id, styles) in model.nodeStyles.sorted(by: { $0.key < $1.key }) where !styles.isEmpty {
                lines.append("  style \(alias(id)) \(MermaidFlowchartSyntax.css(styles))")
            }
            for (index, styles) in model.linkStyles.sorted(by: { $0.key < $1.key }) where !styles.isEmpty {
                lines.append("  linkStyle \(index < 0 ? "default" : String(index)) \(MermaidFlowchartSyntax.css(styles))")
            }
            for (id, interaction) in model.nodeInteractions.sorted(by: { $0.key < $1.key }) {
                let (clickText, diags) = MermaidFlowchartSyntax.click(interaction, nodeID: id)
                diagnostics.append(contentsOf: diags)
                if let clickText { lines.append("  click \(alias(id)) \(clickText)") }
            }
            return lines
        }
    }
}
