# Deprecated Surface Sunset — Phase 0 / Session 7 / Session 8

**Date:** 2026-05-14
**Status:** Spec
**Scope:** `Sources/DiagramKit/` umbrella + 35 test files
**Related:** REVIEW.md Cross-cutting Observation #3; Session 7 `381fd81`; Session 4 `1c2f18f`

## Goal

Delete every `@available(*, deprecated, renamed:)` shim in the `DiagramKit`
umbrella that exists for Phase 0 (Mermaid→Diagram rename) or Session 7
(free-function deprecation). Migrate every in-tree caller to the canonical
API in the same logical change.

End state: zero "Will be removed in the next major version" deprecation
warnings emitted from in-tree builds; the Mermaid-prefixed public alias
cohort retires atomically as planned in Phase 0.

## Inventory of symbols deleted

### A. Public free functions — `Sources/DiagramKit/src_index.swift`

- `public func renderDiagramSVG(_:_:)` (async)
- `public func renderDiagramSVGAsync(_:_:)` (async)
- `public func renderMermaidSVG(_:_:)` (async wrapper)
- `public func renderMermaidSVGAsync(_:_:)` (async wrapper)
- `public func renderMermaid(_:_:)` (async wrapper)
- Internal `func _renderDiagramSVG(_:_:layoutConfig:)` SPI
- Private `func buildColors(_:)` helper (only called by `_renderDiagramSVG`)

### B. Mermaid* typealiases — `Sources/DiagramKit/Deprecations.swift`

- `MermaidStructuralError` → `DiagramStructuralError`
- `MermaidRenderer` → `DiagramEngine`
- `MermaidPipeline` → `DiagramPipeline`
- `MermaidImageRenderer` → `DiagramImageRenderer`
- `MermaidParser` enum (with `.parse(_:)`)

The file is deleted entirely; no surviving content.

### C. `DiagramEngine` static `*Async` shims — `Sources/DiagramKit/DiagramEngine.swift`

Zero in-tree callers across `Sources/`, `Tests/`, `Examples/`. Clean delete:

- `renderImageAsync(source:theme:scale:)` (line 200)
- `renderSVGAsync(source:theme:)` (line 211)
- `renderASCIIAsync(source:theme:)` (line 218)
- `prepareAsync(source:theme:layoutConfig:)` (line 229)

### D. String instance Mermaid* method shims — `Sources/DiagramKit/DiagramEngine.swift`

- `String.parseMermaid()` (line 244) → `parseDiagram()`
- `String.renderMermaidImage(theme:scale:)` (line 259) → `renderDiagramImage(theme:scale:)`
- `String.renderMermaidSVG(theme:layoutConfig:)` (line 280) → `renderDiagramSVG(theme:layoutConfig:)`
- `String.renderMermaidASCII(theme:)` (line 294) → `renderDiagramASCII(theme:)`

### E. Orphaned options overload — `Sources/DiagramKit/DiagramPipeline.swift:210`

`public static func renderSVG(_:options:) throws -> String`. No callers
remain after Cohort A goes; canonical
`renderSVG(source:theme:layoutConfig:idPolicy:registry:)` at line 142
covers the surviving needs.

### F. Phase-0 internal alias — `Sources/DiagramKit/DiagramPreparerWiring.swift:60-63`

```swift
// MARK: - Phase 0 backward-compat deprecated alias

@available(*, deprecated, renamed: "_DiagramPreparerBootstrap", ...)
typealias _MermaidPreparerBootstrap = _DiagramPreparerBootstrap
```

Internal, zero callers.

### G. Legacy test file — `Tests/DiagramKitTests/MermaidLegacyAPITests.swift`

Sole purpose is exercising the deprecation surface. The canonical API
has dedicated test coverage already; deleting this file does not
reduce real coverage.

## Migration map for in-tree callers

| Old | New |
|---|---|
| `try await renderDiagramSVG(s)` | `try await DiagramEngine.renderSVG(source: s)` |
| `try await renderDiagramSVG(s, RenderOptions())` | `try await DiagramEngine.renderSVG(source: s)` |
| `try await renderDiagramSVG(s, RenderOptions(idPolicy: .stable))` | `try await DiagramEngine.renderSVG(source: s, idPolicy: .stable)` |
| `try _renderDiagramSVG(s)` | `try DiagramPipeline.renderSVG(source: s)` |
| `try _renderDiagramSVG(s, RenderOptions(idPolicy: .stable))` | `try DiagramPipeline.renderSVG(source: s, idPolicy: .stable)` |
| `try await s.renderMermaidImage(...)` | `try await s.renderDiagramImage(...)` |
| `try await s.renderMermaidSVG(...)` | `try await s.renderDiagramSVG(...)` |
| `try await s.renderMermaidASCII(...)` | `try await s.renderDiagramASCII(...)` |
| `try await s.parseMermaid()` | `try await s.parseDiagram()` |
| `MermaidParser.parse(s)` | `try MermaidImporter().parse(s).document` |

`MermaidRenderer` / `MermaidPipeline` / `MermaidImageRenderer` /
`MermaidStructuralError`: grep across `Sources/`, `Tests/`, `Examples/`
shows callsites only inside `MermaidLegacyAPITests.swift` (deleted in
Phase 5) and inside the deprecated definitions themselves.

## Affected callsite inventory

- **Async free-function family (`renderDiagramSVG` et al.):** 28 test
  files, ~135 callsites.
- **Sync internal SPI (`_renderDiagramSVG`):** 6 test files
  (`ArchitectureRendererTests`, `WardleyMapEndToEndTests`,
  `QuadrantSvgTests`, `TimelineRendererTests`, `TimelineSvgTests`,
  `ZenUMLSvgTests`, `BlockSvgTests`), 12 callsites.
- **String instance Mermaid* methods:** 10 callsites across Sources/Tests/Examples.
- **`MermaidParser.parse`:** 1 callsite in `MermaidLegacyAPITests.swift`
  (deleted) plus 1 comment in `Sources/DiagramKit/MermaidImporter.swift:39`.
- **Source-side `_renderDiagramSVG`:** 2 callsites
  (`Sources/DiagramKit/DiagramPipeline.swift:215` inside the deprecated
  options overload that is itself being deleted, and
  `Sources/DiagramKit/DiagramImageRenderer.swift:116`).
- **Source-side `DiagramPipeline.renderSVG(_:options:)`:** 2 callsites,
  both inside `src_index.swift` deprecated free functions (also deleted).

Net: every callsite is either migrated (Phases 1–4) or deleted (Phase 5).

## Phases (commit-by-commit on `main`, per standing default)

### Phase 1 — Async test sweep

28 test files migrate from `renderDiagramSVG` / `renderDiagramSVGAsync` /
`renderMermaidSVG` / `renderMermaidSVGAsync` / `renderMermaid` to
`DiagramEngine.renderSVG(source:)`. `RenderOptions()` arguments drop;
`RenderOptions(idPolicy: .stable)` becomes a direct `idPolicy: .stable`
argument.

Per-suite verification: `swift test --filter <SuiteName>` after each
batch of files.

Files (alphabetical for review-ability):
`ArchitectureRendererTests`, `BeautifulMermaidSwiftTests`,
`BlockSvgTests`, `ERParserTests+Foundation`, `ERRendererTests`,
`EventModelingTests`, `FlowchartELKFallbackTests`,
`FlowchartSecurityTests`, `FlowchartVisualDiffTests`,
`IconImageRendererTests`, `IshikawaRendererTests`, `KanbanRendererTests`,
`MindmapRendererTests`, `QuadrantSvgTests`, `RadarEndToEndTests`,
`RequirementRendererTests`, `SemicolonSeparatorTests`,
`TimelineRendererTests`, `TimelineSvgTests`, `TreeViewPipelineTests`,
`TreeViewSvgTests`, `TreemapEndToEndTests`, `VennEndToEndTests`,
`VerificationStepExporterTests`, `WardleyMapEndToEndTests`,
`XYChartCrashRegressionTests`, `XYChartSvgTests`, `ZenUMLSvgTests`.

Note that some of these (`ArchitectureRendererTests`,
`WardleyMapEndToEndTests`, `QuadrantSvgTests`, etc.) also have sync
`_renderDiagramSVG` callsites — those migrate in Phase 2.

### Phase 2 — Sync test sweep

Six test files migrate from `_renderDiagramSVG` to
`DiagramPipeline.renderSVG(source:)`. Same sync semantics; the
`RenderOptions` argument either drops (no options) or becomes
`idPolicy: .stable` (the only customization seen).

Files: `ArchitectureRendererTests`, `WardleyMapEndToEndTests`,
`QuadrantSvgTests`, `TimelineRendererTests`, `TimelineSvgTests`,
`ZenUMLSvgTests`, `BlockSvgTests`.

### Phase 3 — String instance method sweep

10 callsites migrate from `.renderMermaid*` / `.parseMermaid` to
`.renderDiagram*` / `.parseDiagram`. Grep across `Tests/` for
`\.renderMermaid\|\.parseMermaid\b` to enumerate.

### Phase 4 — Source-side migration

- **`Sources/DiagramKit/DiagramImageRenderer.swift:116`** —
  `try _renderDiagramSVG(source, options, layoutConfig: layoutConfig)`
  migrates to
  `try DiagramPipeline.renderSVG(source: source, layoutConfig: layoutConfig, idPolicy: options.idPolicy)`.
  Verify against pre-flight color-customization check
  (see Risk #1) — confirmed that the surrounding code consumes only
  `idPolicy` from `options`, not bg/fg/font/transparent.
- **`Sources/DiagramKit/MermaidImporter.swift:39`** — drive-by removal
  of the stale comment `// Replicate existing MermaidParser.parse() logic.`

### Phase 5 — Delete `MermaidLegacyAPITests.swift`

Sole purpose was exercising deprecated surface that no longer exists.
Confirm `swift test --filter MermaidLegacyAPI` returns zero matches
after deletion.

### Phase 6 — Atomic deletion commit

Cohorts A through F in one commit:

- `Sources/DiagramKit/src_index.swift` — delete public free functions,
  `_renderDiagramSVG`, `buildColors`. If only the `original_src_index`
  empty placeholder class survives, delete the whole file.
- `Sources/DiagramKit/Deprecations.swift` — delete file entirely.
- `Sources/DiagramKit/DiagramEngine.swift` — delete 4 `*Async` static
  shims (lines ~198–238) and 4 String-instance Mermaid* methods
  (lines ~244, 259, 280, 294).
- `Sources/DiagramKit/DiagramPipeline.swift:210` — delete the
  `renderSVG(_:options:)` overload.
- `Sources/DiagramKit/DiagramPreparerWiring.swift:60-63` — delete the
  "Phase 0 backward-compat deprecated alias" section.

### Phase 7 — Docs sync

- `CLAUDE.md` "Public Surface" — drop the sentence "Mermaid-prefixed
  public aliases carry `@available(*, deprecated, renamed:message:)`
  annotations and will be removed in the next major version. Internal/SPI
  aliases were removed in Phase 10."
- `CLAUDE.md` "Testing And Snapshots" — sync test source count 245 → 244.
- Scan `ARCHITECTURE.md` for any references to `MermaidParser`,
  `MermaidRenderer`, etc.; update or remove.
- Update `REVIEW.md` Resolution Status with a Session 12 row.

## Risks / open hazards

### Risk 1 — `DiagramImageRenderer.swift:116` color routing

The old call site passed `options: RenderOptions` through
`_renderDiagramSVG`, which built `DiagramColors` from `options.bg`,
`options.fg`, etc. The new
`DiagramPipeline.renderSVG(source:theme:layoutConfig:idPolicy:)`
derives `DiagramColors` from `DiagramTheme.effective*()`.

**Pre-flight check (must run before Phase 4):** read the
`DiagramImageRenderer` `options` construction. If it only carries
`idPolicy`, the migration is safe with `theme: .default`. If it threads
custom colors, the migration must construct a matching `DiagramTheme`
or change scope.

### Risk 2 — `.stable` ID-policy preservation

A handful of test sites pass `RenderOptions(idPolicy: .stable)`. The
engine and pipeline APIs already take `idPolicy:` as a first-class
parameter, so the wire is the same. Session 4's rebaseline exercised
this exact path. Sanity-check only.

### Risk 3 — Snapshot baseline drift

None expected.
`DiagramPipeline.renderSVG(source:theme:layoutConfig:idPolicy:)` is the
path Session 4's rebaseline already went through. Post-migration
snapshot canary on `block-1-simple` and one C4 entry (cheap insurance,
not a planned rebaseline).

### Risk 4 — Test-source-count drift

`MermaidLegacyAPITests.swift` deletion is -1.
`CLAUDE.md` "Current test source count: 245 Swift files" → 244.

### Risk 5 — Argument-label hygiene

`DiagramEngine.renderSVG(source:)` is keyword-labeled; free-function
`renderDiagramSVG(_:_:)` was positional. Callsites like
`renderDiagramSVG(source, RenderOptions())` need `source: source` (or
the same identifier name) plus the option drop. Multi-line `"""…"""`
literals make naïve `sed` brittle — review each Phase 1 file's diff,
don't blind-apply.

## Non-goals

- **`RenderOptions` itself.** Load-bearing in `DiagramKitModel`'s
  per-family layout APIs (`layoutXYChart`, `layoutSequenceDiagram`,
  `layoutERDiagram`, `layoutClassDiagram`, `layoutRequirementDiagram`,
  etc.). Stays as an internal layout-config type.
- **`original_src_*` placeholder classes** scattered through Phase 0
  code split. Internal stubs, not deprecated. Leave alone.
- **Other deprecated surfaces.** Session 8's
  `DiagramExportLoader.export(_:using:)` deprecation is keyed on
  display-name vs `DiagramFormatID`, a separate trajectory.

## Acceptance criteria

- `grep -rn '@available.*deprecated.*Will be removed in the next major version' Sources/DiagramKit/`
  returns no hits.
- `grep -rn '\bMermaidParser\b\|\brenderMermaid\b\|\brenderDiagramSVG(' Sources/ Tests/ Examples/`
  returns no hits (modulo doc strings deliberately left in importer
  preambles explaining lineage).
- All touched-suite `swift test --filter <Suite>` runs green.
- `Scripts/check-sendable-annotations.sh`,
  `Scripts/check-file-sizes.sh`,
  `Scripts/strict-concurrency-check.sh` green with no new threshold
  crossings.
- Snapshot canary on `block-1-simple` and one C4 entry succeeds without
  rebaselining.
- `swift build` warning count for `@available deprecated` references
  inside `DiagramKit` builds at zero.
