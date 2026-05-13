# DiagramKit Code Quality Remediation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Status (last updated 2026-05-13)

| Phase | Status | Closing commit range | Audit findings closed |
| --- | --- | --- | --- |
| Phase 1 — ELK dictionary boundary | **COMPLETE** | `625207d..aee8904` | A1, D2, Priority 1 |
| Phase 2 — Descriptor-driven render dispatch | **COMPLETE** | `a11f5f3..bff4c71` | A3, A4, Priority 2 |
| Phase 3 — `_typed` + frontmatter runners | **COMPLETE** | `095530a..8e3f626` | A2, D1, Priority 3 |
| Phase 4 — Error taxonomy + target metadata | **COMPLETE** | `7e189a7..8debf64` | P1, P3, Priority 4 |
| Phase 5 — Duplication clean-up | **COMPLETE** | `de2f713..a97b4bf` | D3, D4, D5, P2 |
| Phase 6 — Public legacy port surface | **PENDING** | — | A5, Priority 5 |
| Phase 7 — Comment hygiene + guard script | **PENDING** | — | P4 (residual) |

**Notes on Phases 1–5 (history for the executor):**

- Phase 1 found that ER, Class, and Requirement layouts each carried their own parallel `_ElkNode`/`_RElkNode` typed structs with full encode/decode chains; per the user's "Convert all three" choice we unified them onto the shared `ElkGraphNode` and deleted ~485 lines of encoder/decoder boilerplate. The closure criterion in the original plan said "rg `[String: Any]` returns only the encoder body" — interpret that scoped to the **builder** files (`src_layout.swift`, `src_class_layout.swift`, `src_er_layout.swift`, `src_requirement_layout.swift`), since `src_elk_instance.swift` still hosts the dict-based layout algorithm internally and is the single boundary by design.
- Phase 2's premise was outdated: every diagram family already had `renderPositioned` in `SVGRenderRegistry.all`, so the real work was retiring `_renderDiagramSVG` + the 27 source-based `_render*SvgCase` functions and building `AsciiRenderRegistry`. The flowchart/state ASCII arm stays inline (needs class-private helpers).
- Phase 3 covered 26 of 28 family descriptors with `_typed`; `_flowchart` and `_state` stay direct because they cross-emit (parse one type into another's payload). Frontmatter runners (`SingleSectionBinding`, `ConfigThemeBinding`) cover all 15 paired/single bindings the audit listed.
- Phase 4 used TDD: 6-test `MalformedSourceErrorTaxonomyTests` were written first and failed with `.notYetImplemented` before the conversion.
- Phase 5 introduced one SPI protocol (`_PointLike`) to bridge `DiagramPoint`/`ErPoint`/`ClassPoint`/`_PositionedPointPayload` for the bounding helper without forcing a unified Point type.

**Operating preferences durably established during execution (apply for remaining phases):**

- Direct commits on `main` (no worktrees/branches — see `feedback_branching` memory).
- `swift test --filter <pattern>` only; never run the full corpus inline (signal-10 caveat).
- The user prefers inline execution with batched edits; check in after each phase closes.
- When migrating many similar files, batch 5-ish per commit with one snapshot regression at the end.
- Skip running newly-created snapshots (the test runner auto-records them). Always verify against EXISTING baselines and delete unexpected new files via `git clean -fd Tests/DiagramKitTests/__Snapshots__/`.

---

**Goal:** Resolve every finding in `CODE_QUALITY_AUDIT.md` (2026-05-13) so DiagramKit's abstractions are uniformly adopted, dispatch is descriptor-driven, error taxonomy is correct, and legacy port surfaces are deliberately scoped.

**Architecture:** Work proceeds in seven phases following the audit's five-priority roadmap plus duplication and comment-hygiene clean-up. Phases are independently shippable; each ends in a green `Scripts/bootstrap-smoke-check.sh` and a release-shaped commit on `main`. Phase 1 collapses the ELK dictionary boundary so subsequent layout changes are type-checked; Phase 2 unifies render dispatch so format drift becomes impossible; Phase 3 adopts the helpers the audit shows already exist; Phase 4 fixes the package manifest and error taxonomy; Phase 5 deduplicates the geometry/canvas/export walking helpers; Phase 6 retires the public `original_src_*` surface; Phase 7 sweeps stale "will be introduced" comments.

**Tech Stack:** Swift 6 strict concurrency, SwiftPM, swift-testing + XCTest, swift-snapshot-testing, ELK-via-Java layout, no thread pool (per `CLAUDE.md`).

**Verification spine for every task:**

- `swift build` — must succeed.
- `swift build --build-tests` — must succeed.
- `swift test --filter <NameOrPattern>` — relevant suite only. Never run the full corpus inline (`feedback_test_chunks` memory; `corpus_signal_10` memory).
- `Scripts/check-file-sizes.sh` — warnings only; no new files cross 1000 lines.
- `Scripts/check-sendable-annotations.sh` — banner or allowlist for any new `@unchecked Sendable`.
- `Scripts/strict-concurrency-check.sh` — first-party strict concurrency clean.
- `Scripts/bootstrap-smoke-check.sh` — final phase gate; Docker/Podman-skipped `linux-check.sh` is acceptable.

**Snapshot strategy:** All refactors must keep `Tests/DiagramKitTests/__Snapshots__/` byte-identical. If a snapshot must change, the task explicitly says so and records via:

```bash
SNAPSHOT_TESTING_RECORD=true swift test --filter <suite>
```

Chunked runs use `SNAPSHOT_DIAGRAM_IDS=...` to avoid the known signal-10 caveat on full corpus runs.

**Commit cadence:** Direct commits on `main` (per `feedback_branching` memory). Each numbered task ends in a commit; phases close with a summary commit that updates `CLAUDE.md`/`ARCHITECTURE.md` if any invariant moved.

---

## Phase 1 — Collapse the ELK dictionary boundary

Maps to audit priority **P1** plus duplication finding **D2**. The typed `ElkGraphNode`/`ElkGraphEdge`/`ElkGraphLabel` already exist in `Sources/DiagramKitModel/ElkModels.swift` (170 lines) but `Sources/DiagramKitModel/src_layout.swift` (1557 lines) still aliases `_ElkNode = [String: Any]` at line 14 and constructs ELK graphs as nested dictionaries in three places (`_buildElkGraph`, `_buildElkGraphNoCrossEdges`, `_buildFlatElkGraph`). Same pattern repeats in `src_er_layout.swift`, `src_class_layout.swift`, `src_requirement_layout.swift`, and `src_elk_instance.swift`.

**End state:** Typed ELK builders are the only source of graph descriptions. Dictionary form survives only at the single `layoutEngineSync` boundary, produced by `ElkGraphNode.toDictionary()` (and reverse for the response). `ElkLayoutOptions` owns every root/subgraph/edge-label option table.

### Task 1.1: Add `ElkLayoutOptions` and dictionary encoders

**Files:**

- Create: `Sources/DiagramKitModel/ElkLayoutOptions.swift`
- Modify: `Sources/DiagramKitModel/ElkModels.swift`
- Test: `Tests/DiagramKitTests/ElkModelsTests.swift`

- [ ] **Step 1: Write failing test for `ElkLayoutOptions.root`**

```swift
@Test func rootOptionsForLR() {
    let opts = ElkLayoutOptions.root(direction: .LR, hierarchy: .includeChildren)
    #expect(opts["elk.algorithm"] == "layered")
    #expect(opts["elk.direction"] == "RIGHT")
    #expect(opts["elk.hierarchyHandling"] == "INCLUDE_CHILDREN")
    #expect(opts["elk.padding"] == "[top=40,left=40,bottom=40,right=40]")
}
```

- [ ] **Step 2: Run test to verify failure**

```
swift test --filter ElkModelsTests/rootOptionsForLR
```

Expected: build error (`ElkLayoutOptions` undefined).

- [ ] **Step 3: Implement `ElkLayoutOptions` matching the three current call sites in `src_layout.swift:73-97`, `src_layout.swift:1399-1423`, and the fallback at `src_layout.swift:1426-1484`**

```swift
public enum ElkLayoutOptions {
    public enum HierarchyMode: String {
        case includeChildren = "INCLUDE_CHILDREN"
        case separateChildren = "SEPARATE_CHILDREN"
    }

    public static func root(direction: original_src_types.Direction,
                            hierarchy: HierarchyMode) -> [String: String] { ... }

    public static func subgraph() -> [String: String] { ... }
}
```

- [ ] **Step 4: Add `ElkGraphNode.toDictionary()`, `ElkGraphEdge.toDictionary()`, `ElkGraphLabel.toDictionary()`**

These are pure encoders. Behavior contract: round-tripping `_buildElkGraph` output through the typed builders + `toDictionary()` produces a structurally identical `[String: Any]` (compare via `NSDictionary` equality in tests).

- [ ] **Step 5: Run new tests**

```
swift test --filter ElkModelsTests
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitModel/ElkLayoutOptions.swift \
        Sources/DiagramKitModel/ElkModels.swift \
        Tests/DiagramKitTests/ElkModelsTests.swift
git commit -m "feat(elk): introduce ElkLayoutOptions and dictionary encoders"
```

### Task 1.2: Convert `_buildFlatElkGraph` to typed builder

**Files:**

- Modify: `Sources/DiagramKitModel/src_layout.swift` (rewrite the flat-graph builder; keep the call site identical via a `toDictionary()` shim into `layoutEngineSync`).
- Test: `Tests/DiagramKitTests/LayoutSnapshotTests.swift` (existing flowchart snapshots act as the regression net).

- [ ] **Step 1: Capture current behavior by snapshotting a representative flowchart**

```
SNAPSHOT_DIAGRAM_IDS=flowchart-1-simple,flowchart-2-subgraph swift test \
  --filter CorpusSnapshotTests/imageSnapshot
```

Expected: pass on `main`.

- [ ] **Step 2: Replace the body of `_buildFlatElkGraph` with `ElkGraphBuilder.makeFlowGraph(...)` and `.toDictionary()` at the return.**
- [ ] **Step 3: Rerun the same `SNAPSHOT_DIAGRAM_IDS` slice; expect byte-identical output.**
- [ ] **Step 4: Commit**

```bash
git commit -am "refactor(layout): build flat ELK graph through typed model"
```

### Task 1.3: Convert hierarchical `_buildElkGraph`

**Files:**

- Modify: `Sources/DiagramKitModel/src_layout.swift:1297-1424`

- [ ] **Step 1: Identify every dictionary spot in the hierarchical path (3 sites by `rg -n '\[String: Any\]' Sources/DiagramKitModel/src_layout.swift`).**
- [ ] **Step 2: Replace with `ElkGraphBuilder.makeHierarchicalGraph(...)` returning `ElkGraphNode`.**
- [ ] **Step 3: Snapshot regression: subgraph-heavy slice**

```
SNAPSHOT_DIAGRAM_IDS=flowchart-2-subgraph,flowchart-3-nested-subgraph,block-2-columns \
  swift test --filter CorpusSnapshotTests/imageSnapshot
```

- [ ] **Step 4: Commit.**

### Task 1.4: Convert `_buildElkGraphNoCrossEdges` (fallback)

**Files:**

- Modify: `Sources/DiagramKitModel/src_layout.swift:1426-1484`

- [ ] **Step 1–3:** Mirror Task 1.3 with the no-cross-edges path; verify with the same chunked snapshot.
- [ ] **Step 4: Commit.**

### Task 1.5: Lift `LayoutNode = [String: Any]` from `src_elk_instance.swift`

**Files:**

- Modify: `Sources/DiagramKitModel/src_elk_instance.swift:4`
- Modify: any call sites that depended on the dictionary alias

- [ ] **Step 1: Replace `public typealias LayoutNode = [String: Any]` with `public typealias LayoutNode = ElkGraphNode` (or remove if no consumer needs the alias).**
- [ ] **Step 2: Adjust `layoutEngineSync` to accept `ElkGraphNode` and call `.toDictionary()` inside the function — the only dictionary boundary now.**
- [ ] **Step 3: Compile-fix any leak sites (`rg -n 'LayoutNode' Sources`).**
- [ ] **Step 4: Run smoke build + chunked snapshots.**
- [ ] **Step 5: Commit.**

### Task 1.6: Apply typed builders in remaining family layouts

**Files:**

- Modify: `Sources/DiagramKitModel/src_er_layout.swift` (24 dict hotspots)
- Modify: `Sources/DiagramKitModel/src_class_layout.swift` (13 dict hotspots)
- Modify: `Sources/DiagramKitModel/src_requirement_layout.swift` (14 dict hotspots)

For each file:

- [ ] **Step 1: Snapshot the family slice.** Example for ER:

```
SNAPSHOT_DIAGRAM_IDS=er-1-simple,er-2-multi swift test --filter CorpusSnapshotTests/imageSnapshot
```

- [ ] **Step 2: Replace dict constructions with `ElkGraphBuilder` calls.**
- [ ] **Step 3: Confirm snapshot byte-identity.**
- [ ] **Step 4: Commit per family** (`refactor(er-layout): adopt typed ELK builder`, etc.).

### Task 1.7: Phase 1 closure

- [ ] **Step 1: `rg -n '\[String: Any\]|_ElkNode' Sources/DiagramKitModel`** — only allowed match is the single `ElkGraphNode.toDictionary()` encoder.
- [ ] **Step 2: `swift test --filter LayoutSnapshotTests`** plus a representative `CorpusSnapshotTests/imageSnapshot` chunk per family.
- [ ] **Step 3: Run `Scripts/bootstrap-smoke-check.sh`.**
- [ ] **Step 4: Update `CODE_QUALITY_AUDIT.md` to strike A1 and D2.**
- [ ] **Step 5: Commit `chore(audit): close ELK dictionary findings`.**

---

## Phase 2 — Descriptor-driven render dispatch

Maps to audit priorities **P2** and **A3 / A4**. Today `SVGRenderRegistry.swift` (457 lines) provides positioned descriptors, but `Sources/DiagramKit/src_index.swift` (401 lines) still defines 28 `_render*SvgCase` legacy functions, `DiagramPipeline.swift` keeps two SVG entry points (positioned + source), and `src_ascii_index.swift` (670 lines) is a parallel god-object with its own 28-arm `DiagramType` switch (`src_ascii_index.swift:346-557`).

**End state:** Source → `DiagramDocument` → `PositionedGraph` → output, with one descriptor per family per output format. `_render*SvgCase` and the ASCII switch shrink to thin adapters used only where a family genuinely lacks positioned support.

### Task 2.1: Inventory legacy SVG case paths

**Files:**

- Modify: `Sources/DiagramKit/src_index.swift`
- Create: `Sources/DiagramKit/_LegacySVGCaseInventory.swift` (transient; deleted at Phase 6)

- [ ] **Step 1: Generate the list of `_render*SvgCase` symbols (`rg -n '_render.*SvgCase' Sources/DiagramKit/src_index.swift`) and classify each as "has positioned descriptor" / "no positioned descriptor".**
- [ ] **Step 2: Record the result in a Swift table (compile-checked) keyed by `DiagramType`. This becomes the ground truth for Task 2.2.**
- [ ] **Step 3: Commit `docs(svg): inventory legacy SVG case paths`.**

### Task 2.2: Make positioned SVG the default in `DiagramPipeline.renderSVG`

**Files:**

- Modify: `Sources/DiagramKit/DiagramPipeline.swift:130-211`

- [ ] **Step 1: Add a failing test asserting that for every family with a positioned descriptor, `DiagramPipeline.renderSVG(source:)` produces the same string as `DiagramPipeline.renderSVG(positioned:)` of the same source.** Use 4–6 representative diagrams (flowchart, sequence, class, ER, gantt, sankey).
- [ ] **Step 2: Implement the unification: parse via `loadDocument`, layout via `GraphLayout`, render via `SVGRenderRegistry.render(positioned:)`.**
- [ ] **Step 3: Fall back to a legacy `_render*SvgCase` only when the inventory says no positioned descriptor exists.**
- [ ] **Step 4: Rerun chunked SVG snapshots:**

```
SNAPSHOT_DIAGRAM_IDS=flowchart-1-simple,sequence-1-basic,class-1-basic swift test \
  --filter CorpusSnapshotTests/svgSnapshot
```

- [ ] **Step 5: Commit.**

### Task 2.3: Build `AsciiRenderRegistry`

**Files:**

- Create: `Sources/DiagramKit/AsciiRenderRegistry.swift`
- Modify: `Sources/DiagramKit/src_ascii_index.swift:406-557`
- Test: `Tests/DiagramKitTests/AsciiRenderRegistryTests.swift`

- [ ] **Step 1: Write a failing test asserting `AsciiRenderRegistry.all.keys` covers every `DiagramType` case.** This pins the registry as the single source of truth.
- [ ] **Step 2: Define `AsciiRenderDescriptor` mirroring the illustrative refactor in audit A3.**

```swift
struct AsciiRenderDescriptor: Sendable {
    let type: DiagramType
    let render: @Sendable (DiagramDocument, AsciiRenderContext) throws -> String
}
```

- [ ] **Step 3: Migrate the 28 ASCII arms one-by-one, parsing through `DiagramPipeline.parse` instead of re-running `_preprocessMermaidSource` + family parsers.**
- [ ] **Step 4: Keep `detectDiagramType` mapping (audit lines 346-378) as a thin lookup over `AsciiRenderRegistry.all`.**
- [ ] **Step 5: Snapshot regression per family:**

```
SNAPSHOT_DIAGRAM_IDS=<family-id> swift test --filter CorpusSnapshotTests/asciiSnapshot
```

- [ ] **Step 6: Commit per family migration; final commit reduces `src_ascii_index.swift` below the 500-line warning threshold (currently 670).**

### Task 2.4: Retire `_renderDiagramSVG` once unreachable

**Files:**

- Modify: `Sources/DiagramKit/DiagramPipeline.swift:205-211`
- Modify: `Sources/DiagramKit/src_index.swift:45`

- [ ] **Step 1: `rg -n '_renderDiagramSVG' Sources Tests`** to confirm no remaining caller after Task 2.2.
- [ ] **Step 2: Remove the function and the options-path entry point; mark transitions in `DiagramEngine` docstrings.**
- [ ] **Step 3: Commit `refactor(svg): remove legacy _renderDiagramSVG entry point`.**

### Task 2.5: Phase 2 closure

- [ ] **Step 1:** `swift test --filter CorpusSnapshotTests/svgSnapshot` and `…/asciiSnapshot` in chunked batches (see `CLAUDE.md` for the `SNAPSHOT_DIAGRAM_IDS` pattern).
- [ ] **Step 2:** `Scripts/bootstrap-smoke-check.sh`.
- [ ] **Step 3:** Update `ARCHITECTURE.md`'s "Two independent renderers exist" note to reflect the new positioned-canonical path.
- [ ] **Step 4: Strike audit A3, A4, P5 (the central-switch portion) and Priority 2 in `CODE_QUALITY_AUDIT.md`.**
- [ ] **Step 5: Commit.**

---

## Phase 3 — Adopt `_typed` descriptors and frontmatter binding runners

Maps to audit priority **P3** plus **A2** and **D1**. `DiagramRegistry+TypedDescriptor.swift:24` defines `_typed` but no caller references it (`rg -n '_typed' Sources/DiagramKit`). `DiagramRegistry+Sequence.swift`, `+Class.swift`, `+ER.swift`, and 11+ other family extension files hand-code the same payload-guard + payload-wrap shape. Frontmatter bindings (`FrontmatterBinding+*.swift`, 27 family files) repeat the same prefix-extract + `hasConfig`/`hasTheme` flip + commit skeleton.

**End state:** Every one-to-one family descriptor uses `_typed`; only cross-emitting families (flowchart parsing state) keep direct `DiagramDescriptor` construction. Frontmatter bindings use `SingleSectionBinding` or `ConfigThemeBinding` runners that own prefix matching and section flags.

### Task 3.1: Adopt `_typed` for three example families

**Files:**

- Modify: `Sources/DiagramKit/DiagramRegistry+Sequence.swift`
- Modify: `Sources/DiagramKit/DiagramRegistry+Class.swift`
- Modify: `Sources/DiagramKit/DiagramRegistry+ER.swift`

- [ ] **Step 1: Pin behavior with a small "registry detect → parse → layout" test for each family.**
- [ ] **Step 2: Rewrite each descriptor using `_typed`, matching the audit's A2 illustrative refactor.**
- [ ] **Step 3: Verify byte-identical outputs via a chunked snapshot of the relevant families.**
- [ ] **Step 4: Commit per family** (`refactor(registry): adopt _typed for sequence diagram`, etc.).

### Task 3.2: Migrate the remaining one-to-one descriptors

**Files (modify each):**

- `DiagramRegistry+Architecture.swift`, `+Block.swift`, `+C4.swift`, `+EventModeling.swift`, `+Gantt.swift`, `+GitGraph.swift`, `+Ishikawa.swift`, `+Journey.swift`, `+Kanban.swift`, `+Mindmap.swift`, `+Packet.swift`, `+Pie.swift`, `+Quadrant.swift`, `+Radar.swift`, `+Requirement.swift`, `+Sankey.swift`, `+Timeline.swift`, `+TreeView.swift`, `+Treemap.swift`, `+Venn.swift`, `+Wardley.swift`, `+XYChart.swift`, `+ZenUML.swift`

Cross-emitting families that must **not** be migrated: `DiagramRegistry+Flowchart.swift`, `+State.swift` (they parse one type into another's payload).

- [ ] **Step 1: For each file, replace the descriptor with a `_typed(...)` call.**
- [ ] **Step 2: After each batch of 4–5 files, run `swift build` and a snapshot chunk that covers the migrated families.**
- [ ] **Step 3: Commit per logical batch.**

### Task 3.3: Add frontmatter binding runners

**Files:**

- Modify: `Sources/DiagramKitModel/FrontmatterBinding.swift`
- Create: `Sources/DiagramKitModel/FrontmatterBinding+Runners.swift`
- Test: `Tests/DiagramKitTests/FrontmatterBindingRunnerTests.swift`

- [ ] **Step 1: Write a failing test for `SingleSectionBinding` (mirrors `ERFrontmatterBinding`).** Assert that a path/value pair flips the section flag and applies the typed config.
- [ ] **Step 2: Write a failing test for `ConfigThemeBinding` (mirrors `PacketFrontmatterBinding`).** Cover config-only, theme-only, and mixed paths.
- [ ] **Step 3: Implement both runners as the audit's D1 illustrative refactor.**
- [ ] **Step 4: Run new tests.**
- [ ] **Step 5: Commit `feat(frontmatter): introduce single-section and config/theme binding runners`.**

### Task 3.4: Migrate frontmatter bindings — single-section group

**Files:** `FrontmatterBinding+ER.swift`, `+Ishikawa.swift`, `+Journey.swift`, `+Kanban.swift`, `+Class.swift`, `+C4.swift`, `+Mindmap.swift`, `+State.swift`

- [ ] **Step 1: For each binding, replace the hand-written `apply` body with a `SingleSectionBinding` adapter.**
- [ ] **Step 2: Confirm parser tests for that family still pass:**

```
swift test --filter FrontmatterTests
swift test --filter <Family>ParserTests
```

- [ ] **Step 3: Commit per file** (`refactor(frontmatter): adopt single-section runner for ER`, etc.).

### Task 3.5: Migrate frontmatter bindings — config/theme group

**Files:** `FrontmatterBinding+Architecture.swift`, `+Packet.swift`, `+XYChart.swift`, `+Timeline.swift`, `+Requirement.swift`, `+Venn.swift`, `+Quadrant.swift`

- [ ] **Step 1–2: Mirror Task 3.4 using `ConfigThemeBinding`.**
- [ ] **Step 3: Commit per file.**

### Task 3.6: Phase 3 closure

- [ ] **Step 1:** `rg -n '_typed' Sources/DiagramKit | wc -l` — expect ≥ 24 occurrences (one per migrated family + the definition).
- [ ] **Step 2:** Run a representative `CorpusSnapshotTests` chunk per migrated family.
- [ ] **Step 3:** `Scripts/bootstrap-smoke-check.sh`.
- [ ] **Step 4:** Strike audit A2, D1, and Priority 3.
- [ ] **Step 5: Commit.**

---

## Phase 4 — Error taxonomy and target metadata

Maps to audit priorities **P1 (manifest)**, **P3 (errors)**, and **Priority 4**. Verified misuse: `DOTParserHelpers.swift:34, 99`, `D2Parser.swift:111, 115`, and `StructurizrParser.swift` throws `.notYetImplemented` for 16 distinct syntax errors. `Package.swift:90-92` lists `DiagramKitGraphviz` deps as `["DiagramKitModel", "DiagramKitImport"]` while both `DOTExporter.swift` and `DOTFlowchartExport.swift` import `DiagramKitExport`.

**End state:** `.notYetImplemented` is reserved for genuine feature gaps; malformed source uses `.malformedSource(message:)`; valid-but-unsupported uses a `.unsupported` diagnostic on the import result. `Package.swift` matches the real import graph.

### Task 4.1: Add `DiagramKitExport` to the Graphviz target

**Files:**

- Modify: `Package.swift:89-93`

- [ ] **Step 1: Change the target deps to `["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"]`.**
- [ ] **Step 2: Run `swift package resolve` (per `CLAUDE.md`) then `swift build --target DiagramKitGraphviz`.**
- [ ] **Step 3: Commit `fix(package): declare DiagramKitExport dependency on DiagramKitGraphviz`.**

### Task 4.2: Add malformed-source assertions in importer tests

**Files:**

- Create or extend: `Tests/DiagramKitTests/D2ParserMalformedSourceTests.swift`
- Create or extend: `Tests/DiagramKitTests/StructurizrParserMalformedSourceTests.swift`
- Create or extend: `Tests/DiagramKitTests/DOTParserMalformedSourceTests.swift`

- [ ] **Step 1: Write failing tests asserting that the malformed inputs (unterminated brace, missing `workspace`, missing `]`, etc.) throw `DiagramError.malformedSource(message:)`.**
- [ ] **Step 2: Run tests to verify they fail with `.notYetImplemented` instead.**
- [ ] **Step 3: Commit `test: assert malformed-source taxonomy for D2/DOT/Structurizr`.**

### Task 4.3: Convert parser throws

**Files:**

- Modify: `Sources/DiagramKitD2/D2Parser.swift:102-116`
- Modify: `Sources/DiagramKitGraphviz/DOTParserHelpers.swift:32-35, 98-100`
- Modify: `Sources/DiagramKitStructurizr/StructurizrParser.swift` (16 sites)

- [ ] **Step 1: Replace every "syntax error" throw with `DiagramError.malformedSource(message:)`. Keep `.notYetImplemented` only for genuinely missing features (none expected in these parsers; verify in code review).**
- [ ] **Step 2: Rerun Task 4.2 tests — expect green.**
- [ ] **Step 3: Run full importer test suites:**

```
swift test --filter D2Parser
swift test --filter DOTParser
swift test --filter StructurizrParser
```

- [ ] **Step 4: Commit per parser.**

### Task 4.4: Phase 4 closure

- [ ] **Step 1:** `rg -n 'notYetImplemented' Sources/DiagramKitD2 Sources/DiagramKitGraphviz Sources/DiagramKitStructurizr` — should be empty unless a real implementation gap is documented inline.
- [ ] **Step 2:** `Scripts/bootstrap-smoke-check.sh`.
- [ ] **Step 3:** Strike audit P1, P3, and Priority 4.
- [ ] **Step 4: Commit.**

---

## Phase 5 — Duplication clean-up (geometry, ASCII canvas, exporter walking)

Maps to audit duplications **D3**, **D4**, **D5** and pattern finding **P2** (font resolution). Verified: `DiagramBoundsLookup+Flowchart.swift:48-63`, `+Class.swift:26-41`, `+ER.swift:26-41` repeat polyline bounding; ASCII renderers `src_ascii_sequence.swift:334`, `src_ascii_class_diagram.swift:344`, `src_ascii_er_diagram.swift:322` repeat the same `setC` helper; flowchart exporters in `DiagramKitD2` and `DiagramKitGraphviz` walk `ParsedGraphModel` identically.

### Task 5.1: `DiagramRect.bounding(points:paddedBy:)`

**Files:**

- Modify: `Sources/DiagramKitCommon/DiagramGeometry.swift:43-100`
- Test: `Tests/DiagramKitTests/DiagramGeometryTests.swift`

- [ ] **Step 1: Write failing tests for empty input, single point, multi-point with positive pad, with zero pad.**
- [ ] **Step 2: Implement per audit D3 illustrative refactor.**
- [ ] **Step 3: Replace polyline bounding in `DiagramBoundsLookup+Flowchart.swift`, `+Class.swift`, `+ER.swift` (and any others discovered with `rg -n 'paddedBy|polyline' Sources/DiagramKitModel/DiagramBoundsLookup+*.swift`).**
- [ ] **Step 4: Run hit-test snapshots / interactive editor tests if present (`swift test --filter HitTest`).**
- [ ] **Step 5: Commit.**

### Task 5.2: `AsciiCanvasWriter`

**Files:**

- Modify: `Sources/DiagramKitModel/src_ascii_canvas.swift:41-68`
- Modify: `src_ascii_sequence.swift`, `src_ascii_class_diagram.swift`, `src_ascii_er_diagram.swift` (and any other renderer found with `rg -n 'func setC' Sources/DiagramKitModel`).

- [ ] **Step 1: Add `AsciiCanvasWriter` with `set(_:_:_:role:)` matching the audit D4 refactor.**
- [ ] **Step 2: Replace per-renderer `setC` definitions with calls through `AsciiCanvasWriter`.**
- [ ] **Step 3: Chunked ASCII snapshot regression per renderer.**
- [ ] **Step 4: Commit per renderer.**

### Task 5.3: Flowchart export walker

**Files:**

- Create: `Sources/DiagramKitExport/FlowchartExportWalker.swift`
- Modify: `Sources/DiagramKitD2/D2Exporter.swift:43-88`
- Modify: `Sources/DiagramKitGraphviz/DOTFlowchartExport.swift:9-50`

- [ ] **Step 1: Define `FlowchartExportSink` protocol and the walker per audit D5 refactor.**
- [ ] **Step 2: Re-implement `D2Exporter` and `DOTFlowchartExport` as sinks.**
- [ ] **Step 3: Snapshot the exporter outputs:**

```
swift test --filter D2Exporter
swift test --filter DOTFlowchart
```

- [ ] **Step 4: Commit.**

### Task 5.4: TreeView font resolution

**Files:**

- Modify: `Sources/DiagramKitModel/src_treeview_layout.swift:29-33, 184-189`
- Test: `Tests/DiagramKitTests/TreeViewLayoutTests.swift`

- [ ] **Step 1: Add a failing test that measures a label through both the layout-side and CG-side font resolvers and asserts identical advance widths.**
- [ ] **Step 2: Pipe a `DiagramFontResolver` (or `TextMetrics`) into `TreeViewLayoutContext` per audit P2 refactor.**
- [ ] **Step 3: Verify TreeView ASCII + SVG snapshots remain identical.**
- [ ] **Step 4: Commit.**

### Task 5.5: Phase 5 closure

- [ ] **Step 1:** `rg -n 'func setC|polyline bounds' Sources/DiagramKitModel` — only the new helper should remain.
- [ ] **Step 2:** `Scripts/bootstrap-smoke-check.sh`.
- [ ] **Step 3:** Strike audit D3, D4, D5, P2.
- [ ] **Step 4: Commit.**

---

## Phase 6 — Legacy port surface cleanup

Maps to audit priority **5** and finding **A5**. Verified: 47 `public class original_src_*` (or `public enum/struct`) declarations across `Sources/`, 544 total `original_src_` references. Examples: `src_parser.swift:1268`, `src_layout.swift:1546`, `src_renderer.swift:1128`, `src_ascii_index.swift:221`.

**End state:** Every public `original_src_*` declaration is either intentionally public (and renamed to a domain-meaningful Swift identifier), SPI-only (`@_spi(PortCompatibility)` + `@available(*, deprecated, renamed:)`), or internal.

### Task 6.1: Build the inventory

**Files:**

- Create: `docs/inventory/original-src-public-surface.md` (transient; deleted at end of phase)

- [ ] **Step 1:** Generate the table:

```bash
rg -n '^public (class|open class|public enum|public struct) original_src_' Sources \
  | sort > docs/inventory/original-src-public-surface.md
```

- [ ] **Step 2: Annotate each row with one of: `keep-public`, `spi`, `internal`.** Decisions live in this file until Task 6.4.
- [ ] **Step 3: Commit the inventory.**

### Task 6.2: Move `internal` rows

**Files:** Each annotated as `internal`.

- [ ] **Step 1: Drop `public`/`open` from the declaration.**
- [ ] **Step 2: Re-run `swift build` and `swift test --filter <relevant suite>`. Fix the smallest possible callers; if external callers exist, escalate to `spi` instead.**
- [ ] **Step 3: Commit in 5–10-file batches** (`refactor(port): hide internal original_src_* wrappers`).

### Task 6.3: Annotate `spi` rows

**Files:** Each annotated `spi`.

- [ ] **Step 1: Add `@_spi(PortCompatibility)` + `@available(*, deprecated, message:)` per audit A5 refactor.**
- [ ] **Step 2: Confirm `swift build --target DiagramKit` still succeeds.**
- [ ] **Step 3: Commit per batch.**

### Task 6.4: Rename `keep-public` rows

For each declaration intentionally public:

- [ ] **Step 1: Add a Swift-domain typealias (e.g. `public typealias MermaidGraph = original_src_types.MermaidGraph`).**
- [ ] **Step 2: Mark the original symbol `@available(*, deprecated, renamed: "MermaidGraph", message: "…")`.**
- [ ] **Step 3: Update internal callers to the new name.**
- [ ] **Step 4: Commit per type.**

### Task 6.5: Phase 6 closure

- [ ] **Step 1:** `rg -n '^public (class|open class|public enum|public struct) original_src_' Sources` — expect a much smaller, fully-classified set (≤ 5 intentional surfaces).
- [ ] **Step 2:** Delete `docs/inventory/original-src-public-surface.md`.
- [ ] **Step 3:** Regenerate public docs (`Scripts/bootstrap-smoke-check.sh` if it includes docs, otherwise `swift package generate-documentation` per project norms).
- [ ] **Step 4:** Strike audit A5 and Priority 5.
- [ ] **Step 5: Commit.**

---

## Phase 7 — Comment hygiene and stale transition markers

Maps to audit finding **P4**. Verified: `DiagramRegistry+TypedDescriptor.swift:9` still says "will be introduced in Phase 1" although `ImporterRegistry` is shipped; `MermaidImporter.swift` references a future Phase 6D milestone; `DiagramPipeline.swift:126-129` understates positioned SVG coverage; `ShapeSpecRegistry+Defaults.swift:12-14` repeats a duplicate MARK heading.

### Task 7.1: Sweep "will be introduced" comments

- [ ] **Step 1:** `rg -n 'will be introduced|Phase 6D|Phase 1' Sources` — review every match. Update or remove based on current state.
- [ ] **Step 2: Commit `chore(comments): retire stale transition comments`.**

### Task 7.2: Update positioned-SVG note

- [ ] **Step 1: Replace `DiagramPipeline.swift:126-129` comment with one reflecting the new positioned-canonical path created in Phase 2.**
- [ ] **Step 2: Commit.**

### Task 7.3: Add a guard script for stale phrases

**Files:**

- Create: `Scripts/check-stale-phase-comments.sh`
- Modify: `Scripts/bootstrap-smoke-check.sh`

- [ ] **Step 1: Add a small `rg` over Sources for `"will be introduced"`, `"will become"`, `"Phase \d"` outside `PHASES.md` / `PHASE-0.md`. Exit non-zero on any match.**
- [ ] **Step 2: Wire into the bootstrap smoke check.**
- [ ] **Step 3: Commit.**

### Task 7.4: Phase 7 closure

- [ ] **Step 1:** Run the new guard script — should pass.
- [ ] **Step 2:** `Scripts/bootstrap-smoke-check.sh`.
- [ ] **Step 3:** Strike audit P4.
- [ ] **Step 4: Commit `chore(audit): close P4 comment hygiene findings`.**

---

## Cross-cutting expectations

- **Acceptable repetition (audit D6):** Do **not** flatten `ShapeSpecRegistry+Defaults.swift` or grammar-specific parser bodies. Each phase's success criterion is removing accidental duplication, not domain repetition.
- **Snapshot byte-identity:** Every refactor task above intends zero snapshot drift. If drift appears, treat it as a defect and bisect within the task; do **not** re-record without an explicit "snapshot change expected" sub-task added inline.
- **No new thread pool, registered fonts first, narrow-prefix parser dispatch:** invariants from `CLAUDE.md` are still binding through every phase.
- **Test selection:** every `swift test` invocation uses `--filter`; the full corpus run is left for CI per `feedback_test_chunks` memory.

## Final acceptance criteria

- All audit findings (A1–A5, P1–P5, D1–D6) are crossed out in `CODE_QUALITY_AUDIT.md` with the closing commit hash recorded next to each.
- `rg -n '\[String: Any\]' Sources/DiagramKitModel` returns only the `ElkGraphNode.toDictionary()` encoder body.
- `rg -n '_typed' Sources/DiagramKit | wc -l` ≥ 24.
- `rg -n '_renderDiagramSVG' Sources Tests` returns no matches.
- `rg -n 'notYetImplemented' Sources/DiagramKitD2 Sources/DiagramKitGraphviz Sources/DiagramKitStructurizr` returns no matches.
- `Package.swift` declares `DiagramKitExport` on the `DiagramKitGraphviz` target.
- Public surface no longer exposes accidental `original_src_*` declarations (≤ 5 deliberate, SPI-or-deprecated wrappers).
- `Scripts/bootstrap-smoke-check.sh` passes locally; `linux-check.sh` is allowed-skipped when Docker is unavailable.
- `CLAUDE.md` and `ARCHITECTURE.md` reflect the new positioned-canonical render path, descriptor-driven registries, and absence of dictionary-based ELK construction.
