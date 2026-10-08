# Changelog

All notable changes to DiagramKit are documented in this file.

## [0.1.0-beta.4] - 2026-10-08

### Changed

- `swift-crypto` requirement widened from `from: "3.0.0"` to
  `"3.0.0"..<"6.0.0"`. It is linked on Linux only, for `StableID`'s
  `SHA256.hash`, which is unchanged through swift-crypto 5.0.0. Apple
  platforms keep using CryptoKit. No public API change.

## [0.1.0-beta.2] - 2026-07-14

### Added

- New internal `DiagramKitCorpus` library product/target: it owns the corpus
  schema (`CorpusEntry`/`CorpusFile`) and the single canonical
  `test-diagrams.json` (bundled as a SwiftPM resource, reached via
  `DiagramCorpus.load()` / `DiagramCorpus.resourceURL`). It is not intended for
  external reuse; it ships as a product only so the workspace's path-dependency
  app (`apps/DiagramStudio`) can consume the same fixture.

### Changed

- Single-sourced the diagram corpus. The schema types moved from
  `DiagramKitTestSupport` to `DiagramKitCorpus`, and `test-diagrams.json` moved
  from `Tests/DiagramKitTests/Resources/` into the new target
  (byte-identical). `DiagramKitTestSupport` re-exports `DiagramKitCorpus`, so
  existing `import DiagramKitTestSupport` call sites are unaffected. The corpus
  suites now load through `DiagramCorpus`, eliminating the parallel copy that
  `apps/DiagramStudio` previously had to keep in sync.
- Lowered the package platform floor from macOS 26.3 / iOS 26.3 to
  macOS 14 / iOS 17. The old floor was inherited from the former in-package
  sample app's external code-editor dependency (the sample now lives at
  `apps/DiagramStudio` in the workspace superproject) and was never a real
  API requirement. macOS 14 / iOS 17 is the genuine minimum: the Observation
  framework's `@Observable` macro on `DiagramEditor` (`DiagramKitInteractive`)
  is the highest-versioned first-party API in the package, and the full build
  and test suite pass at that floor.

## [0.1.0-beta.1] - 2026-07-13

First documented prerelease.

- Native Swift diagramming engine covering 28 diagram families across five
  source formats (Mermaid, D2, Graphviz DOT, Structurizr, PlantUML), with
  automatic format detection and three independent render backends (Core
  Graphics images, SVG, and ASCII).
- 14 SwiftPM library products, including SwiftUI/UIKit/AppKit view wrappers
  (`DiagramKitViews`) and a Linux-portable parse-and-layout core for
  non-rendering workflows.
- Interactive, mutation-based editing (`DiagramKitInteractive`) for
  flowchart, sequence, and Gantt diagrams, plus importer/exporter registries
  for round-tripping between the supported formats.
- 1,298 snapshot baselines (437 image + 437 SVG + 424 ASCII) across 424
  corpus entries; builds under Swift 6 strict concurrency
  (`swift-tools-version: 6.3`).
