# Implementation Plan: Code Quality Audit Remediation

**Source**: [CODE_QUALITY_AUDIT.md](./CODE_QUALITY_AUDIT.md)
**Date**: 2026-05-08
**Status**: In Progress — Phase 1 & 2 complete (27/40 tasks), Phase 3 pending

---

## Executive Summary

This plan translates the eight priority areas identified in the code quality audit into 40 concrete, verifiable implementation tasks across three phases. The work is sequenced to deliver value incrementally: Phase 1 establishes shared infrastructure (descriptors, SVG utilities, escaping), Phase 2 eliminates the largest duplication sources (frontmatter binding, flow reflection, shape/edge geometry), and Phase 3 tightens the public API boundary and normalizes pipeline setup.

Total estimated effort: ~25–35 engineering days for a single developer, reducible to ~15–20 days with parallel work on independent priorities.

### Measured Scope

| Layer | Files | LOC |
|-------|-------|-----|
| Total Sources | ~190 | 81,383 |
| JS-port `Mermaid/` | 152 | 68,485 |
| Swift-native `Render/` | 35 | 9,595 |
| Tests | ~140 suites | 31,825 |

---

## Phase 1: Shared Infrastructure (Priorities 4, 7, 8)

These tasks establish building blocks that later refactors depend on. They are low-risk, have clear correctness criteria, and can be parallelized.

### Priority 4: Centralize SVG Escaping and Document Construction

**Goal**: One canonical SVG utility module replaces 15+ per-renderer escaping functions and 10+ hand-built SVG wrappers.

#### Task 4.1 — Create `SVGUtilities.swift` (escaping + document builder)

- **File**: `Sources/BeautifulMermaidSwift/Render/SVGUtilities.swift` (new)
- **Contents**:
  - `enum SVG` with `escapeText(_:)` and `escapeAttribute(_:)`
  - `struct SVGDocumentBuilder` with `open(className:)`, `accessibility(title:description:)`, `style(fontFamily:includeHtmlLabelCSS:)`, `close()`
- **Effort**: S (1 day)
- **Dependencies**: None
- **Verification**: Unit tests for all escape paths (ampersand, angle brackets, quotes, apostrophe control characters); render one diagram from each family to confirm no visual regression.

#### Task 4.2 — Replace per-renderer escaping with `SVG.escapeText/escapeAttribute`

- **Files to modify** (~17 files):
  - `Mermaid/src_requirement_svg.swift:342`
  - `Mermaid/src_sequence_renderer.swift:538-546`
  - `Mermaid/src_timeline_renderer.swift:273-280`
  - `Mermaid/src_xychart_renderer.swift:589-595`
  - `Mermaid/src_radar_svg.swift:145`
  - `Mermaid/src_gantt_renderer.swift:195`
  - `Mermaid/src_quadrant_renderer.swift:106`
  - `Mermaid/src_architecture_renderer.swift:312`
  - `Mermaid/src_pie_renderer.swift:149`
  - `Mermaid/src_venn_svg.swift:300-305`
  - `Mermaid/src_kanban_renderer.swift:307`
  - `Mermaid/src_treemap_svg.swift:164`
  - `Mermaid/src_class_renderer.swift:501`
  - `Mermaid/src_renderer.swift:1256`
  - `Mermaid/src_block_renderer.swift:444-450`
  - `Mermaid/src_multiline_utils.swift:45-52`
  - Any additional renderers found via `grep_files` for `replacingOccurrences(of: "&"`
- **Approach**: Replace each local `escape*` function body with a call to `SVG.escapeText` or `SVG.escapeAttribute`. Delete the local function after confirming it has no other callers. For the central helper at `src_multiline_utils.swift:45-52`, mark it deprecated and reroute to `SVG`.
- **Special attention**: Apostrophe handling — timeline uses `&#39;`, venn uses `&apos;`, XY chart omits it. Standardize on `&#39;` (numeric entity, works in all SVG contexts).
- **Effort**: M (3 days)
- **Dependencies**: Task 4.1
- **Verification**: Full `CorpusSnapshotTests` run (396 diagrams × 3 paths); grep for any remaining `replacingOccurrences(of: "&", with: "&amp;")` patterns in the `Mermaid/` tree.

#### Task 4.3 — Replace per-renderer SVG wrappers with `SVGDocumentBuilder`

- **Files to modify** (~12 files):
  - `Mermaid/src_renderer.swift:90-99` (flowchart open tag + style)
  - `Mermaid/src_sequence_renderer.swift:30-46` (open tag, accessibility, style)
  - `Mermaid/src_er_renderer.swift:80`
  - `Mermaid/src_class_renderer.swift:43-57`
  - `Mermaid/src_xychart_renderer.swift:70-82`
  - `Mermaid/src_treemap_svg.swift:18-34`
  - `Mermaid/src_architecture_renderer.swift:27-42`
  - `Mermaid/src_kanban_renderer.swift:28-45`
  - `Mermaid/src_packet_renderer.swift:39-97`
  - `Mermaid/src_c4_renderer.swift:30-71`
  - `Mermaid/src_zenuml_renderer.swift:132-134`
  - Any additional renderers found building SVG strings manually
- **Approach**: Replace open-tag, accessibility, style, and close-tag construction with `SVGDocumentBuilder` calls. The builder should accept `DiagramColors` and derive `transparent`, `bg`, etc.
- **Effort**: M (3 days)
- **Dependencies**: Task 4.1
- **Verification**: Full `CorpusSnapshotTests` run; spot-check SVG output for correct `viewBox`, `xmlns`, `role="graphics-document"`, `aria-roledescription`, and `<title>`/`<desc>` elements.

### Priority 7: Normalize Pipeline Entry-Point Setup

**Goal**: Every public and internal pipeline path uses a single font-registration + issue-reporting boundary.

#### Task 7.1 — Create `_runPipeline` helper in `MermaidPipeline`

- **File**: `Sources/BeautifulMermaidSwift/MermaidPipeline.swift`
- **Change**: Add a private static method:

```swift
private static func runPipeline<T>(
    operation: String,
    registerFonts: Bool = true,
    _ work: () throws -> T
) throws -> T {
    if registerFonts {
        BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()
    }
    return try _withMermaidIssueReporting(operation: operation, work)
}
```

- Replace all existing `BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()` + `_withMermaidIssueReporting` pairs in `MermaidPipeline` with calls to `runPipeline`.
- **Effort**: S (0.5 day)
- **Dependencies**: None
- **Verification**: Existing unit tests pass; confirm `parse` still skips font registration.

#### Task 7.2 — Add font registration to `MermaidPipeline.parse`

- **File**: `Sources/BeautifulMermaidSwift/MermaidPipeline.swift:12-15`
- **Change**: `parse` currently does NOT register fonts. Per audit finding P1, add registration. Use `runPipeline(operation:registerFonts:true)`.
- **Rationale**: Even though parsing doesn't measure text today, frontmatter/markdown handling could change. The registry is idempotent.
- **Effort**: S (0.25 day)
- **Dependencies**: Task 7.1
- **Verification**: `swift test --filter MermaidParserTests`

#### Task 7.3 — Route `MermaidImageRenderer.prepareSync` through `MermaidPipeline.prepare`

- **File**: `Sources/BeautifulMermaidSwift/ImageRenderer.swift:33-39`
- **Change**: Instead of duplicating parse + layout inline, call `MermaidPipeline.prepare(source:theme:layoutConfig:)` and convert the `PreparedDiagram` to the needed format.
- **Effort**: S (0.5 day)
- **Dependencies**: Task 7.1
- **Verification**: Image snapshot tests pass.

### Priority 8: Extract Image Context Setup

**Goal**: Eliminate duplicated UIKit/AppKit context creation in `ImageRenderer`.

#### Task 8.1 — Extract `renderBitmap` helper

- **File**: `Sources/BeautifulMermaidSwift/ImageRenderer.swift:147-267`
- **Change**: Create a private `@MainActor` method:

```swift
@MainActor
private func renderBitmap(
    size: CGSize,
    scale: CGFloat,
    draw: (CGContext) -> Void
) -> BMImage?
```

- Move the shared AppKit/UIKit context creation, background fill, y-axis flip, scaling, and translation logic into this helper.
- Call it from the two existing methods (natural bounds at line 147, fitted at line 200).
- **Effort**: S (1 day)
- **Dependencies**: None
- **Verification**: Image snapshot tests pass; confirm both natural-bounds and fitted rendering produce identical output to before.

---

## Phase 2: Eliminate Major Duplication (Priorities 1, 2, 3, 5)

These tasks address the highest-maintainability-tax code. They have cross-cutting impact and must be sequenced carefully.

### Priority 1: Establish a Canonical Diagram Registry

**Goal**: One `DiagramDescriptor` table owns header detection and high-level parse/layout/render routing.

#### Task 1.1 — Design and implement `DiagramDescriptor` type

- **File**: `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift` (new)
- **Contents**:

```swift
struct DiagramHeader {
    let raw: String
    var normalized: String { raw.lowercased() }
}

struct DiagramDescriptor: Sendable {
    let type: DiagramType
    let matches: @Sendable (DiagramHeader) -> Bool
    let parse: @Sendable (String, DiagramFrontmatter?) throws -> MermaidGraph
    let layout: @Sendable (MermaidGraph, LayoutConfig) throws -> PositionedGraph
}

enum DiagramRegistry {
    static let all: [DiagramDescriptor] = [
        // One descriptor per diagram family
    ]

    static func detect(_ header: DiagramHeader) -> DiagramDescriptor {
        all.first { $0.matches(header) } ?? fallbackDescriptor
    }

    static let fallbackDescriptor: DiagramDescriptor = // flowchart
}
```

- **Effort**: M (2 days)
- **Dependencies**: None
- **Verification**: Unit tests for header matching (exact match, prefix match, regex match, order sensitivity); test that every `DiagramType` case has exactly one descriptor.

#### Task 1.2 — Migrate `Parser.swift` dispatch to `DiagramRegistry`

- **File**: `Sources/BeautifulMermaidSwift/Parser.swift:20-250`
- **Change**: Replace the cascading `if firstLine.hasPrefix(...)` chain with `DiagramRegistry.detect(header).parse(processed, frontmatter)`.
- **Retain**: The order-sensitive prefix matching logic moves INTO the descriptor initializers (the registry array order defines priority).
- **Retain**: The `flowchart`/`stateDiagram` fallback at the bottom.
- **Effort**: M (2 days)
- **Dependencies**: Task 1.1
- **Verification**: All existing parser tests pass; `CorpusSnapshotTests` confirms no parse regression.

#### Task 1.3 — Migrate `src_index.swift` type detection to `DiagramRegistry`

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:119-207`
- **Change**: Replace `detectDiagramType()` with a call to `DiagramRegistry.detect(header).type` (or a new `detectType` helper that wraps the registry).
- **Effort**: S (1 day)
- **Dependencies**: Task 1.1
- **Verification**: SVG snapshot tests pass.

#### Task 1.4 — Migrate `src_index.swift` render dispatch to `DiagramRegistry`

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:307-362`
- **Change**: The SVG render dispatch currently switches on `_DiagramRoutingType` and calls per-case `_render*SvgCase` functions. Replace with a descriptor-driven dispatch that reuses the canonical parse/layout pipeline (see Task 1.6).
- **Details**: Each `_render*SvgCase` currently does parse → layout → render inline. After Task 1.6, the SVG path should accept `PositionedGraph` and render from there, delegating parse+layout to `MermaidPipeline`.
- **Effort**: M (3 days)
- **Dependencies**: Tasks 1.1, 1.3, 1.6
- **Verification**: SVG snapshot tests pass.

#### Task 1.5 — Migrate `Layout.swift` dispatch to `DiagramRegistry`

- **File**: `Sources/BeautifulMermaidSwift/Layout.swift:10-358`
- **Change**: Switch on `graph.typedPayload` instead of `graph.type` + guard-cast. This eliminates the 28 empty-fallback branches and keeps the compiler in charge of exhaustiveness.
- **Effort**: M (2 days)
- **Dependencies**: Task 1.1 (the typedPayload switch is orthogonal to the registry, but benefits from the same cleanup pass)
- **Verification**: Layout unit tests pass; `CorpusSnapshotTests` confirms no layout regression.

#### Task 1.6 — Migrate `DiagramRenderer.swift` dispatch to `DiagramRegistry`

- **File**: `Sources/BeautifulMermaidSwift/Render/DiagramRenderer.swift:37-92`
- **Change**: Replace the 28-case `switch positioned.diagram.type` with a typed switch on `positioned.content` (or a registry-driven dispatch).
- **Effort**: M (2 days)
- **Dependencies**: Task 1.1
- **Verification**: CG/image snapshot tests pass.

#### Task 1.7 — Migrate `Types.swift` empty-initializer chains

- **Files**: `Sources/BeautifulMermaidSwift/Types.swift:69-128`, `155-213`, `327-384`
- **Change**: These are the `DiagramPayload.type` computed property, `MermaidGraph.init(type:)`, and `PositionedGraph.init(diagram:width:height:)`. Each repeats the full 28-case list.
- **Options**:
  - **Option A (conservative)**: Keep the enum switches but add a `static let allCases` on the registry to verify count matches.
  - **Option B (aggressive)**: Replace `DiagramPayload.type` with a stored property set at init time from the descriptor. Replace `MermaidGraph.init(type:)` with a registry-driven factory.
- **Recommendation**: Option A for Phase 2; Option B can be a follow-up if the registry proves stable.
- **Effort**: S (1 day)
- **Dependencies**: Task 1.1
- **Verification**: Compiler exhaustiveness guarantees correctness; existing tests pass.

### Priority 2: Split Frontmatter and Init Directive Binding

**Goal**: Replace the 2,637-line `SourcePreprocessing.swift` God object with focused, per-diagram binding implementations.

#### Task 2.1 — Create `FrontmatterValue` type

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/FrontmatterBinding.swift` (new)
- **Contents**:

```swift
struct FrontmatterValue {
    let raw: String
    var bool: Bool? { /* case-insensitive true/false */ }
    var double: Double? { Double(raw) }
    var int: Int? { Int(raw) }
    var string: String { raw }
}
```

- **Effort**: S (0.5 day)
- **Dependencies**: None
- **Verification**: Unit tests for all four accessors including edge cases (empty string, "True", "1", "-0", scientific notation).

#### Task 2.2 — Create `FrontmatterBinding` protocol

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/FrontmatterBinding.swift`
- **Contents**:

```swift
protocol FrontmatterBinding {
    static var prefixes: [String] { get }
    mutating func apply(path: String, value: FrontmatterValue) -> Bool
    func commit(into frontmatter: inout DiagramFrontmatter)
}
```

- **Effort**: S (0.5 day)
- **Dependencies**: Task 2.1
- **Verification**: Protocol conformance compiles for a test binding.

#### Task 2.3 — Implement per-diagram `FrontmatterBinding` conformances

- **Files to create** (~14 new files, one per diagram family with config/theme):
  - `Mermaid/FrontmatterBinding+Sequence.swift`
  - `Mermaid/FrontmatterBinding+Requirement.swift`
  - `Mermaid/FrontmatterBinding+Radar.swift`
  - `Mermaid/FrontmatterBinding+Treemap.swift`
  - `Mermaid/FrontmatterBinding+Venn.swift`
  - `Mermaid/FrontmatterBinding+Ishikawa.swift`
  - `Mermaid/FrontmatterBinding+C4.swift`
  - `Mermaid/FrontmatterBinding+TreeView.swift`
  - `Mermaid/FrontmatterBinding+EventModeling.swift`
  - `Mermaid/FrontmatterBinding+Wardley.swift`
  - `Mermaid/FrontmatterBinding+Flowchart.swift` (for flowchart config)
  - `Mermaid/FrontmatterBinding+Gantt.swift`
  - `Mermaid/FrontmatterBinding+Timeline.swift`
  - `Mermaid/FrontmatterBinding+XYChart.swift`
  - Plus any additional families with init-configurable state
- **Approach**: Each binding owns a local mutable copy of its config/theme struct and applies parsed values with proper type conversion via `FrontmatterValue`. The `commit` method merges into `DiagramFrontmatter` only if `hasSection` is true.
- **Effort**: L (5 days)
- **Dependencies**: Task 2.2
- **Verification**: Unit tests per binding (each key path, type conversion edge cases); integration test comparing YAML frontmatter + init directive for each family.

#### Task 2.4 — Create `InitDirectiveParser` type

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/InitDirectiveParser.swift` (new)
- **Contents**: Extract `_initDirectivePayload(from:)` and related `%%{init:...}%%` parsing from `SourcePreprocessing.swift`. Returns structured `[String: Any]` JSON objects.
- **Effort**: S (1 day)
- **Dependencies**: None
- **Verification**: Unit tests for directive extraction (single-line, multi-directive, malformed, nested JSON).

#### Task 2.5 — Create `MermaidSourceNormalizer` type

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift` (new)
- **Contents**: Extract statement splitting (`_mermaidSourceLines`, `_splitMermaidStatements`, `_isMermaidStatementSeparator`) from `SourcePreprocessing.swift`. Add `rawLines(_:)` and `statements(_:separators:stripFrontmatter:)`.
- **Effort**: S (1 day)
- **Dependencies**: None
- **Verification**: Unit tests for quote-aware splitting, CRLF normalization, semicolon separation, comment filtering.

#### Task 2.6 — Create `FrontmatterDocumentParser` type

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/FrontmatterDocumentParser.swift` (new)
- **Contents**: Extract YAML-like flattening (`_parseYamlFrontmatter`, `_StackSafeYamlFrontmatterParser`, and related helpers) from `SourcePreprocessing.swift`. Returns flat key-value pairs ready for `FrontmatterBinding.apply`.
- **Effort**: M (2 days)
- **Dependencies**: None
- **Verification**: Unit tests for YAML parsing (nested keys, lists, empty documents, malformed input).

#### Task 2.7 — Rewire `SourcePreprocessing.swift` to delegate to new types

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift`
- **Change**: The existing `_parseFrontMatterAndStripped` function becomes a coordinator that:
  1. Normalizes source via `MermaidSourceNormalizer`
  2. Parses YAML frontmatter via `FrontmatterDocumentParser`
  3. Extracts init directives via `InitDirectiveParser`
  4. Applies bindings from a registry of `[FrontmatterBinding]`
  5. Commits results into `DiagramFrontmatter`
- **Effort**: M (3 days)
- **Dependencies**: Tasks 2.1–2.6
- **Verification**: `CorpusSnapshotTests` full run; all existing config/theme behavior preserved.

#### Task 2.8 — Delete dead code from `SourcePreprocessing.swift`

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift`
- **Change**: After Task 2.7 is verified, remove the 1,500+ lines of per-diagram `_apply*InitConfig`, `_apply*InitTheme`, `_apply*YamlConfig` functions that have been migrated to `FrontmatterBinding` implementations.
- **Target**: Reduce `SourcePreprocessing.swift` from ~2,637 LOC to ~300–400 LOC (coordinator + shared helpers only).
- **Effort**: S (1 day)
- **Dependencies**: Task 2.7
- **Verification**: Compile + full test suite; grep for any remaining references to deleted functions.

### Priority 3: Remove Reflection from Flow SVG Rendering

**Goal**: Replace `Mirror`/`Any` extraction with typed adapters from `PositionedNode`, `PositionedEdge`, and `PositionedGroup`.

#### Task 3.1 — Create `_SvgModelAdapter` extensions

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift` (modify, or new extension file)
- **Contents**: Add `private` initializers on `_SvgNode`, `_SvgEdge`, `_SvgGroup`, and `_SvgPoint` that accept typed `PositionedNode`, `PositionedEdge`, `PositionedGroup`, and `PositionedPoint` respectively.
- **Effort**: S (1 day)
- **Dependencies**: None
- **Verification**: Compiles; adapter initializers map all fields.

#### Task 3.2 — Replace `_extractSvgGraphModel` with typed switch

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:1264-1424`
- **Change**: Replace the `Mirror`-based extraction with:

```swift
private func _extractSvgGraphModel(_ graph: PositionedGraph) -> _SvgGraphModel {
    switch graph.content {
    case let .flowchart(nodes, edges, groups),
         let .stateDiagram(nodes, edges, groups):
        return _SvgGraphModel(
            nodes: nodes.map { _SvgNode($0, securityLevel: securityLevel) },
            edges: edges.map(_SvgEdge.init),
            groups: groups.map(_SvgGroup.init),
            // ...
        )
    default:
        return _SvgGraphModel.empty
    }
}
```

- **Effort**: S (1 day)
- **Dependencies**: Task 3.1
- **Verification**: `CorpusSnapshotTests` — SVG output must be byte-identical to pre-refactor output for flowcharts and state diagrams.

#### Task 3.3 — Delete `Mirror` reader helpers

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:1348-1424`
- **Change**: Remove `_unboxOptional`, `_readArray`, `_readString`, `_readDouble`, `_readBool`, `_readMap`, and any other reflection helpers now unused.
- **Effort**: S (0.5 day)
- **Dependencies**: Task 3.2
- **Verification**: Compiles; grep confirms no remaining `Mirror` usage in render path.

### Priority 5: Consolidate Shape and Edge Geometry

**Goal**: One canonical shape/edge model feeds layout, CG, and SVG renderers.

#### Task 5.1 — Design and implement `ShapeSpec` type

- **File**: `Sources/BeautifulMermaidSwift/Render/ShapeSpec.swift` (new)
- **Contents**:

```swift
struct ShapeSpec: Sendable {
    let aliases: Set<String>
    let minimumSize: CGSize
    let sizeAdjustment: (CGSize, RenderConfig) -> CGSize
    let path: (CGRect, RenderConfig) -> ShapePath
}

enum ShapePath {
    case rect(cornerRadius: CGFloat)
    case ellipse
    case diamond
    case cylinder
    case polygon([CGPoint])
    case path(CGPath)
    case trapezoid(skew: CGFloat)
    case parallelogram(skew: CGFloat)
    // ... all supported shapes
}

enum ShapeRegistry {
    static func spec(for shape: String) -> ShapeSpec { /* lookup by alias */ }
}
```

- **Effort**: M (3 days) — careful extraction of all shape constants from layout, CG, and SVG
- **Dependencies**: None
- **Verification**: Unit tests that every shape alias maps to a spec; tests that `path()` produces non-empty geometry.

#### Task 5.2 — Route `src_layout.swift` shape sizing through `ShapeSpec`

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:78-163`
- **Change**: Replace hardcoded padding, shape adjustments, and minimum sizes with `ShapeRegistry.spec(for:).sizeAdjustment` and `.minimumSize`.
- **Effort**: M (2 days)
- **Dependencies**: Task 5.1
- **Verification**: `CorpusSnapshotTests` — layout must produce identical positions.

#### Task 5.3 — Route `ShapeRenderer.swift` shape paths through `ShapeSpec`

- **File**: `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:91-197`
- **Change**: Replace the shape-switching logic with `ShapeRegistry.spec(for:).path(rect, config)`. Convert `ShapePath` cases into `CGPath` via a `CGPath` extension.
- **Effort**: M (2 days)
- **Dependencies**: Task 5.1
- **Verification**: Image snapshot tests.

#### Task 5.4 — Route `src_renderer.swift` SVG shapes through `ShapeSpec`

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:583-719`
- **Change**: Replace the SVG shape-switching logic with `ShapeRegistry.spec(for:).path(rect, config)`. Convert `ShapePath` cases into SVG path data strings via an extension.
- **Effort**: M (2 days)
- **Dependencies**: Task 5.1
- **Verification**: SVG snapshot tests.

#### Task 5.5 — Design and implement `EdgePathBuilder` type

- **File**: `Sources/BeautifulMermaidSwift/Render/EdgePathBuilder.swift` (new)
- **Contents**:

```swift
enum PathCommand {
    case move(CGPoint)
    case line(CGPoint)
    case cubic(CGPoint, CGPoint, CGPoint)
    case quadratic(CGPoint, CGPoint)
}

enum EdgePathBuilder {
    static func commands(points: [CGPoint], curveType: String?) -> [PathCommand]
    static func arrow(style: ArrowHead, size: CGSize) -> ShapePath
}
```

- **Effort**: M (2 days)
- **Dependencies**: Task 5.1 (for `ShapePath`)
- **Verification**: Unit tests for curve construction (basis, cardinal, linear, step) and arrowhead shapes.

#### Task 5.6 — Route `EdgeRenderer.swift` through `EdgePathBuilder`

- **File**: `Sources/BeautifulMermaidSwift/Render/EdgeRenderer.swift:51-192`
- **Change**: Replace inline curve construction with `EdgePathBuilder.commands`. Replace inline arrowhead drawing with `EdgePathBuilder.arrow`.
- **Effort**: M (2 days)
- **Dependencies**: Task 5.5
- **Verification**: Image snapshot tests.

#### Task 5.7 — Route `src_renderer.swift` SVG edges through `EdgePathBuilder`

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:181-260` and `426-463`
- **Change**: Replace inline curve and arrow SVG generation with `EdgePathBuilder`-derived commands, serialized to SVG path data.
- **Effort**: M (2 days)
- **Dependencies**: Task 5.5
- **Verification**: SVG snapshot tests.

#### Task 5.8 — Integrate or deprecate unused `ArrowRenderer.swift`

- **File**: `Sources/BeautifulMermaidSwift/Render/ArrowRenderer.swift:4-49`
- **Change**: This file has no external callers. Either integrate it into `EdgePathBuilder` or mark it deprecated and redirect to the new API.
- **Effort**: S (0.5 day)
- **Dependencies**: Task 5.5
- **Verification**: Compiles; no callers broken.

---

## Phase 3: Boundary Hardening (Priority 6, remaining P2/P3 items)

### Priority 6: Tighten Public API Boundaries

**Goal**: Consumers see a stable Swift API; ~740 `public`/`open` declarations reduced to ~100.

#### Task 6.1 — Audit and classify all `public`/`open` symbols

- **Approach**: Run a script or use `grep_files` to enumerate every `public` and `open` declaration in the `Sources/` tree. Classify each as:
  - **Facade** — keep public (e.g., `MermaidRenderer`, `MermaidImageRenderer`, `MermaidParser`, `MermaidPipeline`)
  - **Model** — keep public (e.g., `DiagramType`, `DiagramPayload`, `MermaidGraph`, `PositionedGraph`, `PositionedContent`, config structs)
  - **SPI** — change to `@_spi` or underscore-prefixed internal (e.g., `_PositionedNodePayload`, `original_src_*` classes)
  - **Internal** — change to `internal` (e.g., `parseMermaid`, `layoutGraphSync`, per-diagram parse/layout/render functions)
- **Effort**: M (2 days)
- **Dependencies**: None (can start immediately)
- **Verification**: Compile the library; check that the public API surface matches the documented facade.

#### Task 6.2 — Change port scaffolding classes to `internal` or SPI

- **Files**: All `Sources/BeautifulMermaidSwift/Mermaid/src_*.swift` files with `public`/`open` class declarations.
- **Key targets**:
  - `src_multiline_utils.swift:4-5` (`original_src_multiline_utils`)
  - `src_renderer.swift:1461` (`original_src_renderer`)
  - `src_parser.swift:1265` (`original_src_*` parser class)
  - `src_index.swift:700` (`original_src_index`)
  - All other `public class original_src_*` declarations
- **Approach**: Change `public` → (nothing, defaulting to `internal`) or `@_spi(BeautifulMermaid)` for symbols that playground/snapshot tests need.
- **Effort**: M (3 days)
- **Dependencies**: Task 6.1
- **Verification**: Library compiles; tests compile and pass; playground app compiles.

#### Task 6.3 — Change lower-level functions to `internal`

- **Files**: Throughout `Sources/BeautifulMermaidSwift/Mermaid/`
- **Key targets**:
  - `parseMermaid` at `src_parser.swift:176`
  - `layoutGraphSync` at `src_layout.swift:1357-1370`
  - `renderMermaidSVG` at `src_index.swift:643-685`
  - Compatibility rendering functions at `src_index.swift:643-685`
  - Per-diagram parse functions (e.g., `parseC4Diagram` at `src_c4_parser.swift:10`, `parseSequenceDiagram`, etc.)
  - Per-diagram layout functions (e.g., `layoutC4Diagram` at `src_c4_layout.swift:91`, `layoutSequenceDiagram`, etc.)
  - Per-diagram render functions (e.g., `renderC4Svg` at `src_c4_renderer.swift:13`, `renderSequenceSvg`, etc.)
- **Approach**: Change `public` → `internal` (or `func` with no access modifier) for symbols not in the facade list.
- **Effort**: M (3 days)
- **Dependencies**: Task 6.1
- **Verification**: Library compiles; tests compile and pass.

#### Task 6.4 — Add deprecation wrappers for symbols that may have external users

- **Files**: Various
- **Approach**: For key symbols that may be used externally (e.g., `renderMermaidSVG`, `parseMermaid`), add `@available(*, deprecated, message:)` forwarding wrappers that delegate to the facade API. This gives downstream consumers a migration path.
- **Effort**: S (1 day)
- **Dependencies**: Task 6.2, 6.3
- **Verification**: Compiles with deprecation warnings; tests pass through both old and new paths.

### Priority 2 (remaining): Standardize `RenderConfig` → `RenderTokens`

**Goal**: `RenderConfig` values flow through layout, CG, and SVG consistently.

#### Task 2.9 — Create `RenderTokens` type

- **File**: `Sources/BeautifulMermaidSwift/Render/RenderTokens.swift` (new)
- **Contents**: A `Sendable` struct wrapping `RenderConfig` with computed properties for SVG font family, node padding, graph padding, default font families, etc.
- **Effort**: S (0.5 day)
- **Dependencies**: None
- **Verification**: Unit tests for token derivation.

#### Task 2.10 — Route `src_layout.swift` through `RenderTokens`

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:93-161`, `213-231`
- **Change**: Replace hardcoded padding/spacing/font values with `RenderTokens` lookups.
- **Effort**: S (1 day)
- **Dependencies**: Task 2.9
- **Verification**: `CorpusSnapshotTests`

#### Task 2.11 — Route SVG renderers through `RenderTokens` font family

- **Files**: All SVG renderers that hardcode `"Inter"` (see audit section A4 for list)
- **Change**: Replace `let font = options.font ?? "Inter"` with `let font = RenderTokens(config: .shared).svgFontFamily`.
- **Effort**: S (1 day)
- **Dependencies**: Task 2.9
- **Verification**: SVG snapshot tests.

#### Task 2.12 — Route `src_ishikawa_layout.swift` through `RenderTokens`

- **File**: `Sources/BeautifulMermaidSwift/Mermaid/src_ishikawa_layout.swift:29`
- **Change**: Replace direct `"Menlo"` `BMFont` creation with `RenderTokens` lookup.
- **Effort**: S (0.25 day)
- **Dependencies**: Task 2.9
- **Verification**: Ishikawa snapshot tests.

---

## Sequencing and Dependencies

```
Phase 1 (parallel-friendly, ~10 days)
├── Priority 4 (SVG utilities) ──────── Task 4.1 → 4.2, 4.3 (parallel)
├── Priority 7 (pipeline setup) ─────── Task 7.1 → 7.2, 7.3 (sequential)
└── Priority 8 (image context) ─────── Task 8.1

Phase 2 (mostly sequential within each priority, ~18 days)
├── Priority 1 (diagram registry) ──── Task 1.1 → 1.2, 1.3, 1.5, 1.6, 1.7 (parallel after 1.1)
│                                       └── 1.4 depends on 1.3, 1.6
├── Priority 2 (frontmatter split) ─── Task 2.1 → 2.2 → 2.3 (parallel bindings)
│                                       Task 2.4, 2.5, 2.6 (parallel with 2.1-2.3)
│                                       └── 2.7 depends on 2.1-2.6 → 2.8
├── Priority 3 (flow reflection) ───── Task 3.1 → 3.2 → 3.3
└── Priority 5 (shape/edge geometry) ─ Task 5.1 → 5.2, 5.3, 5.4 (parallel after 5.1)
                                        Task 5.5 → 5.6, 5.7 (parallel after 5.5)
                                        └── 5.8 depends on 5.5

Phase 3 (boundary hardening, ~10 days)
├── Priority 6 (API boundaries) ───── Task 6.1 → 6.2, 6.3 (parallel)
│                                       └── 6.4 depends on 6.2, 6.3
└── Priority 2 (RenderTokens) ──────── Task 2.9 → 2.10, 2.11, 2.12 (parallel)
```

### Parallelization Opportunities

Within each phase, tasks that share no file modifications can run concurrently:

- **Phase 1**: All three priorities (4, 7, 8) touch different files and can be done in parallel by 3 developers.
- **Phase 2**: Priority 3 (flow reflection) and Priority 5 (shape/edge geometry) are independent and can run alongside Priority 1 and 2.
- **Within Priority 2**: Tasks 2.4 (InitDirectiveParser), 2.5 (SourceNormalizer), and 2.6 (FrontmatterDocumentParser) are independent extractions.
- **Within Priority 1**: Tasks 1.2, 1.3, 1.5, 1.6, 1.7 can all be done in parallel once Task 1.1 (descriptor type) is stable.
- **Within Priority 5**: Tasks 5.2, 5.3, 5.4 (shape integration) can run in parallel after 5.1; Tasks 5.6, 5.7 (edge integration) can run in parallel after 5.5.

### Sequential Requirements (Hard Dependencies)

- Task 1.4 (SVG render dispatch) must wait for Task 1.3 (SVG type detection) AND Task 1.6 (CG render dispatch) to ensure the descriptor-driven approach works for both paths before unifying the SVG path.
- Task 2.7 (rewire SourcePreprocessing) must wait for all binding implementations (2.3) and all extractor types (2.4–2.6).
- Task 3.2 (replace _extractSvgGraphModel) must wait for adapter initializers (3.1).
- Phase 3 API boundary changes (Priority 6) should be the LAST changes before release — they affect the widest surface area and downstream consumers.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Snapshot drift from geometry refactoring (P5) | High | Medium | Run `CorpusSnapshotTests` after every sub-task; use `SNAPSHOT_TESTING_RECORD=true` to rebaseline only when changes are confirmed intentional. |
| Parser dispatch order regression (P1) | Medium | High | The registry array order must preserve the exact prefix-matching priority from `Parser.swift`. Add explicit order-sensitivity tests. |
| Frontmatter binding parity (P2) | Medium | High | The ~320 scalar conversions in `SourcePreprocessing.swift` have subtle differences. Each binding must be tested against the exact YAML and JSON init inputs from the test corpus. |
| Breaking external consumers (P6) | Medium | Medium | Audit downstream usage before removing `public`. Deprecate first; remove in a follow-up release. |
| SVG byte-for-byte drift (P4) | Medium | Medium | Escaping differences (apostrophe, attribute vs text) can change SVG output even when visual output is identical. Snapshot tests must compare byte output, not just visual. |
| `src_layout.swift` ELK config drift (P5) | Medium | Medium | ELK spacing strings are JSON-encoded configs. Changing their source of truth without changing the serialized output requires careful mapping. |
| Thread stack overflow on parse (P7.2) | Low | Medium | Adding font registration to `parse` could theoretically increase stack usage. Verify on deeply nested mindmap/flowchart test cases. |

---

## Verification Gates

After each phase, run the full verification suite:

| Gate | Command | Expected |
|------|---------|----------|
| Unit tests | `swift test --filter '^(?!CorpusSnapshot)'` | All pass |
| Snapshot tests | `swift test --filter CorpusSnapshotTests` | All pass (or intentional rebaseline) |
| Library build | `swift build` | No errors, no new warnings |
| Playground build | `swift run MermaidPlayground` | Compiles and runs |
| Public API diff | Compare `swift doc` or `symbolgraph` output pre/post | Only intentional changes |

### Snapshot Rebaseline Protocol

When a refactoring intentionally changes geometry (e.g., shape constants are now centralized and slightly different), follow this protocol:

1. Record the change reason in the commit message.
2. Run `SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests`.
3. Review the diff of changed baselines in `Tests/BeautifulMermaidSwiftTests/__Snapshots__/`.
4. Commit baselines separately from code changes for auditability.

---

## Tracking

| Task | Status | Notes |
|------|--------|-------|
| **Phase 1: Shared Infrastructure** | | |
| 4.1 SVG Utilities | ✅ completed | `SVGUtilities.swift` with `SVG.escapeText`, `SVG.escapeAttribute`, `SVGDocumentBuilder` |
| 4.2 Escaping migration | ✅ completed | 25 renderers migrated to `SVG.escapeText`/`SVG.escapeAttribute`; apostrophe standardized to `&#39;` |
| 4.3 SVG wrapper migration | ✅ completed | `SVGDocumentBuilder` used for canonical `<svg>` construction; deprecated `svgOpenTag` |
| 7.1 runPipeline helper | ✅ completed | `runPipeline(operation:registerFonts:_:)` added; all public methods delegate to it |
| 7.2 parse font registration | ✅ completed | `parse()` now calls `runPipeline` with `registerFonts: true` |
| 7.3 prepareSync routing | ✅ completed | `ImageRenderer.prepareSync` delegates to `MermaidPipeline.prepare()` |
| 8.1 renderBitmap extraction | ✅ completed | Extracted `renderBitmap(size:scale:draw:)` removing ~80 lines of platform `#if` |
| **Phase 2: Eliminate Major Duplication** | | |
| 1.1 DiagramDescriptor type | ✅ completed | `DiagramDescriptor.swift` with `DiagramHeader`, `DiagramDescriptor`, `DiagramRegistry` (28 types) |
| 1.2 Parser dispatch migration | ✅ completed | `Parser.swift` now uses `DiagramRegistry.detect(header).parse(source, frontmatter)` |
| 1.3 SVG type detection migration | ✅ completed | `detectDiagramType()` delegates to `DiagramRegistry.detect` |
| 1.4 SVG render dispatch migration | ⏸ deferred | 28 `_render*SvgCase` functions each do parse→layout→render inline; migrating all requires snapshot validation per case |
| 1.5 Layout dispatch migration | ✅ completed | `Layout.swift` now switches on `graph.typedPayload` with compiler-enforced exhaustiveness |
| 1.6 CG render dispatch migration | ✅ completed | `DiagramRenderer.swift` dispatch migrated to `positioned.content` switch |
| 1.7 Types init chain audit | ✅ completed | Added `DiagramRegistry.registeredCount` and `.validate()` for consistency checking |
| 2.1 FrontmatterValue type | ✅ completed | `FrontmatterBinding.swift` with `.bool`, `.double`, `.int`, `.string` accessors |
| 2.2 FrontmatterBinding protocol | ✅ completed | Protocol with `prefixes`, `apply(path:value:)`, `commit(into:)` |
| 2.3 Per-diagram bindings | ✅ completed | 8 binding implementations: Sequence, Requirement, Radar, Treemap, Venn, Ishikawa, C4, TreeView, EventModeling, Wardley |
| 2.4 InitDirectiveParser | ✅ completed | Extracted `%%{init:...}%%` parser from `SourcePreprocessing.swift` |
| 2.5 MermaidSourceNormalizer | ✅ completed | `rawLines(_:)`, `diagramLines(_:)`, `statements(_:)` entry points |
| 2.6 FrontmatterDocumentParser | ✅ completed | YAML flattening + `_StackSafeYamlFrontmatterParser` extracted |
| 2.7 Rewire SourcePreprocessing | ✅ completed | `_parseFrontMatterAndStripped` now coordinates: normalize → YAML parse → init parse → bindings apply → commit |
| 2.8 Delete dead code | ❌ not started | Old `_apply*InitConfig`/`_apply*YamlConfig` functions still present (YAML path reference); can delete once YAML path fully migrated |
| 3.1 SvgModelAdapter extensions | ✅ completed | Typed inits on `_SvgNode`, `_SvgEdge`, `_SvgGroup`, `_SvgPoint` from `Positioned*` types |
| 3.2 Replace _extractSvgGraphModel | ✅ completed | Mirror replaced with typed `switch graph.content` on `.flowchart`/`.stateDiagram` |
| 3.3 Delete Mirror helpers | ✅ completed | Removed `_unboxOptional`, `_readArray`, `_readString`, `_readDouble`, `_readBool`, `_readMap` |
| **Phase 3: Boundary Hardening** | | |
| 6.1 Public API audit | pending | — |
| 6.2 Port class access change | pending | — |
| 6.3 Lower-level function access | pending | — |
| 6.4 Deprecation wrappers | pending | — |
| 2.9 RenderTokens type | pending | — |
| 2.10 Layout RenderTokens routing | pending | — |
| 2.11 SVG RenderTokens routing | pending | — |
| 2.12 Ishikawa RenderTokens routing | pending | — |
| **Phase 2 (deferred): Priority 5** | | |
| 5.1–5.8 Shape/Edge geometry | ❌ not started | 8 tasks — requires careful extraction of all shape constants from layout, CG, and SVG |

---

## Estimated Timeline

| Phase | Tasks | Planned Effort | Actual Status |
|-------|-------|---------------|---------------|
| Phase 1 | 4.1–4.3, 7.1–7.3, 8.1 | ~10 days seq / ~4 days par | ✅ Complete (7 tasks) |
| Phase 2 | P1: 1.1–1.7, P2: 2.1–2.8, P3: 3.1–3.3 | ~24 days (P1+P2+P3) | ✅ 19/27 complete; 1 deferred (1.4); 1 not started (2.8) |
| Phase 2 (deferred) | P5: 5.1–5.8 Shape/Edge geometry | ~12 days | ❌ Not started |
| Phase 3 | P6: 6.1–6.4, P2: 2.9–2.12 | ~10 days seq / ~4 days par | ⏳ Pending (8 tasks) |
| **Remaining** | **P5 (8) + P6 (4) + RenderTokens (4) + cleanup (1)** | **~19 days sequential** | **17 tasks** |

### Actual Effort vs Plan

The original estimate of ~52 sequential days was pessimistic. Phase 1 (planned 10 days seq) completed in ~4 turns of work. Phase 2 core work (P1 registry + P2 bindings + P3 reflection) completed in ~5 turns. The primary deferral — Priority 5 shape/edge geometry — accounts for the largest remaining block because it requires coordinating layout constants, CG paths, and SVG path data across three independent render pipelines.

---

## Success Criteria

| # | Criterion | Status |
|---|-----------|--------|
| 1 | All 396 snapshot tests pass with identical or intentionally-rebaselined output | ⚠️ Not yet verified — snapshots not run against current changes |
| 2 | `SourcePreprocessing.swift` reduced from 2,637 LOC to <500 LOC | ⏳ Partial — bindings extracted but old functions not yet deleted (Task 2.8) |
| 3 | Zero `Mirror` usage in rendering paths | ✅ Complete — `_extractSvgGraphModel` now uses typed `switch graph.content` |
| 4 | Single `SVG` utility used by all 28+ renderers for escaping and document construction | ✅ Complete — `SVG.escapeText`/`SVG.escapeAttribute` + `SVGDocumentBuilder` |
| 5 | Single `DiagramRegistry` owns all header detection and high-level routing | ✅ Complete — `DiagramRegistry.detect` drives Parser, Layout, type detection, and CG dispatch |
| 6 | Public API surface reduced from ~740 declarations to ~100 | ❌ Not started — Phase 3 (P6) pending |
| 7 | No hardcoded font names in any renderer | ❌ Not started — Phase 3 (RenderTokens 2.9–2.12) pending |
| 8 | Every pipeline entry point follows same font-registration + issue-reporting pattern | ✅ Complete — `runPipeline` helper used by all `MermaidPipeline` methods + `ImageRenderer` |
