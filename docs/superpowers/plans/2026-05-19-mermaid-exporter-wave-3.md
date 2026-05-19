# Mermaid Exporter Completion — Wave 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land Mermaid-source exporters for the final 3 families
(`block`, `architecture`, `wardleyBeta`), then close out the spec by
making `MermaidExporter.export(_:)` an exhaustive switch and updating
COVERAGE.md to reflect 28/28 Mermaid Export coverage. Wave 3 is the
**closing wave**. After it lands, every `DiagramDocument` whose
payload is a Mermaid-native family round-trips through `MermaidExporter`
losslessly.

**Architecture:** One file per family under
`Sources/DiagramKitMermaid/Exporter/MermaidExport/`, mirroring Waves 1
and 2 exactly. Dispatch added to `MermaidExporter.export(_:)` arm by
arm; the `default: .unsupportedDiagram` fall-through is **removed** in
the closing commit once the switch is exhaustive at 28/28. Round-trip
discipline is the primary acceptance gate via two `.md` fixtures per
family, structural diff via per-family
`DiagramDocumentDiff+<Family>.swift`, and the existing
`CorpusRoundTripTests` suite which auto-grows as each family lands in
`supportedDiagramTypes`. `block` reuses Wave 1's `emitIndentedTree`
(becoming its 5th caller); `architecture` and `wardleyBeta` emit
linearly with no helper reuse.

**Tech Stack:** Swift 6, SwiftPM,
[swift-testing](https://github.com/swiftlang/swift-testing) for new
tests (XCTest for `CorpusRoundTripTests`),
`DiagramKitTestSupport.RoundTripHarness`,
`Scripts/check-diagnostic-discipline.sh`,
`Scripts/check-file-sizes.sh`,
`Scripts/check-sendable-annotations.sh`,
`Scripts/strict-concurrency-check.sh`.

**Source spec:**
[docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md](../specs/2026-05-19-mermaid-exporter-completion-design.md)
(commit `34705b4`).

**Prior wave plans (reference for structural template + lessons):**
- [Wave 1](2026-05-19-mermaid-exporter-wave-1.md) — flat-text DSLs
  (`pie`, `journey`, `timeline`, `sankey`, `kanban`, `mindmap`,
  `treemap`, `packet`, `gitGraph`); 16/28.
- [Wave 2](2026-05-19-mermaid-exporter-wave-2.md) — structured but
  bounded (`xyChart`, `quadrantChart`, `requirement`, `radar`, `venn`,
  `ishikawa`, `treeView`, `zenuml`, `eventModeling`); 25/28.

---

## Lessons Folded In Up-Front (from Waves 1 + 2)

These are baked into every task below; do not relearn them.

1. **No `accDescr: { ... }` block form** for body-level emission.
   Several Mermaid family parsers reject the multiline block form even
   when their grammar lists it as accepted. Every exporter collapses
   multiline `accDescr` to a single line via `newline → space`. Each
   family file holds a private `singleLine(_:)` helper (≤ 5 lines of
   duplication; do not promote to `MermaidExportHelpers`).
2. **Test filter form.** Always use `swift test --filter
   <ExactSuiteName>` per the `feedback_swift_test_filter` standing
   default. Substring filters that match parameterized
   `CorpusSnapshotTests` cases hang. Each task's run command names the
   exact `SameFormatRoundTripTests/<methodName>` path.
3. **Commit-by-commit on `main`.** Per `feedback_branching`. No
   branches or worktrees. Each task ends with a commit.
4. **SourceKit lag is normal.** When you add a new file to a module,
   IDE diagnostics like "Cannot find X in scope" persist briefly.
   `swift build` is the source of truth. Do not chase ghost errors.
5. **Pre-existing failures in non-Wave families are allowlisted.**
   `CorpusRoundTripTests.knownFailures` already lists them; leave that
   allowlist alone. **Do NOT add a Wave 3 family to `knownFailures`** —
   if a corpus entry fails for `block`/`architecture`/`wardleyBeta`,
   the failure is on the new exporter; fix the exporter, not the
   allowlist.
6. **Diagnostic discipline.** Only typed factories
   (`.lossyTransform`, `.featureDropped`, `.informational`). Raw
   `DiagramDiagnostic(severity:message:)` is forbidden.
   `Scripts/check-diagnostic-discipline.sh` enforces it.
7. **Set-keyed diffs for declaration-order-fragile arms.** Where the
   parser does not preserve declaration order (Wave 2 hit this on
   `QuadrantChart.points` and `RequirementRelationship` reversed
   src/dest), compare as a set keyed on a normalized tuple rather than
   `zip` pairwise. Wave 3 needs the same discipline for block edges
   (auto-generated `count` prefix in edge id), architecture edges
   (`{group}` boundary modifier, reversed lhs/rhs), and wardley
   `WardleyLink` (label-direction permutations).
8. **Corpus is the final say.** Hand-authored fixtures cover the basic
   case. `CorpusRoundTripTests` auto-runs every corpus entry of newly
   supported families as soon as the family lands in
   `supportedDiagramTypes`. Expect corpus to surface edge cases the
   fixtures don't (block: nested composite ids, `block-beta` header
   alias, body-block indent; architecture: external icons like
   `logos:aws-s3`, edge labels, group boundary; wardleyBeta: hyphenated
   names, custom evolution stages, link arrow variants, accelerators).
   The cadence inside each task is: implement minimal emit → pass
   hand-authored fixtures → run `CorpusRoundTripTests` → fix corpus
   regressions inline → commit. **Do NOT defer corpus fixes.**

---

## Wave 3 Family → Payload Type Cheat Sheet

These names come from real source inspection (`Sources/DiagramKitModel/`).
Field names below the struct are what each task's diff arm and emit
code references.

| Family | `DiagramType` case | Payload struct | Top-level fields used |
|---|---|---|---|
| block | `.block` | `BlockDiagram` (`src_block_types.swift:167`) | `rootChildren: [String]`, `blockDatabase: [String: BlockNode]`, `edges: [BlockEdge]`, `classes: [String: BlockClassDef]`, `diagramTitle`, `accTitle`, `accDescr` |
| architecture | `.architecture` | `ArchitectureDiagram` (`src_architecture_types.swift:85`) | `groups: [ArchitectureGroup]`, `services: [ArchitectureService]`, `junctions: [ArchitectureJunction]`, `edges: [ArchitectureEdge]`, `diagramTitle`, `accTitle`, `accDescr` |
| wardleyBeta | `.wardleyBeta` | `WardleyMapDiagram` (`src_wardley_types.swift:203`) | `nodes: [WardleyNode]`, `links: [WardleyLink]`, `trends: [WardleyTrend]`, `pipelines: [WardleyPipeline]`, `annotations: [WardleyAnnotation]`, `notes: [WardleyNote]`, `accelerators`, `deaccelerators`, `annotationsBox: WardleyCoordinate?`, `axes: WardleyAxesConfig` (`xLabel`, `yLabel`, `stages`, `stageBoundaries`), `size: WardleySize?`, `diagramTitle`, `accTitle`, `accDescr` |

### Critical parser quirks per family

**Block.** The block parser does **not** recognize body-level
`title`, `accTitle:`, or `accDescr` keywords. They are populated from
frontmatter only (`src_block_parser.swift:653`:
`diagram.diagramTitle = fmc.shared.title`). Therefore the block
exporter **must not** emit a body-level title/acc* line — it would be
re-tokenized as a node. The umbrella
`MermaidExporter.prependingDocumentTitle` already handles the
document-level title via `---\ntitle: <text>\n---` frontmatter. The
block emit body just emits the diagram structure. Mirror
`MermaidIshikawaExport`'s approach
(`Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidIshikawaExport.swift:18-24`).

**Architecture.** The architecture parser **does** recognize
body-level `title`, `acctitle:`, and `accdescr` (single-line + block
form, `src_architecture_parser.swift:285-315`). Emit body-level
`title <text>` / `accTitle: <text>` / `accDescr: <text>` lines.
Collapse multiline `accDescr` to single-line via `singleLine(_:)` per
the Wave 1+2 standing rule, regardless of whether this parser would
accept the block form — uniform handling reduces surface area.
Header can carry an inline title: `architecture-beta title <text>`
(`src_architecture_parser.swift:253-256`). Prefer the body `title`
line over the inline header form for stable canonical output.

**WardleyBeta.** The wardley parser recognizes body-level `title`
(no colon, no quotes, single-line — `src_wardley_parser.swift:478-483`),
`acctitle:` and `accdescr` (single-line + block form). The DSL header
is the hyphenated `wardley-beta` (matched by `DiagramRegistry+Wardley.swift:14`),
even though the `DiagramType` enum case is the camelCase `.wardleyBeta`.

**WardleyBeta coordinate swap (load-bearing).** The parser stores
coordinates with an **OWM convention swap**: the first DSL field is
*visibility* (mapped to `y`) and the second is *evolution* (mapped to
`x`). See `src_wardley_parser.swift:80-83` and `:97-104`. So a DSL
`component Foo [0.6, 0.8]` parses to `WardleyNode(x: 80, y: 60)`. The
parser also normalizes any value ≤ 1 by multiplying by 100
(`src_wardley_parser.swift:64-70`); both `[0.6, 0.8]` and `[60, 80]`
parse to the same coords.

**Re-emission rule for wardley coordinates:** emit
`[<y_pct/100>, <x_pct/100>]` — i.e. the first DSL slot gets `node.y`
(visibility), the second gets `node.x` (evolution), each divided by
100 and formatted with up to two decimal places (trim trailing
zeros). This restores the corpus idiom (`[0.95, 0.63]`). The
structural round-trip will fail noisily if the swap is wrong: a node
written at the wrong axis re-parses to swapped coords, and the diff
arm flags `x != x` or `y != y` immediately.

---

## File Structure

**Files created (Wave 3):**

```
Sources/DiagramKitMermaid/Exporter/MermaidExport/
  MermaidBlockExport.swift            # Task 1
  MermaidArchitectureExport.swift     # Task 2
  MermaidWardleyExport.swift          # Task 3

Sources/DiagramKitTestSupport/
  DiagramDocumentDiff+Block.swift            # Task 1
  DiagramDocumentDiff+Architecture.swift     # Task 2
  DiagramDocumentDiff+Wardley.swift          # Task 3

Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/
  mermaid-block/01-basic.md, 02-nested-with-edges.md
  mermaid-architecture/01-basic.md, 02-edge-labels.md
  mermaid-wardleybeta/01-basic.md, 02-pipeline-and-evolve.md
```

**Files modified (Wave 3):**

```
Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift     # +3 case arms, +3 supportedDiagramTypes, default: REMOVED in Task 4
Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift      # +3 case arms
Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift  # +3 cells
Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift  # +3 @Test methods
COVERAGE.md                                                  # Wave 3 closing: Mermaid Export 25/28 → 28/28, backlog item #1 removed, audit date moved
BASELINES.md                                                 # Wave 3 closing entry
```

No changes to `MermaidExportHelpers.swift`. The Wave 1 helpers
(`emitIndentedTree`, `emitSectionedItems`, `quote`, `escapeBracketLabel`,
`sanitizeIdentifier`) are sufficient. `block` becomes the 5th caller
of `emitIndentedTree` (after mindmap, treemap, treeView, ishikawa).

---

## Task Ordering Rationale

Task 1 (block) lands first to validate the 5th `emitIndentedTree`
caller and exercise the nested-composite emission path before
architecture (which has its own group/parent containment but no shared
helper). Task 2 (architecture) lands second — it has no helper reuse
but follows a simpler one-statement-per-line shape similar to Wave 2's
`requirement`. Task 3 (wardleyBeta) lands third because it carries the
heaviest schema (nodes, links, trends, pipelines, annotations, notes,
accelerators, deaccelerators, axes, size — 10 first-class collections)
and the coordinate-swap caveat that has to be right for any round-trip
to pass. Task 4 is the closing task: remove `default:`, update
COVERAGE.md, update BASELINES.md.

---

## Task 1: Block Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidBlockExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Block.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-block/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-block/02-nested-with-edges.md`
- Modify: `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`
- Modify: `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`

- [ ] **Step 1.1: Add fixture `01-basic.md`**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-block/01-basic.md`:

```
block-beta
    columns 3
    A["A"] B["B"]:2 C["C"]
```

> Derived from corpus entry `block-2-columns` with the canonicalized
> `block-beta` header. The parser accepts both `block` and `block-beta`;
> the exporter emits `block-beta` as the canonical form.

- [ ] **Step 1.2: Stub the exporter file**

Create `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidBlockExport.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `block-beta` source from a `BlockDiagram`.
///
/// Walks the `blockDatabase` starting from `rootChildren`. For each
/// node, emits one line at the node's nesting depth (2-space indent
/// per level). Composite blocks open as `block:<id>["<label>"]` and
/// close with `end`. Leaf nodes emit as bare identifiers or with a
/// shape suffix (`[`...`]`, `(`...`)`, etc.) matching `BlockNodeType`.
/// `widthInColumns` becomes a trailing `:<n>` span. `columns <n>` is
/// emitted as the first child line of any composite (including root)
/// that carries a non-default column count. Edges and `classDef`/
/// `class` lines are appended after the structural tree.
///
/// Body-level title / accessibility metadata is NOT emitted: the block
/// parser does not recognize those keywords (they are frontmatter-only,
/// applied by the umbrella `MermaidExporter.prependingDocumentTitle`).
/// Reuses `MermaidExportHelpers.emitIndentedTree` for the structural
/// walk (5th caller after mindmap / treemap / treeView / ishikawa).
enum MermaidBlockExport {

    static func emit(_ model: BlockDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "block-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 1.3: Wire dispatch arm**

In `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`, append
`.block` to `supportedDiagramTypes`:

```swift
        .block,           // wave 3
```

And insert a case arm above the `default:`:

```swift
        case .block(let model):
            result = try MermaidBlockExport.emit(model)
```

- [ ] **Step 1.4: Create the diff arm**

Create `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Block.swift`:

```swift
import DiagramKitModel

func diffBlockDiagram(_ a: BlockDiagram, _ b: BlockDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "block.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.accTitle != b.accTitle {
        deltas.append(.unexpected(
            path: "block.accTitle",
            detail: "lhs=\(a.accTitle ?? "nil") rhs=\(b.accTitle ?? "nil")"
        ))
    }
    if a.accDescr != b.accDescr {
        deltas.append(.unexpected(
            path: "block.accDescr",
            detail: "lhs=\(a.accDescr ?? "nil") rhs=\(b.accDescr ?? "nil")"
        ))
    }

    // Root children must appear in the same order — the rootChildren
    // array is the parser-visible declaration order.
    if a.rootChildren != b.rootChildren {
        deltas.append(.unexpected(
            path: "block.rootChildren",
            detail: "lhs=\(a.rootChildren) rhs=\(b.rootChildren)"
        ))
    }

    // Walk every node in the database. Spaces and auto-generated ids
    // (matching `^id-\d+`) are normalized: their ids may renumber on
    // re-parse, but they should appear at the same position under the
    // same parent. Compare by node-type-by-position for those; compare
    // user-named nodes by id.
    let aIds = Set(a.blockDatabase.keys).filter { !$0.hasPrefix("id-") }
    let bIds = Set(b.blockDatabase.keys).filter { !$0.hasPrefix("id-") }
    if aIds != bIds {
        deltas.append(.unexpected(
            path: "block.nodes.userIds",
            detail: "onlyLhs=\(aIds.subtracting(bIds).sorted()) onlyRhs=\(bIds.subtracting(aIds).sorted())"
        ))
    }
    for id in aIds where bIds.contains(id) {
        guard let l = a.blockDatabase[id], let r = b.blockDatabase[id] else { continue }
        if l.label != r.label {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].label",
                detail: "lhs=\(l.label) rhs=\(r.label)"
            ))
        }
        if l.type != r.type {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].type",
                detail: "lhs=\(l.type) rhs=\(r.type)"
            ))
        }
        if l.columns != r.columns {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].columns",
                detail: "lhs=\(String(describing: l.columns)) rhs=\(String(describing: r.columns))"
            ))
        }
        if l.widthInColumns != r.widthInColumns {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].widthInColumns",
                detail: "lhs=\(String(describing: l.widthInColumns)) rhs=\(String(describing: r.widthInColumns))"
            ))
        }
        // Children — strip auto-generated space ids to a placeholder
        // before comparing; positional comparison stays meaningful.
        func normalizeChildren(_ ids: [String], _ db: [String: BlockNode]) -> [String] {
            ids.map { cid in
                if cid.hasPrefix("id-"), db[cid]?.type == .space { return "<space>" }
                return cid
            }
        }
        let lc = normalizeChildren(l.children, a.blockDatabase)
        let rc = normalizeChildren(r.children, b.blockDatabase)
        if lc != rc {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].children",
                detail: "lhs=\(lc) rhs=\(rc)"
            ))
        }
        if (l.classes ?? []) != (r.classes ?? []) {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].classes",
                detail: "lhs=\(l.classes ?? []) rhs=\(r.classes ?? [])"
            ))
        }
        if (l.styles ?? []) != (r.styles ?? []) {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].styles",
                detail: "lhs=\(l.styles ?? []) rhs=\(r.styles ?? [])"
            ))
        }
    }

    // Edges: parser-assigned ids prefix a count to disambiguate
    // duplicate (start, end) pairs. Drop the count prefix for diffing.
    // Compare as multisets keyed on the normalized tuple.
    func edgeKey(_ e: BlockEdge) -> String {
        "\(e.start)|\(e.end)|\(e.label ?? "")|\(e.thickness)|\(e.pattern)|\(e.arrowTypeEnd)|\(e.arrowTypeStart)"
    }
    let lhsEdges = a.edges.map(edgeKey).sorted()
    let rhsEdges = b.edges.map(edgeKey).sorted()
    if lhsEdges != rhsEdges {
        deltas.append(.unexpected(
            path: "block.edges",
            detail: "lhs=\(lhsEdges) rhs=\(rhsEdges)"
        ))
    }

    // Classes by name.
    let aClassNames = Set(a.classes.keys)
    let bClassNames = Set(b.classes.keys)
    if aClassNames != bClassNames {
        deltas.append(.unexpected(
            path: "block.classes.keys",
            detail: "onlyLhs=\(aClassNames.subtracting(bClassNames).sorted()) onlyRhs=\(bClassNames.subtracting(aClassNames).sorted())"
        ))
    }
    for name in aClassNames where bClassNames.contains(name) {
        guard let l = a.classes[name], let r = b.classes[name] else { continue }
        if l.styles != r.styles {
            deltas.append(.unexpected(
                path: "block.classes[\(name)].styles",
                detail: "lhs=\(l.styles) rhs=\(r.styles)"
            ))
        }
    }
    return deltas
}
```

In `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift`, add an
arm to the `compare(_:_:)` switch (above the `default:`):

```swift
    case (.block(let lhs), .block(let rhs)):
        deltas.append(contentsOf: diffBlockDiagram(lhs, rhs))
```

- [ ] **Step 1.5: Register the round-trip cell**

In `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`, add
after `mermaidEventModeling` and before `d2Flowchart`:

```swift
    static let mermaidBlock = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.block,
        allowedLosses: []
    )
```

- [ ] **Step 1.6: Register the test method**

In `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`,
add inside `struct SameFormatRoundTripTests` after the
`mermaidEventModeling` test:

```swift
    @Test(
        "Mermaid block round-trip",
        arguments: try fixtures(for: "mermaid-block", fromRoot: roundTripResourcesRoot())
    )
    func mermaidBlock(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidBlock,
            fixture: fixture
        )
    }
```

- [ ] **Step 1.7: Run test to confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidBlock`
Expected: FAIL. The stub returns just `"block-beta\n"` so the diff
reports `block.rootChildren` mismatch (lhs=`["A", "B", "C"]`,
rhs=`[]`).

- [ ] **Step 1.8: Implement the emit body**

Replace the stub `emit` in `MermaidBlockExport.swift` with:

```swift
    static func emit(_ model: BlockDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["block-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        // Root-level `columns N` if the root block has an explicit
        // (non-default) column count. Default is -1 (auto) per
        // `BlockNode(... columns: -1)` in the root sentinel.
        if let root = model.blockDatabase["root"], let cols = root.columns, cols != -1 {
            lines.append("    columns \(cols)")
        }

        // Walk the rootChildren preserving declaration order. For each
        // child, emit either a leaf line or a composite block:
        // `block:<id>["<label>"]` ... children ... `end`.
        for childId in model.rootChildren {
            emitNode(id: childId, depth: 1, into: &lines, model: model)
        }

        // Edges after the structural tree.
        for edge in model.edges {
            let arrow = arrowToken(
                thickness: edge.thickness,
                pattern: edge.pattern,
                arrowTypeEnd: edge.arrowTypeEnd,
                arrowTypeStart: edge.arrowTypeStart
            )
            if let label = edge.label, !label.isEmpty {
                lines.append("    \(edge.start) -- \"\(escapeQuotedLabel(label))\" \(arrow) \(edge.end)")
            } else {
                lines.append("    \(edge.start) \(arrow) \(edge.end)")
            }
        }

        // classDefs in alphabetical order for stable output.
        for name in model.classes.keys.sorted() {
            guard let def = model.classes[name] else { continue }
            let joined = def.styles.joined(separator: ",")
            lines.append("    classDef \(name) \(joined)")
        }

        // class assignments: walk nodes and collect class memberships.
        // Emit as `class <id> <className>` for each (node, className)
        // pair in deterministic order.
        for nid in model.blockDatabase.keys.sorted() {
            guard let node = model.blockDatabase[nid] else { continue }
            for cls in (node.classes ?? []).sorted() {
                lines.append("    class \(nid) \(cls)")
            }
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func emitNode(
        id: String,
        depth: Int,
        into lines: inout [String],
        model: BlockDiagram
    ) {
        let indent = String(repeating: "    ", count: depth)
        guard let node = model.blockDatabase[id] else {
            lines.append("\(indent)\(id)")
            return
        }

        // Auto-generated space nodes — emit as bare `space` keyword.
        if node.type == .space {
            lines.append("\(indent)space")
            return
        }

        if node.type == .composite {
            // `block:<id>["<label>"]` opener. Label is optional; if
            // empty, omit the shape suffix entirely.
            let head: String
            if node.label.isEmpty {
                head = "block:\(node.id)"
            } else {
                head = "block:\(node.id)[\"\(escapeQuotedLabel(node.label))\"]"
            }
            let span = node.widthInColumns.map { ":\($0)" } ?? ""
            lines.append("\(indent)\(head)\(span)")
            // Composite-local `columns N`
            if let cols = node.columns, cols != -1 {
                lines.append("\(indent)    columns \(cols)")
            }
            for childId in node.children {
                emitNode(id: childId, depth: depth + 1, into: &lines, model: model)
            }
            lines.append("\(indent)end")
            return
        }

        // Leaf node — emit `<id>[shape "label" shape]:span`.
        let shape = shapeTokens(for: node.type)
        let labelPart: String
        if node.label.isEmpty || node.label == node.id {
            labelPart = ""
        } else if shape == nil {
            labelPart = ""
        } else {
            labelPart = "\(shape!.open)\"\(escapeQuotedLabel(node.label))\"\(shape!.close)"
        }
        let spanPart = node.widthInColumns.map { ":\($0)" } ?? ""
        lines.append("\(indent)\(node.id)\(labelPart)\(spanPart)")
    }

    private static func shapeTokens(for type: BlockNodeType) -> (open: String, close: String)? {
        switch type {
        case .square: return ("[", "]")
        case .round: return ("(", ")")
        case .circle: return ("((", "))")
        case .doublecircle: return ("(((", ")))")
        case .diamond: return ("{", "}")
        case .hexagon: return ("{{", "}}")
        case .stadium: return ("([", "])")
        case .subroutine: return ("[[", "]]")
        case .cylinder: return ("[(", ")]")
        case .leanRight: return ("[/", "/]")
        case .leanLeft: return ("[\\", "\\]")
        case .trapezoid: return ("[/", "\\]")
        case .invTrapezoid: return ("[\\", "/]")
        case .rectLeftInvArrow: return (">", "]")
        case .na, .columnSetting, .edge, .space, .composite, .classDef, .applyClass, .applyStyles, .blockArrow:
            return nil
        }
    }

    private static func arrowToken(
        thickness: String,
        pattern: String,
        arrowTypeEnd: String,
        arrowTypeStart: String
    ) -> String {
        // Mirror the small grammar in src_block_types.swift:408-434.
        let stem: String
        if pattern == "dotted" {
            stem = thickness == "thick" ? "=.=" : "-.-"
        } else {
            stem = thickness == "thick" ? "==" : "--"
        }
        let endMark: String
        switch arrowTypeEnd {
        case "arrow_point": endMark = ">"
        case "arrow_circle": endMark = "o"
        case "arrow_cross": endMark = "x"
        default: endMark = ""
        }
        let startMark: String
        switch arrowTypeStart {
        case "arrow_point": startMark = "<"
        case "arrow_circle": startMark = "o"
        case "arrow_cross": startMark = "x"
        default: startMark = "" // includes "arrow_open"
        }
        return "\(startMark)\(stem)\(endMark.isEmpty ? "-" : endMark)"
    }

    private static func escapeQuotedLabel(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
```

> **Type alignment notes.**
> - `BlockNode.children` is `[String]` (child ids), not nested
>   `BlockNode` instances. Walk via `model.blockDatabase[id]` lookups.
> - `BlockNode.classes` and `BlockNode.styles` are `[String]?`.
> - `BlockNodeType` enum cases include `.na`, `.columnSetting`, `.edge`,
>   `.blockArrow` — all currently produced by the parser only for
>   internal bookkeeping; the exporter doesn't synthesize them. If a
>   corpus entry surfaces a `.blockArrow` leaf, extend
>   `shapeTokens(for:)` to emit `<["label"]>` syntax with `.directions`
>   appended; defer that until corpus surfaces it.

- [ ] **Step 1.9: Run test to confirm GREEN on `01-basic.md`**

Run: `swift test --filter SameFormatRoundTripTests/mermaidBlock`
Expected: PASS for `01-basic.md`.

- [ ] **Step 1.10: Add fixture `02-nested-with-edges.md`**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-block/02-nested-with-edges.md`:

```
block-beta
    columns 3
    block:frontend["Frontend"]
        columns 1
        WebApp
        MobileApp
    end
    block:backend["Backend"]
        columns 1
        API
        Workers
    end
    block:data["Data"]
        columns 1
        DB
        Cache
    end
    frontend --> backend
    backend --> data
```

> Derived from corpus entry `block-7-architecture`. Exercises nested
> composite blocks with per-composite `columns 1` and inter-composite
> edges where the endpoints are nested-composite ids.

- [ ] **Step 1.11: Run test to confirm GREEN on both fixtures**

Run: `swift test --filter SameFormatRoundTripTests/mermaidBlock`
Expected: PASS for both fixtures. If `block.edges` diverges because of
the auto-generated `count-start-end` id prefix, verify the diff arm's
`edgeKey` strips the prefix correctly. If `block.nodes[<id>].children`
diverges on a `<space>` placeholder, verify the
`normalizeChildren(_:_:)` helper is matching space-typed `id-N` nodes.

Then run the corpus:
`swift test --filter CorpusRoundTripTests`
Expected: PASS for all 12 `block-*` entries (`block-1-simple` through
`block-12-mixed-rows`). If a corpus entry diverges, fix the exporter
inline — common pitfalls to investigate first:
- `block-4-arrow` uses `arrow<[\"sync\"]>(right)` (the `.blockArrow`
  type) — if surfaced, extend `shapeTokens(for:)` accordingly.
- `block-9-arrows-all` and `block-12-mixed-rows` use `space:N`
  multi-span — the parser materializes N separate space nodes; emit
  N separate `space` lines, not a single `space:N`.
- `block-11-style-default` uses `style <id> <styles>` directly — if
  the model populates `BlockNode.styles` for those nodes, the
  class-assignment loop above will emit them via `style` rather than
  `class`. Add a `style <id> <joined-styles>` arm to the emit body.

- [ ] **Step 1.12: Run discipline gates**

```bash
Scripts/check-diagnostic-discipline.sh
Scripts/check-file-sizes.sh
```
Expected: both exit 0. The new file should sit well under the
500-line warn line.

- [ ] **Step 1.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidBlockExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Block.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-block/

git commit -m "$(cat <<'EOF'
Add Mermaid block exporter

Wave 3 of the Mermaid exporter completion spec. Lossless re-emission
from BlockDiagram: `block-beta` header → optional `columns N` → tree
of composite blocks (`block:<id>["<label>"]` opener, `end` closer)
and leaf nodes with shape suffixes → flat edges in declaration order
→ classDef lines → class assignments. Reuses
MermaidExportHelpers.emitIndentedTree's tree-walk pattern (5th
caller after mindmap/treemap/treeView/ishikawa). Body-level title
and accessibility metadata are intentionally skipped — the block
parser populates them via frontmatter only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Architecture Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidArchitectureExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Architecture.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-architecture/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-architecture/02-edge-labels.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 2.1: Add fixture `01-basic.md`**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-architecture/01-basic.md`:

```
architecture-beta
    group api(cloud)[API]
    service db(database)[Database] in api
    service server(server)[Server] in api
    db:L -- R:server
```

> Derived from corpus entry `architecture-basic`. Smallest example
> that exercises groups, services in groups, icons, titles, and
> a single edge with directional ports.

- [ ] **Step 2.2: Stub the exporter file**

Create `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidArchitectureExport.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `architecture-beta` source from an `ArchitectureDiagram`.
///
/// Lossless: `architecture-beta` header → optional `title` →
/// accessibility metadata → groups (`group <id>(<icon>)[<title>] in
/// <parent>`) → services (`service <id>(<icon>|"<text>")[<title>]
/// in <parent>`) → junctions (`junction <id> in <parent>`) → edges
/// (`<lhs>[{group}]:<dir>[<-][-[<label>]-|--][>]<dir>:<rhs>[{group}]`).
///
/// Icons emit as `(<iconName>)`; iconText emits as `("<text>")` per
/// the architecture parser's icon-section grammar
/// (`src_architecture_parser.swift:134-145`).
enum MermaidArchitectureExport {

    static func emit(_ model: ArchitectureDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "architecture-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 2.3: Wire dispatch arm**

In `MermaidExporter.swift`, append `.architecture` to
`supportedDiagramTypes`:

```swift
        .architecture,    // wave 3
```

And insert a case arm above the `default:`:

```swift
        case .architecture(let model):
            result = try MermaidArchitectureExport.emit(model)
```

- [ ] **Step 2.4: Create the diff arm**

Create `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Architecture.swift`:

```swift
import DiagramKitModel

func diffArchitectureDiagram(_ a: ArchitectureDiagram, _ b: ArchitectureDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "architecture.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.accTitle != b.accTitle {
        deltas.append(.unexpected(
            path: "architecture.accTitle",
            detail: "lhs=\(a.accTitle ?? "nil") rhs=\(b.accTitle ?? "nil")"
        ))
    }
    if a.accDescr != b.accDescr {
        deltas.append(.unexpected(
            path: "architecture.accDescr",
            detail: "lhs=\(a.accDescr ?? "nil") rhs=\(b.accDescr ?? "nil")"
        ))
    }

    // Groups, services, junctions: compare by id with full-tuple
    // value equality (id, icon, title, parentGroupId — and for
    // services also iconText).
    func groupKey(_ g: ArchitectureGroup) -> String {
        "\(g.id)|\(g.icon ?? "")|\(g.title ?? "")|\(g.parentGroupId ?? "")"
    }
    let lhsGroups = Set(a.groups.map(groupKey))
    let rhsGroups = Set(b.groups.map(groupKey))
    if lhsGroups != rhsGroups {
        deltas.append(.unexpected(
            path: "architecture.groups",
            detail: "onlyLhs=\(lhsGroups.subtracting(rhsGroups).sorted()) onlyRhs=\(rhsGroups.subtracting(lhsGroups).sorted())"
        ))
    }

    func serviceKey(_ s: ArchitectureService) -> String {
        "\(s.id)|\(s.icon ?? "")|\(s.iconText ?? "")|\(s.title ?? "")|\(s.parentGroupId ?? "")"
    }
    let lhsServices = Set(a.services.map(serviceKey))
    let rhsServices = Set(b.services.map(serviceKey))
    if lhsServices != rhsServices {
        deltas.append(.unexpected(
            path: "architecture.services",
            detail: "onlyLhs=\(lhsServices.subtracting(rhsServices).sorted()) onlyRhs=\(rhsServices.subtracting(lhsServices).sorted())"
        ))
    }

    func junctionKey(_ j: ArchitectureJunction) -> String {
        "\(j.id)|\(j.parentGroupId ?? "")"
    }
    let lhsJunctions = Set(a.junctions.map(junctionKey))
    let rhsJunctions = Set(b.junctions.map(junctionKey))
    if lhsJunctions != rhsJunctions {
        deltas.append(.unexpected(
            path: "architecture.junctions",
            detail: "onlyLhs=\(lhsJunctions.subtracting(rhsJunctions).sorted()) onlyRhs=\(rhsJunctions.subtracting(lhsJunctions).sorted())"
        ))
    }

    // Edges: the DSL syntax does not encode an inherent lhs/rhs
    // direction beyond the lhs/rhs labels themselves; if the parser
    // preserves declaration order, fine to compare ordered tuples.
    // Use a sorted multiset to be safe.
    func edgeKey(_ e: ArchitectureEdge) -> String {
        "\(e.lhsId):\(e.lhsDirection.rawValue)\(e.lhsGroupBoundary ? "{g}" : "")|\(e.rhsId):\(e.rhsDirection.rawValue)\(e.rhsGroupBoundary ? "{g}" : "")|sa=\(e.sourceArrow)|ta=\(e.targetArrow)|label=\(e.label ?? "")"
    }
    let lhsEdges = a.edges.map(edgeKey).sorted()
    let rhsEdges = b.edges.map(edgeKey).sorted()
    if lhsEdges != rhsEdges {
        deltas.append(.unexpected(
            path: "architecture.edges",
            detail: "lhs=\(lhsEdges) rhs=\(rhsEdges)"
        ))
    }
    return deltas
}
```

In `DiagramDocumentDiff.swift`, add an arm above the `default:`:

```swift
    case (.architecture(let lhs), .architecture(let rhs)):
        deltas.append(contentsOf: diffArchitectureDiagram(lhs, rhs))
```

- [ ] **Step 2.5: Register the round-trip cell**

In `RoundTripCellRegistry.swift`, add after `mermaidBlock`:

```swift
    static let mermaidArchitecture = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.architecture,
        allowedLosses: []
    )
```

- [ ] **Step 2.6: Register the test method**

In `SameFormatRoundTripTests.swift`, add after `mermaidBlock`:

```swift
    @Test(
        "Mermaid architecture round-trip",
        arguments: try fixtures(for: "mermaid-architecture", fromRoot: roundTripResourcesRoot())
    )
    func mermaidArchitecture(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidArchitecture,
            fixture: fixture
        )
    }
```

- [ ] **Step 2.7: Run test to confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidArchitecture`
Expected: FAIL on `architecture.groups` or `architecture.services` —
the stub emits zero declarations.

- [ ] **Step 2.8: Implement the emit body**

Replace the stub `emit` in `MermaidArchitectureExport.swift` with:

```swift
    static func emit(_ model: ArchitectureDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["architecture-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        // Groups first: any group used as a `parentGroupId` must be
        // declared before its child references it. The parser validates
        // parent existence at parse time.
        for group in orderedByParentChain(model.groups) {
            var line = "    group \(group.id)"
            if let icon = group.icon, !icon.isEmpty {
                line += "(\(icon))"
            }
            if let title = group.title, !title.isEmpty {
                line += "[\(escapeBracketTitle(title))]"
            }
            if let parent = group.parentGroupId, !parent.isEmpty {
                line += " in \(parent)"
            }
            lines.append(line)
        }

        // Services next.
        for service in model.services {
            var line = "    service \(service.id)"
            if let icon = service.icon, !icon.isEmpty {
                line += "(\(icon))"
            } else if let iconText = service.iconText, !iconText.isEmpty {
                line += "(\"\(escapeQuotedTitle(iconText))\")"
            }
            if let title = service.title, !title.isEmpty {
                line += "[\(escapeBracketTitle(title))]"
            }
            if let parent = service.parentGroupId, !parent.isEmpty {
                line += " in \(parent)"
            }
            lines.append(line)
        }

        // Junctions.
        for junction in model.junctions {
            var line = "    junction \(junction.id)"
            if let parent = junction.parentGroupId, !parent.isEmpty {
                line += " in \(parent)"
            }
            lines.append(line)
        }

        // Edges.
        for edge in model.edges {
            let lhsPart = "\(edge.lhsId)\(edge.lhsGroupBoundary ? "{group}" : ""):\(edge.lhsDirection.rawValue)"
            let rhsPart = "\(edge.rhsDirection.rawValue):\(edge.rhsId)\(edge.rhsGroupBoundary ? "{group}" : "")"
            let arrow = arrowToken(
                sourceArrow: edge.sourceArrow,
                targetArrow: edge.targetArrow,
                label: edge.label
            )
            lines.append("    \(lhsPart) \(arrow) \(rhsPart)")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // Topological sort: groups whose parentGroupId references another
    // group must come after their parent. Groups without a parent
    // sort first, then groups whose parent has been emitted.
    private static func orderedByParentChain(_ groups: [ArchitectureGroup]) -> [ArchitectureGroup] {
        var remaining = groups
        var emitted: Set<String> = []
        var result: [ArchitectureGroup] = []
        // Outer loop bounded by group count.
        var safety = groups.count * 2
        while !remaining.isEmpty && safety > 0 {
            safety -= 1
            let readyIdx = remaining.firstIndex { g in
                guard let p = g.parentGroupId, !p.isEmpty else { return true }
                return emitted.contains(p)
            }
            if let idx = readyIdx {
                let g = remaining.remove(at: idx)
                emitted.insert(g.id)
                result.append(g)
            } else {
                // Cycle or dangling parent — emit remaining as-is.
                result.append(contentsOf: remaining)
                break
            }
        }
        return result
    }

    private static func arrowToken(
        sourceArrow: Bool,
        targetArrow: Bool,
        label: String?
    ) -> String {
        var head = ""
        if sourceArrow { head = "<" }
        let body: String
        if let label, !label.isEmpty {
            body = "-[\(escapeBracketTitle(label))]-"
        } else {
            body = "--"
        }
        var tail = ""
        if targetArrow { tail = ">" }
        return "\(head)\(body)\(tail)"
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escapeBracketTitle(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escapeQuotedTitle(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
```

> **Type alignment notes.**
> - `ArchitectureDirection` is an enum with `.L`, `.R`, `.T`, `.B`
>   whose `rawValue` is the uppercase letter — exactly what the DSL
>   expects.
> - `ArchitectureService.iconText` is mutually exclusive with
>   `ArchitectureService.icon` per the parser
>   (`src_architecture_parser.swift:141-142`).
> - The DSL `( <inner> )` section is read as iconName if `inner`
>   has no quotes, or iconText if `inner` is `"..."` / `'...'`.
> - The architecture parser does not preserve the inline-header title
>   form (`architecture-beta title Foo`); it normalizes to body-level
>   title storage, so the exporter always emits the body-level form.

- [ ] **Step 2.9: Run test to confirm GREEN on `01-basic.md`**

Run: `swift test --filter SameFormatRoundTripTests/mermaidArchitecture`
Expected: PASS for `01-basic.md`.

- [ ] **Step 2.10: Add fixture `02-edge-labels.md`**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-architecture/02-edge-labels.md`:

```
architecture-beta
    title Edge Variants
    group core(cloud)[Core]
    service db(database)[DB] in core
    service api(server)[API] in core
    service ext(internet)[Ext]
    db:R -[SQL]- L:api
    api:T <-- B:ext
    ext:R -[HTTPS]- L:db
```

> Derived from corpus entry `architecture-edge-labels-arrows`. Exercises
> body-level `title`, labeled edges (`-[SQL]-`), and reverse-direction
> arrows (`<--`).

- [ ] **Step 2.11: Run test to confirm GREEN on both fixtures**

Run: `swift test --filter SameFormatRoundTripTests/mermaidArchitecture`
Expected: PASS for both fixtures.

Then run the corpus:
`swift test --filter CorpusRoundTripTests`
Expected: PASS for all 9 `architecture-*` corpus entries
(`architecture-basic` through `architecture-edge-labels-arrows`).
Common pitfalls if a corpus entry diverges:
- `architecture-title-accessibility` uses the inline-header title
  form (`architecture-beta title Simple Architecture`) — the parser
  normalizes to body-level storage; the exporter must emit body-level
  `title <text>` regardless. Verify that path is exercised.
- `architecture-external-icons` uses `logos:aws-s3` style icon names
  with embedded `:` — the icon section grammar allows that verbatim.
  Confirm no extra escaping is applied.
- `architecture-group-boundary` uses `server{group}:B --> T:subnet{group}`
  — verify the `{group}` modifier emits on both sides.

- [ ] **Step 2.12: Run discipline gates**

```bash
Scripts/check-diagnostic-discipline.sh
Scripts/check-file-sizes.sh
```
Expected: both exit 0.

- [ ] **Step 2.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidArchitectureExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Architecture.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-architecture/

git commit -m "$(cat <<'EOF'
Add Mermaid architecture exporter

Wave 3: `architecture-beta` header → body-level title and
accessibility metadata → groups (parent-chain ordered) → services
(with icon or iconText) → junctions → edges with port specifiers,
optional `{group}` boundary modifiers, reverse-direction arrows,
and bracketed labels. Icons emit as `(iconName)` and iconText
emits as `("text")`.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: WardleyBeta Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidWardleyExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Wardley.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-wardleybeta/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-wardleybeta/02-pipeline-and-evolve.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 3.1: Add fixture `01-basic.md`**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-wardleybeta/01-basic.md`:

```
wardley-beta
title Tea Shop Value Chain
anchor Business [0.95, 0.63]
component Cup of Tea [0.79, 0.61]
component Tea [0.63, 0.81]
Business -> Cup of Tea
Cup of Tea -> Tea
evolve Tea 0.89
```

> Derived from corpus entry `wardley-1-tea-shop`. Smallest example
> that exercises title, anchor + component, links, and `evolve`.

- [ ] **Step 3.2: Stub the exporter file**

Create `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidWardleyExport.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `wardley-beta` source from a `WardleyMapDiagram`.
///
/// Lossless: `wardley-beta` header → optional title and accessibility
/// metadata → optional `size [w, h]` → optional `evolution <stage> ->
/// <stage> -> ...` → nodes (anchors first, then components by source
/// order with optional decorator and inertia) → notes → annotations →
/// `annotations [x, y]` box → accelerators / deaccelerators → links
/// (with arrow variants encoding `dashed`/`flow`/`label`) → `evolve`
/// trends → pipeline blocks.
///
/// CRITICAL: the wardley parser stores `[visibility, evolution]` from
/// the DSL as `WardleyNode(x: evolution, y: visibility)` after a
/// 0-100 normalization. The exporter emits `[node.y/100,
/// node.x/100]` to restore the corpus-idiom decimal form.
enum MermaidWardleyExport {

    static func emit(_ model: WardleyMapDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "wardley-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 3.3: Wire dispatch arm**

In `MermaidExporter.swift`, append `.wardleyBeta` to
`supportedDiagramTypes`:

```swift
        .wardleyBeta,     // wave 3
```

And insert a case arm above the `default:`:

```swift
        case .wardleyBeta(let model):
            result = try MermaidWardleyExport.emit(model)
```

- [ ] **Step 3.4: Create the diff arm**

Create `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Wardley.swift`:

```swift
import DiagramKitModel

func diffWardleyMapDiagram(_ a: WardleyMapDiagram, _ b: WardleyMapDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "wardley.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.accTitle != b.accTitle {
        deltas.append(.unexpected(
            path: "wardley.accTitle",
            detail: "lhs=\(a.accTitle ?? "nil") rhs=\(b.accTitle ?? "nil")"
        ))
    }
    if a.accDescr != b.accDescr {
        deltas.append(.unexpected(
            path: "wardley.accDescr",
            detail: "lhs=\(a.accDescr ?? "nil") rhs=\(b.accDescr ?? "nil")"
        ))
    }

    // Size: tuple-equality on width/height.
    let aSize = a.size.map { ($0.width, $0.height) }
    let bSize = b.size.map { ($0.width, $0.height) }
    if aSize?.0 != bSize?.0 || aSize?.1 != bSize?.1 {
        deltas.append(.unexpected(
            path: "wardley.size",
            detail: "lhs=\(String(describing: aSize)) rhs=\(String(describing: bSize))"
        ))
    }

    // Axes config.
    if a.axes.xLabel != b.axes.xLabel
        || a.axes.yLabel != b.axes.yLabel
        || (a.axes.stages ?? []) != (b.axes.stages ?? [])
        || (a.axes.stageBoundaries ?? []) != (b.axes.stageBoundaries ?? []) {
        deltas.append(.unexpected(
            path: "wardley.axes",
            detail: "lhs={xLabel=\(a.axes.xLabel ?? "nil"), yLabel=\(a.axes.yLabel ?? "nil"), stages=\(a.axes.stages ?? []), boundaries=\(a.axes.stageBoundaries ?? [])} rhs={xLabel=\(b.axes.xLabel ?? "nil"), yLabel=\(b.axes.yLabel ?? "nil"), stages=\(b.axes.stages ?? []), boundaries=\(b.axes.stageBoundaries ?? [])}"
        ))
    }

    // Nodes: compare by id with full-value equality (including
    // coordinates rounded to 4 decimal places to absorb floating-point
    // drift through the 0-1 / 0-100 normalization).
    func roundedCoord(_ v: Double) -> Double {
        (v * 10000).rounded() / 10000
    }
    func nodeKey(_ n: WardleyNode) -> String {
        let x = roundedCoord(n.x), y = roundedCoord(n.y)
        return "\(n.id)|x=\(x)|y=\(y)|label=\(n.label)|cls=\(n.className?.rawValue ?? "nil")|inertia=\(n.inertia)|strategy=\(n.sourceStrategy?.rawValue ?? "nil")"
    }
    let lhsNodes = Set(a.nodes.map(nodeKey))
    let rhsNodes = Set(b.nodes.map(nodeKey))
    if lhsNodes != rhsNodes {
        deltas.append(.unexpected(
            path: "wardley.nodes",
            detail: "onlyLhs=\(lhsNodes.subtracting(rhsNodes).sorted()) onlyRhs=\(rhsNodes.subtracting(lhsNodes).sorted())"
        ))
    }

    // Links: parser does not preserve declaration order across
    // re-emit; compare as multiset on (source, target, dashed, label, flow).
    func linkKey(_ l: WardleyLink) -> String {
        "\(l.source)|\(l.target)|dashed=\(l.dashed)|label=\(l.label ?? "")|flow=\(l.flow?.rawValue ?? "nil")"
    }
    let lhsLinks = a.links.map(linkKey).sorted()
    let rhsLinks = b.links.map(linkKey).sorted()
    if lhsLinks != rhsLinks {
        deltas.append(.unexpected(
            path: "wardley.links",
            detail: "lhs=\(lhsLinks) rhs=\(rhsLinks)"
        ))
    }

    // Trends (evolve).
    func trendKey(_ t: WardleyTrend) -> String {
        "\(t.nodeId)|tx=\(roundedCoord(t.targetX))"
    }
    let lhsTrends = a.trends.map(trendKey).sorted()
    let rhsTrends = b.trends.map(trendKey).sorted()
    if lhsTrends != rhsTrends {
        deltas.append(.unexpected(
            path: "wardley.trends",
            detail: "lhs=\(lhsTrends) rhs=\(rhsTrends)"
        ))
    }

    // Pipelines.
    func pipelineKey(_ p: WardleyPipeline) -> String {
        "\(p.nodeId)|children=\(p.componentIds.joined(separator: ","))"
    }
    let lhsPipelines = Set(a.pipelines.map(pipelineKey))
    let rhsPipelines = Set(b.pipelines.map(pipelineKey))
    if lhsPipelines != rhsPipelines {
        deltas.append(.unexpected(
            path: "wardley.pipelines",
            detail: "onlyLhs=\(lhsPipelines.subtracting(rhsPipelines).sorted()) onlyRhs=\(rhsPipelines.subtracting(lhsPipelines).sorted())"
        ))
    }

    // Notes.
    func noteKey(_ n: WardleyNote) -> String {
        "\(n.text)|x=\(roundedCoord(n.x))|y=\(roundedCoord(n.y))"
    }
    let lhsNotes = Set(a.notes.map(noteKey))
    let rhsNotes = Set(b.notes.map(noteKey))
    if lhsNotes != rhsNotes {
        deltas.append(.unexpected(
            path: "wardley.notes",
            detail: "onlyLhs=\(lhsNotes.subtracting(rhsNotes).sorted()) onlyRhs=\(rhsNotes.subtracting(lhsNotes).sorted())"
        ))
    }

    // Annotations: number-keyed; coordinates and text must match.
    func annotationKey(_ ann: WardleyAnnotation) -> String {
        let coords = ann.coordinates.map { "(\(roundedCoord($0.x)),\(roundedCoord($0.y)))" }.joined(separator: ",")
        return "#\(ann.number)|coords=\(coords)|text=\(ann.text ?? "")"
    }
    let lhsAnnos = Set(a.annotations.map(annotationKey))
    let rhsAnnos = Set(b.annotations.map(annotationKey))
    if lhsAnnos != rhsAnnos {
        deltas.append(.unexpected(
            path: "wardley.annotations",
            detail: "onlyLhs=\(lhsAnnos.subtracting(rhsAnnos).sorted()) onlyRhs=\(rhsAnnos.subtracting(lhsAnnos).sorted())"
        ))
    }

    // Annotations box.
    let aBox = a.annotationsBox.map { (roundedCoord($0.x), roundedCoord($0.y)) }
    let bBox = b.annotationsBox.map { (roundedCoord($0.x), roundedCoord($0.y)) }
    if aBox?.0 != bBox?.0 || aBox?.1 != bBox?.1 {
        deltas.append(.unexpected(
            path: "wardley.annotationsBox",
            detail: "lhs=\(String(describing: aBox)) rhs=\(String(describing: bBox))"
        ))
    }

    // Accelerators / deaccelerators.
    func accelKey(_ a: WardleyAccelerator) -> String {
        "\(a.name)|x=\(roundedCoord(a.x))|y=\(roundedCoord(a.y))"
    }
    func deaccelKey(_ d: WardleyDeaccelerator) -> String {
        "\(d.name)|x=\(roundedCoord(d.x))|y=\(roundedCoord(d.y))"
    }
    let lhsAccels = Set(a.accelerators.map(accelKey))
    let rhsAccels = Set(b.accelerators.map(accelKey))
    if lhsAccels != rhsAccels {
        deltas.append(.unexpected(
            path: "wardley.accelerators",
            detail: "onlyLhs=\(lhsAccels.subtracting(rhsAccels).sorted()) onlyRhs=\(rhsAccels.subtracting(lhsAccels).sorted())"
        ))
    }
    let lhsDeaccels = Set(a.deaccelerators.map(deaccelKey))
    let rhsDeaccels = Set(b.deaccelerators.map(deaccelKey))
    if lhsDeaccels != rhsDeaccels {
        deltas.append(.unexpected(
            path: "wardley.deaccelerators",
            detail: "onlyLhs=\(lhsDeaccels.subtracting(rhsDeaccels).sorted()) onlyRhs=\(rhsDeaccels.subtracting(lhsDeaccels).sorted())"
        ))
    }
    return deltas
}
```

In `DiagramDocumentDiff.swift`, add an arm above the `default:`:

```swift
    case (.wardleyBeta(let lhs), .wardleyBeta(let rhs)):
        deltas.append(contentsOf: diffWardleyMapDiagram(lhs, rhs))
```

- [ ] **Step 3.5: Register the round-trip cell**

In `RoundTripCellRegistry.swift`, add after `mermaidArchitecture`:

```swift
    static let mermaidWardley = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.wardleyBeta,
        allowedLosses: []
    )
```

- [ ] **Step 3.6: Register the test method**

In `SameFormatRoundTripTests.swift`, add after `mermaidArchitecture`:

```swift
    @Test(
        "Mermaid wardleyBeta round-trip",
        arguments: try fixtures(for: "mermaid-wardleybeta", fromRoot: roundTripResourcesRoot())
    )
    func mermaidWardleyBeta(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidWardley,
            fixture: fixture
        )
    }
```

- [ ] **Step 3.7: Run test to confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidWardleyBeta`
Expected: FAIL on `wardley.nodes` (stub emits zero nodes).

- [ ] **Step 3.8: Implement the emit body**

Replace the stub `emit` in `MermaidWardleyExport.swift` with:

```swift
    static func emit(_ model: WardleyMapDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["wardley-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("accDescr: \(singleLine(accDescr))")
        }

        if let size = model.size {
            lines.append("size [\(formatPlain(size.width)), \(formatPlain(size.height))]")
        }

        // Custom evolution stages, if present.
        if let stages = model.axes.stages, !stages.isEmpty {
            lines.append("evolution \(stages.joined(separator: " -> "))")
        }

        // Identify nodes participating in any pipeline so we can emit
        // them inside their pipeline block rather than at top level.
        let pipelineChildIds: Set<String> = Set(model.pipelines.flatMap { $0.componentIds })

        // Anchors first, then components, then pipeline parents.
        for node in model.nodes where node.className == .anchor {
            lines.append(emitTopNode(node))
        }
        for node in model.nodes where node.className != .anchor && !pipelineChildIds.contains(node.id) {
            // Pipeline parents are still emitted as `component <name>
            // [y, x]` at top level — their child components live inside
            // the `pipeline <name> { ... }` block below.
            lines.append(emitTopNode(node))
        }

        // Notes.
        for note in model.notes {
            lines.append("note \"\(escapeQuoted(note.text))\" [\(coord(note.y)), \(coord(note.x))]")
        }

        // Annotations (numbered).
        if let box = model.annotationsBox {
            lines.append("annotations [\(coord(box.y)), \(coord(box.x))]")
        }
        for ann in model.annotations.sorted(by: { $0.number < $1.number }) {
            guard let first = ann.coordinates.first else { continue }
            let text = ann.text ?? ""
            lines.append("annotation \(ann.number),[\(coord(first.y)), \(coord(first.x))] \"\(escapeQuoted(text))\"")
        }

        // Accelerators / deaccelerators.
        for acc in model.accelerators {
            lines.append("accelerator \"\(escapeQuoted(acc.name))\" [\(coord(acc.y)), \(coord(acc.x))]")
        }
        for deacc in model.deaccelerators {
            lines.append("deaccelerator \"\(escapeQuoted(deacc.name))\" [\(coord(deacc.y)), \(coord(deacc.x))]")
        }

        // Links — emit in stored order.
        for link in model.links {
            let arrow = arrowToken(dashed: link.dashed, flow: link.flow, label: link.label)
            lines.append("\(link.source) \(arrow) \(link.target)")
        }

        // Evolve trends — `evolve <component> <targetEvolution>`.
        for trend in model.trends {
            lines.append("evolve \(trend.nodeId) \(coord(trend.targetX))")
        }

        // Pipeline blocks last.
        for pipeline in model.pipelines {
            // Look up the parent node to confirm it exists in nodes
            // (already emitted at top level).
            lines.append("pipeline \(pipeline.nodeId) {")
            for childId in pipeline.componentIds {
                if let child = model.nodes.first(where: { $0.id == childId }) {
                    // Inside pipeline: single coord (evolution only).
                    lines.append("  component \(child.label) [\(coord(child.x))]")
                }
            }
            lines.append("}")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func emitTopNode(_ node: WardleyNode) -> String {
        let kind = (node.className == .anchor) ? "anchor" : "component"
        // CRITICAL coordinate swap: DSL is [visibility, evolution] =
        // [y/100, x/100] in stored model coordinates.
        var line = "\(kind) \(node.label) [\(coord(node.y)), \(coord(node.x))]"
        if let strategy = node.sourceStrategy {
            line += " (\(strategy.rawValue))"
        }
        if node.inertia {
            line += " (inertia)"
        }
        return line
    }

    private static func arrowToken(
        dashed: Bool,
        flow: WardleyFlowDirection?,
        label: String?
    ) -> String {
        // Labeled flow arrows: `+'label'<>` `+'label'>` `+'label'<`.
        // Unlabeled flow arrows: `+>` (forward), `+<` (backward),
        // `<+>` is not in the grammar; bidirectional uses `+'label'<>`.
        // Dashed: `-.->` for unflow dashed. Plain: `->`.
        if let label, !label.isEmpty {
            let marker: String
            switch flow {
            case .bidirectional: marker = "<>"
            case .backward: marker = "<"
            default: marker = ">"
            }
            return "+'\(escapeSingle(label))'\(marker)"
        }
        switch flow {
        case .forward: return "+>"
        case .backward: return "+<"
        case .bidirectional: return "+'<>"
        case .none:
            return dashed ? "-.->" : "->"
        }
    }

    private static func coord(_ value: Double) -> String {
        // Stored as 0-100; emit as 0-1 with up to 2 decimal places,
        // trimming trailing zeros. Anchors with stored x=63 emit `0.63`.
        let asUnit = value / 100.0
        // Use printf-style formatting then trim trailing zeros after `.`.
        var s = String(format: "%.4f", asUnit)
        // Trim trailing zeros, but keep at least one digit after `.`.
        while s.contains(".") && s.last == "0" {
            s.removeLast()
        }
        if s.last == "." {
            s.append("0")
        }
        return s
    }

    private static func formatPlain(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escapeQuoted(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escapeSingle(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
```

> **Type alignment notes.**
> - `WardleyNode.className` is `WardleyNodeClass?`; the
>   `.pipelineComponent` rawValue (`pipeline-component`) is set on
>   children inside a pipeline block. The exporter emits those via
>   `pipeline <parent> { component ... [<x>] }` and does not emit
>   them as top-level component lines (filtered via the
>   `pipelineChildIds` set above).
> - `WardleyLink` carries `flow: WardleyFlowDirection?` with cases
>   `.forward` / `.backward` / `.bidirectional`. The arrow tokens
>   `+>`, `+<`, `+'<>` cover those without labels; labeled variants
>   wrap the label in single quotes.
> - `WardleyTrend.targetY` mirrors the source component's `y`; the
>   DSL only encodes the `targetX` (evolution), not `targetY`.
> - `WardleyAxesConfig.stageBoundaries` is parser-internal — derived
>   from `stages` text; the DSL writes only the named stages.

- [ ] **Step 3.9: Run test to confirm GREEN on `01-basic.md`**

Run: `swift test --filter SameFormatRoundTripTests/mermaidWardleyBeta`
Expected: PASS for `01-basic.md`. If `wardley.nodes` diverges on
coordinate values, the swap is wrong — confirm the emit code uses
`[node.y/100, node.x/100]` in that order.

- [ ] **Step 3.10: Add fixture `02-pipeline-and-evolve.md`**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-wardleybeta/02-pipeline-and-evolve.md`:

```
wardley-beta
title Pipeline Evolution
component Compute [0.5, 0.6]
pipeline Compute {
  component Virtual Machine [0.3]
  component Container [0.55]
  component Serverless [0.8]
}
Compute -> Virtual Machine
```

> Derived from corpus entry `wardley-6-pipeline`. Exercises pipeline
> blocks with multi-component children at single-coord depth.

- [ ] **Step 3.11: Run test to confirm GREEN on both fixtures**

Run: `swift test --filter SameFormatRoundTripTests/mermaidWardleyBeta`
Expected: PASS for both fixtures.

Then run the corpus:
`swift test --filter CorpusRoundTripTests`
Expected: PASS for all 12 `wardley-*` corpus entries
(`wardley-1-tea-shop` through `wardley-12-minimal`). Common pitfalls
if a corpus entry diverges:
- `wardley-3-decorators` uses `(build)` / `(buy)` / `(outsource)` /
  `(market)` — confirm the `sourceStrategy` round-trips correctly.
- `wardley-4-link-types` exercises `->`, `+>`, `+<`, `-.->`, and
  `+'sync'<>` — verify `arrowToken(dashed:flow:label:)` produces all
  five variants.
- `wardley-7-custom-stages` exercises the `evolution Genesis / Concept
  -> Custom / Emerging -> Product / Converging -> Commodity / Accepted`
  line — verify stage names with `/` and spaces re-emit verbatim.
- `wardley-10-hyphenated` exercises hyphenated component names
  (`real-time processing`) — the parser's `tokenizeNameWithHyphens`
  handles them; the exporter just emits them as-is.
- `wardley-8-annotations` and `wardley-9-accelerators` exercise the
  `annotation`, `annotations`, `note`, `accelerator`, `deaccelerator`
  lines.

- [ ] **Step 3.12: Run discipline gates**

```bash
Scripts/check-diagnostic-discipline.sh
Scripts/check-file-sizes.sh
```
Expected: both exit 0.

- [ ] **Step 3.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidWardleyExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Wardley.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-wardleybeta/

git commit -m "$(cat <<'EOF'
Add Mermaid wardleyBeta exporter

Wave 3: `wardley-beta` header → title and accessibility metadata →
optional size and custom evolution stages → anchors → components
(with optional sourceStrategy decorator and inertia marker) → notes
→ annotations box and numbered annotations → accelerators /
deaccelerators → links (`->`, `+>`, `+<`, `-.->`, `+'label'<>` etc.)
→ evolve trends → pipeline blocks with single-coord child components.
DSL coordinate swap restored: emits `[node.y/100, node.x/100]` to
match the parser's OWM convention.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Wave 3 Closing — Exhaustive Switch + COVERAGE.md + BASELINES.md

This is the spec-level closing task. The Mermaid exporter switch
becomes exhaustive at 28/28; the `default: .unsupportedDiagram`
fall-through is removed; COVERAGE.md is updated to reflect 28/28
Mermaid Export coverage; BASELINES.md gains a Wave 3 entry.

**Files:**
- Modify: `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`
- Modify: `COVERAGE.md`
- Modify: `BASELINES.md`

- [ ] **Step 4.1: Confirm all 28 families are wired**

Inspect `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`.
The `supportedDiagramTypes` set must contain exactly 28 entries:
the original 7 (`flowchart`, `sequenceDiagram`, `classDiagram`,
`erDiagram`, `c4`, `gantt`, `stateDiagram`) + Wave 1's 9 (`pie`,
`sankey`, `packet`, `journey`, `timeline`, `kanban`, `mindmap`,
`treemap`, `gitGraph`) + Wave 2's 9 (`xyChart`, `quadrantChart`,
`requirement`, `radar`, `venn`, `ishikawa`, `treeView`, `zenuml`,
`eventModeling`) + Wave 3's 3 (`block`, `architecture`,
`wardleyBeta`).

Run:
```bash
grep -E "^\s*\.(flowchart|sequenceDiagram|classDiagram|erDiagram|c4|gantt|stateDiagram|pie|sankey|packet|journey|timeline|kanban|mindmap|treemap|gitGraph|xyChart|quadrantChart|requirement|radar|venn|ishikawa|treeView|zenuml|eventModeling|block|architecture|wardleyBeta)," \
  Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift | wc -l
```
Expected: `28`.

If the count is less than 28, identify the missing entry by
diffing the line list against the enumeration above and add it. Do
NOT proceed to Step 4.2 until this count is exactly 28.

- [ ] **Step 4.2: Remove the `default:` arm**

In `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`, locate
the `default:` arm in `export(_:)`:

```swift
        default:
            return .unsupportedDiagram(formatName: name, type: document.type)
```

Delete those two lines. The switch is now exhaustive — the Swift
compiler will verify that every case of `DiagramPayload` is handled.

> **Why this is the right test.** `DiagramPayload` is the typed enum
> covering all 28 families. Removing `default:` turns
> "Mermaid Export coverage" from a runtime claim into a compile-time
> invariant: any future family addition will surface as a Swift error
> at this switch until the corresponding `case .<family>` arm is
> added.

Verify the build succeeds:
```bash
swift build
```
Expected: builds clean. If Swift reports
`'switch' statement must be exhaustive`, the missing arm is the
remaining family that didn't make it into the switch — add the arm
and rerun.

- [ ] **Step 4.3: Verify the full Mermaid round-trip suite stays green**

```bash
swift test --filter SameFormatRoundTripTests
swift test --filter CorpusRoundTripTests
swift test --filter RoundTripHarnessTests
swift test --filter LossPairingTests
```
Expected: all PASS. `CorpusRoundTripTests` is now exercising every
Mermaid corpus entry whose family is in `supportedDiagramTypes` —
which is now all 28 families. If a Wave 3 family entry fails, do NOT
add it to `CorpusRoundTripTests.knownFailures`: investigate the
exporter, fix the divergence, and commit the fix as a separate
commit citing the corpus entry id (e.g.
`Fix Mermaid block exporter on block-12-mixed-rows`).

- [ ] **Step 4.4: Run all discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
```
Expected: all exit 0.

- [ ] **Step 4.5: Run the bootstrap smoke check**

```bash
Scripts/bootstrap-smoke-check.sh
```
Expected: exit 0. If Docker/Podman is not running locally, the
`linux-check.sh` step inside `bootstrap-smoke-check.sh` records as
skipped — that is acceptable per CLAUDE.md.

- [ ] **Step 4.6: Update COVERAGE.md — Export coverage table**

Open `COVERAGE.md`. In the **Export coverage** table (lines 56–86 at
present), change every `—` in the Mermaid column for the 21 Wave
1+2+3 families to `✓`. The result should match the Import column
shape:

```
| Family            | Mermaid | D2 | DOT | Structurizr | PlantUML |
|-------------------|:-------:|:--:|:---:|:-----------:|:--------:|
| flowchart         |   ✓    | ✓ | ✓  |     —      |    —    |
| stateDiagram      |   ✓    | — | —  |     —      |    ✓    |
| sequenceDiagram   |   ✓    | — | —  |     —      |    ⚠    |
| classDiagram      |   ✓    | — | —  |     —      |    ✓    |
| erDiagram         |   ✓    | — | —  |     —      |    —    |
| xyChart           |   ✓    | — | —  |     —      |    —    |
| pie               |   ✓    | — | —  |     —      |    —    |
| journey           |   ✓    | — | —  |     —      |    —    |
| gantt             |   ✓    | — | —  |     —      |    ✓    |
| quadrantChart     |   ✓    | — | —  |     —      |    —    |
| requirement       |   ✓    | — | —  |     —      |    —    |
| gitGraph          |   ✓    | — | —  |     —      |    —    |
| mindmap           |   ✓    | — | —  |     —      |    ✓    |
| timeline          |   ✓    | — | —  |     —      |    —    |
| sankey            |   ✓    | — | —  |     —      |    —    |
| block             |   ✓    | — | —  |     —      |    —    |
| packet            |   ✓    | — | —  |     —      |    —    |
| kanban            |   ✓    | — | —  |     —      |    —    |
| architecture      |   ✓    | — | —  |     —      |    —    |
| radar             |   ✓    | — | —  |     —      |    —    |
| treemap           |   ✓    | — | —  |     —      |    —    |
| venn              |   ✓    | — | —  |     —      |    —    |
| ishikawa          |   ✓    | — | —  |     —      |    —    |
| treeView          |   ✓    | — | —  |     —      |    —    |
| eventModeling     |   ✓    | — | —  |     —      |    —    |
| wardleyBeta       |   ✓    | — | —  |     —      |    —    |
| c4                |   ✓    | — | —  |     ⚠      |    ✓    |
| zenuml            |   ✓    | — | —  |     —      |    —    |
| **Totals**        | 28/28  | 1/28 | 1/28 | 1/28      | 6/28    |
```

The only Mermaid Export column change is `7/28` → `28/28` in the
Totals row, and 21 `—` → `✓` substitutions in the body rows.

- [ ] **Step 4.7: Update COVERAGE.md — remove the §1 backlog item**

Delete the entire **§ "1. Mermaid exporter completion (21 missing
families)"** section (lines 129–152 at present, from
`### 1. Mermaid exporter completion (21 missing families)` through
the closing
`This is bounded, mechanical work — the model is already in hand and
the SVG renderer/parser pair pins the semantics.`).

Renumber the remaining sections:
- `### 2. PlantUML expansion …` → `### 1. PlantUML expansion …`
- `### 3. D2 and DOT expansion …` → `### 2. D2 and DOT expansion …`
- `### 4. Structurizr scope` → `### 3. Structurizr scope`

In the **Backlog summary** section (currently lines 210–226), delete
the first bullet:

```
1. **Mermaid exporter: 21 families.** Bounded, lossless, unblocks every
   document → Mermaid round-trip and the "edit in Mermaid" sample-app flow.
```

Renumber the remaining bullets accordingly (PlantUML → 1, D2/DOT → 2,
Structurizr → 3).

- [ ] **Step 4.8: Update COVERAGE.md — Last audited date**

Change the `Last audited:` line near the top (line 8 at present) to
the current commit date. Today's date is **2026-05-19**:

```
Last audited: 2026-05-19. Cross-reference [CLAUDE.md](CLAUDE.md) "What Lives
```

(If the closing commit lands on a later date, use that date instead;
the rule is "match the date in the closing commit's
`git log -1 --format=%ad --date=short` output".)

- [ ] **Step 4.9: Update BASELINES.md**

Append a Wave 3 entry to `BASELINES.md` noting:
- Mermaid Export coverage: 25/28 → 28/28.
- 3 new families (`block`, `architecture`, `wardleyBeta`).
- 6 new round-trip fixture files (3 directories × 2 fixtures each).
- `MermaidExporter.export(_:)` switch is now exhaustive — no
  `default:` arm.
- `CorpusRoundTripTests` count grows automatically to include all
  Mermaid corpus entries (the new `block-*`, `architecture-*`, and
  `wardley-*` arms).

Read the current `BASELINES.md` first to find the canonical
insertion point and format (mirror the Wave 2 entry that landed in
commit `7a4befaf`).

- [ ] **Step 4.10: Commit the closing change**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        COVERAGE.md \
        BASELINES.md

git commit -m "$(cat <<'EOF'
Close Mermaid exporter completion: 28/28 exhaustive switch

Wave 3 closes the Mermaid exporter completion spec. The
MermaidExporter.export(_:) switch is now exhaustive at 28 families;
the default: .unsupportedDiagram fall-through is removed. The
compile-time exhaustiveness invariant replaces the runtime
"unsupportedDiagram" claim, so any future Mermaid family addition
will surface as a Swift error at this switch until the corresponding
case arm is added.

COVERAGE.md updates: Mermaid Export column moves from 7/28 to 28/28,
the "21 missing families" backlog item is removed, remaining backlog
items renumbered, "Last audited" date moved to today.

BASELINES.md entry added covering Wave 3's 3 families (block,
architecture, wardleyBeta) and 6 new round-trip fixture files.

Closes the Mermaid exporter completion spec
(docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist (executor uses on completion)

- [ ] All 3 Wave 3 family `case` arms present in
      `MermaidExporter.export(_:)`: `.block`, `.architecture`,
      `.wardleyBeta`.
- [ ] `supportedDiagramTypes` contains all 28 entries — verified by
      Task 4 Step 4.1's grep count.
- [ ] `default: .unsupportedDiagram` arm is **removed** from
      `MermaidExporter.export(_:)`. `swift build` succeeds; the
      Swift compiler's exhaustiveness check passes.
- [ ] 3 new `Mermaid<Family>Export.swift` files exist; each is under
      500 lines (the `check-file-sizes.sh` warn line). `block` may
      approach but not exceed 500.
- [ ] 3 new `DiagramDocumentDiff+<Family>.swift` files exist for
      `Block`, `Architecture`, `Wardley`.
- [ ] `DiagramDocumentDiff.swift` switch has arms for `.block`,
      `.architecture`, `.wardleyBeta`.
- [ ] 3 round-trip fixture directories exist with 2 fixtures each
      (6 fixtures total): `mermaid-block/`, `mermaid-architecture/`,
      `mermaid-wardleybeta/`.
- [ ] 3 new cells in `RoundTripCellRegistry`: `mermaidBlock`,
      `mermaidArchitecture`, `mermaidWardley`.
- [ ] 3 new `@Test` methods in `SameFormatRoundTripTests`:
      `mermaidBlock`, `mermaidArchitecture`, `mermaidWardleyBeta`.
- [ ] `MermaidExportHelpers.swift` is unchanged from end of Wave 2.
      Wave 1 helpers (`emitIndentedTree`, `emitSectionedItems`,
      `quote`, `escapeBracketLabel`, `sanitizeIdentifier`) are reused
      as-is.
- [ ] `CorpusRoundTripTests.swift` still passes; the `knownFailures`
      set is unchanged from end of Wave 2 — no Wave 3 family
      identifiers added.
- [ ] `swift test --filter SameFormatRoundTripTests` passes.
- [ ] `swift test --filter CorpusRoundTripTests` passes.
- [ ] `swift test --filter RoundTripHarnessTests` passes.
- [ ] `swift test --filter LossPairingTests` passes.
- [ ] All discipline gates green:
      - `Scripts/check-file-sizes.sh`
      - `Scripts/check-diagnostic-discipline.sh`
      - `Scripts/check-sendable-annotations.sh`
      - `Scripts/strict-concurrency-check.sh`
- [ ] `Scripts/bootstrap-smoke-check.sh` exits 0 (Linux step may
      record as skipped if Docker/Podman is unavailable).
- [ ] `COVERAGE.md` updated:
      - Mermaid Export totals: `7/28` → `28/28`.
      - 21 `—` cells in the Mermaid Export column replaced with `✓`.
      - `### 1. Mermaid exporter completion (21 missing families)`
        section deleted; remaining sections renumbered.
      - Backlog summary item #1 (Mermaid exporter) deleted; remaining
        items renumbered.
      - `Last audited:` date updated to closing commit date.
- [ ] `BASELINES.md` updated with a Wave 3 entry.
- [ ] No raw `DiagramDiagnostic(severity:message:)` constructors
      introduced; the diagnostic-discipline gate confirms.
- [ ] No exporter throws on lossy emission. Wave 3 families emit
      `[]` diagnostics on round-trip — Mermaid is canonical.
- [ ] Hand-authored fixtures derive from real corpus seeds
      (`block-2-columns`, `block-7-architecture`, `architecture-basic`,
      `architecture-edge-labels-arrows`, `wardley-1-tea-shop`,
      `wardley-6-pipeline`).
- [ ] Wardley coordinate swap is correct: emit code uses
      `[node.y/100, node.x/100]` (visibility-first, evolution-second
      per OWM convention).

---

## References

- Spec:
  [docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md](../specs/2026-05-19-mermaid-exporter-completion-design.md)
- Wave 1 plan:
  [docs/superpowers/plans/2026-05-19-mermaid-exporter-wave-1.md](2026-05-19-mermaid-exporter-wave-1.md)
- Wave 2 plan:
  [docs/superpowers/plans/2026-05-19-mermaid-exporter-wave-2.md](2026-05-19-mermaid-exporter-wave-2.md)
- Diagnostic discipline:
  [docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md)
- Existing exemplar exporters:
  - `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidIshikawaExport.swift` —
    closest match for `block` (also reuses `emitIndentedTree`).
  - `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidRequirementExport.swift` —
    closest match for `architecture` (typed-block grammar with
    relationship lines).
  - `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidEventModelingExport.swift` —
    closest match for `wardleyBeta` (multi-section linear emission).
- Round-trip harness:
  `Sources/DiagramKitTestSupport/RoundTripHarness.swift`,
  `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`,
  `Tests/DiagramKitTests/RoundTrip/CorpusRoundTripTests.swift`.
- Model types (read these before editing the diff arms):
  - `Sources/DiagramKitModel/src_block_types.swift:167` —
    `BlockDiagram`.
  - `Sources/DiagramKitModel/src_architecture_types.swift:85` —
    `ArchitectureDiagram`.
  - `Sources/DiagramKitModel/src_wardley_types.swift:203` —
    `WardleyMapDiagram`.
- Parser invariants (read these to confirm DSL syntax and the
  coordinate-swap caveat):
  - `Sources/DiagramKitModel/src_block_parser.swift:23-454` —
    block parser entry point; line 653 confirms title is
    frontmatter-only.
  - `Sources/DiagramKitModel/src_architecture_parser.swift:221-369` —
    architecture parser entry point.
  - `Sources/DiagramKitModel/src_wardley_parser.swift:80-104` —
    coordinate normalization and OWM x↔y swap.
- Discipline gates:
  `Scripts/check-diagnostic-discipline.sh`,
  `Scripts/check-file-sizes.sh`,
  `Scripts/check-sendable-annotations.sh`,
  `Scripts/strict-concurrency-check.sh`,
  `Scripts/bootstrap-smoke-check.sh`.
