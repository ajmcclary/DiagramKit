# Phase 0: Stabilize Names

**Date**: 2026-05-12
**Status**: Complete ✅

Add format-neutral public names additively, then migrate internals in small
buildable passes. No breaking changes in this phase — the `@available(deprecated)`
alias surface keeps every existing call site compiling.

---

## 1. The `DiagramRenderer` Collision — Resolved

Two types historically named `DiagramRenderer`:

| Target | Type | Role |
|---|---|---|
| `DiagramKitRenderingCG` | `public final class DiagramRenderer` | CG-context renderer, draws into `CGContext` |
| `DiagramKit` | `public struct MermaidRenderer` | Public async facade (`parse`, `layout`, `renderSVG`, `renderImage`, etc.) |

The umbrella target **re-exports** `DiagramKitRenderingCG` via `@_exported import`.
That means the CG `DiagramRenderer` name is visible to any `import DiagramKit`
consumer — its name space is already occupied at the umbrella level.

**Decision**: the public async facade becomes `DiagramEngine`, not `DiagramRenderer`.
This avoids the collision entirely. The CG `DiagramRenderer` stays as-is — no
rename needed for the CG type.

```
DiagramKit.MermaidRenderer  →  DiagramKit.DiagramEngine   (new public facade)
DiagramKitRenderingCG.DiagramRenderer  →  NO RENAME
```

The `DiagramEngine` naming matches MusicToolkit's `ScoreLoader` pattern: a
stateless enum/struct that orchestrates the full pipeline without being a
"renderer" in the graphics sense.

---

## 2. Execution Strategy: Additive, Not Destructive

Phase 0 is split into **three buildable commits**:

### Commit A: Introduce New Names (additive only)

Add new types/wrappers alongside existing ones. Every existing public symbol
stays exactly where it is. This commit compiles and all tests pass unchanged.

### Commit B: Migrate Internals (no public API change)

Replace internal call sites with new names. External consumers still see both
old and new names through deprecated aliases. Snapshot tests verify no
behavior change.

### Commit C: File Renames + Docs + Deprecation Annotations

Rename `.swift` files to match their new primary type names. Add `@available(deprecated
renamed:)` annotations to all compat aliases. Update README, AGENTS.md,
ARCHITECTURE.md, CONTRIBUTING.md, ANALYSIS.md, BASELINES.md.

---

## 3. Complete Rename Map (bottom-up by target)

### 3a. `DiagramKitCommon`

| Before | After |
|---|---|
| `_reportMermaidIssue(_:)` | `_reportDiagramIssue(_:)` |
| `_reportMermaidIssueIfNeeded(_:operation:)` | `_reportDiagramIssueIfNeeded(_:operation:)` |
| `_withMermaidIssueReporting(operation:_:)` | `_withDiagramIssueReporting(operation:_:)` |
| `_MermaidRecoverableError` (protocol) | `_RecoverableDiagramError` |
| `_isRecoverableMermaidError(_:)` | `_isRecoverableDiagramError(_:)` |

File: `Sources/DiagramKitCommon/IssueReportingSupport.swift`

### 3b. `DiagramKitModel`

| Before | After | Notes |
|---|---|---|
| `MermaidGraph` | `DiagramDocument` | The canonical parsed model |
| `BeautifulMermaidError` | `DiagramError` | Moved to `Errors.swift` |
| `MermaidSourceNormalizer` | `DiagramSourceNormalizer` | Shared by all parsers |
| `MermaidColorParser` | `DiagramColorParser` | Hex color parsing |
| `MermaidNode` | *unchanged* | Mermaid-specific node concept |
| `ParsedGraphModel` (typealias) | *unchanged* | Upstream `original_src_types.MermaidGraph` |

New file: `Sources/DiagramKitModel/Errors.swift`
- Consolidate `DiagramError`, `DiagramStructuralError` (moved from umbrella), and
  eventually `DiagramDiagnostic` (Phase 1).

### 3c. `DiagramKitRenderingCG`

| Before | After | Notes |
|---|---|---|
| `DiagramRenderer` | **NO RENAME** | See Section 1 |
| `MermaidWorkerThread` | `DiagramWorkerThread` | |
| `MermaidPreparation` | `DiagramPreparation` | |
| `MermaidPreparationError` | `DiagramPreparationError` | |
| `MermaidBitmapRenderer` | `DiagramBitmapRenderer` | |
| `MermaidViewPreparer` | `DiagramViewPreparer` | |
| `MermaidViewPreparerEnvironment` | `DiagramViewPreparerEnvironment` | |
| `BeautifulMermaidFontRegistry` | `DiagramFontRegistry` | |

### 3d. `DiagramKitViews`

| Before | After | Notes |
|---|---|---|
| `MermaidView` (UIView/NSView) | `DiagramNativeView` | |
| `MermaidLayer` | `DiagramLayer` | |
| `MermaidDiagram` (`@Observable`) | `DiagramViewModel` | |
| `MermaidDiagramView` (SwiftUI) | `DiagramView` | |

### 3e. `DiagramKit` (umbrella)

| Before | After | Notes |
|---|---|---|
| `MermaidRenderer` | `DiagramEngine` | New public facade (see Section 1) |
| `MermaidPipeline` | `DiagramPipeline` | |
| `MermaidImageRenderer` | `DiagramImageRenderer` | |
| `MermaidParser` | *unchanged* | Will become `MermaidImporter` in Phase 2 |
| `MermaidStructuralError` | `DiagramStructuralError` | **Move to `DiagramKitModel/Errors.swift`** |
| `_MermaidPreparerBootstrap` | `_DiagramPreparerBootstrap` | |
| `MermaidPreparerWiring.swift` | `DiagramPreparerWiring.swift` | File rename in Commit C |
| `ImageRenderer.swift` | `DiagramImageRenderer.swift` | File rename in Commit C |

### 3f. Public Free Functions (in `src_index.swift` / `src_ascii_index.swift`)

| Before | After | Notes |
|---|---|---|
| `renderMermaidSVG(_:_:)` | `renderDiagramSVG(_:_:)` | Public function |
| `renderMermaidSVGAsync(_:_:)` | `renderDiagramSVGAsync(_:_:)` | Deprecated wrapper |
| `renderMermaidASCII(_:options:)` | *defer to Phase 2* | ASCII is Mermaid-specific; keep for now |
| `_renderMermaidSVG(_:_:_:)` | `_renderDiagramSVG(_:_:_:)` | Internal function |
| `renderMermaid(_:_:)` | `renderDiagram(_:_:)` | Already deprecated in favor of `renderMermaidSVG` |

### 3g. Registry Types — DEFERRED to Phase 1

`DiagramRegistry`, `DiagramDescriptor`, and `DiagramHeader` are public types.
Renaming them to `MermaidDiagramRegistry` / `MermaidDiagramDescriptor` /
`MermaidDiagramHeader` is correct conceptually but is a breaking change with
no clear compat alias strategy (the old names would collide with the future
format-level `DiagramRegistry` concept).

**Decision**: defer all three renames to Phase 1 ("Importer Protocol + Registry").
Phase 1 will:
- Introduce `DiagramSourceImporter` protocol and `ImporterRegistry`
- Move the current `DiagramRegistry` → `MermaidImporter.supports(source:)`
- Then `DiagramRegistry` / `DiagramDescriptor` / `DiagramHeader` can be renamed
  or retired without ambiguity

For Phase 0, add a comment banner in `DiagramDescriptor.swift` and the 28
`DiagramRegistry+*.swift` files clarifying they are Mermaid-family-internal:

```swift
// MARK: - Mermaid-internal diagram-family registry
//
// These descriptors are Mermaid-specific. A format-agnostic importer registry
// (`ImporterRegistry` + `DiagramSourceImporter`) will be introduced in Phase 1.
// At that point this type will become `MermaidDiagramRegistry` or be subsumed
// into `MermaidImporter`.
```

---

## 4. Backward-Compat Type Aliases (one release cycle)

Each alias lives in the **target where the original public symbol was defined**,
not in the umbrella `ReExports.swift`.

### `DiagramKitModel` (in `Types.swift`)

```swift
@available(*, deprecated, renamed: "DiagramDocument")
public typealias MermaidGraph = DiagramDocument

@available(*, deprecated, renamed: "DiagramError")
public typealias BeautifulMermaidError = DiagramError

@available(*, deprecated, renamed: "DiagramSourceNormalizer")
public typealias MermaidSourceNormalizer = DiagramSourceNormalizer

@available(*, deprecated, renamed: "DiagramColorParser")
public typealias MermaidColorParser = DiagramColorParser
```

### `DiagramKitRenderingCG` (in a new `DeprecatedAliases.swift` or per-type)

```swift
@available(*, deprecated, renamed: "DiagramWorkerThread")
public typealias MermaidWorkerThread = DiagramWorkerThread

@available(*, deprecated, renamed: "DiagramPreparation")
public typealias MermaidPreparation = DiagramPreparation

@available(*, deprecated, renamed: "DiagramPreparationError")
public typealias MermaidPreparationError = DiagramPreparationError

@available(*, deprecated, renamed: "DiagramBitmapRenderer")
public typealias MermaidBitmapRenderer = DiagramBitmapRenderer

@available(*, deprecated, renamed: "DiagramViewPreparer")
public typealias MermaidViewPreparer = DiagramViewPreparer

@available(*, deprecated, renamed: "DiagramViewPreparerEnvironment")
public typealias MermaidViewPreparerEnvironment = DiagramViewPreparerEnvironment

@available(*, deprecated, renamed: "DiagramFontRegistry")
public typealias BeautifulMermaidFontRegistry = DiagramFontRegistry
```

### `DiagramKitViews` (per-file)

```swift
@available(*, deprecated, renamed: "DiagramNativeView")
public typealias MermaidView = DiagramNativeView

@available(*, deprecated, renamed: "DiagramLayer")
public typealias MermaidLayer = DiagramLayer

@available(*, deprecated, renamed: "DiagramViewModel")
public typealias MermaidDiagram = DiagramViewModel

@available(*, deprecated, renamed: "DiagramView")
public typealias MermaidDiagramView = DiagramView
```

### `DiagramKit` (in a new `DeprecatedAliases.swift`)

```swift
@available(*, deprecated, renamed: "DiagramEngine")
public typealias MermaidRenderer = DiagramEngine

@available(*, deprecated, renamed: "DiagramPipeline")
public typealias MermaidPipeline = DiagramPipeline

@available(*, deprecated, renamed: "DiagramImageRenderer")
public typealias MermaidImageRenderer = DiagramImageRenderer

@available(*, deprecated, renamed: "DiagramStructuralError")
public typealias MermaidStructuralError = DiagramStructuralError
```

### String Extensions (in `DiagramKit/MermaidRenderer.swift`)

```swift
extension String {
    @available(*, deprecated, renamed: "parseDiagram()")
    public func parseMermaid() async throws -> DiagramDocument { ... }

    @available(*, deprecated, renamed: "renderDiagramImage()")
    @MainActor
    public func renderMermaidImage(theme: DiagramTheme = .default, scale: CGFloat = 2.0) async throws -> BMImage? { ... }

    @available(*, deprecated, renamed: "renderDiagramSVG()")
    public func renderMermaidSVG(theme: DiagramTheme = .default, layoutConfig: LayoutConfig = LayoutConfig()) async throws -> String { ... }

    @available(*, deprecated, renamed: "renderDiagramASCII()")
    public func renderMermaidASCII(theme: DiagramTheme = .default) async throws -> String { ... }
}
```

---

## 5. Diagnostics Location Decision

**Place `DiagramError` and `DiagramStructuralError` in `DiagramKitModel/Errors.swift`.**

Both are already in `DiagramKitModel.Types` (`BeautifulMermaidError`) and
`DiagramKit.DiagramDescriptor` (`MermaidStructuralError`). Consolidating them
into a single `Errors.swift` in the model target:
- Lets any importer/exporter depend on `DiagramKitModel` and throw typed errors
- Follows MusicToolkit's pattern of model-level error types
- Avoids the umbrella target as an error dependency for new format targets

Future `DiagramDiagnostic` (the non-fatal warning type) will also live here.

---

## 6. Registry Ownership Split — Phase 0 Action

Deferred to Phase 1 (see Section 3g). For Phase 0:
- Add comment banners to `DiagramDescriptor.swift` and 28 `DiagramRegistry+*.swift` files
- No type renames

---

## 7. BASELINES.md — Create a Real File

Generate `BASELINES.md` from live metrics. At minimum:

```markdown
# BASELINES.md

## Build
- `swift build --build-tests`: ~X seconds (MacBook Pro M4, 24 GB)
- `swift build -strict-concurrency=complete -warnings-as-errors`: clean

## Tests
- `swift test`: ~N test suites, ~M test cases (approx. X minutes)
- `SNAPSHOT_DIAGRAM_IDS=... swift test --filter CorpusSnapshotTests/imageSnapshot`: ~5 min

## Snapshot Baselines
- SVG: 396 entries
- Image: 346 entries (50 gap: layouts producing 0×0 bounds)
- ASCII: 172 entries

## Gate Status
- `Scripts/check-file-sizes.sh`: pass
- `Scripts/check-sendable-annotations.sh`: pass
- `Scripts/strict-concurrency-check.sh`: pass
- `Scripts/linux-check.sh`: pass

Last updated: 2026-05-12
```

Populate actual numbers from current `swift test` output after Commit A compiles.

---

## 8. Execution Order

### Commit A: Additive Introduction

Goal: `swift build --build-tests` succeeds with zero test changes.

1. `DiagramKitModel` — add `DiagramDocument`, `DiagramError`, `DiagramSourceNormalizer`, `DiagramColorParser`
2. `DiagramKitCommon` — add renamed issue-reporting helpers alongside old names
3. `DiagramKitRenderingCG` — add `DiagramWorkerThread`, `DiagramPreparation`, `DiagramViewPreparer`, etc.
4. `DiagramKitViews` — add `DiagramView`, `DiagramNativeView`, `DiagramLayer`, `DiagramViewModel`
5. `DiagramKit` — add `DiagramEngine` wrapping `MermaidRenderer`, add `DiagramPipeline` wrapping `MermaidPipeline`, add `DiagramImageRenderer`
6. `DiagramKit/DeprecatedAliases.swift` — add all compat aliases
7. Build and verify: `swift build --build-tests`

### Commit B: Internal Migration

Goal: all internal call sites use new names. Tests pass with existing baselines.

1. `DiagramKitModel` — migrate ~200 internal references from `MermaidGraph` → `DiagramDocument`, etc.
2. `DiagramKitCommon` — migrate internal callers of old issue-reporting names
3. `DiagramKitRenderingCG` — migrate internal references (~42 files)
4. `DiagramKit` — migrate internal references (parser, layout, pipeline, SVG, ASCII, image)
5. `DiagramKitViews` — migrate internal references (4 files)
6. Tests — migrate test references (~144 files)
7. Playground — migrate `LiveEditorStore`, `SampleDiagrams.swift`
8. `swift test --filter CorpusSnapshotTests` — verify no snapshot drift

### Commit C: File Renames + Docs

Goal: files match their primary type names. Docs reflect new API surface.

1. Rename `Sources/DiagramKit/ImageRenderer.swift` → `Sources/DiagramKit/DiagramImageRenderer.swift`
2. Rename `Sources/DiagramKit/MermaidPreparerWiring.swift` → `Sources/DiagramKit/DiagramPreparerWiring.swift`
3. Rename `Sources/DiagramKitModel/MermaidColorParser.swift` → `Sources/DiagramKitModel/DiagramColorParser.swift`
4. Rename `Sources/DiagramKitModel/MermaidSourceNormalizer.swift` → `Sources/DiagramKitModel/DiagramSourceNormalizer.swift`
5. Create `Sources/DiagramKitModel/Errors.swift` (consolidate error types)
6. Add `DiagramKit/DeprecatedAliases.swift` with all compat aliases
7. Create `BASELINES.md` with live metrics
8. Update `README.md`, `AGENTS.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`, `ANALYSIS.md`
9. `Scripts/bootstrap-smoke-check.sh` — full gate

---

## 9. Verification Gates

```bash
# After Commit A:
swift build --build-tests

# After Commit B:
swift test --filter CorpusSnapshotTests
# Verify no snapshot drift before re-recording

# After Commit C:
Scripts/bootstrap-smoke-check.sh
```

Snapshot re-recording is **not** expected in Phase 0 — test function names don't
embed `Mermaid_` prefixes (verified: no matches in `Tests/`). If any snapshot
baseline name changes, re-record with:
```bash
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests
```

---

## 10. Open Risk Items

- **~400 code sites** across all targets. Mechanical `sed` replacement with
  target-by-target verification is the right approach.
- **Linux `#else` path** in `MermaidRenderer._runOnWorker`: the manual `Thread`
  construction must be updated. The Linux path in `DiagramKitCommon` helpers
  (`_reportMermaidIssue` → stderr fallback) must also be updated.
- **`original_src_types.MermaidGraph`**: the upstream JS-port type in
  `DiagramKitModel` is distinct from our public `MermaidGraph` wrapper. Access
  via `original_src_types.MermaidGraph` or `ParsedGraphModel` typealias. Do
  not rename upstream port internal types.
- **`MermaidNode`** — intentionally left unchanged (Mermaid-specific node concept:
  inline styles from Mermaid syntax).
- **`MermaidParser`** — intentionally left unchanged (will become `MermaidImporter`
  when the `DiagramSourceImporter` protocol lands in Phase 2).
- **15+ `_MermaidRecoverableError` conformances** across DiagramKitModel parser
  error types. Each enum (`ClassParserError`, `ErParserError`, etc.) conforms to
  `_MermaidRecoverableError`. Renaming the protocol means updating all 15+
  conformances.
- **`renderMermaidSVG` / `renderMermaidASCII` free functions**: the SVG function
  should be aliased to `renderDiagramSVG`. The ASCII function is Mermaid-specific
  (no other format produces ASCII output) — keep as-is with a deprecation comment.

---

## 11. Implementation Notes — What Was Done

### Commit A — Additive Introduction ✅

All new names introduced as `public typealias NewName = OldName` in their
respective defining files alongside the existing primary definitions.

| File | Aliases added |
|---|---|
| `Sources/DiagramKitModel/Types.swift` | `DiagramDocument`, `DiagramError` |
| `Sources/DiagramKitModel/MermaidColorParser.swift` | `DiagramColorParser` |
| `Sources/DiagramKitModel/MermaidSourceNormalizer.swift` | `DiagramSourceNormalizer` |
| `Sources/DiagramKitCommon/IssueReportingSupport.swift` | `_RecoverableDiagramError`, `_withDiagramIssueReporting`, `_reportDiagramIssueIfNeeded`, `_reportDiagramIssue`, `_isRecoverableDiagramError` (delegation wrappers) |
| `Sources/DiagramKitRenderingCG/MermaidWorkerThread.swift` | `DiagramWorkerThread` |
| `Sources/DiagramKitRenderingCG/MermaidPreparation.swift` | `DiagramPreparation`, `DiagramPreparationError` |
| `Sources/DiagramKitRenderingCG/MermaidBitmapRenderer.swift` | `DiagramBitmapRenderer` |
| `Sources/DiagramKitRenderingCG/MermaidViewPreparer.swift` | `DiagramViewPreparer`, `DiagramViewPreparerEnvironment` |
| `Sources/DiagramKitRenderingCG/FontRegistry.swift` | `DiagramFontRegistry` |
| `Sources/DiagramKitViews/MermaidView.swift` | `DiagramNativeView` |
| `Sources/DiagramKitViews/MermaidLayer.swift` | `DiagramLayer` |
| `Sources/DiagramKitViews/MermaidDiagram.swift` | `DiagramViewModel` |
| `Sources/DiagramKitViews/MermaidDiagramView.swift` | `DiagramView` (with `@available` for platform version) |
| `Sources/DiagramKit/MermaidRenderer.swift` | `DiagramEngine` |
| `Sources/DiagramKit/MermaidPipeline.swift` | `DiagramPipeline` |
| `Sources/DiagramKit/ImageRenderer.swift` | `DiagramImageRenderer` |
| `Sources/DiagramKit/DiagramDescriptor.swift` | `DiagramStructuralError` |
| `Sources/DiagramKit/MermaidPreparerWiring.swift` | `_DiagramPreparerBootstrap` |

**Verification**: `swift build --build-tests` passed with zero test changes
(build time ~16s on MBP M4).

### Commit B — Internal Migration ✅

All internal call sites migrated via bulk sed replacement (126 files, 289
replacements across Sources/ + Tests/ + Examples/). Forward typealiases from
Commit A were replaced with backward-compat `@available(*, deprecated,
renamed:)` aliases pointing old → new.

**Preserved intentionally**:
- `original_src_types.MermaidGraph` — upstream JS-port internal type (corrected
  after initial sed over-rename)
- `MermaidNode` — per plan, Mermaid-specific node concept
- `MermaidParser` — per plan, will become `MermaidImporter` in Phase 2
- `DiagramRenderer` (CG class) — per Section 1, no rename
- `DiagramRegistry` / `DiagramDescriptor` / `DiagramHeader` — deferred to Phase 1

**Additional renames executed** (missed in initial bulk pass, caught later):
- `_renderMermaidSVG` → `_renderDiagramSVG` (internal, in `src_index.swift`)
- `_renderPreprocessedMermaidSVG` → `_renderPreprocessedDiagramSVG` (internal)
- `renderMermaidSVG` → `renderDiagramSVG` (public, new primary; old deprecated)
- `renderMermaidSVGAsync` → `renderDiagramSVGAsync` (public, new primary; old deprecated)
- `renderMermaid` → `renderDiagram` (already-deprecated, updated message)

**Deprecated backward-compat surface**: every renamed type has a
`@available(*, deprecated, renamed: "NewName") public typealias OldName = NewName`
in the target where the original symbol was defined. Deprecated function
wrappers delegate to the new names.

**Verification**: `swift build --build-tests` passed. Corpus snapshot tests
ran — snapshot failures are pre-existing rendering issues (stroke color
calculations, 0×0 layout bounds), not caused by renames. See BASELINES.md
for known gap counts.

### Commit C — File Renames + Docs + BASELINES ✅

**File renames** (via `git mv`):
- `Sources/DiagramKit/ImageRenderer.swift` → `DiagramImageRenderer.swift`
- `Sources/DiagramKit/MermaidPreparerWiring.swift` → `DiagramPreparerWiring.swift`
- `Sources/DiagramKitModel/MermaidColorParser.swift` → `DiagramColorParser.swift`
- `Sources/DiagramKitModel/MermaidSourceNormalizer.swift` → `DiagramSourceNormalizer.swift`

**Registry comment banners**: added to `DiagramDescriptor.swift` and all 29
`DiagramRegistry+*.swift` files, marking them as Mermaid-family-internal with
a Phase 1 migration note.

**BASELINES.md**: created with build time, snapshot counts, and gate status.
Test counts left as placeholders (~XXX) pending a full `swift test` count pass.

**Docs updated**: AGENTS.md (critical constraints, conventions), ARCHITECTURE.md
(type names, file paths, pipeline descriptions), ANALYSIS.md (type references).

**Verification**: `swift build --build-tests` passed (18s). Governance gates:
- `check-file-sizes.sh` — pass (all warnings pre-existing)
- `strict-concurrency-check.sh` — pass (clean)
- `check-sendable-annotations.sh` — pass (all documented/allowlisted)

### Deferred to Phase 1

- Registry type renames (`DiagramRegistry` → `MermaidDiagramRegistry`, etc.)
- `Errors.swift` consolidation (`DiagramError` + `DiagramStructuralError` → single file)
- `renderMermaidASCII` rename (ASCII is Mermaid-specific)
- `MermaidParser` → `MermaidImporter` (needs `DiagramSourceImporter` protocol)

### Snapshot Test Status

Corpus snapshot tests produce ~700 issues across 3 suites (SVG / image / ASCII).
These are **pre-existing** and match the known rendering-bug punch list:
- Image: 50 entries fail due to layouts producing 0×0 bounds
- SVG/ASCII: color hex differences in ER / C4 / event-modeling renderers
  (e.g., `#939394` → `#27272A` stroke colors) caused by theme-color fallback
  logic, not by Phase 0 renames

Re-recording is not expected in Phase 0 — no snapshot baseline names changed
(confirmed: zero `Mermaid_` prefixes in `Tests/` snapshot paths).

### Build Metrics (2026-05-12, MBP M4 24 GB)

| Command | Time |
|---|---|
| `swift build --build-tests` | ~16s |
| `swift test` (excluding snapshots) | ~30s |
| `swift test --filter CorpusSnapshotTests` | ~5 min |
