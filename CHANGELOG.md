# Changelog

All notable changes to DiagramKit are documented in this file.

## [0.1.0-beta.5] - 2026-10-08

### Added

- **Linux support for the whole `DiagramEngine` SVG/ASCII surface.** Every
  target now builds on Linux (swift:6.3.1) and the full portable test suite
  passes there, including the new `CorpusRenderTests`, which renders every
  corpus diagram (all 28 families, all source formats) to SVG and ASCII. The
  umbrella target had never compiled on Linux before. Flowchart, state,
  ZenUML and mindmap now render on Linux (mindmap measures text with
  `TextMetrics` there, like the other Linux-portable layouts).
- `PortableRenderSupport.swift`: on Linux only, `DiagramTheme` (colours as
  the new `DiagramThemeColor`) and `RenderConfig` (numeric shape metrics).
  Apple's types are unchanged.
- `RenderMetricDefaults`, the single source for literal shape metrics (Apple
  `RenderTokens` reads it; values unchanged), and `DiagramSVGFontFamily`
  (`proportional`, `proportionalChain`).
- Public underscore-SPI `_ganttCalendar`, `_ganttTimeZone`,
  `_ganttDateFormatter()`.

### Fixed

- **Gantt output no longer depends on the host time zone or locale.** All
  Gantt date parsing, arithmetic and formatting (parser, layout, Mermaid
  exporter) use one Gregorian/UTC/POSIX calendar; the today-marker is the
  user's wall-clock date on that timeline. Previously the same chart
  rendered differently per machine and weekday-name excludes depended on the
  user's language. *Behavior change:* for Unix-timestamp date formats, axis
  labels now show UTC times.
- Class-diagram ASCII layout and edge bundling iterate in declaration order
  (as the mermaid-js original's JS `Set`/`Map` do); cyclic class diagrams no
  longer lay out differently from run to run.
- The Linux-portable targets had stopped building on Linux after several
  May refactors (SVG font default, shape fallbacks, CGPoint bridging, an
  ungated `DiagramKitInteractive`).

### Changed

- `Dockerfile.linux-check` fails the build when any target fails (it used
  to record the FAIL and continue) and runs the full portable `swift test`.
- Test suite: image snapshots compare native pixels (`.nativePixels`), so
  they no longer depend on the display scale of the recording Mac; 52
  references were re-recorded at their native size. 51 Apple-only test files
  are whole-file gated for Linux.

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
