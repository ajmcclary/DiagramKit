# AGENTS.md

Native Swift mermaid-js port (~28 diagram types). The companion `CLAUDE.md` has deeper architecture notes — read it for the three-stage pipeline, directory layout, and JS-ported parser conventions.

## Commands

```bash
swift build                                         # library + playground
swift build --build-tests                           # also compile tests
swift test --filter <NameOrPattern>                 # one suite/test
swift test --filter CorpusSnapshotTests             # snapshot test (~5 min)
swift run MermaidPlayground                         # SwiftUI sample app (macOS/iOS)

# Record/refresh snapshot baselines (env var needed):
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests

# After editing Package.swift:
swift package resolve
```

There is no lint/format/typecheck step — `swift test` is the primary verification step.

## Critical constraints

- **Never introduce a thread pool.** Every public entry point spawns a fresh 8 MB-stack `Thread` via `MermaidRenderer._runOnWorker`. This was tried and reverted (`ff2622b`) — the cooperative pool's ~512 KB stack can't handle deeply nested subgraph layouts.
- **`BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()` must be called first** in every pipeline method. Skipping it breaks snapshot determinism (fonts drift across OS versions).
- **Parser dispatch order matters.** `Parser.swift` uses a cascading `firstLine.hasPrefix(...)` chain; narrower prefixes must come before broader ones. The fallback handles `flowchart`, `graph`, `stateDiagram-v2`, and `state`.
- **Two independent renderers exist** (`Render/DiagramRenderer+<Type>.swift` for CG/images and `Mermaid/src_<type>_renderer.swift` for SVG). They share no geometry/text-measurement logic and will drift. Snapshot tests are the only guardrail.
- **Use `bmColorEquals()` for color comparisons**, not `hexString` round-trips — AppKit `NSColor` normalizes through `.deviceRGB`.

## Conventions

- Public API: `async throws` static methods on `MermaidRenderer` or `MermaidImageRenderer`.
- `@MainActor` **only** on methods that produce/consume `BMImage` or `CGContext`. `renderSVG`/`renderASCII` are intentionally NOT main-actor.
- Underscore-prefixed top-level names (`_PositionedNodePayload`, `_renderMermaidSVG`) are SPI; use public typealiases (`PositionedNode`) outside the module.
- Font family: route through `RenderConfig.defaultFontFamily` / `defaultProportionalFontFamily`. Never hardcode `"Menlo"`, `"Trebuchet MS"`, etc. in a renderer.
- Type-safe payloads: always pattern-match `graph.typedPayload` / `graph.content` enums — never cast to `Any`.

## Testing

- ~140 XCTest files + a few swift-testing suites (`CorpusSnapshotTests` uses `@Suite`/`@Test`).
- The test corpus is `Examples/MermaidPlayground/Resources/test-diagrams.json` (396 entries).
- `CorpusSnapshotTests` renders every diagram through SVG, image, and ASCII paths. Baselines at `Tests/BeautifulMermaidSwiftTests/__Snapshots__/CorpusSnapshotTests/`. ~161 image baselines — missing image cases are rendering bugs (layout producing 0×0 bounds).
- Snapshot precision: image snapshots use `precision: 0.99, perceptualPrecision: 0.98` to tolerate CoreText rasterization drift across CPU architectures.

## Dependencies

- `swift-custom-dump` and `xctest-dynamic-overlay` (IssueReporting) — upstream pointfreeco releases.
- `swift-snapshot-testing` is **pinned to a fork** (`ajmcclary/swift-snapshot-testing`, branch `fix-swift-6.3-attachable`) while [PR #1090](https://github.com/pointfreeco/swift-snapshot-testing/pull/1090) awaits upstream merge. Do not switch back to upstream until that PR ships in a tagged release.
- `swiftLanguageModes: [.v6]` enforced; all public types are `Sendable`.
