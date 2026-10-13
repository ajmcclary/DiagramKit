# AGENTS.md

Native Swift mermaid-js port that now ships a multi-format DiagramKit
(Mermaid + D2 + Graphviz DOT + Structurizr + PlantUML). For invariants
and conventions, read `CLAUDE.md` first. For architecture details, read
[ARCHITECTURE.md](ARCHITECTURE.md). For current metrics, read
[BASELINES.md](BASELINES.md). (The former `docs/archive/` history tree was
removed from this repo in `e88a7a09`; preserved specs/plans live in the
workspace superproject under `docs/archive/package/DiagramKit/`.)

The package ships **14 layered SwiftPM library products** (plus two
**unsupported tooling products**, `DiagramKitTestSupport` and
`DiagramKitCorpus` — round-trip harness + corpus schema/fixture; exempt
from semver stability, not for external reuse). Imports flow
strictly downward:

```text
DiagramKitCommon           (Linux + Apple)
   ^
DiagramKitModel            (Linux + Apple, partial)
   ^
   +-----------+-----------+-----------+-----------+-----------+
DiagramKitRenderingCG  DiagramKitImport  DiagramKitExport  DiagramKitTestSupport  format slices:
   (Apple-only)        (Linux + Apple)   (Linux + Apple)   (Linux + Apple)        DiagramKitMermaid / D2 / Graphviz / Structurizr / PlantUML
   ^
DiagramKitViews            (Apple-only)
   ^                       DiagramKitInteractive (Apple-only)
DiagramKit                 (umbrella public API + re-exports)
```

Apple-only targets (`DiagramKitRenderingCG`, `DiagramKitViews`,
`DiagramKitInteractive`) are ordinary manifest dependencies; the platform
restriction is enforced at the **source level** — their files are whole-file
gated with `#if canImport(UIKit) || canImport(AppKit)` /
`#if canImport(CoreGraphics)` and compile to empty on Linux. The only
platform-conditioned manifest dependency in the package is `swift-crypto`
(`condition: .when(platforms: [.linux])` in `DiagramKitCommon`).

## Commands

```bash
swift build                                         # library targets
swift build --build-tests                           # compile tests
swift test --filter <NameOrPattern>                 # one suite/test
swift test --filter CorpusSnapshotTests             # corpus snapshots (~5 min; see caveats)
SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns swift test --filter CorpusSnapshotTests/imageSnapshot
# Sample app: external to this repo — apps/DiagramStudio in the workspace
# superproject (cd apps/DiagramStudio && swift run DiagramStudio).

# Record/refresh snapshot baselines:
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests
SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns swift test --filter CorpusSnapshotTests/imageSnapshot

# After editing Package.swift:
swift package resolve
```

There is no separate lint/format/typecheck step. Use `swift test` plus the gates
below.

## Verification Gates

`Scripts/bootstrap-smoke-check.sh` is the full local merge gate. It chains
`swift package dump-package`, `swift test`, the governance gates, Linux check,
and a multiplatform `xcodebuild` sweep.

- `Scripts/check-file-sizes.sh` - 500 warn / 1000 error per `.swift` file.
- `Scripts/check-sendable-annotations.sh` - every `@unchecked Sendable` must be
  allowlisted or carry a "Concurrency Contract" banner.
- `Scripts/strict-concurrency-check.sh` - first-party strict-concurrency build.
- `Scripts/linux-check.sh` - Docker/Podman build of the Linux-portable matrix.
  If Docker/Podman is missing or not running locally, record it as skipped due
  to environment; do not treat that as a source failure.

## Critical Constraints

- **Never introduce a thread pool.** Public entry points use a fresh 8 MB-stack
  worker thread via `DiagramEngine._runOnWorker` / `DiagramWorkerThread.run`.
  This was tried and reverted in `ff2622b`.
- **`DiagramFontRegistry.registerBundledFontsIfNeeded()` must be called first**
  in every pipeline method. Skipping it breaks snapshot determinism.
- **Parser dispatch order matters.** `Sources/DiagramKit/DiagramDescriptor.swift`
  uses cascading `firstLine.hasPrefix(...)`; narrower prefixes must come
  before broader ones.
- **Two independent renderers exist.** CG/image renderers live in
  `DiagramKitRenderingCG`; SVG renderers live in `DiagramKitModel`. They drift;
  snapshots are the guardrail.
- **Use `bmColorEquals()` for color comparisons**, not `hexString` round-trips.

## Conventions

- Public API: `async throws` static methods on `DiagramEngine` or
  `DiagramImageRenderer`.
- Deprecated Mermaid-prefixed names remain for compatibility. Use
  Diagram-prefixed names in new code.
- `@MainActor` only on methods that produce/consume `BMImage`, `CGContext`, or
  native UI types. `renderSVG` and `renderASCII` are intentionally not
  main-actor, and since the M-CG-4 fix neither is rasterization:
  `DiagramBitmapRenderer.render`, `PreparedDiagram.render`, and the
  `DiagramImageRenderer` static render paths are nonisolated so large
  bitmaps never block the UI thread; only thin configuration-reading
  instance wrappers stay `@MainActor`.
- Underscore-prefixed top-level names (`_PositionedNodePayload`,
  `_renderDiagramSVG`) are SPI. Use public typealiases such as `PositionedNode`
  outside the module.
- Font family: route through `RenderConfig.defaultFontFamily` /
  `defaultProportionalFontFamily`. Never hardcode `"Menlo"`, `"Trebuchet MS"`,
  etc. in a renderer.
- Type-safe payloads: pattern-match `graph.typedPayload` / `graph.content`;
  never cast to `Any`.

## Current Roadmap

Feature-complete and in maintenance. Importers and exporters cover
Mermaid, D2, Graphviz DOT, Structurizr, and PlantUML (sequence + class +
state/activity + mindmap + gantt + C4). Format-neutral public names are
primary; Mermaid-prefixed aliases have been removed. The active backlog
is empty; [COVERAGE.md](COVERAGE.md) tracks the remaining deliberate
non-coverage (`—`) cells.

## Testing

- Test sources: 387 Swift files under `Tests/` (383 in
  `Tests/DiagramKitTests`, 4 in `Tests/DiagramKitLinuxTests`). The XCUI
  bundle was removed alongside the 2026-05-18 sample-app relocation.
- Corpus: `Sources/DiagramKitCorpus/Resources/test-diagrams.json`
  (435 entries: 406 Mermaid-only + 29 multi-format with D2, DOT,
  Structurizr, PlantUML sources).
- Snapshot baselines (measured 2026-10-13):
  - SVG: 435 (one per corpus entry) + 15 multi-format
  - Image: 435 (one per corpus entry) + 15 multi-format
  - ASCII: 435 (one per corpus entry)
- Total tracked: **1,335 files** (450 PNG + 885 `.txt`;
  `swift-snapshot-testing` writes SVG and ASCII as `.txt`).
- `CorpusMultiFormatSnapshotTests` renders every `(entry, format)` pair with
  format-suffixed snapshot names (`entry-id-format`), honoring `skipSnapshots`.
  Chunked execution with `SNAPSHOT_DIAGRAM_IDS` avoids the known signal-10
  parameterized-suite issue.
- Image snapshots use `precision: 0.99, perceptualPrecision: 0.98`.
- Pure renames should not re-record snapshots. Re-record only for intentional
  rendering or fixture changes.

## Dependencies

- `swift-custom-dump` and `xctest-dynamic-overlay` (IssueReporting) are upstream
  pointfreeco releases.
- `swift-snapshot-testing` is consumed from upstream pointfreeco by version
  (`from: "1.19.3"`). The former `ajmcclary/swift-snapshot-testing`
  `fix-swift-6.3-attachable` branch pin was only needed on the open-source
  swift-6.3-RELEASE toolchain and was dropped 2026-07-14.
- `swiftLanguageModes: [.v6]` is enforced; public types are `Sendable`.
