# DiagramKit Code Review — Complete

Six parallel reviewers covered architecture/public-API, model (parsers + layouts), rendering + views, format slices, playground + interactive editor, and tests/gates/concurrency. Findings are aggregated and ranked below; every item is file:line-grounded.

## Executive Summary

The library's structural discipline is real and load-bearing: the no-thread-pool 8 MB worker rule, font-registry bootstrap, payload typing, target layering, and `@unchecked Sendable` governance all hold up. The two biggest problem areas are **exporter correctness** (silent data corruption in Mermaid flowchart + PlantUML state/sequence/class exporters) and **playground undo plumbing** (the recent Cmd-Z work is being silently undone by an unrelated re-seed loop). A long-standing testing gap — 248 missing ASCII snapshot baselines combined with auto-record-on-first-run — means renderer drift in 22 ASCII families is currently invisible to CI.

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

**Ready to merge to main as-is?** No — the exporter correctness bugs (Mermaid flowchart shapes, sub-graph drops, PlantUML state pseudostate rewrite, sequence/class escape gaps) silently corrupt valid input on common cases and should be fixed before relying on the multi-format export matrix. The playground undo regression makes the recent Cmd-Z work non-functional in practice and is a clean fix at `LiveEditorStore.didCompleteRender`. The ASCII snapshot baseline gap is the single most consequential testing issue — recording the missing 248 baselines (and gating ASCII to honour `shouldSkipSnapshot` like the multi-format paths do) closes a real blind spot.

**Suggested fix order**: 1) ASCII baselines + bootstrap-smoke-check filtering (so subsequent fixes have a real gate), 2) playground undo (`didCompleteRender` re-seed loop + Cmd-Z text-edit conflict), 3) exporter correctness batch (Mermaid flowchart shape, subgraph walker, PlantUML state pseudostate, sequence escape, class comments), 4) parser dispatch tokenization across `DiagramRegistry+*.swift`, 5) renderer color/flip cleanups.
