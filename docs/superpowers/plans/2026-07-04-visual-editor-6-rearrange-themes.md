# Visual Editor Plan 6/6 — Rearrange + Themes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Theme and layout-preset selection from the visual toolbar, persisted in YAML frontmatter so they round-trip with the source — `setTheme` / `setLayoutPreset` document mutations, a Hierarchical/Adaptive ELK preset, and a source-pinned theme bridge in the sample app.

**Architecture:** New end-to-end frontmatter plumbing (verified absent at every stage): `DiagramDocument` gains a `frontmatter: DiagramDocumentFrontmatter?` slot (`theme` + `layout` strings); `MermaidImporter` lifts `shared.theme/layout` onto it; `MermaidExporter` emits them in the title frontmatter block. `DiagramMutation` gains `setTheme(String?)` + `setLayoutPreset(LayoutPreset)`. The layout preset threads parser→`FlowchartConfig.layoutPreset`→`ElkLayoutOptions` (adaptive = spline routing, relaxed model order, wider spacing). The sample app resolves a source-pinned theme via the existing `DiagramTheme.theme(named:)` catalog.

**Tech Stack:** Swift 6, swift-testing + XCTest, SwiftUI.

**Spec:** `docs/superpowers/specs/2026-07-04-visual-editor-design.md` Sections 1 (document mutations) + 6. **Spec corrections (verified):** the spec claimed frontmatter theme keys were "already parsed" and "the pipeline already resolves frontmatter themes at render time" — parsing exists but values are discarded, and the core pipeline takes `theme:` as a caller parameter only. This plan adds the missing plumbing. Core render behavior stays caller-driven (auto-applying frontmatter themes in the core would shift existing corpus snapshots); the **sample app** consumes the source-pinned theme, which delivers the spec's UX. Documented deviation.

## Global Constraints

- Work directly on `main`, commit-by-commit; `swift test --filter <ExactSuiteName>` only.
- Typed diagnostic factories; gates in the closer. File-size warn 500 / error 1000.
- `DiagramMutation` extensions require: case + `undoActionName` + `==`/`hash` (existing discriminators 0–3; new cases use **4, 5**) + `_apply` arm + `LiveEditorStore.undoKind/undoLabel(for: DiagramMutation)` arms (exhaustive, in `Sources/DiagramKitSample/Models/LiveEditorStore.swift` ~line 660).
- Known pre-existing: old corpus image baselines crash the snapshot harness; assert only session-recorded ids.

## Reference — verified facts (from the frontmatter survey)

- `DiagramDocument` (`Sources/DiagramKitModel/Types.swift:134`): fields are exactly `payload` + `title`. `_setTitle` (`DiagramEditor+Mutations.swift:245`) is the model for document-level mutation application.
- `SharedFrontmatter` (`Sources/DiagramKitModel/SharedFrontmatter.swift:6-17`): `title, diagramTitle, layout, look, theme, …` all `String?`. `MermaidImporter.swift:45-46` lifts only title onto the document — theme/layout are discarded.
- `MermaidExporter.swift:112-125` `prependingDocumentTitle` emits `---\ntitle: X\n---\n` only, gated on non-empty title.
- `DiagramTheme.theme(named:) -> DiagramTheme?` + `DiagramTheme.allThemes: [(name, theme)]` (`Sources/DiagramKitModel/Theme.swift:321-341`) — the name→theme catalog (17 themes).
- `ElkLayoutOptions.root(direction:hierarchy:)` / `flatRoot(direction:)` (`Sources/DiagramKitModel/ElkLayoutOptions.swift:36-90`): `elk.edgeRouting` hardcoded `"ORTHOGONAL"`, `considerModelOrder` hardcoded `"NODES_AND_EDGES"`, `elk.spacing.nodeNode: "28"`, `nodeNodeBetweenLayers: "48"`. Called from `src_layout_factory.swift:84,186,357` with only `graph.direction`.
- `FlowchartConfig` (`src_types.swift:417-440`): `curve, htmlLabels, markdownAutoWrap, width, inheritDir, securityLevel` — parse-time only today. `MermaidGraph.config: FlowchartConfig?` exists on the graph the layout builders receive.
- `DiagramRegistry+Flowchart.swift:17-18` forwards `frontmatter?.perDiagram.flowchart.config` into `parseMermaid` — the hook point for copying `shared.layout` into the config.
- Sample app: `previewTheme` (`LiveEditorStore.swift:156-159`) = `DiagramTheme.theme(named: previewThemeName) ?? .default` (+ ThemeBuilder overrides); no bridge from source frontmatter.
- Frontmatter YAML shapes: verify which key spelling lands in `SharedFrontmatter.theme` by reading `Sources/DiagramKitModel/DiagramFrontmatter.swift` / `FrontmatterDocumentParser.swift` during Task 1 (both top-level `theme:` and `config:\n  theme:` may flatten; the Task 1 round-trip test pins whichever the parser accepts — emit that shape).
- Round-trip harness: `DiagramDocumentDiff` (`Tests/DiagramKitTests/RoundTrip/DiagramDocumentDiffTests.swift` + `Sources/DiagramKitTestSupport/`) compares documents structurally — check whether it needs a frontmatter field comparison (add it so theme/layout loss would be caught).

## File Structure

- `Sources/DiagramKitModel/Types.swift` — `DiagramDocumentFrontmatter` struct + `DiagramDocument.frontmatter` field.
- `Sources/DiagramKit/MermaidImporter.swift` — lift `shared.theme/layout`.
- `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift` — frontmatter emission.
- `Sources/DiagramKitInteractive/DiagramMutation.swift` + `DiagramEditor+Mutations.swift` + `DiagramEditorError.swift` — `setTheme`/`setLayoutPreset` + `LayoutPreset` + `unknownThemeName`.
- `Sources/DiagramKitModel/ElkLayoutOptions.swift`, `src_types.swift` (FlowchartConfig), `src_layout_factory.swift`, `Sources/DiagramKit/DiagramRegistry+Flowchart.swift` — preset thread.
- Sample: `LiveEditorStore.swift`/`+Visual.swift` (undo arms, source-pinned theme, apply methods), `Views/Visual/CanvasCenterToolbar.swift` (Rearrange + Theme popovers), `Views/Visual/RearrangePopover.swift` (new), `Views/Visual/ThemeSwatchPicker.swift` (new), `Views/ThemePicker.swift` (source-pinned indicator), `View+Accessibility.swift`.
- Tests: `Tests/DiagramKitTests/FrontmatterDocumentFieldTests.swift` (new), `Tests/DiagramKitTests/Interactive/DocumentThemeLayoutMutationTests.swift` (new), `Tests/DiagramKitTests/LayoutPresetTests.swift` (new), `Tests/DiagramKitTests/Playground/ThemeLayoutFlowTests.swift` (new).

---

### Task 1: Document frontmatter slot — model + importer lift + exporter emission

**Files:**
- Modify: `Sources/DiagramKitModel/Types.swift`, `Sources/DiagramKit/MermaidImporter.swift`, `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`
- Test: `Tests/DiagramKitTests/FrontmatterDocumentFieldTests.swift`

**Interfaces:**
- Produces (Tasks 2–4 use):

```swift
public struct DiagramDocumentFrontmatter: Sendable, Equatable, Hashable {
    public var theme: String?
    public var layout: String?
    public init(theme: String? = nil, layout: String? = nil)
    public var isEmpty: Bool
}
// on DiagramDocument:
public var frontmatter: DiagramDocumentFrontmatter?
```

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/FrontmatterDocumentFieldTests.swift`:

```swift
// Visual editor plan 6 — frontmatter theme/layout round-trip through
// the document model, importer, and exporter.

import Testing
import DiagramKitModel
import DiagramKitMermaid
@testable import DiagramKit

@Suite
struct FrontmatterDocumentFieldTests {

    private let themedSource = """
    ---
    title: Themed
    theme: nord
    layout: adaptive
    ---
    graph TD
      A --> B
    """

    @Test("importer lifts shared theme/layout onto the document")
    func importerLift() throws {
        let doc = try MermaidImporter().parse(themedSource).document
        #expect(doc.frontmatter?.theme == "nord")
        #expect(doc.frontmatter?.layout == "adaptive")
        #expect(doc.title == "Themed")
    }

    @Test("exporter emits theme/layout in the frontmatter block")
    func exporterEmit() throws {
        var doc = try MermaidImporter().parse("graph TD\n  A --> B\n").document
        doc.frontmatter = DiagramDocumentFrontmatter(theme: "nord", layout: "adaptive")
        let result = try MermaidExporter().export(doc)
        #expect(result.source.hasPrefix("---\n"))
        #expect(result.source.contains("theme: nord"))
        #expect(result.source.contains("layout: adaptive"))
    }

    @Test("theme/layout survive parse → export → parse")
    func roundTrip() throws {
        let doc = try MermaidImporter().parse(themedSource).document
        let exported = try MermaidExporter().export(doc).source
        let reparsed = try MermaidImporter().parse(exported).document
        #expect(reparsed.frontmatter?.theme == "nord")
        #expect(reparsed.frontmatter?.layout == "adaptive")
        #expect(reparsed.title == "Themed")
    }

    @Test("no frontmatter → nil slot and no emitted block")
    func absentFrontmatter() throws {
        let doc = try MermaidImporter().parse("graph TD\n  A --> B\n").document
        #expect(doc.frontmatter == nil || doc.frontmatter?.isEmpty == true)
        let exported = try MermaidExporter().export(doc).source
        #expect(!exported.hasPrefix("---"))
    }

    @Test("theme-only frontmatter emits without a title")
    func themeWithoutTitle() throws {
        var doc = try MermaidImporter().parse("graph TD\n  A --> B\n").document
        doc.frontmatter = DiagramDocumentFrontmatter(theme: "dracula")
        let exported = try MermaidExporter().export(doc).source
        #expect(exported.hasPrefix("---\n"))
        #expect(exported.contains("theme: dracula"))
        let reparsed = try MermaidImporter().parse(exported).document
        #expect(reparsed.frontmatter?.theme == "dracula")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter FrontmatterDocumentFieldTests`
Expected: BUILD FAILURE — `DiagramDocument` has no member `frontmatter`.

If `importerLift` later fails because top-level `theme:`/`layout:` keys don't reach `SharedFrontmatter`, read `Sources/DiagramKitModel/DiagramFrontmatter.swift` + `FrontmatterDocumentParser.swift` to find the accepted spelling (possibly `config:\n  theme:`) and update BOTH the test source and the exporter emission to that spelling — the parser is the source of truth; do not modify the parser.

- [ ] **Step 3: Implement**

`Types.swift` — next to `DiagramDocument`:

```swift
/// Diagram-level presentation settings carried in YAML frontmatter
/// (visual editor plan 6). Round-trips through the Mermaid importer
/// and exporter alongside `title`.
public struct DiagramDocumentFrontmatter: Sendable, Equatable, Hashable {
    /// Theme name (resolved via `DiagramTheme.theme(named:)` by hosts).
    public var theme: String?
    /// Layout preset name ("adaptive"; nil/absent = hierarchical default).
    public var layout: String?

    public init(theme: String? = nil, layout: String? = nil) {
        self.theme = theme
        self.layout = layout
    }

    public var isEmpty: Bool { theme == nil && layout == nil }
}
```

and on `DiagramDocument` (after `title`):

```swift
    /// Frontmatter presentation settings (theme / layout preset), or
    /// nil when the source carried none.
    public var frontmatter: DiagramDocumentFrontmatter?
```

(Existing memberwise inits: `DiagramDocument` init(s) get `frontmatter: DiagramDocumentFrontmatter? = nil` appended with a default so no call sites break.)

`MermaidImporter.swift` — where `document.title` is set from `frontmatter?.shared` (~line 45), add:

```swift
        let fmTheme = frontmatter?.shared.theme
        let fmLayout = frontmatter?.shared.layout
        if fmTheme != nil || fmLayout != nil {
            document.frontmatter = DiagramDocumentFrontmatter(theme: fmTheme, layout: fmLayout)
        }
```

(Apply at every site in the importer that constructs the returned document with frontmatter in scope — grep `shared.diagramTitle` in the file; mirror each title-lift site.)

`MermaidExporter.swift` — replace `prependingDocumentTitle` (lines ~112–125) with a general frontmatter emitter that writes any of title/theme/layout (same normalization for title as today):

```swift
    /// Prefix `source` with a YAML frontmatter block carrying the
    /// document title and presentation settings. Emits nothing when
    /// all are absent. Key spelling matches what
    /// FrontmatterDocumentParser reads back (round-trip pinned by
    /// FrontmatterDocumentFieldTests).
    private func prependingFrontmatter(_ source: String, document: DiagramDocument) -> String {
        var lines: [String] = []
        if let title = document.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            lines.append("title: \(title)")   // keep the existing title normalization/escaping code here
        }
        if let theme = document.frontmatter?.theme, !theme.isEmpty {
            lines.append("theme: \(theme)")
        }
        if let layout = document.frontmatter?.layout, !layout.isEmpty {
            lines.append("layout: \(layout)")
        }
        guard !lines.isEmpty else { return source }
        return "---\n" + lines.joined(separator: "\n") + "\n---\n" + source
    }
```

and update its call site (previously `prependingDocumentTitle`). Preserve whatever title escaping the current implementation does — move it, don't drop it.

- [ ] **Step 4: Run to verify pass + blast radius**

`swift test --filter FrontmatterDocumentFieldTests` — PASS (5 tests).
Blast radius: `swift test --filter MermaidExporterTests`, `swift test --filter SameFormatRoundTripTests`, `swift test --filter CorpusRoundTripTests`, `swift test --filter DiagramDocumentDiffTests` — PASS. If the document diff harness compares documents field-by-field, add `frontmatter` to its comparison (in `Sources/DiagramKitTestSupport/` — find `title` comparison and mirror it); if it only compares payload+title structurally via existing accessors, no change needed.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitModel/Types.swift Sources/DiagramKit/MermaidImporter.swift Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift Tests/DiagramKitTests/FrontmatterDocumentFieldTests.swift
git commit -m "Visual editor 6a — DiagramDocument.frontmatter slot round-trips theme/layout"
```

(Include any TestSupport diff change in the same commit.)

---

### Task 2: `setTheme` + `setLayoutPreset` document mutations

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramMutation.swift`, `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift`, `Sources/DiagramKitInteractive/DiagramEditorError.swift`, `Sources/DiagramKitSample/Models/LiveEditorStore.swift`
- Test: `Tests/DiagramKitTests/Interactive/DocumentThemeLayoutMutationTests.swift`

**Interfaces:**
- Produces (Task 4 uses):

```swift
public enum LayoutPreset: String, Sendable, CaseIterable, Hashable {
    case hierarchical   // ELK layered defaults; frontmatter layout omitted
    case adaptive       // spline routing + relaxed model order + wider spacing
}
// DiagramMutation new cases:
case setTheme(String?)              // nil clears; name validated via DiagramTheme.theme(named:)
case setLayoutPreset(LayoutPreset)  // .hierarchical clears the layout key
// DiagramEditorError:
case unknownThemeName(name: String)
```

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/Interactive/DocumentThemeLayoutMutationTests.swift`:

```swift
// Visual editor plan 6 — setTheme / setLayoutPreset document mutations.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart, .stateDiagram]
    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        DiagramExportResult(source: "mock")
    }
}

private func flowDoc() -> DiagramDocument {
    DiagramDocument(payload: .flowchart(original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: [(id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rectangle))],
        edges: []
    )))
}

@MainActor
private func makeEditor() -> DiagramEditor {
    DiagramEditor(
        document: flowDoc(),
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(MockExporter())
    )
}

@Suite @MainActor
struct DocumentThemeLayoutMutationTests {

    @Test("setTheme writes the frontmatter theme")
    func setTheme() async throws {
        let editor = makeEditor()
        try await editor.perform(.setTheme("nord"))
        #expect(editor.document.frontmatter?.theme == "nord")
    }

    @Test("setTheme nil clears the theme and drops an empty frontmatter")
    func clearTheme() async throws {
        let editor = makeEditor()
        try await editor.perform(.setTheme("nord"))
        try await editor.perform(.setTheme(nil))
        #expect(editor.document.frontmatter?.theme == nil)
        #expect(editor.document.frontmatter == nil || editor.document.frontmatter?.isEmpty == true)
    }

    @Test("unknown theme name throws unknownThemeName")
    func unknownTheme() async {
        let editor = makeEditor()
        await #expect(throws: DiagramEditorError.self) {
            try await editor.perform(.setTheme("not-a-theme-xyz"))
        }
    }

    @Test("setLayoutPreset adaptive writes layout; hierarchical clears it")
    func layoutPreset() async throws {
        let editor = makeEditor()
        try await editor.perform(.setLayoutPreset(.adaptive))
        #expect(editor.document.frontmatter?.layout == "adaptive")
        try await editor.perform(.setLayoutPreset(.hierarchical))
        #expect(editor.document.frontmatter?.layout == nil)
    }

    @Test("theme survives alongside layout")
    func combined() async throws {
        let editor = makeEditor()
        try await editor.perform(.setTheme("dracula"))
        try await editor.perform(.setLayoutPreset(.adaptive))
        #expect(editor.document.frontmatter?.theme == "dracula")
        #expect(editor.document.frontmatter?.layout == "adaptive")
    }

    @Test("undo restores the previous frontmatter")
    func undoRestores() async throws {
        let editor = makeEditor()
        try await editor.perform(.setTheme("nord"))
        editor.undoManager.undo()
        #expect(editor.document.frontmatter?.theme == nil)
    }
}
```

- [ ] **Step 2: Run** `swift test --filter DocumentThemeLayoutMutationTests` — Expected: BUILD FAILURE (no member `setTheme`).

- [ ] **Step 3: Implement**

`DiagramMutation.swift` — add to the enum:

```swift
    /// Set (or clear, with nil) the frontmatter theme. Names are
    /// validated against DiagramTheme.theme(named:).
    case setTheme(String?)

    /// Choose the layout preset. `.hierarchical` is the default and
    /// clears the frontmatter layout key; `.adaptive` persists it.
    case setLayoutPreset(LayoutPreset)
```

plus, at file scope:

```swift
/// Flowchart layout presets (visual editor plan 6). Hierarchical is
/// the ELK layered default; adaptive relaxes model order, routes
/// edges as splines, and widens spacing for connection-dense flows.
public enum LayoutPreset: String, Sendable, CaseIterable, Hashable {
    case hierarchical
    case adaptive
}
```

`undoActionName`: `"Set Theme"` / `"Set Layout"`. `==`/`hash`: field-wise, discriminators `4` and `5`.

`DiagramEditorError.swift`: `case unknownThemeName(name: String)` + description `"Unknown theme name '\(name)'"`.

`DiagramEditor+Mutations.swift` — `_apply` arms:

```swift
        case .setTheme(let name):
            return try _setTheme(name, in: document)
        case .setLayoutPreset(let preset):
            return _setLayoutPreset(preset, in: document)
```

implementations (next to `_setTitle`):

```swift
    func _setTheme(_ name: String?, in document: DiagramDocument) throws -> DiagramDocument {
        if let name, DiagramTheme.theme(named: name) == nil {
            throw DiagramEditorError.unknownThemeName(name: name)
        }
        var doc = document
        var fm = doc.frontmatter ?? DiagramDocumentFrontmatter()
        fm.theme = name
        doc.frontmatter = fm.isEmpty ? nil : fm
        return doc
    }

    func _setLayoutPreset(_ preset: LayoutPreset, in document: DiagramDocument) -> DiagramDocument {
        var doc = document
        var fm = doc.frontmatter ?? DiagramDocumentFrontmatter()
        fm.layout = preset == .adaptive ? LayoutPreset.adaptive.rawValue : nil
        doc.frontmatter = fm.isEmpty ? nil : fm
        return doc
    }
```

(`DiagramTheme` lives in `DiagramKitModel`, already imported.)

`LiveEditorStore.swift` — `undoKind(for: DiagramMutation)` gains `case .setTheme, .setLayoutPreset: return .setTitle`; `undoLabel(for:)` gains:

```swift
        case .setTheme(let name):
            return "Theme → \(name ?? "default")"
        case .setLayoutPreset(let preset):
            return "Layout → \(preset.rawValue)"
```

- [ ] **Step 4: Run** `swift test --filter DocumentThemeLayoutMutationTests` — PASS (6 tests). Also `swift test --filter DiagramMutationTests` + `swift test --filter DiagramEditorMutationTests` — PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramMutation.swift Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift Sources/DiagramKitInteractive/DiagramEditorError.swift Sources/DiagramKitSample/Models/LiveEditorStore.swift Tests/DiagramKitTests/Interactive/DocumentThemeLayoutMutationTests.swift
git commit -m "Visual editor 6b — setTheme + setLayoutPreset document mutations"
```

---

### Task 3: Adaptive layout preset through ELK

**Files:**
- Modify: `Sources/DiagramKitModel/ElkLayoutOptions.swift`, `Sources/DiagramKitModel/src_types.swift` (FlowchartConfig), `Sources/DiagramKitModel/src_layout_factory.swift`, `Sources/DiagramKit/DiagramRegistry+Flowchart.swift`
- Test: `Tests/DiagramKitTests/LayoutPresetTests.swift`

**Interfaces:**
- Produces: `ElkLayoutOptions.Preset` (`hierarchical`/`adaptive`); `FlowchartConfig.layoutPreset: String?`; layout builders read `graph.config?.layoutPreset == "adaptive"`.

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/LayoutPresetTests.swift`:

```swift
// Visual editor plan 6 — adaptive layout preset changes geometry.

import Testing
@testable import DiagramKit
@testable import DiagramKitModel

@Suite
struct LayoutPresetTests {

    private let denseFlow = """
    graph TD
      A --> B
      A --> C
      B --> D
      C --> D
      D --> E
      B --> E
    """

    @Test("adaptive preset produces different geometry than hierarchical")
    func adaptiveDiffers() async throws {
        let hierarchical = try await DiagramEngine.renderSVG(source: denseFlow)
        let adaptive = try await DiagramEngine.renderSVG(
            source: "---\nlayout: adaptive\n---\n" + denseFlow
        )
        #expect(hierarchical.contains("<svg"))
        #expect(adaptive.contains("<svg"))
        #expect(hierarchical != adaptive, "adaptive preset must change layout output")
    }

    @Test("adaptive option dictionary relaxes model order and widens spacing")
    func adaptiveOptions() {
        let opts = ElkLayoutOptions.root(
            direction: .TD, hierarchy: .includeChildren, preset: .adaptive
        )
        #expect(opts["elk.layered.considerModelOrder.strategy"] == "NONE")
        #expect(opts["elk.spacing.nodeNode"] == "40")
        #expect(opts["elk.layered.spacing.nodeNodeBetweenLayers"] == "64")
        let defaults = ElkLayoutOptions.root(direction: .TD, hierarchy: .includeChildren)
        #expect(defaults["elk.layered.considerModelOrder.strategy"] == "NODES_AND_EDGES")
    }

    @Test("unknown layout value falls back to hierarchical without crashing")
    func unknownValue() async throws {
        let svg = try await DiagramEngine.renderSVG(
            source: "---\nlayout: bananas\n---\n" + denseFlow
        )
        #expect(svg.contains("<svg"))
    }
}
```

- [ ] **Step 2: Run** — Expected: BUILD FAILURE (`root` has no `preset:` parameter).

- [ ] **Step 3: Implement**

`ElkLayoutOptions.swift`:

```swift
    /// Layout presets (visual editor plan 6). Hierarchical is the
    /// classic layered default; adaptive relaxes model-order
    /// constraints, routes edges as splines, and widens spacing so
    /// connection-dense flows arrange by connectivity.
    public enum Preset: String, Sendable {
        case hierarchical
        case adaptive
    }
```

Give `root(direction:hierarchy:)` a `preset: Preset = .hierarchical` parameter; after building the existing dictionary, apply:

```swift
        if preset == .adaptive {
            options["elk.layered.considerModelOrder.strategy"] = "NONE"
            options["elk.edgeRouting"] = "SPLINES"
            options["elk.spacing.nodeNode"] = "40"
            options["elk.layered.spacing.nodeNodeBetweenLayers"] = "64"
        }
        return options
```

Do the same for `flatRoot(direction:)` (add `preset: Preset = .hierarchical`). `subgraph(direction:)` stays as-is.

`src_types.swift` — `FlowchartConfig` gains `public var layoutPreset: String?` (append to fields + memberwise init with `= nil` default).

`DiagramRegistry+Flowchart.swift` — where the parse closure forwards `frontmatter?.perDiagram.flowchart.config` (~line 17), copy the shared layout key in first:

```swift
            var flowConfig = frontmatter?.perDiagram.flowchart.config
            if let layout = frontmatter?.shared.layout {
                var cfg = flowConfig ?? original_src_types.FlowchartConfig()
                cfg.layoutPreset = layout
                flowConfig = cfg
            }
```

and pass `flowConfig` where the original expression was passed. (Match the actual local naming in the file; the state-config forward on line 18 is untouched.)

`src_layout_factory.swift` — at the three `ElkLayoutOptions.root(...)` call sites (lines ~84, ~186) and the `flatRoot` site (~357), thread the preset:

```swift
        let preset: ElkLayoutOptions.Preset =
            graph.config?.layoutPreset == "adaptive" ? .adaptive : .hierarchical
```

then `ElkLayoutOptions.root(direction: graph.direction, hierarchy: …, preset: preset)` / `flatRoot(direction: graph.direction, preset: preset)`.

(If `_ParsedGraph` doesn't expose `config`, check its definition — it is a typealias/wrapper of `MermaidGraph` which has `config: FlowchartConfig?`; use the accessor the builders already use for `graph.stateConfig` as the pattern.)

- [ ] **Step 4: Run** `swift test --filter LayoutPresetTests` — PASS (3 tests). Blast radius: `SNAPSHOT_DIAGRAM_IDS=flow-28-visual-styles,flow-29-icon-nodes,flow-30-image-node swift test --filter CorpusSnapshotTests` — PASS (no corpus entry uses `layout:`; defaults unchanged). `swift test --filter BlockLayoutTests` — PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitModel/ElkLayoutOptions.swift Sources/DiagramKitModel/src_types.swift Sources/DiagramKit/DiagramRegistry+Flowchart.swift Sources/DiagramKitModel/src_layout_factory.swift Tests/DiagramKitTests/LayoutPresetTests.swift
git commit -m "Visual editor 6c — adaptive layout preset threads frontmatter → FlowchartConfig → ELK"
```

---

### Task 4: Sample app — source-pinned theme + Rearrange/Theme toolbar pickers

**Files:**
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore.swift` (previewTheme bridge), `Models/LiveEditorStore+Visual.swift` (apply methods)
- Create: `Sources/DiagramKitSample/Views/Visual/RearrangePopover.swift`, `Sources/DiagramKitSample/Views/Visual/ThemeSwatchPicker.swift`
- Modify: `Views/Visual/CanvasCenterToolbar.swift`, `Views/ThemePicker.swift` (indicator), `Views/Support/View+Accessibility.swift`
- Test: `Tests/DiagramKitTests/Playground/ThemeLayoutFlowTests.swift`

**Interfaces:**
- Produces: `LiveEditorStore.sourcePinnedThemeName: String?` (from `editor?.document.frontmatter?.theme`), `applyThemeFromToolbar(named: String?) async`, `applyLayoutPreset(_: LayoutPreset) async`; `previewTheme` prefers the source-pinned theme.

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/Playground/ThemeLayoutFlowTests.swift`:

```swift
//
//  ThemeLayoutFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 6 — toolbar theme/layout flows and the
//  source-pinned theme bridge.
//

#if canImport(CoreGraphics)
import CoreGraphics
import XCTest
import DiagramKit
import DiagramKitInteractive
import DiagramKitModel
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class ThemeLayoutFlowTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    private func waitForEditor(store: LiveEditorStore, timeout: TimeInterval = 5) async throws {
        let start = Date()
        while store.editor == nil {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("editor never became available")
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
            store.didCompleteRender(parseError: nil, diagramBounds: .zero)
        }
    }

    func test_applyThemeWritesFrontmatterAndPinsPreview() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)

        await store.applyThemeFromToolbar(named: "nord")

        XCTAssertTrue(store.state.source.contains("theme: nord"), "source gains frontmatter theme")
        XCTAssertEqual(store.sourcePinnedThemeName, "nord")
        XCTAssertEqual(store.previewTheme, DiagramTheme.theme(named: "nord"))
    }

    func test_clearThemeRemovesFrontmatter() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)
        await store.applyThemeFromToolbar(named: "nord")

        await store.applyThemeFromToolbar(named: nil)

        XCTAssertFalse(store.state.source.contains("theme:"))
        XCTAssertNil(store.sourcePinnedThemeName)
    }

    func test_applyLayoutPresetWritesAndClearsLayoutKey() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)

        await store.applyLayoutPreset(.adaptive)
        XCTAssertTrue(store.state.source.contains("layout: adaptive"))

        await store.applyLayoutPreset(.hierarchical)
        XCTAssertFalse(store.state.source.contains("layout:"))
    }
}
#endif
```

- [ ] **Step 2: Run** — Expected: BUILD FAILURE (`applyThemeFromToolbar`).

- [ ] **Step 3: Implement store side**

`LiveEditorStore+Visual.swift` (after the image-sheet section):

```swift
    // MARK: - Theme / layout toolbar (visual editor plan 6)

    /// Theme name pinned in the diagram source's frontmatter, if any.
    public var sourcePinnedThemeName: String? {
        editor?.document.frontmatter?.theme
    }

    /// Apply (or clear, with nil) a theme from the visual toolbar.
    /// Writes frontmatter through the mutation path so it round-trips.
    public func applyThemeFromToolbar(named name: String?) async {
        do {
            try await performMutation(.setTheme(name))
        } catch {
            // performMutation already recorded the error.
        }
    }

    /// Apply a layout preset from the Rearrange popover.
    public func applyLayoutPreset(_ preset: LayoutPreset) async {
        do {
            try await performMutation(.setLayoutPreset(preset))
        } catch {
            // performMutation already recorded the error.
        }
    }
```

`LiveEditorStore.swift` — in the `previewTheme` computed property (~line 156), prefer the source-pinned theme before `previewThemeName`:

```swift
        if let pinned = editor?.document.frontmatter?.theme,
           let theme = DiagramTheme.theme(named: pinned) {
            return _applyThemeBuilderOverrides(to: theme)   // match the existing override-application call
        }
```

(Insert as the first resolution step; reuse whatever override-application the property already performs — read the property and mirror its exact structure.)

- [ ] **Step 4: Run** `swift test --filter ThemeLayoutFlowTests` — PASS (3 tests).

- [ ] **Step 5: UI**

Create `Sources/DiagramKitSample/Views/Visual/RearrangePopover.swift`:

```swift
//
//  RearrangePopover.swift
//  DiagramPlayground
//
//  Rearrange picker (visual editor plan 6): Hierarchical vs Adaptive
//  layout preset cards. Selection persists via frontmatter.
//

import SwiftUI
import DiagramKitInteractive

struct RearrangePopover: View {
    @Bindable var store: LiveEditorStore
    let dismiss: () -> Void

    private var current: LayoutPreset {
        store.editor?.document.frontmatter?.layout == "adaptive" ? .adaptive : .hierarchical
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rearrange layout")
                .font(.system(size: 12, weight: .semibold))
            card(
                preset: .hierarchical,
                title: "Hierarchical",
                detail: "Top-down tree structure. Best for org charts and decision trees.",
                symbol: "square.grid.3x1.below.line.grid.1x2"
            )
            card(
                preset: .adaptive,
                title: "Adaptive",
                detail: "Arranges by connections. Best for complex, dense flows.",
                symbol: "point.3.connected.trianglepath.dotted"
            )
        }
        .padding(12)
        .frame(width: 280)
    }

    private func card(preset: LayoutPreset, title: String, detail: String, symbol: String) -> some View {
        Button {
            dismiss()
            Task { await store.applyLayoutPreset(preset) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .medium))
                    Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if current == preset {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(current == preset ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(A11yID.Visual.rearrangeOption(preset.rawValue))
    }
}
```

Create `Sources/DiagramKitSample/Views/Visual/ThemeSwatchPicker.swift`:

```swift
//
//  ThemeSwatchPicker.swift
//  DiagramPlayground
//
//  Toolbar theme picker (visual editor plan 6): swatches for every
//  DiagramTheme, applied via frontmatter so the theme travels with
//  the source. "Default" clears the pin.
//

import SwiftUI
import DiagramKitModel

struct ThemeSwatchPicker: View {
    @Bindable var store: LiveEditorStore
    let dismiss: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Theme (saved in source)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("Default") {
                    dismiss()
                    Task { await store.applyThemeFromToolbar(named: nil) }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(DiagramTheme.allThemes, id: \.name) { entry in
                        swatch(name: entry.name, theme: entry.theme)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 320, height: 360)
        .accessibilityIdentifier(A11yID.Visual.themePicker)
    }

    private func swatch(name: String, theme: DiagramTheme) -> some View {
        let isPinned = store.sourcePinnedThemeName == name
        return Button {
            dismiss()
            Task { await store.applyThemeFromToolbar(named: name) }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Color(theme.background)
                    Color(theme.foreground)
                    Color(theme.effectiveAccent())
                }
                .frame(height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isPinned ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isPinned ? 2 : 1)
                )
                Text(name)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(width: 88)
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityIdentifier(A11yID.Visual.themeSwatch(name))
    }
}
```

(If `DiagramTheme.allThemes` tuples are unlabeled or `effectiveAccent()` differs, match the real API — `ThemePicker.swift` already iterates `allThemes` and `PreviewToolbar` uses `theme.effectiveAccent()`; copy their idiom.)

`A11yID.Visual` additions:

```swift
        public static let rearrangeButton = "visual.centerToolbar.rearrange"
        public static func rearrangeOption(_ name: String) -> String { "visual.rearrange.\(name)" }
        public static let themeButton = "visual.centerToolbar.theme"
        public static let themePicker = "visual.themePicker"
        public static func themeSwatch(_ name: String) -> String { "visual.themePicker.\(name)" }
```

`CanvasCenterToolbar.swift` — two more state vars + buttons after Image:

```swift
    @SwiftUI.State private var showRearrange = false
    @SwiftUI.State private var showThemePicker = false
```

```swift
            Button {
                showRearrange.toggle()
            } label: {
                Label("Rearrange", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Auto-arrange the diagram")
            .accessibilityIdentifier(A11yID.Visual.rearrangeButton)
            .popover(isPresented: $showRearrange, arrowEdge: .top) {
                RearrangePopover(store: store) { showRearrange = false }
            }

            Button {
                showThemePicker.toggle()
            } label: {
                Label("Theme", systemImage: "paintpalette")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Apply a theme (saved into the source)")
            .accessibilityIdentifier(A11yID.Visual.themeButton)
            .popover(isPresented: $showThemePicker, arrowEdge: .top) {
                ThemeSwatchPicker(store: store) { showThemePicker = false }
            }
```

`Views/ThemePicker.swift` — add a source-pinned indicator: where the picker renders its header/menu, show a small note when pinned:

```swift
            if let pinned = store.sourcePinnedThemeName {
                Text("Source-pinned: \(pinned)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .help("The diagram source's frontmatter pins this theme; it overrides the app theme.")
            }
```

(Place inside the picker's existing container view — read the file and slot it under the theme controls.)

- [ ] **Step 6: Build + smoke + commit**

`swift build` — Build complete. Launch smoke ~8s.

```bash
git add Sources/DiagramKitSample/Models/LiveEditorStore.swift Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift Sources/DiagramKitSample/Views/Visual/RearrangePopover.swift Sources/DiagramKitSample/Views/Visual/ThemeSwatchPicker.swift Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift Sources/DiagramKitSample/Views/ThemePicker.swift Sources/DiagramKitSample/Views/Support/View+Accessibility.swift Tests/DiagramKitTests/Playground/ThemeLayoutFlowTests.swift
git commit -m "Visual editor 6d — toolbar Rearrange + Theme pickers, source-pinned theme bridge"
```

---

### Task 5: Closer — corpus entry, snapshots, docs, gates

- [ ] **Step 1:** Corpus entry (verify `flow-31` unused; bump `_counts.flowchart` 46→47? — read the current values first; they were 45/53 after plan 5):

```json
{
  "id": "flow-31-frontmatter-theme-layout",
  "category": "flowchart",
  "name": "Frontmatter Theme + Adaptive Layout",
  "source": "---\ntitle: Pinned\ntheme: nord\nlayout: adaptive\n---\ngraph TD\n  A --> B\n  A --> C\n  B --> D\n  C --> D"
}
```

- [ ] **Step 2:** `swift test --filter CorpusEntryFormatIDTests` + `CorpusRoundTripTests` — PASS (theme/layout round-trip via Task 1; the harness must show no loss).
- [ ] **Step 3:** Record + assert `SNAPSHOT_DIAGRAM_IDS=flow-31-frontmatter-theme-layout` — 3 baselines, PASS.
- [ ] **Step 4:** Docs: corpus 429→430 (401 Mermaid-only), SVG/image 442→443, ASCII 429→430, total 1313→1316, PNG 442→443, txt 871→873, multi-format cases 429→430 (verify on-disk first). Also update CLAUDE.md's `MermaidImporter` diagnostics bullet if needed (no diagnostics added — skip) and BASELINES "Gate status" untouched.
- [ ] **Step 5:** Gates + suites: `FrontmatterDocumentFieldTests`, `DocumentThemeLayoutMutationTests`, `LayoutPresetTests`, `ThemeLayoutFlowTests`, `"RoundTrip"`, `MermaidExporterTests` — all PASS. Launch smoke.
- [ ] **Step 6:** Commit `"Visual editor 6e — frontmatter theme/layout corpus entry + snapshots"`.

---

## Plan Self-Review (done at authoring time)

- **Spec coverage (Section 6 + Section 1 document mutations):** Rearrange popover with two cards + persistence via frontmatter → Tasks 2–4; `ElkLayoutOptions` preset param → Task 3; `FrontmatterBinding` mapping → Task 3 (registry-level copy — the shared key already parses; binding it to FlowchartConfig happens in the registry closure, a deliberate simplification over touching the per-diagram binding file); theme picker with swatches writing `config.theme` → Tasks 2+4 (emitted spelling pinned to whatever the parser reads back — Task 1); app-level picker "source-pinned" indicator → Task 4; mermaid-js graceful-ignore note → spec, no code. Spec's "pipeline already resolves frontmatter themes" corrected: sample-app bridge instead (header).
- **Placeholder scan:** clean — discovery-dependent edits (importer lift sites, previewTheme structure, ThemePicker slot, diff harness) each name the exact file, the search anchor, and the mirroring pattern.
- **Type consistency:** `DiagramDocumentFrontmatter(theme:layout:)` across Tasks 1/2/4; `LayoutPreset` (Interactive) vs `ElkLayoutOptions.Preset` (Model) are deliberately separate types bridged by the `"adaptive"` string — noted here so no one "unifies" them across module boundaries; discriminators 4/5 unique within `DiagramMutation`.
- **Risk register:** frontmatter key spelling (pinned by Task 1 round-trip test with explicit fallback instruction); `SPLINES` support in the ported ELK (test asserts geometry difference, which the spacing overrides guarantee even if routing is ignored); `previewTheme` equality in tests (`DiagramTheme` is `Equatable` — verified §Theme.swift:25).
