import Foundation
import Testing
import DiagramKit
import DiagramKitMermaid
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
import DiagramKitTestSupport

// The app writes `MermaidExporter`'s output back as the document text after
// every canvas edit, so for flowcharts the exporter must be lossless:
// parse → export → parse has to give back the model it started from, field
// for field, and the export has to be byte-stable so an edit does not
// reorder unrelated lines.

/// A canonical, order-preserving description of everything a flowchart
/// document carries. Two documents with the same fingerprint lay out and
/// render the same.
///
/// `NodeProperties.shape` is left out on purpose: it is the raw alias the
/// author wrote (`lean-r`, `docs`), which the parser has already resolved
/// into `MermaidNode.shape`; nothing reads it afterwards.
func flowchartFingerprint(_ document: DiagramDocument) -> String {
    var out: [String] = []
    out.append("title=\(document.title ?? "∅")")
    if let fm = document.frontmatter {
        out.append("theme=\(fm.theme ?? "∅") layout=\(fm.layout ?? "∅")")
        for entry in fm.preservedEntries {
            out.append("fm \(entry.path)=\(entry.value)")
        }
    }
    guard case .flowchart(let g) = document.payload else {
        out.append("payload=\(document.type.rawValue)")
        return out.joined(separator: "\n")
    }
    out.append("direction=\(g.direction.rawValue)")
    for (id, node) in g.nodesInOrder {
        out.append("node \(id) label=\(node.label) shape=\(node.shape.rawValue) descr=\(node.descriptions) props=\(propertiesFingerprint(node.properties))")
    }
    for (i, e) in g.edges.enumerated() {
        out.append(
            "edge[\(i)] \(e.source)->\(e.target) label=\(e.label ?? "∅") style=\(e.style.rawValue) id=\(e.id ?? "∅") " +
            "heads=\(e.arrowHeadStart.rawValue),\(e.arrowHeadEnd.rawValue) inline=\(sortedDict(e.inlineStyle)) " +
            "props=\(propertiesFingerprint(e.properties)) animate=\(e.animate.map(String.init) ?? "∅") " +
            "speed=\(e.animationSpeed ?? "∅") classes=\(e.classes ?? []) curve=\(e.curve ?? "∅") minlen=\(e.minlen ?? 0)"
        )
    }
    func walk(_ s: original_src_types.MermaidSubgraph, _ depth: Int) {
        out.append(
            "\(String(repeating: "  ", count: depth))subgraph \(s.id) label=\(s.label) nodes=\(s.nodeIds) " +
            "dir=\(s.direction?.rawValue ?? "∅") shape=\(s.shape?.rawValue ?? "∅") alt=\(s.altBkg)"
        )
        for child in s.children { walk(child, depth + 1) }
    }
    for s in g.subgraphs { walk(s, 0) }
    for (name, styles) in g.classDefs.sorted(by: { $0.key < $1.key }) {
        out.append("classDef \(name) \(sortedDict(styles))")
    }
    out.append("defaultClassDef \(sortedDict(g.defaultClassDef))")
    for (id, classes) in g.classAssignments.sorted(by: { $0.key < $1.key }) {
        out.append("class \(id) \(classes)")
    }
    for (id, styles) in g.nodeStyles.sorted(by: { $0.key < $1.key }) {
        out.append("style \(id) \(sortedDict(styles))")
    }
    for (index, styles) in g.linkStyles.sorted(by: { $0.key < $1.key }) {
        out.append("linkStyle \(index) \(sortedDict(styles))")
    }
    out.append("accTitle=\(g.accTitle ?? "∅") accDescr=\(g.accDescr ?? "∅")")
    if let c = g.config {
        out.append(
            "config curve=\(c.curve ?? "∅") html=\(c.htmlLabels.map(String.init) ?? "∅") " +
            "wrap=\(c.markdownAutoWrap.map(String.init) ?? "∅") width=\(c.width.map(String.init) ?? "∅") " +
            "inherit=\(c.inheritDir.map(String.init) ?? "∅") security=\(c.securityLevel ?? "∅") preset=\(c.layoutPreset ?? "∅")"
        )
    } else {
        out.append("config=∅")
    }
    out.append("renderer=\(g.rendererType ?? "∅")")
    for (id, interaction) in g.nodeInteractions.sorted(by: { $0.key < $1.key }) {
        let kind: String
        switch interaction.type {
        case .callback(let name): kind = "callback(\(name))"
        case .call(let name, let args): kind = "call(\(name),\(args))"
        case .href(let url): kind = "href(\(url))"
        }
        out.append("click \(id) \(kind) tip=\(interaction.tooltip ?? "∅") target=\(interaction.target ?? "∅")")
    }
    for (id, cls) in g.edgeClassAssignments.sorted(by: { $0.key < $1.key }) {
        out.append("edgeClass \(id) \(cls)")
    }
    for (id, props) in g.edgeProperties.sorted(by: { $0.key < $1.key }) {
        out.append("edgeProps \(id) \(propertiesFingerprint(props))")
    }
    return out.joined(separator: "\n")
}

private func sortedDict(_ dict: [String: String]?) -> String {
    guard let dict else { return "∅" }
    return dict.sorted(by: { $0.key < $1.key }).map { "\($0.key):\($0.value)" }.joined(separator: ";")
}

private func propertiesFingerprint(_ p: original_src_types.NodeProperties?) -> String {
    guard let p else { return "∅" }
    let unset = p.label == nil && p.icon == nil && p.form == nil && p.pos == nil && p.img == nil
        && p.w == nil && p.h == nil && p.constraint == nil && p.animate == nil && p.animation == nil && p.curve == nil
    if unset { return "∅" }
    let parts: [String] = [
        "label=\(p.label ?? "∅")", "icon=\(p.icon ?? "∅")", "form=\(p.form ?? "∅")",
        "pos=\(p.pos ?? "∅")", "img=\(p.img ?? "∅")", "w=\(p.w.map { "\($0)" } ?? "∅")",
        "h=\(p.h.map { "\($0)" } ?? "∅")", "constraint=\(p.constraint ?? "∅")",
        "animate=\(p.animate.map(String.init) ?? "∅")", "animation=\(p.animation ?? "∅")",
        "curve=\(p.curve ?? "∅")",
    ]
    return "{" + parts.joined(separator: ",") + "}"
}

/// Hand-written sources covering the features the canvas editor rewrites:
/// nested subgraphs with directions, every classic node shape, labelled
/// edges with every arrowhead, `linkStyle` (indexed and default),
/// `classDef`/`class`, `click`, accessibility text and frontmatter config.
let flowchartFidelityFixtures: [(name: String, source: String)] = [
    ("subgraphs-and-styles", """
    ---
    title: Round trip
    config:
      theme: forest
      flowchart:
        curve: basis
        htmlLabels: false
      themeVariables:
        primaryColor: "#ffcc00"
        lineColor: "#333"
    ---
    flowchart LR
      accTitle: Accessible title
      accDescr: Accessible description
      subgraph Outer [Outer group]
        direction TB
        A[Alpha] --> B(Beta)
        subgraph Inner
          direction LR
          C[/Trap\\] --> D[/Para/]
          E[\\Alt/] --> F[\\ParaAlt\\]
        end
      end
      subgraph S2
        G{{Hex}} -->|plain| H((Circle))
      end
      H --o|open end| I>Asym]
      I --x|cross end| J[(Db)]
      J <-->|both| K([Stadium])
      K -.->|dotted| L[[Sub]]
      L ==>|thick| M{Diamond}
      M ~~~|hidden| N
      N -.- O
      O === P
      P o--o Q
      Q x--x R
      R --> S(((Double)))
      S --> T(-Ellipse-)
      T --> Outer
      linkStyle default stroke:#999
      linkStyle 0 stroke:red,stroke-width:2px
      linkStyle 3,4 stroke:blue
      classDef hot fill:#f96,stroke:#333,stroke-width:2px,color:#000
      classDef cold fill:#9cf
      classDef default fill:#eee
      class A,B hot
      class C cold
      D:::hot
      style G fill:#bbf,stroke:#f66
      click A href "https://example.com" "Go to example" _blank
      click B callbackFn "Run callback"
      click C call doThing()
    """),
    ("duplicate-subgraph-ids", """
    flowchart TD
      subgraph S
        A
      end
      subgraph S
        B
      end
    """),
    ("membership-out-of-order", """
    flowchart TD
      X[Outside first]
      subgraph G [Group]
        Y[Inside]
      end
      Z[Outside last]
      subgraph G2
        W
      end
      X --> Y
      Y --> Z
    """),
    ("labels-equal-ids-and-metadata", """
    flowchart TD
      A(A) --> B{B}
      C@{ shape: cloud, label: "Cloud node" }
      D@{ shape: docs }
      E[Sized]@{ w: 120, h: 40 }
      A e1@--> C
      e1@{ animate: true, curve: basis }
      class e1 animate
    """),
    ("init-directive", """
    %%{init: {"theme": "dark", "flowchart": {"curve": "linear"}}}%%
    graph TD
      A --> B
    """),
]

private func parseFlowchart(_ source: String) throws -> DiagramDocument {
    try MermaidImporter().parse(source).document
}

private func exportMermaid(_ document: DiagramDocument) throws -> DiagramExportResult {
    try MermaidExporter().export(document)
}

/// The flowchart entries of the canonical corpus plus the fixtures above.
private func flowchartRoundTripInputs() throws -> [(name: String, source: String)] {
    let corpus = try DiagramCorpus.load().compactMap { entry -> (String, String)? in
        guard let doc = try? parseFlowchart(entry.source), doc.type == .flowchart else { return nil }
        return (entry.id, entry.source)
    }
    return corpus + flowchartFidelityFixtures
}

@Suite("Flowchart Mermaid export fidelity")
struct FlowchartExportFidelityTests {

    @Test("parse → export → parse gives back the same flowchart, for every corpus flowchart and fixture")
    func roundTripPreservesTheModel() throws {
        let inputs = try flowchartRoundTripInputs()
        #expect(inputs.count > flowchartFidelityFixtures.count + 20)
        var failures: [String] = []
        for (name, source) in inputs {
            let original = try parseFlowchart(source)
            let exported = try exportMermaid(original)
            let reparsed: DiagramDocument
            do {
                reparsed = try parseFlowchart(exported.source)
            } catch {
                failures.append("[\(name)] reparse threw \(error)\n\(exported.source)")
                continue
            }
            let before = flowchartFingerprint(original)
            let after = flowchartFingerprint(reparsed)
            if before != after {
                let a = before.split(separator: "\n"), b = after.split(separator: "\n")
                let firstDiff = zip(a, b).first(where: { $0 != $1 }).map { "  lhs: \($0)\n  rhs: \($1)" }
                    ?? "  line count \(a.count) vs \(b.count)"
                failures.append("[\(name)] model changed\n\(firstDiff)\n--- export:\n\(exported.source)")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) of \(inputs.count) diverged:\n\(failures.joined(separator: "\n\n"))")
    }

    @Test("export is deterministic and idempotent")
    func exportIsStable() throws {
        var failures: [String] = []
        for (name, source) in try flowchartRoundTripInputs() {
            let original = try parseFlowchart(source)
            let first = try exportMermaid(original).source
            for _ in 0..<4 where try exportMermaid(original).source != first {
                failures.append("[\(name)] two exports of one document differ")
                break
            }
            if let again = try? exportMermaid(parseFlowchart(first)).source, again != first {
                failures.append("[\(name)] export(parse(export)) differs from export\n--- 1:\n\(first)\n--- 2:\n\(again)")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n\n"))")
    }

    @Test("subgraph members are written inside their subgraph block")
    func membersInsideBlocks() throws {
        let source = """
        flowchart TD
          subgraph S1 [Group one]
            A[Alpha] --> B[Beta]
          end
          B --> C
        """
        let exported = try exportMermaid(parseFlowchart(source)).source
        let lines = exported.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let open = try #require(lines.firstIndex(where: { $0.hasPrefix("subgraph S1") }))
        let close = try #require(lines[open...].firstIndex(of: "end"))
        #expect(lines[open..<close].contains("A[Alpha]"))
        #expect(lines[open..<close].contains("B[Beta]"))
    }

    @Test("two subgraphs with one id export without trapping")
    func duplicateSubgraphIDs() throws {
        let source = "flowchart TD\n  subgraph S\n    A\n  end\n  subgraph S\n    B\n  end\n"
        let exported = try exportMermaid(parseFlowchart(source))
        let reparsed = try parseFlowchart(exported.source)
        guard case .flowchart(let g) = reparsed.payload else { Issue.record("not a flowchart"); return }
        #expect(g.subgraphs.map(\.id) == ["S", "S"])
        #expect(g.subgraphs.map(\.nodeIds) == [["A"], ["B"]])
    }

    @Test("trapezoid and parallelogram keep their shapes", arguments: [
        ("D[/\"Retry\"/]", original_src_types.NodeShape.parallelogram),
        ("D[/Retry\\]", .trapezoid),
        ("D[\\Retry/]", .trapezoidAlt),
        ("D[\\Retry\\]", .parallelogramAlt),
    ])
    func slashShapes(declaration: String, shape: original_src_types.NodeShape) throws {
        let exported = try exportMermaid(parseFlowchart("flowchart TD\n  \(declaration)\n")).source
        guard case .flowchart(let g) = try parseFlowchart(exported).payload else { Issue.record("not a flowchart"); return }
        #expect(g.nodesInOrder.first?.node.shape == shape, "export: \(exported)")
    }

    @Test("a huge node width exports without trapping")
    func hugeMetadataNumber() throws {
        let exported = try exportMermaid(parseFlowchart("flowchart TD\n  A@{ shape: rect, w: 1e30 }\n")).source
        #expect(exported.contains("w: "))
    }

    @Test("an unlabelled open link has no arrowhead", arguments: ["A --- B", "A---B", "A ---- B"])
    func openLink(_ link: String) throws {
        guard case .flowchart(let g) = try parseFlowchart("flowchart LR\n  \(link)\n").payload else {
            Issue.record("not a flowchart"); return
        }
        #expect(g.edges.count == 1)
        #expect(g.edges.first?.arrowHeadEnd == original_src_types.ArrowHeadType.none)
        #expect(g.edges.first?.style == .solid)
    }

    @Test("classDef property order is stable")
    func classDefOrder() throws {
        let source = "flowchart TD\n  A\n  classDef hot fill:#f96,stroke:#333,stroke-width:2px,color:#000\n"
        let exported = try exportMermaid(parseFlowchart(source)).source
        #expect(exported.contains("classDef hot color:#000,fill:#f96,stroke:#333,stroke-width:2px"))
    }
}
