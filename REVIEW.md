# DiagramKit Code Review — Complete

Six parallel reviewers covered architecture/public-API, model (parsers + layouts), rendering + views, format slices, playground + interactive editor, and tests/gates/concurrency. Findings are aggregated and ranked below; every item is file:line-grounded.

## Executive Summary

The library's structural discipline is real and load-bearing: the no-thread-pool 8 MB worker rule, font-registry bootstrap, payload typing, target layering, and `@unchecked Sendable` governance all hold up. The two biggest problem areas are **exporter correctness** (silent data corruption in Mermaid flowchart + PlantUML state/sequence/class exporters) and **playground undo plumbing** (the recent Cmd-Z work is being silently undone by an unrelated re-seed loop). A long-standing testing gap — 248 missing ASCII snapshot baselines combined with auto-record-on-first-run — means renderer drift in 22 ASCII families is currently invisible to CI.

---

## Resolution Status

The "Suggested fix order" at the bottom of this review was executed across five commits on `main`. Each commit lands one phase; subsequent phases assume the gate from the previous one is in place.

| # | Phase | Commit | What landed |
|---|---|---|---|
| 1 | ASCII baselines + smoke-check filter | `7143128` | 247 missing ASCII baselines recorded; `asciiSnapshot` honours `shouldSkipSnapshot(for: "ascii")`; `bootstrap-smoke-check.sh` stops invoking the signal-10-prone unfiltered `swift test` and runs per-suite passes instead. Bonus: D2 probe extended to cover `xychart`/`quadrantChart`/`journey`/`treemap`/`ishikawa`/`eventModeling`/C4* headers and strip leading frontmatter before header dispatch (case-insensitive token boundary). |
| 2 | Playground undo | `138e367` | `SourceOrigin` split into `.system` (wholesale swap, do re-seed) and `.mutation` (editor's document already in sync, skip re-seed). `performMutation` / `performFlowchartMutation` switched to `.mutation`. Cmd-Z command routes through `performScopedUndo` — the focused `NSTextView.undoManager` gets first refusal, falling back to `store.undoStructural()` only when no text view is focused. |
| 3 | Exporter correctness batch | `a13b67c` | `MermaidFlowchartExport.shapeMarker` returns `(open, close)` tuple; subgraph emission walks `model.subgraphs` after the node loop; trapezoid vs parallelogram open/close disambiguated. PlantUML state pseudostate restoration switched from id-suffix matching to `NodeShape.stateStart`/`.stateEnd`. PlantUML sequence message escape routes through the slice's `escape()` helper. PlantUML class parser tracks an `inBlockComment` flag so `/' … '/` multi-line comments are skipped entirely. MermaidClass annotation emitted bare (`<<interface>>`, not `<<"interface">>`); stray space after `:::` removed. |
| 4 | Parser dispatch tokenization | `633bec4` | 21 `DiagramRegistry+*.swift` matchers migrated from `$0.normalized.hasPrefix("…")` to `$0.startsWithToken("…")`. State's compound expression split into `startsWithToken("statediagram") || startsWithToken("state")`. Block/Gantt/Pie were already correct; C4 uses an anchored regex; Flowchart is the `{ _ in true }` fallback. |
| 5 | Renderer color/flip | `f7990d5` | `ShapeRenderer` fill/stroke suppression checks now use `bmColorEquals(.clear)` so AppKit color-space differences don't slip past. `LabelRenderer` always installs its own `NSGraphicsContext(flipped: false)` (save + restore), eliminating the bitmap-path vs AppKit-NSView-path double-flip. |

`er-25-parent-marker` is now tagged `skipSnapshots: ["ascii"]` so the ASCII gate is green; SVG/image still cover the entry. The underlying `.invalidCardinality("MD_PARENT")` in the ER ASCII renderer remains and is recorded in the deferred list below.

---

## Deferred Effort — Recommendations

Some review items were intentionally deferred during the five-phase pass; others surfaced during execution and were scoped out to keep individual commits coherent. Listed in priority order.

### 1. SVG color-mix variable resolver (renderer-deep)

**Status:** investigated and rolled back in Phase 1. The malformed `stroke="#27272A 40%, #FFFFFF))"` strings the reviewer observed come from `Sources/DiagramKitModel/SVGHelpers.swift:138-145` (`color-mix\([^)]+\)`) and `:88-89` (`var\(\s*--…\s*(?:,\s*([^)]+))?\)`) — both regexes use `[^)]+` for the fallback/body, which stops at the first `)` and so mis-parses nested calls like `var(--muted, color-mix(in srgb, var(--fg) 40%, var(--bg)))`. A paren-counting walker (drafted during Phase 1, reverted before commit) produced correct output but changed 182 SVG baselines in addition to the 28 entries already failing.

**Recommendation:** treat as a dedicated phase. Steps:
- Land the paren-counting `_resolveVarFunctions` + `_flattenBalancedFunction` rewrite (the drafted version is in the Phase 1 reflog if useful — search for `"_resolveVarFunctions"`).
- Re-record all SVG and image baselines as one commit, with a commit message that says "rebaseline after color-mix resolver fix" and links here so future readers know why the diff is enormous.
- Audit whether the simultaneous theme-default regression (`flow-1-simple` baseline has `--muted:#A9A9AA;--line:#939394`; current renderer emits `--muted:#27272A;--line:#27272A`) is intentional. If unintentional, fix the theme system before rebaselining so the new baselines reflect the intended palette.

### 2. D2 / DOT `FlowchartExportWalker` subgraph traversal

**Status:** Mermaid flowchart export now emits subgraphs (Phase 3 fix). The walker shared by D2 and DOT exporters at `Sources/DiagramKitExport/FlowchartExportWalker.swift:42-52` still iterates only `nodesInOrder` and `edges`. D2 and DOT continue to silently drop subgraphs.

**Recommendation:** add two new methods to `FlowchartExportSink` (`subgraphBegin(_:depth:)` / `subgraphEnd(_:depth:)`) with default no-op implementations that emit a `.warning` diagnostic. Have the walker invoke them around the contained nodes. Existing D2/DOT sinks inherit the warning behavior; full subgraph emission for D2 (`subgraph: { … }`) and DOT (`subgraph cluster_… { … }`) can ship as follow-ups in each slice.

### 3. ER ASCII renderer `.invalidCardinality("MD_PARENT")`

**Status:** `er-25-parent-marker` is marked `skipSnapshots: ["ascii"]` to keep the gate green. SVG and image renderers handle the parent-marker (`u--o{`) cardinality correctly; only ASCII throws.

**Recommendation:** add `MD_PARENT` to the ER ASCII renderer's cardinality table in `Sources/DiagramKitModel/src_er_renderer.swift` (or wherever the ASCII variant lives). Remove the `skipSnapshots` entry once fixed and record the new ASCII baseline.

### 4. Important-tier review items not in the original fix plan

The following Important findings from the review remain. None are correctness-critical but each is either an architecture hazard, a long-term debt, or a fragility the next major release should address.

**Architecture & API**
- `ReExports.swift:6-13` does not re-export `DiagramKitInteractive` despite `Package.swift` adding it as an umbrella dep. Add the re-export so `import DiagramKit` surfaces `DiagramEditor`.
- `src_theme.swift:4`, `src_styles.swift:4`, `src_text_metrics.swift:4`, `src_multiline_utils.swift:4` are `open class`. Lock down to `internal` or `public final` — these are JS-port shims with no documented subclassing contract.
- `DiagramFormatID` exists only on the exporter side; importers identify by `name: String`. Either move `DiagramFormatID` to `DiagramKitCommon` and adopt symmetrically, or document the asymmetry.
- Deprecated typealiases (`MermaidParser`, `MermaidRenderer`, `MermaidPipeline`, `MermaidImageRenderer`, `MermaidStructuralError`) are scattered across the umbrella. Consolidate in a single `Deprecations.swift` so the next major can sunset them atomically.
- `MermaidImporter.swift:23-34` — `supports(source:)` returns true for any non-empty source. Add an explicit `isFallback: Bool` to the protocol so the registry can mechanically validate "exactly one fallback, last."

**Model: numeric & concurrency edges**
- `src_block_parser.swift:546-547` accepts non-positive `span` values; at `src_block_layout.swift:117` this becomes a divide-by-zero / NaN. Reject `Int(parts[1])` ≤ 0 at parse time.
- `src_class_parser.swift:19` stores `direction: String`; every other family uses a typed enum. Migrate to a typed `ClassDirection` enum (`TB`/`BT`/`LR`/`RL`).
- `src_radar_layout.swift:19-20` — `maxValue = -.infinity` when entries are empty and `options.max` is nil. Add an empty-curve guard and clamp `relativeRadius(...)` against `min == max`.
- `src_gantt_parser.swift:410-423` — `_dateFormatterCache` is `nonisolated(unsafe)`; `DateFormatter.date(from:)` is not documented thread-safe. Wrap with a serial queue, or per-call instantiate, or migrate to `Date.ParseStrategy`.
- `SourcePreprocessing.swift:69-89` — every `---`-bounded section between the first and last marker is treated as frontmatter; a body containing a literal `---` separator line is partially eaten. Tighten to "exactly one closing `---` after the opener, no greedy consumption."
- `src_parser.swift:438-440` — anonymous-subgraph id `"subgraph_\(graph.subgraphIds.count)"` has no collision guard against user-defined ids.

**Rendering & views**
- `EdgeRenderer.swift:119` — `.arrow` case hardcodes `context.setLineWidth(0.75)`, ignoring the configured `lineWidth`. Source the width from the configured stroke.
- `DiagramLayer.swift:182-189` — on parse failure, `preparedDiagram` is not cleared. Pick an intentional semantics (clear-on-failure vs preserve-with-error-overlay) and document it.
- `DiagramEditor+Undo.swift:29-51` — undo snapshot does not capture `selection`. After `.deleteElement(...)`, undo restores doc/source/diagnostics but the dangling selection can throw on the next mutation. Capture selection in the snapshot.
- `DiagramRenderer.swift:147-161` — 4000pt multiline bounding box is a band-aid. Replace with a `measure-first` strategy so the box matches the actual text extent.
- `DiagramLayer.swift:91` — `UIScreen.main.scale` is deprecated on iOS 13+ multi-scene. Source scale from the view's window scene (`view.window?.windowScene?.screen.scale`).

**Format slices: round-trip & diagnostic discipline**
- Identifier-sanitization severity is inconsistent between `MermaidExportHelpers.sanitizeIdentifier` (`.info`) and Structurizr's `uniqueSanitizedAlias` (`.warning`). Pick one (`.warning` is closer to the right severity for lossy operations) and apply across slices.
- `MermaidC4Export.swift:42-54` and `PlantUMLC4Export.swift:47-56` disagree on the slot semantics of the third positional arg (`desc` vs `tech`). Cross-format C4 round-trip silently swaps technology↔description. Align via a single `C4ArgsEmitter` helper.
- `PlantUMLImporter.swift:30-32, 110` throws `.notYetImplemented` for two distinct conditions (malformed source vs unrecognized family). Split into `.malformedSource` and `.unsupportedFamily`.
- `PlantUMLSequenceParser.swift:409-411` declares `title` unsupported; both exporters emit it. Add title parsing to close the round-trip.
- `PlantUMLFamilyProbe.swift:58-61` — class probe false-matches any text containing `--`. Tighten the heuristic.
- `MermaidExportHelpers.sanitizeIdentifier` silently drops non-`[A-Za-z0-9_-]` chars without collision checking. Mirror Structurizr's `usedAliases` set.
- `D2Parser.swift:43-49` only strips `#` as inline-comment marker; `// note` trailing values leak into the value.
- `DOTLexer` does not enter HTML-label mode; `label=<<TABLE>…</TABLE>>` drops the rest of the attribute list. `DOTMapper._isHTMLLabel` (`DOTMapper.swift:382-391`) is dead code until the lexer is fixed.
- `StructurizrExporter.swift:84-91` drops boundary metadata; the companion importer rebuilds boundaries from parent relationships, so export → import loses information. Emit a paired `.warning` on the import side or close the round-trip.
- `D2Mapper.swift:74-101` silently drops direction/icon/tooltip/link from second occurrences in duplicate-node-ID paths.

**Playground state machine**
- `UndoManager.canUndo`/`canRedo` are not Observation-tracked; SwiftUI `.disabled(!editor.undoManager.canUndo)` modifiers drift. Phase 2 sidesteps this by dropping `.disabled` and routing in the action body, but the structural undo footer still has the issue. Mirror `canUndo`/`canRedo` as `@Observable` shims on `DiagramEditor`.
- `DiagramEditor.preferredExportFormat` is `let`; format swaps mid-edit can export under the old format. Either make mutable or rebuild the editor on format change.
- `previewState` is captured pre-render; auto-save can record a state the user hasn't actually rendered. Capture post-render in `didCompleteRender`.
- `_export` runs synchronously on `@MainActor`; large flowcharts block main. Hop to a worker for the export call.
- `NativeCodeEditor.Coordinator.textDidChange` retains `self` through the debounce. Use `[weak self]` or cancel-and-replace the in-flight task.
- `LiveEditorStore.performMutation` and `InsertNodeSection.insert` both surface mutation errors, producing duplicate UI. Pick one source of truth.
- `SidebarView.loadDiagram` ignores `expectedDiagnostics` / `unsupportedNote`. Wire the corpus metadata into the load path.
- `requestRender(reason:)` doesn't reset `parseError`; the error overlay sits atop a fresh render until completion. Clear on render request.

**Tests, gates, concurrency**
- `GanttAsciiRendererTests.swift:9-10` sets+defers `DIAGRAMKIT_GANTT_TODAY`; `CorpusSnapshotTests.swift:46` only sets it. Pin the env var process-wide in a shared suite bootstrap.
- `Scripts/strict-concurrency-check.sh:24` ignores `swift build`'s exit code. Capture and surface it.
- `CLAUDE.md` claims 188 test files; actual is 216. Sync the doc.
- No targeted test for the parser dispatch-order invariant. Add a small suite that pins "stateDiagram-v2 does not fall into state branch", "flowchart-elk does not fall into flowchart branch", etc.

### 5. Minor / polish items

The "Minor" tier in the review (file-size warnings, dead code, header comments referencing removed files, accessibility labels, `MermaidFlowchartExport.shapeMarker` shape-downgrade diagnostics) is left as a backlog. Pick up opportunistically when touching the relevant file.

### 6. Tautological probe tests (Critical, deferred)

`Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift:30-48` — three `@Test` cases (`d2ProbeSignature`, `plantumlProbeSignature`, `structurizrProbeSignature`) construct a literal then `#expect` the same literal contains its own substring. Tautological. Delete or replace with real importer-probe assertions.

---

## Critical (Must Fix)

### Exporters silently corrupt valid input
- **`Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidFlowchartExport.swift:45`** — node-shape wrapping uses `shapeStr.prefix(1) + label + shapeStr.suffix(from: 1)`, so any marker longer than 2 chars produces invalid Mermaid: `(())` becomes `(label())`, plus `[[]]`, `((()))`, `[(%)]`, `([])`, `{{}}`, and all circle variants.
- **`MermaidFlowchartExport.swift:31-55` + `Sources/DiagramKitExport/FlowchartExportWalker.swift:42-52`** — the walker iterates `nodesInOrder` and `edges` only; `model.subgraphs` is never visited. Mermaid, D2, and DOT flowchart exports silently drop all subgraphs/clusters with no diagnostic.
- **`Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift:41`** — message labels escape only `\n`, bypassing the slice's own `escape()` (lines 184-195) that handles `\\`, `"`, and CR. Labels containing a backslash or quote corrupt the line.
- **`Sources/DiagramKitPlantUML/Exporter/PlantUMLStateExporter.swift:107-112`** — `restorePseudostate` rewrites any node id ending in `_start` or `_end` to `[*]`. A legitimately named `customer_start` becomes a pseudostate. Silent data corruption.
- **`Sources/DiagramKitPlantUML/Sequence/PlantUMLSequenceParser.swift:304-308` and `PlantUMLStateParser.swift:190-201`** — `firstIndex(of: ":")` is not quote-aware despite a code comment saying it should be. `Alice -> Bob : "label: detail"` loses everything after the inner colon.
- **`Sources/DiagramKitPlantUML/Class/PlantUMLClassParser.swift:22-27`** — only the opening line of `/' … '/` block comments is skipped; subsequent lines parse as content.
- **`Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidClassExport.swift:51,73`** — annotations emit as `<<"quoted">>` (helper-quoted into the bracket form) and `:::  classes` has a stray space, both producing invalid Mermaid.

### Parser dispatch invariant drifting
- **Sources/DiagramKit/DiagramRegistry+\<Family\>.swift** — most matchers use `$0.normalized.hasPrefix("…")` instead of the bespoke `DiagramHeader.startsWithToken(...)` helper at `DiagramDescriptor.swift:29-36`. `+Pie`, `+Gantt`, `+Block` use it correctly; Architecture, Sequence, Class, ER, Mindmap, Sankey, GitGraph, Packet, Kanban, Timeline, Treemap, etc. do not. A future header like `architectureGroup` would mis-match `architecture`.

### Public API contract holes
- **`Sources/DiagramKit/Parser.swift:7`** — `public enum MermaidParser` carries `@available(*, deprecated, renamed:)`, but its sole member `static func parse` is `internal`. The deprecation guidance has no public surface to deprecate.
- **`Sources/DiagramKit/DiagramEngine.swift:120-146`** — `renderSVG` and `renderASCII` are wrapped in `#if canImport(CoreGraphics)`, silently removing the Linux SVG/ASCII entry points that ARCHITECTURE.md advertises.

### Renderer color/flip discipline
- **`Sources/DiagramKitRenderingCG/ShapeRenderer.swift:78,85`** — `if fillColor != .clear` / `if strokeColor != .clear` violates CLAUDE.md's "use `bmColorEquals()` for color comparisons." AppKit `.==` is color-space sensitive; on AppKit a `BMColor(hex:)`-derived `.clear` may not compare equal to the class property, producing snapshot drift.
- **`Sources/DiagramKitRenderingCG/LabelRenderer.swift:120-128`** — when an outer view installs an `NSGraphicsContext` (as `DiagramNativeView.draw(_:)` does), `needsContext` is false and the manual CTM unflip can compound with `NSAttributedString.draw(in:)`'s own flip handling. Bitmap path vs `DiagramNativeView` AppKit path may emit non-identical baselines.

### Playground destroys its own undo history
- **`Sources/DiagramPlayground/Models/LiveEditorStore.swift:313, 338-365`** — `didCompleteRender(...)` calls `seedEditorFromSource()` on every successful render; every mutation triggers a render via `setSource(..., origin: .system)` at `LiveEditorStore.swift:749`; the seed replaces `editor` with a fresh `DiagramEditor` whose `UndoManager` is new. One mutation wipes the undo stack — defeating commit `1bfeb0c` (Cmd-Z routing) and silently losing work.
- **`Sources/DiagramPlayground/DiagramPlaygroundApp.swift:38-45`** — the `.undoRedo` command group is replaced with `store.undoStructural()` whenever `editor?.undoManager.canUndo == true`. The macOS Edit > Undo menu then intercepts Cmd-Z while the user is typing in `NativeCodeEditor` (which has its own `allowsUndo = true`), undoing graph mutations instead of recent typing.
- **`LiveEditorStore.swift:323-335`** — `seedEditorFromSource()` spawns an unstructured `Task` per render with no cancellation/generation token; an older parse can land after a newer one and replace `editor` with a stale document.
- **`Sources/DiagramPlayground/Views/Editor/LiveEditorToolbar.swift:181-187`** + **`LiveEditorView.swift:20, 68-75`** — Cmd-I on iOS toggles `state.inspectorOpen`, but the compact layout gates the Inspector on a local `@SwiftUI.State private var compactMode`. `inspectorOpen` is unread; the iPhone shortcut and toolbar toggle are silent no-ops.

### Test gates that can't actually pass
- **`Tests/DiagramKitTests/CorpusSnapshotTests.swift:85-89`** — `asciiSnapshot` records-on-first-run with no committed baselines for 248 of 422 entries; only 6 families (class/xychart/flow/er/seq/state) have ASCII baselines on disk. Reviewer ran it: 248 issues, all auto-recorded. ASCII regressions in 22 renderers are currently invisible.
- **`Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift:30-48`** — three `@Test` cases (`d2ProbeSignature`, `plantumlProbeSignature`, `structurizrProbeSignature`) construct a literal then `#expect` the same literal contains its own substring. Fixture-comparing-fixture; tautologically green.
- **`Scripts/bootstrap-smoke-check.sh:57`** — `run_gate "swift test" swift test` runs the full suite, which is documented (and remembered) to hang on signal-10. The merge gate can never green-light as written.

---

## Important (Should Fix)

### Architecture & API
- **`ReExports.swift:6-13`** does not re-export `DiagramKitInteractive`, but Package.swift adds it as an Apple-platform umbrella dep and CLAUDE.md claims it's re-exported. `import DiagramKit` won't see `DiagramEditor`.
- **`Sources/DiagramKitModel/src_theme.swift:4`, `src_styles.swift:4`, `src_text_metrics.swift:4`, `src_multiline_utils.swift:4`** are `open class`. JS-port shims with no public-subclassing contract should be `internal` or `public final`.
- **`DiagramFormatID`** lives only on the exporter side (`DiagramKitExport/DiagramFormatID.swift`); importers identify by `name: String` (`DiagramSourceImporter.swift:14`). Asymmetric and a long-term dispatch hazard.
- **`DiagramImportResult.swift:5`** uses `@_exported import DiagramKitCommon` to re-export `DiagramDiagnostic`. Couples consumers transitively to all of `DiagramKitCommon` — preferable to re-export the specific symbol or document the choice in a banner.
- **Deprecated `MermaidParser`/`MermaidRenderer`/`MermaidPipeline`/`MermaidImageRenderer`/`MermaidStructuralError` typealiases** are scattered across the umbrella. Consolidate in a single `Deprecations.swift` so the next major can sunset them atomically.
- **`MermaidImporter.swift:23-34`** — `supports()` returns true on any non-empty source. Protocol can't express "fallback"; consider adding `isFallback: Bool` so the registry can validate exactly-one-fallback-and-it's-last.

### Model: numeric & concurrency edges
- **`src_block_parser.swift:546-547`** accepts `Int(parts[1])` ≤ 0 as `span`/`widthInColumns`. At `src_block_layout.swift:117` that becomes `size.width / Double(child.widthInColumns ?? 1)` → NaN on `id:0`.
- **`src_class_parser.swift:19`** stores `direction: String`; every other family uses a typed enum (`ErDirection`, `GitGraphOrientation`, etc.). Breaks payload-modeling consistency.
- **`src_radar_layout.swift:19-20`** — if `options.max == nil` and `curves.flatMap(\.entries).isEmpty`, `maxValue = -.infinity`; combined with unguarded `options.min`, downstream `relativeRadius(...)` may yield NaN reaching `cos/sin`.
- **`src_gantt_parser.swift:410-423`** — `_dateFormatterCache` is `nonisolated(unsafe)` and `DateFormatter.date(from:)` is not documented as thread-safe. Two pipeline calls sharing the same cache key under concurrent workers → technically undefined.
- **`SourcePreprocessing.swift:69-89`** — every `---`-bounded section between the first and last marker is treated as frontmatter; a source like `---\nA\n---\nbody1\n---\nbody2` swallows `body1`.
- **`src_parser.swift:438-440`** — anonymous-subgraph id `"subgraph_\(graph.subgraphIds.count)"` has no collision guard against user-defined ids.

### Rendering & views
- **`EdgeRenderer.swift:119`** — `.arrow` case hardcodes `context.setLineWidth(0.75)`, ignoring the configured `lineWidth` at line 72. SVG won't carry this hardcode → visual drift.
- **`DiagramLayer.swift:182-189`** — on parse failure, `preparedDiagram` is not cleared; views keep displaying the previous successful render with `parseError` surfaced separately. Bindings consumers can't observe the failure as a state change.
- **`Sources/DiagramKitInteractive/DiagramEditor+Undo.swift:29-51`** — undo snapshot does not capture `selection`. After `.deleteElement(...)`, undo restores doc/source/diagnostics but selection dangles → next mutation throws `elementNotFound` mid-flow.
- **`DiagramRenderer.swift:147-161`** — 4000pt multiline bounding box is a band-aid over missing measurement; structurally repeats the prior 1000pt → larger-number cycle.
- **`DiagramLayer.swift:91`** — `UIScreen.main.scale` is deprecated on iOS 13+ multi-scene; wrong backing scale on a secondary scene (iPad / Catalyst).

### Format slices: round-trip & error/diagnostic discipline
- **Identifier-sanitization severity inconsistent**: `MermaidExportHelpers.sanitizeIdentifier` (`MermaidExportHelpers.swift:90-95`) uses `.info`; Structurizr's `uniqueSanitizedAlias` (`StructurizrExporter.swift:204-209`) uses `.warning`. Same lossy operation should pick one.
- **C4 slot semantics disagree**: `MermaidC4Export.swift:42-54` emits third positional arg as `desc` if present else `tech`. `PlantUMLC4Export.swift:47-56` orders args `[alias, label, tech?, desc?]`; `PlantUMLC4Parser.swift:49-50` reads `args[2]=technology, args[3]=description`. Cross-format round-trip silently swaps technology↔description.
- **`PlantUMLImporter.swift:30-32, 110`** throws `.notYetImplemented` for both malformed-source and unrecognized-family — conflates two different states.
- **`PlantUMLSequenceParser.swift:409-411`** marks `title` unsupported, but `MermaidSequenceExport` and `PlantUMLSequenceExporter` both emit it. Round-trip silently drops titles.
- **`PlantUMLFamilyProbe.swift:58-61`** — class probe `trimmed.contains("--") && !trimmed.contains("-->")` false-matches any text with `--`.
- **`MermaidExportHelpers.sanitizeIdentifier` lines 70-83** silently drops non-`[A-Za-z0-9_-]` chars without checking post-sanitize collisions (`foo bar` and `foo!bar` both become `foo_bar`). Mirror Structurizr's `usedAliases` set.
- **`D2Parser.swift:43-49`** strips only `#` as inline-comment marker; `// note` trailing values is left in the value.
- **`DOTLexer`** does not enter HTML-label mode for `label=<<TABLE>…</TABLE>>`; parser drops the rest of the attribute list. `DOTMapper._isHTMLLabel` (`DOTMapper.swift:382-391`) is dead because the lexer never produces such values.
- **`StructurizrExporter.swift:84-91`** drops boundary metadata as `.unsupported`, but its companion `StructurizrMapper.swift:169-181` rebuilds boundaries from parent relationships. Export → import loses boundaries without compensating import-side diagnostic.
- **`D2Mapper.swift:74-101`** — duplicate-node-ID path (line 41-46) silently drops direction/icon/tooltip/link from second occurrences.

### Playground state machine
- **`UndoManager.canUndo`/`canRedo`** are plain Foundation, not Observation-tracked. `.disabled(!editor.undoManager.canUndo)` modifiers in `DiagramEditorPane.swift:484, 491` + `DiagramPlaygroundApp.swift:41, 44` only re-evaluate when other observed properties change → footer state drifts.
- **`DiagramEditor.preferredExportFormat`** is `let` (`DiagramEditor.swift:46`). Between `setSourceFormat(_:)` and the next `applySeededEditor`, a `performMutation` exports through the old format then overwrites source under the new format.
- **`previewState` is captured pre-render** (`LiveEditorStore.swift:716-721`) then auto-saved post-render (`LiveEditorStore.swift:315`); on parse failure followed by a different request, the auto-saved state may not match what's on screen.
- **`DiagramEditor` is `@MainActor` and `_export` runs synchronously** (`DiagramEditor+Mutations.swift:30-34, 91-96`). `DiagramExportLoader.export(...)` is inline → blocks main on large flowcharts.
- **`NativeCodeEditor.Coordinator.textDidChange`** (`NativeCodeEditor.swift:174-190`) cancels prior debounce but `MainActor.run` retains `self`; keystrokes during slow renders pile coroutines.
- **`LiveEditorStore.performMutation` writes `lastMutationError`** while `InsertNodeSection.insert` and `InsertEdgeSection.insert` (`DiagramEditorPane.swift:317-329, 427-448`) also keep `localError`; the pane renders both → duplicate error UI on a single failure.
- **`SidebarView.loadDiagram` ignores `expectedDiagnostics` and `unsupportedNote`** (`SampleDiagramPanel.swift:230-234`); known-unsupported corpus picks surface as generic parse errors.
- **`requestRender(reason:)`** (`LiveEditorStore.swift:283-287`) flips status but leaves `parseError` set; error overlay sits atop a fresh render until next completion.

### Tests, gates, concurrency
- **`GanttAsciiRendererTests.swift:9-10`** sets+defers `DIAGRAMKIT_GANTT_TODAY`; **`CorpusSnapshotTests.swift:46`** only sets it. Under parallel `swift-testing`, the Gantt unset races corpus loads.
- **`Scripts/strict-concurrency-check.sh:24`** runs `swift build … || true` and greps the log. A non-first-party build failure prints "✓ first-party clean" — capture exit code or detect "Build complete!" before declaring green.
- **`CLAUDE.md` claims 188 test files; actual is 216.** Coverage docs drift.
- **No targeted test for the parser dispatch-order invariant** (CLAUDE.md "stateDiagram-v2 must not fall into state branch"). Cheap regression insurance.
- **`DiagramKitTestSupport.swift`** is a 9-line placeholder; corpus loader actually lives in `CorpusEntry.swift`. Documented surface vs reality.

---

## Minor (Polish)

- **Files over the 500-line warn threshold** (allowlisted where applicable, but candidates for split):
  - Library: `src_ascii_index.swift:492`, `DiagramRenderer+Sequence.swift:609`, `ShapeRenderer.swift:533`, `DiagramRenderer+Wardley.swift:514`, `src_sequence_renderer.swift:555`, `src_er_renderer.swift:549`, `src_class_renderer.swift:515`, `src_xychart_renderer.swift:599`.
  - Playground: `LiveEditorStore.swift:873`, `SampleDiagrams.swift:685`, `PreviewCanvas.swift:617`, `ActionsView.swift:595`, `DiagramEditorPane.swift:502`, `NativeCodeEditor.swift:503`.
  - Tests: nine files >500, all in pre-existing allowlist.
- **Dead code**: `Sources/DiagramKitRenderingCG/ArrowRenderer.swift` (no callers), `Sources/DiagramKitRenderingCG/Version.swift` (empty), `DiagramFontResolver` deprecated shims with no in-tree callers, `_DiagramFontPlatform` placeholders.
- **`EdgeRenderer`/`LabelRenderer`** declared `public class` (non-final) — mark `final`.
- **`DiagramEditor+Mutations.swift`** — near-identical `.flowchart` / `.stateDiagram` blocks in `_deleteElement` and `_setLabel` (~80 dup lines, `:81-117, 134-186`).
- **`LiveEditorStore.didCompleteRender:306`** has a dead `_ = parseError`.
- **`DiagramEditorPane.swift:6`** header comment still references the removed legacy `InspectorView`.
- **`LiveEditorToolbar.swift:96-105` and `:179-187`** duplicate Cmd-I markup; one helper would keep icon/state in sync.
- Accessibility labels missing across `DiagramEditorPane` insert/delete/undo controls — for a demo app, this is a missed showcase.
- **`MermaidFlowchartExport.shapeMarker`** (lines 156-226) maps ~25 distinct shapes to plain `[]` — silent shape loss; a `.warning` diagnostic would mirror DOTMapper's discipline.
- **`AsciiVisualReportGenerator.swift` / `VisualReportGenerator.swift` / `ExampleImageExporter.swift`** are env-gated but still discovered by `swift test`; renaming them off the `*Tests` suffix would clean the default listing.
- **`src_parser.swift:1202-1211`** — `case "BR": return .BT` with misleading comment "Bottom-Right = Bottom-to-Top".
- **`DiagramColorParser.swift:95-117`** — `_parseRGBFunction` does not clamp r/g/b/a; percentage notation silently ignored.
- **`DOTFlowchartExport.swift:13` vs `D2Exporter.swift:47`** — cosmetic trailing-newline difference.

---

## Cross-cutting Observations

1. **Exporter testing is weaker than parser/renderer testing.** The Mermaid/PlantUML exporter bugs above would be caught by any round-trip suite (`parse → export → parse → assert structural equality`). None of these bugs depend on visual fidelity; they would fail purely structural assertions.
2. **`.unsupported` vs throw vs `.warning` vs `.info` is inconsistent across slices.** PlantUML throws for unrecognized family; Structurizr returns `.warning` diagnostics for identifier rewrites; Mermaid returns `.info` for the same operation; D2 silently drops second-occurrence properties. A single discipline doc + linter would help.
3. **The umbrella exposes two paths for the same operation** (`renderDiagramSVG` free function in `src_index.swift:70` and `DiagramEngine.renderSVG`). Pick one canonical entry.
4. **CLAUDE.md drift** is small but real: 188 vs 216 test files; "Interactive re-exported" claim vs actual `ReExports.swift`. Worth a sync.
5. **Linux support is partial-by-design** but the umbrella's `#if canImport(CoreGraphics)` around SVG/ASCII undermines the "DiagramKit on Linux exists" story.

---

## Assessment

**Original verdict (pre-fix):** Not ready to merge — the exporter correctness bugs silently corrupt valid input on common cases, the playground undo regression makes the recent Cmd-Z work non-functional in practice, and the ASCII snapshot baseline gap leaves renderer drift in 22 families invisible to CI.

**Updated verdict (post-fix, commits `7143128` → `f7990d5`):** The five-phase fix plan landed end-to-end. The originally critical exporter, playground-undo, and ASCII-gate failures are addressed; the renderer color/flip discipline issues are addressed; and a bonus D2-probe header fix unblocks Mermaid sources the importer had been wrongly claiming.

Remaining work is captured in the **Deferred Effort — Recommendations** section above. The highest-priority deferred item is the SVG color-mix paren-balancing bug in `_resolveSvgCssVariables` — fixing it correctly requires re-recording all 422 SVG + image baselines, so it deserves its own phase rather than a tail-on to Phase 5. None of the deferred items block merge of the five commits to date.

**Suggested fix order (executed):** 1) ASCII baselines + bootstrap-smoke-check filtering (so subsequent fixes have a real gate) — **shipped in `7143128`**, 2) playground undo (`didCompleteRender` re-seed loop + Cmd-Z text-edit conflict) — **shipped in `138e367`**, 3) exporter correctness batch (Mermaid flowchart shape, subgraph walker, PlantUML state pseudostate, sequence escape, class comments) — **shipped in `a13b67c`**, 4) parser dispatch tokenization across `DiagramRegistry+*.swift` — **shipped in `633bec4`**, 5) renderer color/flip cleanups — **shipped in `f7990d5`**.
