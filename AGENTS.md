# AGENTS.md

Native Swift mermaid-js port (~28 diagram types). For invariants and conventions, read `CLAUDE.md` (the source of truth for "do not break this"). For long-form architecture, read [ARCHITECTURE.md](ARCHITECTURE.md). For current metrics (build time, test counts, snapshot counts, gate status), read [BASELINES.md](BASELINES.md). For PR workflow + the green/yellow/red `@unchecked Sendable` policy, read [CONTRIBUTING.md](CONTRIBUTING.md). For upstream `mermaid-js` lineage, read [ATTRIBUTION.md](ATTRIBUTION.md). The six-stage import plan is in [ANALYSIS.md](ANALYSIS.md).

The package is split into six layered targets: `DiagramKitCommon` (Linux+Apple) → `DiagramKitModel` (Linux+Apple) → `DiagramKitRenderingCG` (Apple-only) / `DiagramKitTestSupport` (Linux+Apple) / `DiagramKitViews` (Apple-only stub) → `DiagramKit` (umbrella, public API + Views). Imports flow strictly along that direction.

## Commands

```bash
swift build                                         # library + playground
swift build --build-tests                           # also compile tests
swift test --filter <NameOrPattern>                 # one suite/test
swift test --filter CorpusSnapshotTests             # snapshot test (~5 min)
SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns swift test --filter CorpusSnapshotTests/imageSnapshot
swift run MermaidPlayground                         # SwiftUI sample app (macOS/iOS)

# Record/refresh snapshot baselines (env var needed):
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests
SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns swift test --filter CorpusSnapshotTests/imageSnapshot

# After editing Package.swift:
swift package resolve
```

There is no lint/format/typecheck step — `swift test` plus the discipline gates below are the verification surface.

## Verification gates

`Scripts/bootstrap-smoke-check.sh` is the local "is this branch healthy?" gate. It chains `swift package dump-package`, `swift test`, the three governance gates below, `linux-check.sh`, and a multiplatform `xcodebuild` sweep. Run individual gates while iterating; run the orchestrator before merging.

- `Scripts/check-file-sizes.sh` — 500 warn / 1000 error per `.swift` file. Allowlist: `Scripts/check-file-sizes-allowlist.txt` (11 JS-port files in `DiagramKitModel` grandfathered).
- `Scripts/check-sendable-annotations.sh` — every `@unchecked Sendable` must be in `.sendable-allowlist.txt` (yellow + sunset) **or** carry a "Concurrency Contract" banner in the first 50 lines / within 10 lines of the annotation. Prefer green (banner) over yellow (allowlist).
- `Scripts/strict-concurrency-check.sh` — `swift build -strict-concurrency=complete -warnings-as-errors`, filtered to `Sources/DiagramKit*/`. Currently clean.
- `Scripts/linux-check.sh` — Docker/Podman build of the Linux-portable matrix on `swift:6.3.1-noble`.

`Package.swift` applies `strictConcurrencySettings` (the `StrictConcurrency` upcoming feature only) per target via the top-level `let strictConcurrencySettings: [SwiftSetting]` constant. `InferSendableFromCaptures` is omitted — it's already default in Swift 6 mode, and including it produced a per-file "already enabled" warning.

## Critical constraints

- **Never introduce a thread pool.** Every public entry point spawns a fresh 8 MB-stack `Thread` via `DiagramEngine._runOnWorker`. This was tried and reverted (`ff2622b`) — the cooperative pool's ~512 KB stack can't handle deeply nested subgraph layouts.
- **`DiagramFontRegistry.registerBundledFontsIfNeeded()` must be called first** in every pipeline method. Skipping it breaks snapshot determinism (fonts drift across OS versions).
- **Parser dispatch order matters.** `Parser.swift` uses a cascading `firstLine.hasPrefix(...)` chain; narrower prefixes must come before broader ones. The fallback handles `flowchart`, `graph`, `stateDiagram-v2`, and `state`.
- **Two independent renderers exist** (`Sources/DiagramKitRenderingCG/DiagramRenderer+<Type>.swift` for CG/images and `Sources/DiagramKitModel/src_<type>_renderer.swift` for SVG). They share no geometry/text-measurement logic and will drift. Snapshot tests are the only guardrail.
- **Use `bmColorEquals()` for color comparisons**, not `hexString` round-trips — AppKit `NSColor` normalizes through `.deviceRGB`.

## Conventions

- Public API: `async throws` static methods on `DiagramEngine` or `DiagramImageRenderer`.
- `@MainActor` **only** on methods that produce/consume `BMImage` or `CGContext`. `renderSVG`/`renderASCII` are intentionally NOT main-actor.
- Underscore-prefixed top-level names (`_PositionedNodePayload`, `_renderDiagramSVG`) are SPI; use public typealiases (`PositionedNode`) outside the module.
- Font family: route through `RenderConfig.defaultFontFamily` / `defaultProportionalFontFamily`. Never hardcode `"Menlo"`, `"Trebuchet MS"`, etc. in a renderer.
- Type-safe payloads: always pattern-match `graph.typedPayload` / `graph.content` enums — never cast to `Any`.

## Testing

- ~144 XCTest files + a few swift-testing suites (`CorpusSnapshotTests` uses `@Suite`/`@Test`).
- The test corpus is `Examples/MermaidPlayground/Resources/test-diagrams.json` (396 entries).
- `CorpusSnapshotTests` renders every diagram through SVG, image, and ASCII paths. Baselines at `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/` (~396 SVG, ~346 image, ~172 ASCII). The remaining image gap is the rendering-bug punch list (layouts producing 0×0 bounds).
- Snapshot precision: image snapshots use `precision: 0.99, perceptualPrecision: 0.98` to tolerate CoreText rasterization drift across CPU architectures.

## Dependencies

- `swift-custom-dump` and `xctest-dynamic-overlay` (IssueReporting) — upstream pointfreeco releases.
- `swift-snapshot-testing` is **pinned to a fork** (`ajmcclary/swift-snapshot-testing`, branch `fix-swift-6.3-attachable`) while [PR #1090](https://github.com/pointfreeco/swift-snapshot-testing/pull/1090) awaits upstream merge. Do not switch back to upstream until that PR ships in a tagged release.
- `swiftLanguageModes: [.v6]` enforced; all public types are `Sendable`.
