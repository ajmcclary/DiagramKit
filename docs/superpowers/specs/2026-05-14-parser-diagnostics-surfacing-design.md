# Parser diagnostics surfacing — design

**Status:** Draft (brainstorming complete; pending user review before plan)
**Date:** 2026-05-14
**Closes:** REVIEW.md Session 9 "Deferred follow-up" + Important §4 → Format slices: round-trip & diagnostic discipline (the Mermaid-side blind spot)

## Background

`DiagramImportResult.diagnostics` exists today on `Sources/DiagramKitImport/DiagramImportResult.swift:15` and is populated by every non-Mermaid importer:

- `D2Importer`, `PlantUMLImporter`, `StructurizrImporter`, `GraphvizImporter` all destructure `(model, [DiagramDiagnostic])` tuples from their parsers/mappers and pass the concatenated array into `DiagramImportResult(document:, diagnostics:)`.
- `MermaidImporter.parse(...)` returns `DiagramImportResult(document: document, diagnostics: [])` at `Sources/DiagramKit/MermaidImporter.swift:50` — always empty.

The reason is the registry parse-closure shape. `DiagramDescriptor.parse` is `@Sendable (String, DiagramFrontmatter?) throws -> DiagramDocument` (`Sources/DiagramKit/DiagramDescriptor.swift:97`) — no diagnostics channel. Session 9 introduced an SPI variant `_parseC4DiagramWithDiagnostics(...) throws -> (C4Diagram, [DiagramDiagnostic])` that does carry diagnostics, but its two call sites discard the array:

```swift
// Sources/DiagramKit/DiagramRegistry+C4.swift:16
let (diagram, _) = try _parseC4DiagramWithDiagnostics(
    DiagramSourceNormalizer.rawLines(source),
    frontmatter: frontmatter
)
return diagram

// Sources/DiagramKit/AsciiRenderRegistry.swift:223
let (model, _) = try _parseC4DiagramWithDiagnostics(rawLines, frontmatter: frontmatter)
return renderC4Ascii(model)
```

Beyond the C4 case, nine other Mermaid parser/layout sites emit through `_reportDiagramIssue(...)` (`Sources/DiagramKitCommon/IssueReportingSupport.swift:39-41`), which routes to the `IssueReporting` library and is fire-and-forget. Counted call sites:

- `Sources/DiagramKitModel/src_layout.swift` × 3 — subgraph-recursion truncations
- `Sources/DiagramKitModel/src_ishikawa_layout.swift` × 1 — recursion depth
- `Sources/DiagramKitModel/src_gitgraph_layout.swift` × 1 — missing-position fallback
- `Sources/DiagramKitModel/src_kanban_parser.swift` × 1 — duplicate node ID
- `Sources/DiagramKitModel/src_sankey_parser.swift` × 1 — via `_withDiagramIssueReporting` wrapper (error path; out of scope)
- `Sources/DiagramKitCommon/CrossPlatform.swift` × 2 — render-time color/validation fallback (out of scope)

Net effect today: every Mermaid source returns `DiagramImportResult.diagnostics == []`, even when the parser detects boundary mismatches, recursion overflows, duplicate IDs, or named-arg overrides that the user would want to know about.

## Goal

Close the Mermaid diagnostic gap by:

1. Widening the registry parse-closure return type to carry a diagnostics array.
2. Routing layout-time diagnostics into `PositionedGraph` and aggregating into `PreparedDiagram` for CG / SVG / image consumers.
3. Adding an `AsciiRenderOutput` shape so the ASCII path (which bypasses `PreparedDiagram`) can surface diagnostics too.
4. Converting the in-scope `_reportDiagramIssue` sites to return-based emit; leaving render-time and error-wrap helpers alone.

End state: Mermaid sources surface diagnostics identically to D2/PlantUML/Structurizr/Graphviz today, and layout-time observations reach the caller through a documented field rather than disappearing into IssueReporting.

## Non-goals

- **No change to error semantics.** Fatal conditions continue to `throw`; `.error` severity is reserved and unused in this spec. Throws lose any diagnostics accumulated up to that point — matching the existing contract.
- **No change to `DiagramExportResult.diagnostics`** (export side). This spec is import + layout only.
- **No conversion of render-time emitters.** `CrossPlatform.swift`'s `BMColor(hex:)` fallback and validation messages stay on `_reportDiagramIssue` — they execute from rendering paths with no collector available.
- **No deletion of `_reportDiagramIssue` / `_withDiagramIssueReporting`.** Both helpers stay defined for the out-of-scope sites and the error-wrap discipline.
- **No widening of `DiagramSourceImporter` protocol.** D2/PlantUML/Structurizr/Graphviz already surface diagnostics; no protocol change is needed.

## Type-shape changes

### Registry / parser layer

`DiagramDescriptor.parse` closure:

```swift
// Before — Sources/DiagramKit/DiagramDescriptor.swift:97
public let parse: @Sendable (String, DiagramFrontmatter?) throws -> DiagramDocument

// After
public let parse: @Sendable (String, DiagramFrontmatter?) throws -> (DiagramDocument, [DiagramDiagnostic])
```

Family-level parser entry points called from the registry (`parseMermaid`, `parsePieChart`, `parseJourneyDiagram`, `parseGanttDiagram`, …, plus the C4 SPI variant) all migrate to `throws -> (Model, [DiagramDiagnostic])`. The C4 SPI variant `_parseC4DiagramWithDiagnostics` becomes the canonical `parseC4Diagram`; the old name is preserved one release as `@available(*, deprecated, renamed:)`.

`AsciiRenderRegistry.AsciiRenderDescriptor.render` closure (`Sources/DiagramKit/AsciiRenderRegistry.swift:12`):

```swift
// Before — Sources/DiagramKit/AsciiRenderRegistry.swift
let render: @Sendable (String, DiagramFrontmatter?, AsciiRenderConfig, …) throws -> String

// After
let render: @Sendable (String, DiagramFrontmatter?, AsciiRenderConfig, …) throws -> (String, [DiagramDiagnostic])
```

### Layout layer

`PositionedGraph` gains a diagnostics field (`Sources/DiagramKitModel/Types.swift:306`):

```swift
public struct PositionedGraph: Sendable {
    // … existing fields …
    public var diagnostics: [DiagramDiagnostic] = []
}
```

`GraphLayout(config:).layout(_:)` keeps its `throws -> PositionedGraph` shape. Internally, it threads a local `var diagnostics: [DiagramDiagnostic] = []` as `inout` into the helpers that need to emit, then writes the accumulated array onto the returned `PositionedGraph`.

### Aggregator types

`PreparedDiagram` (`Sources/DiagramKitRenderingCG/PreparedDiagram.swift:13`):

```swift
public struct PreparedDiagram: Sendable {
    public let bounds: CGRect
    public let positioned: PositionedGraph
    public let theme: DiagramTheme
    public let diagnostics: [DiagramDiagnostic]   // NEW

    public init(
        positioned: PositionedGraph,
        theme: DiagramTheme,
        importDiagnostics: [DiagramDiagnostic] = []   // NEW
    ) {
        self.positioned = positioned
        self.theme = theme
        self.diagnostics = importDiagnostics + positioned.diagnostics
        self.bounds = /* unchanged */
    }
}
```

The init's new parameter is appended with a default of `[]`, so existing call sites that don't pass it stay source-compatible at the cost of dropping import diagnostics (acceptable for the deprecated paths; `DiagramPipeline.prepare` is updated to pass it).

New top-level type:

```swift
// New file: Sources/DiagramKit/AsciiRenderOutput.swift
public struct AsciiRenderOutput: Sendable {
    public let text: String
    public let diagnostics: [DiagramDiagnostic]
}
```

## Data flow

```
source: String
  │
  ▼
DiagramLoader.parse(source, registry)
  │   ├─ importer.supports(source) probe  (unchanged)
  │   └─ importer.parse(source) → DiagramImportResult { document, diagnostics }
  │         │
  │         └─ (Mermaid path) DiagramRegistry+<Family>.parse closure
  │               └─ returns (DiagramDocument, [DiagramDiagnostic])
  │                        ▲
  │                        └── from family parser
  ▼
DiagramImportResult { document, diagnostics: [parse-time] }
  │
  ▼
GraphLayout(config:).layout(document)
  │   └─ helpers write into a local [DiagramDiagnostic]
  │      via inout; final array set on the returned graph.
  ▼
PositionedGraph { …, diagnostics: [layout-time] }
  │
  ▼  (CG / SVG / image path — ASCII forks below)
PreparedDiagram(positioned:, theme:, importDiagnostics: …)
  │   self.diagnostics = importDiagnostics + positioned.diagnostics
  ▼
PreparedDiagram { bounds, positioned, theme, diagnostics: [parse + layout] }
  │
  ▼
prepared.render(in:bounds:) → CGContext / BMImage / SVG
```

ASCII fork (no `PreparedDiagram`):

```
source → DiagramLoader (as above) → DiagramImportResult { document, [parse] }
       → AsciiRenderRegistry.render(source, frontmatter, …)
            └─ returns (String, [DiagramDiagnostic])

DiagramEngine.renderASCII(source:theme:)
  → AsciiRenderOutput { text: String, diagnostics: [DiagramDiagnostic] }
```

**Ordering invariant.** Aggregation order is `importDiagnostics` first, then `positioned.diagnostics`. Within each list, insertion order from the producing closure is preserved. No de-dup, no sorting. Predictable for tests.

## Pipeline call sites

| Site | Current return | New return | Notes |
|---|---|---|---|
| `DiagramPipeline.loadDocument(_:registry:)` (`DiagramPipeline.swift:64-69`) | `DiagramDocument` | private; replaced by `loadImportResult(_:registry:) -> DiagramImportResult` | Internal helper; callers in `prepare` route through the new one. |
| `DiagramPipeline.parse(_:)` / `parse(_:registry:)` (lines 71-84) | `DiagramDocument` | unchanged | Convenience; diagnostics dropped at this layer by design. |
| `DiagramPipeline.layout(_:config:registry:)` (line 88-97) | `PositionedGraph` | unchanged | Diagnostics now on the struct itself. |
| `DiagramPipeline.prepare(source:theme:layoutConfig:registry:)` (line 111-122) | `PreparedDiagram` | unchanged signature | Body wires `loadImportResult` → `PreparedDiagram(importDiagnostics:)`. |
| `DiagramPipeline.renderSVG(source:...)` (line 131+) | `String` | unchanged | SVG byte output untouched; consumers wanting diagnostics call `prepare` first. **No baseline regen.** |
| `DiagramPipeline.renderSVG(positioned:theme:)` (line 168+) | `String` | unchanged | Same rationale. |
| `DiagramPipeline.renderASCII(source:theme:)` (line 214+) | `String` | `AsciiRenderOutput` | The one breaking pipeline return. |
| `DiagramEngine.parseDiagram() async throws` (line 224) | `DiagramDocument` | unchanged | Convenience entry. |
| `DiagramEngine.parseImportResult() async throws` (NEW) | — | `DiagramImportResult` | Diagnostic-aware parse entry. |
| `DiagramEngine.renderSVG(source:...)` | `String` | unchanged | — |
| `DiagramEngine.renderASCII(source:theme:)` | `String` | `AsciiRenderOutput` | Deprecated `renderMermaidASCII` shim forwards `.text`. |

## Importer wiring

`Sources/DiagramKit/MermaidImporter.swift:50` becomes:

```swift
public func parse(_ source: String) throws -> DiagramImportResult {
    let document = /* … existing dispatch … */
    let frontmatter = /* … */
    let descriptor = /* … */
    let (doc, diagnostics) = try descriptor.parse(source, frontmatter)
    return DiagramImportResult(document: doc, diagnostics: diagnostics)
}
```

No change to `DiagramSourceImporter` protocol. No change to `D2Importer` / `PlantUMLImporter` / `StructurizrImporter` / `GraphvizImporter` — they were already correct.

`Sources/DiagramKitImport/DiagramLoader.swift` gains:

```swift
public static func parseImportResult(
    _ source: String,
    registry: ImporterRegistry = .default
) throws -> DiagramImportResult {
    let importer = try registry.match(source: source)
    return try importer.parse(source)
}
```

The existing `parseDocument(_:registry:) -> DiagramDocument` keeps its shape; internally it routes through `parseImportResult` and returns `.document`.

## Severity convention

| Severity | When | Examples |
|---|---|---|
| `.error` | Currently always `throw`s. Reserved in the diagnostic array; no emit sites use it. | (none) |
| `.warning` | Recoverable input loss or silent semantic shift the consumer would want to know about. | C4 `$boundary` named-arg overrides lexical scope (Session 9); Kanban duplicate node ID; layout recursion-depth truncations; gitgraph missing-position fallback; Ishikawa overflow; anonymous-subgraph ID collision; frontmatter-eats-body warning. |
| `.info` | Reserved for cosmetic normalization. No in-scope emit sites. | (none planned) |

The two existing Session 9 C4 emit sites already use `.warning`; converted `_reportDiagramIssue` sites all map to `.warning` (none of today's wording suggests `.info` tone).

## Migration plan

### Phase A — Foundation types (no behavior change)

Files:
- `Sources/DiagramKitModel/Types.swift:306` — add `PositionedGraph.diagnostics: [DiagramDiagnostic] = []`.
- `Sources/DiagramKitRenderingCG/PreparedDiagram.swift:13-19` — add `diagnostics` field; init grows `importDiagnostics:` param with `[]` default.
- New `Sources/DiagramKit/AsciiRenderOutput.swift`.

Tests: type-existence + default-empty assertions. No baseline impact.

### Phase B — Layout-time emitters convert

Convert 5 `_reportDiagramIssue` call sites to write into `PositionedGraph.diagnostics` via `GraphLayout(...).layout(_:)`'s locally owned accumulator threaded `inout` into helpers:

- `src_layout.swift` × 3 (`_allNodeIds`, `_subgraphContainsNode`, `_findSubgraph` recursion-limit warnings)
- `src_ishikawa_layout.swift` × 1
- `src_gitgraph_layout.swift` × 1

Tests: per-site, pathological input that triggers the warning; assert `positioned.diagnostics` contains the expected `.warning` message.

### Phase C — Family parser signatures widen

Mechanical signature migration. Per slice, roughly one commit:

- `parseMermaid` — `src_parser.swift`. Generic Mermaid parser used by flowchart / state / multiple registry sites; largest signature-change blast even though its diagnostics array starts empty today. (Session 2's `7bdd439` made the anonymous-subgraph collision a silent fix, and the same commit's frontmatter tightening was silent too — no emit sites to convert here.)
- Other family parsers start with `[]` diagnostics: `parsePieChart`, `parseJourneyDiagram`, `parseGanttDiagram`, `parseQuadrantChart`, `parseRequirementDiagram`, `parseGitGraph`, `parseMindmap`, `parseTimelineDiagram`, `parseBlockDiagram`, `parseRadarDiagram`, `parseSankeyDiagram`, `parseClassDiagram`, `parseERDiagram`, `parseSequenceDiagram`, `parseStateDiagram`, `parseXYChartDiagram`, `parseArchitectureDiagram`, `parseTreemapDiagram`, `parsePacketDiagram`, `parseEventModeling`. Pure signature-widen, no behavior change.
- `parseKanbanDiagram` — gains a `.warning` for the duplicate-node-ID case (today emitted via `_reportDiagramIssue` in `src_kanban_parser.swift`). Conversion lands in the same commit as the signature change.
- `_parseC4DiagramWithDiagnostics` → canonical `parseC4Diagram`; the old `parseC4Diagram` wrapper kept one release as deprecated.

`src_sankey_parser.swift`'s `_withDiagramIssueReporting(operation:)` usage is an error-wrap (not a non-fatal emit) and stays.

### Phase D — Registry closures rewire

Touches ~21 `Sources/DiagramKit/DiagramRegistry+<Family>.swift` + `Sources/DiagramKit/AsciiRenderRegistry.swift`. Each closure becomes:

```swift
parse: { source, frontmatter in
    let (parsed, diagnostics) = try parseFoo(source, frontmatter: frontmatter)
    return (DiagramDocument(payload: .foo(parsed)), diagnostics)
}
```

The C4 closure (`DiagramRegistry+C4.swift:16`) and the C4 ASCII site (`AsciiRenderRegistry.swift:223`) stop discarding the array — Session 9's deferred follow-up is closed here.

### Phase E — Importer + pipeline plumbing

- `Sources/DiagramKit/MermaidImporter.swift:50` — destructure tuple; populate `DiagramImportResult.diagnostics`.
- `Sources/DiagramKitImport/DiagramLoader.swift` — add `parseImportResult(_:registry:)`.
- `Sources/DiagramKit/DiagramPipeline.swift` — `loadDocument` → `loadImportResult`; `prepare` passes `importDiagnostics:`; `renderASCII` returns `AsciiRenderOutput`.
- `Sources/DiagramKit/DiagramEngine.swift` — add `parseImportResult()`; `renderASCII` returns `AsciiRenderOutput`; `renderMermaidASCII` deprecated shim forwards `.text`.

### Phase F — Test fan-out

- SVG / image baselines untouched — `renderSVG`/`renderImage` shapes unchanged.
- ASCII unit tests: every `XCTAssertEqual(try renderASCII(...), expected)` becomes `... .text`.
- ASCII snapshot tests: 174 baselines stay valid; the snapshot helper in `Tests/DiagramKitTests/CorpusSnapshotTests.swift` reads `.text`.
- New parser + layout diagnostic tests: 8 `@Test`s, one per converted emit site (see Tests, by tier).
- New layout-diagnostic tests: per-site as in Phase B.
- New aggregation test: source string with both parse-time + layout-time warnings → `prepare(source:)` → assert `prepared.diagnostics` contains both in `[parse, layout]` order.
- New per-family `MermaidImporter().parse(source)` tests asserting `.diagnostics` is populated for diagnostic-emitting families (today: C4 and Kanban only — others surface only layout diagnostics via `PositionedGraph`).

### Phase G — Doc sync

- `CLAUDE.md` "Pipeline" diagram annotated with diagnostic flow.
- `CLAUDE.md` "Public Surface" notes `AsciiRenderOutput` shape change.
- `ARCHITECTURE.md` "Importers / Loaders" paragraph on parse-time vs layout-time diagnostic surfaces.
- `REVIEW.md` gains "Resolution Status — Session 10" entry referencing this spec + the plan.

## Tests, by tier

1. **Schema tests** (Phase A): `PositionedGraph.diagnostics` default-empty; `PreparedDiagram.diagnostics` aggregation order with explicit fixtures; `AsciiRenderOutput` shape. ~5–6 assertions.
2. **Per-emitter tests** (Phases B + C): one `@Test` per converted site. Coverage list (8 tests):
   - 3 × `src_layout.swift` recursion-limit
   - 1 × `src_ishikawa_layout.swift`
   - 1 × `src_gitgraph_layout.swift`
   - 1 × `src_kanban_parser.swift` duplicate node
   - 2 × C4 (re-pin Session 9's lexical-override + unresolved-ref against the new public surface)
3. **End-to-end aggregation test** (Phase E): one fixture triggering both parse + layout warnings via `DiagramPipeline.prepare`.
4. **MermaidImporter populates diagnostics** (Phase E): one `@Test` per diagnostic-emitting family (currently C4 + Kanban); assert `.diagnostics.count > 0`.
5. **Snapshot delta check** (Phase F): SVG + image baselines byte-stable; ASCII baselines pass through the new `.text` adapter.

## Discipline gates

- `Scripts/check-file-sizes.sh`: `src_parser.swift` already in yellow band (~928 lines post-Session 9); Phase-C adds ~10–20 lines. Stays yellow; no red crossing.
- `Scripts/check-sendable-annotations.sh`: no new `@unchecked Sendable`.
- `Scripts/strict-concurrency-check.sh`: tuple returns and `inout [DiagramDiagnostic]` are Sendable-safe.
- `Scripts/linux-check.sh`: all changes are in Linux-portable targets (`DiagramKitCommon`, `DiagramKitModel`, `DiagramKitImport`, `DiagramKit`). `PreparedDiagram` lives in `DiagramKitRenderingCG` (Apple-only); its diagnostic field is also Apple-only — Linux callers go through `DiagramImportResult` + `PositionedGraph.diagnostics` directly.

## Risk callouts

- **Phase C source-compat break**: any third party importing a family parser directly (`parsePieChart`, etc.) breaks at source level. Acceptable — these are SPI-prefixed in spirit (`src_*_parser.swift`) and were never part of the documented public surface.
- **Phase E `renderASCII` shape change**: every ASCII-consuming test site rewrites to `.text`. All in-repo; no external break beyond CLAUDE.md's documented surface. The deprecated `renderMermaidASCII` shim preserves backward compat via `.text` forwarding.
- **Phase B `inout` threading**: `src_layout.swift` helpers already pass substantial state; adding one more `inout [DiagramDiagnostic]` is in-pattern. No isolated risk.
- **Throw-loses-partial-diagnostics**: when a parser throws mid-way, diagnostics accumulated up to that point are lost. Matches existing `DiagramImportResult` contract (errors throw, results return). Documented invariant; no partial-result reporting.

## Estimated commit count

~30 commits on `main`, each independently green:

- Phase A: 2 commits (foundation types, AsciiRenderOutput).
- Phase B: 3 commits (one per layout file).
- Phase C: ~21 commits (one per family parser slice).
- Phase D: 2 commits (DiagramRegistry+\* en masse + AsciiRenderRegistry).
- Phase E: 2 commits (importer/loader + pipeline/engine).
- Phase F: 1 commit (test sweep).
- Phase G: 1 commit (doc sync + REVIEW Session 10 entry).

Commit boundaries follow the standing default: commit-by-commit on `main`, no worktrees/branches.

## Out of scope — explicit deferrals

- `CrossPlatform.swift` `BMColor(hex:)` fallback warning (render-time site).
- `_withDiagramIssueReporting(operation:)` helper (error-wrap; orthogonal to non-fatal diagnostics).
- Widening `DiagramSourceImporter` protocol or restructuring the per-format importers — D2/PlantUML/Structurizr/Graphviz are already correct.
- Adding a `DiagramExportResult.diagnostics` parallel surface (already exists).
- The umbrella's `#if canImport(CoreGraphics)` gate that hides SVG/ASCII on Linux (cross-cutting #5 from REVIEW.md; separate spec).
- The `renderDiagramSVG` free-function deprecation migration (Cross-cutting #3 from REVIEW.md; separate spec).
