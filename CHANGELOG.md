# Changelog

All notable changes to DiagramKit are documented in this file.

## [Unreleased]

## [0.1.0-beta.9] - 2026-11-13

Remediates the 2026-11-12 full review of the package (parsing, layout,
rendering, export and the interactive editor).

### Changed — what a consumer will notice

- **Canvas edits keep the user's source faithful.** After a `DiagramEditor`
  mutation, the saved Mermaid text keeps flowchart subgraph members inside
  their blocks, reproduces state and sequence diagrams exactly (notes,
  composites, regions, every arrow type, boxes, blocks, autonumber,
  `create`/`destroy`, `link`/`links`/`properties`), writes frontmatter and
  `%%{init}%%` directives back verbatim, keeps `%%` comments in place
  (trailing ones too, on flowchart lines and on state and sequence lines
  before the first unquoted `:`), and keeps `click`/`link` lines as written.
  The source's dominant line ending (CRLF or LF) is kept.
- **An edit that would lose content is refused.** The editor reads the
  exported text back and compares it with the edited model (Mermaid
  flowchart, state, sequence and gantt), and checks that every comment,
  preamble line and `click`/`link` line of the original is still there
  unless the edit removed its element. Otherwise the mutation throws the new
  `DiagramEditorError.exportWouldLoseContent(details:)`, whose description
  reads "The edit was not applied because … You can make this change in the
  source instead.", and the source, document and undo stack are unchanged.
  The check is active when the editor's registry has a read-back;
  `DiagramPipeline.defaultExportRegistry` sets one.
- **Canvas write-back is not available for D2, DOT, PlantUML and
  Structurizr sources in this release.** Every writing mutation on such a
  document (including writing Mermaid for it) is refused with
  `exportWouldLoseContent` before any export. The new
  `DiagramEditor.supportsCanvasEditing` tells a host up front so it can
  disable its editing controls; selection, inspection, layout and rendering
  are unaffected.
- **Title, theme and layout edits change only their own lines.**
  `setTitle`, `setTheme` and `setLayoutPreset` edit the preamble key in place
  (YAML key, init-directive value, or a new frontmatter block) and keep every
  line from the diagram header on byte for byte, on every Mermaid type.
- **A gantt resize changes only that task's line.** Durations stay
  durations and dates stay dates in the gantt's `dateFormat`; dependent tasks
  move as in Mermaid. A resize on a gantt with `excludes` is refused.
- **Hostile and oversized inputs end in typed errors** instead of traps or
  hangs. The new `DiagramInputLimitError` (`limit`, `detail`) is thrown with
  `.nestingDepth` for nesting deeper than 100 (inclusive: 100 levels parse,
  101 throw) in block, class namespaces, ZenUML, treemap, C4 and
  architecture; `.layoutSize` when a layout would take too much work (block
  nesting lays out to 15 levels in a single chain; 16–100 parse and then
  throw); and `.textDrawingSize` when ASCII drawing of a flowchart or state
  diagram would exceed 150 million cell operations or 3 million path-search
  steps (SVG and image rendering are unaffected; a 150-node tree now draws).
  Packet and radar values out of range throw their existing typed errors.
- **SVG output is escaped through one path.** Every renderer's text and
  attribute sinks go through `SVG.escapeText` / `escapeAttribute`, which also
  drop characters XML 1.0 forbids; every corpus SVG parses as XML. Theme
  values that could break out of a style block are rejected. **URL schemes
  are checked at output**: parsers keep every link in the model (custom
  schemes such as `obsidian://` round-trip and render as links), and only
  `javascript:`, `data:` and `vbscript:` are withheld at each SVG link sink.
- **CRLF and CR sources parse in every family**, through every importer
  (`DiagramLoader` normalises line endings before probing).
- **Flowchart parsing fixes that change results:** a later explicit
  declaration (`A[Start]` after `A --> B`) sets the node's label and shape;
  subgraph membership follows upstream (every node mentioned in a body is
  listed, and a node listed by two subgraphs belongs to the first to close);
  quoted labels may contain their closing bracket; `;` inside node text and
  multi-line markdown strings are kept; `A--text-->B` is one labelled edge;
  `A --- B` is an open link. A `"` in a quoted label is exported as `#quot;`.
- **Other parsing changes:** states named like keywords (`End`, `Start`)
  are ordinary states; one-line `state X { … }` and `class X { … }` bodies
  parse; an unclosed subgraph or composite is closed at end of input with a
  warning; `%%` inside a double-quoted string, inside mindmap node shapes,
  and after the first unquoted `:` in state/sequence descriptions is text;
  sequence entity codes (`#59;`, `#35;`) are text; gantt directives need a
  token boundary; frontmatter nests keys by relative indentation and bounds
  numbers (non-finite → nil, magnitude clamped to 1e6); init-directive JSON
  `0`/`1` are numbers; kanban and block model labels are raw text (not
  HTML-escaped); a quoted ER entity name is one entity; unspaced class/ER
  relationships parse.
- `DiagramView` now takes the size SwiftUI proposes. It used to fall back to
  the native view's `intrinsicContentSize` (the diagram's natural size) with
  default compression resistance, so it could grow but never shrink: a
  `.frame` below natural size left the drawing at 100%, overflowing the frame
  from its centre, while the host's own geometry (hit-testing, selection
  overlays) used the smaller frame. Both representables (AppKit and UIKit)
  implement `sizeThatFits`: a proposed dimension is taken as is, and an
  unspecified one is the natural size, scaled down with the other dimension
  when that is proposed below natural. **Behaviour change:** in a stack the
  view is now compressible like a resizable image; a host that relied on it
  holding its natural size should add `.fixedSize()`.

### Added

- New public enum cases that an exhaustive `switch` outside the package must
  handle: `DiagramEditorError.exportWouldLoseContent(details:)` and
  `DiagnosticCategory.exportReadBackMismatch`. New type
  `DiagramInputLimitError` with `Limit` cases `.nestingDepth`,
  `.numericRange`, `.layoutSize` and `.textDrawingSize`.
- `DiagramEditor.supportsCanvasEditing`.
- `DiagramSourceAnnotations`, `DiagramSourceComment`,
  `DiagramSourceCommentAnchor`, `DiagramDocument.sourceAnnotations` and
  `DiagramDocument.sourceFormat` (the source's preamble, comments and
  `click`/`link` lines as written).
- `ExporterRegistry.readBack` and `readingBack(with:)`. A same-format export
  through `DiagramExportLoader` that does not read back exactly carries an
  `exportReadBackMismatch` warning naming the first differing field.
- `FrontmatterValue.cssValue`, `FrontmatterValue.maxNumericMagnitude`, and
  `DiagramSourceNormalizer.normalizedLineEndings(_:)`,
  `strippingInlineComment(_:)` and `flowchartStatements(_:separators:)`.

### Fixed

- **Editor:** Group moves the selected nodes out of their old groups and
  nests the new group in their innermost common subgraph; a sequence message
  drag moves only that message (with its own activation and
  `create`/`destroy`); Rearrange/Adaptive layout presets apply on every
  flowchart and state diagram; deleting a node or edge keeps `linkStyle`
  indices and per-node state consistent; stale `DiagramViewModel`
  preparations are dropped.
- **Parsing:** block diagrams stay a bounded tree (self, mutual and cyclic
  nesting is ignored with a diagnostic; composite membership wins regardless
  of statement order; huge column spans are clamped to 1000); packet bit
  indices, radar ticks and frontmatter numbers are bounded before arithmetic;
  super-linear regexes in state, treemap, class, ER, packet, wardley,
  sequence and the style-colour pre-pass are linear; wardley and
  eventmodeling loops on unterminated quotes end; pie trailing comments,
  unspaced ER cardinalities and in-word apostrophes parse; a style colour
  ending in `;` is not decoded as an entity, and decoding never produces
  control characters.
- **Layout and rendering:** block, venn and large ASCII flowchart layouts no
  longer hang; D2/DOT tree imports are bounded and containment cycles are
  repaired in every imported model; duplicate subgraph ids no longer trap;
  computed numbers go through shared guards (sankey values ≥ 1e19, huge
  layout configs, extreme gantt dates); ASCII xychart bars stay on the
  canvas; ASCII C4 no longer recurses on a self-parented boundary; SVG CSS
  variables resolve in one pass, in style regions only; gitGraph
  reverse-commit classes are escaped; quadrant point order is kept.
- **Export:** the Mermaid flowchart export is lossless on the corpus;
  state and sequence exports reproduce the model; kanban and block labels,
  C4 titles and boundaries, and the cheap class losses round-trip.

### Tests

- 116 corpus snapshot baseline files were re-recorded for intended output
  changes (SVG escaping in sequence, PlantUML, timeline, journey, sankey,
  wardley, treemap, eventmodeling, block and class; sankey ASCII node names; the
  `dot-3`/`dot-4` open link, `state-6-choice-fork` now drawing `End`,
  `state-8-notes` drawing all three notes). `CorpusRoundTripTests` known
  divergences are down from 16 to 8. New suites cover CRLF across the whole
  corpus, hostile-input sweeps (bounded by thread CPU time), export fidelity
  and edit preservation for flowchart, state, sequence and gantt, and the
  editor's safety net.

## [0.1.0-beta.8] - 2026-11-09

### Fixed

- Assert known corpus round-trip divergences with portable XCTest assertions.
  Linux executes the same corpus checks without relying on the unavailable
  XCTest expected-failure API; a fixed or no-longer-exercised known entry fails.

### Added

- `DiagramEditor.setFlowchartDirection(_:)` applies direction through the editor's
  serialized transaction and undo stack. Its initializer accepts the exact parsed
  `initialSource`, avoiding a redundant export when attaching an existing document.

## [0.1.0-beta.7] - 2026-11-03

### Fixed

- Gate the canvas-theme catalog test to Apple platforms and install ripgrep for
  the stale-comment CI gate.

## [0.1.0-beta.6] - 2026-11-03

Remediation cycle following the 2026-10 full code review, including removal of
retired canvas themes.

### Removed

- The 20 Zed Trek canvas themes (`zedTrek<Family><Dark|Light>`), the
  `zedTrekDark` reference value, `Scripts/zed-trek.json`,
  `Scripts/gen_zedtrek.py` and the `check-zedtrek-pin` gate. `allThemes` is
  the 17 neutral canvas themes; `theme(named:)` returns nil for the removed
  names, and `DiagramTheme.default` is still `zincLight`.

### Fixed

- **Hostile diagram text can no longer crash or hang the engine.** The
  single-quote/unquote parser family and other index traps (fatal traps
  reachable from diagram text) are closed; the infinite loops reachable from
  diagram text are closed.
- **SVG injection hardening.** Sequence SVG embeds `<script>` only for
  interactive rendering (never in static output); ER class tokens are
  sanitized; theme variables are validated against a CSS color allow-list
  (`Sources/DiagramKitCommon/CSSColorSafety.swift`).
- **Flowchart edges crossing a subgraph boundary now render** (previously
  silently dropped).
- **Sequence ASCII** renders loop blocks and notes with correct indices
  (message-index vs item-index fix).
- **`A-->B` (no-space arrow) parses as an edge** instead of a node named
  `A--`; actor names starting with a block keyword no longer corrupt
  sequence diagrams; apostrophes no longer swallow the rest of the diagram.
- **CG renderer draws parser-authored requirement text and icon/image nodes**
  (requirement diagrams no longer render empty on macOS); rasterization no
  longer blocks the main actor.
- **Interactive editor**: the mutation chain no longer loses updates under
  concurrent `perform`; `editor.undo()`/`redo()` respect `canUndo`/`canRedo`
  gating.
- **DOT importer** accepts ordinary Graphviz output (numerals, braced
  endpoint sets, chain-wide attributes); exporters emit typed diagnostics
  instead of silently dropping structure.
- **README** no longer calls `DiagramEngine.bootstrap()` inside
  `View.init`; the example now bootstraps once at startup.
- **Docs re-baselined** against the tree: corpus path
  (`Sources/DiagramKitCorpus/Resources/test-diagrams.json`), measured counts
  (435 corpus entries, 1,335 tracked snapshot files, 387 test files),
  macOS 27 / iOS 27 floors, iOS-only platform sweep, truthful CI
  description, upstream `swift-snapshot-testing` pin, and removal of the
  dead `docs/archive/` links (history removed in `e88a7a09`; preserved in
  the workspace superproject).

### Changed

- Mindmap tree construction is O(n) (was O(n³)).
- `GraphLayout` is SPI (`_GraphLayout`, deprecated typealias kept);
  `DiagramViewModel` is a `@MainActor` class.
- Around 2,600 lines of dead code removed (`src_renderer` shape helpers and
  friends); the file-size allowlist is down to 8 entries.
- `CorpusRoundTripTests`: the 17 permanently-skipped `knownFailures` entries
  are now exercised — `flow-21-cicd-pipeline` passes and was unskipped; the
  16 still-diverging entries run under `withExpectedIssue` so regressions
  and fixes both surface. Gantt tests pin `DIAGRAMKIT_GANTT_TODAY` through a
  shared helper and use the production UTC calendar for expectations.
- `DiagramKitTests` declares all the modules it imports (`DiagramKitImport`,
  `DiagramKitViews` were previously reached through transitive visibility).
- `DiagramKitTestSupport` and `DiagramKitCorpus` are documented as
  **unsupported tooling products** (doc-comment banners; exempt from semver
  stability).

### Known issues

- **Bundled Noto fonts never register under SwiftPM.** The resource bundle
  carries the fonts flattened at the root (`NotoSans-Regular.otf`) while
  `DiagramFontRegistry.registerBundledFontsIfNeeded()` probes
  `Fonts/noto-sans/…` and `Resources/Fonts/noto-sans/…`, so every lookup
  misses and rendering silently uses system-font fallbacks. All image
  baselines were recorded in that state, so fixing the lookup would
  invalidate them; deferred deliberately.

### Correction (added 2026-10-13)

- The README shipped with beta.3–beta.5 claimed a macOS 14 / iOS 17 floor;
  the actual floor since beta.3 is **macOS 27 / iOS 27** (Swift 6 language
  mode). The README is corrected in this cycle.

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

## [0.1.0-beta.3] - 2026-07-25

### Changed

- Platform floor raised from macOS 14 / iOS 17 to macOS 27 / iOS 27, and
  every target declares Swift 6 language mode per target (the package was
  already Swift 6; no source change).
- Docs refer to CodeEditorKit (formerly CodeEditorPlugin).

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

> **Correction (2026-10-13):** those counts were wrong at tag time. The
> tree tagged `0.1.0-beta.1` actually carried **1,320** snapshot baselines
> (445 image + 445 SVG + 430 ASCII; 445 PNG + 875 `.txt` on disk) across
> 430 corpus entries. (The corpus has since grown to 435 entries; see
> [Unreleased].)
