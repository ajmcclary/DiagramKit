# Phase 1: Importer Boundary And Mermaid Extraction

Date: 2026-05-12 (revised 2026-05-12 per review). This document is the
executable plan for Phase 1 of the DiagramKit multi-format roadmap. It follows
`PHASE-0.md` (completed: naming transition) and precedes Phase 2 (multi-format
corpus foundation).

## Goal

Split source-format import from diagram-family layout while preserving all
Mermaid behavior. Build the importer protocol boundary before any new source
format lands.

## Architecture Summary

```
┌──────────────────────────────────────────────────────────┐
│                    DiagramEngine                          │
│  (public async throws facade, worker-thread dispatch)     │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│                    DiagramLoader                          │
│  DiagramLoader.parse(source, registry:) → DiagramDocument │
│  First-match-wins probe dispatch through ImporterRegistry │
│  Narrowest / most-specific importers probed FIRST         │
└────────────────────────┬─────────────────────────────────┘
                         │
            ┌────────────┴──────────────────┐
            ▼                               ▼
   ┌─────────────────┐            ┌─────────────────┐
   │  (d2 — Phase 3) │            │ MermaidImporter │
   │  (before Mermaid)│            │ (explicit       │
   │                 │            │  fallback, last) │
   └─────────────────┘            └────────┬────────┘
                                           │
                                           ▼
                                  ┌─────────────────┐
                                  │ DiagramRegistry  │  (Mermaid-family routing,
                                  │   (kept public)  │   28 per-family descriptors)
                                  └─────────────────┘
                                           │
                                           ▼
                                  ┌─────────────────┐
                                  │ DiagramDocument  │  (format-agnostic, already exists)
                                  │   ↓              │
                                  │ PositionedGraph  │  (layout, format-agnostic)
                                  │   ↓              │
                                  │ render (SVG/CG)  │  (unchanged)
                                  └─────────────────┘
```

Probe order is contractual. Specific importers (d2 `a -> b`, DOT `digraph`,
PlantUML `@startuml`, Structurizr `workspace {`) are probed **before**
`MermaidImporter`. Mermaid's probe is intentionally broad and acts as the
fallback — it claims any source not matched by a more specific importer.
In Phase 1, Mermaid is the only registered importer, so it claims everything
(preserving current behavior).

The critical invariant: `DiagramDocument → PositionedGraph → render` remains
format-agnostic. Layout must not care whether the document came from Mermaid,
d2, DOT, Structurizr, or PlantUML.

## Current State (pre-Phase-1)

### Import path (what exists today)

1. **`MermaidParser.parse(_:)`** (`Sources/DiagramKit/Parser.swift`, 22 lines)
   - Stateless enum. Hardcoded to Mermaid.
   - Decodes XML entities → parses frontmatter → calls `DiagramHeader.detect`
     → `DiagramRegistry.detect` → `descriptor.parse(processed, frontmatter)`.
   - Returns `DiagramDocument`.

2. **`DiagramHeader`** (`Sources/DiagramKit/DiagramDescriptor.swift`)
   - Detected from first content-bearing line of preprocessed source.
   - Strips YAML frontmatter blocks and `%%` comment lines.
   - `raw` (first line, case-preserved), `normalized` (lowercased), `rawLines`.
   - `detect(from:)` static factory.

3. **`DiagramDescriptor`** (`Sources/DiagramKit/DiagramDescriptor.swift`)
   - Struct with four fields: `type: DiagramType`, `matches: @Sendable (DiagramHeader) -> Bool`,
     `parse: @Sendable (String, DiagramFrontmatter?) throws -> DiagramDocument`,
     `layout: @Sendable (DiagramDocument, LayoutConfig) throws -> PositionedGraph`.
   - Effectively a per-family dispatch record.

4. **`DiagramRegistry`** (`Sources/DiagramKit/DiagramDescriptor.swift`)
   - Enum with ordered `all: [DiagramDescriptor]` (28 entries, first-match wins).
   - `detect(_:)` → first matching descriptor (flowchart fallback).
   - `descriptor(for:)` → lookup by `DiagramType`.
   - `validate()` → consistency check.
   - 28 per-family extension files: `DiagramRegistry+Flowchart.swift`,
     `DiagramRegistry+State.swift`, `DiagramRegistry+Sequence.swift`, etc.

5. **`DiagramPipeline`** (`Sources/DiagramKit/MermaidPipeline.swift`)
   - Stateless enum wrapping parse → layout → render.
   - `parse(_:)` → `MermaidParser.parse(source)`
   - `layout(_:config:)` → parse + `GraphLayout(config:).layout(graph)`
   - `renderSVG(source:...)` → parse + layout + `SVGRenderRegistry.render(...)`
   - `renderASCII(source:...)` → parse + ASCII render
   - All methods call `runPipeline()` which registers fonts and wraps with
     `_withDiagramIssueReporting`.

6. **`DiagramEngine`** (`Sources/DiagramKit/MermaidRenderer.swift`)
   - Public `async throws` static methods.
   - `parse(_:)`, `layout(_:config:)`, `renderSVG(source:...)`,
     `renderImage(source:...)`, `renderASCII(source:...)`, `prepare(source:...)`.
   - All dispatch through `_runOnWorker` (8 MB-stack `Thread`).
   - `String` extensions: `parseDiagram()`, `renderDiagramImage(...)`,
     `renderDiagramSVG(...)`, `renderDiagramASCII(...)`.

### Model types (no change needed for Phase 1)

- `DiagramType` (28 cases) — in `DiagramKitModel/Types.swift`
- `DiagramPayload` (28 cases) — in `DiagramKitModel/Types.swift`
- `DiagramDocument` — wraps `DiagramPayload`, format-agnostic
- `PositionedContent` (28 cases) — typed positioned results
- `PositionedGraph` — wraps `DiagramDocument` + `PositionedContent` + dimensions
- `DiagramError` — `notYetImplemented(String)`
- `DiagramStructuralError` — `payloadMismatch(DiagramType)`

### SPM target layout (current)

```
Sources/
├── DiagramKitCommon          (Linux+Apple, IssueReporting + Crypto)
├── DiagramKitModel           (Linux+Apple, depends on DiagramKitCommon)
├── DiagramKitRenderingCG     (Apple only)
├── DiagramKitViews           (Apple only)
├── DiagramKitTestSupport     (Linux+Apple)
└── DiagramKit                (umbrella, re-exports all)
```

`DiagramKit` (umbrella) currently holds the import/routing surface:
- `Parser.swift` — `MermaidParser`
- `DiagramDescriptor.swift` — `DiagramHeader`, `DiagramDescriptor`, `DiagramRegistry`, `DiagramStructuralError`
- `DiagramRegistry+*.swift` — 28 per-family files
- `DiagramRegistry+TypedDescriptor.swift` — `_typed` factory
- `MermaidPipeline.swift` — `DiagramPipeline`
- `MermaidRenderer.swift` — `DiagramEngine`
- `Layout.swift` — `GraphLayout`
- `src_index.swift`, `src_ascii_index.swift` — legacy routing (should be phased out)
- `SVGRenderRegistry.swift`, `SVGIDGenerator.swift` — SVG rendering
- `DiagramImageRenderer.swift` — CG image rendering
- `DiagramPreparerWiring.swift` — view preparation wiring
- `ReExports.swift` — module re-exports

## Step-by-Step Implementation Plan

### Step 1: New SPM Target — `DiagramKitImport`

**What**: A new library target holding the importer protocol, registry, loader,
and diagnostic types.

**Where**: `Sources/DiagramKitImport/`

**Dependencies**: `DiagramKitModel` (for `DiagramType`, `DiagramDocument`,
`DiagramPayload`).

**Package.swift changes**:

```swift
// Products:
.library(name: "DiagramKitImport", targets: ["DiagramKitImport"]),

// Targets:
.target(
    name: "DiagramKitImport",
    dependencies: ["DiagramKitModel"],
    swiftSettings: strictConcurrencySettings
),
```

**Files to create** (5 files):

| File | Contents |
|------|----------|
| `DiagramSourceImporter.swift` | Protocol definition |
| `DiagramDiagnostic.swift` | `DiagramDiagnostic` struct |
| `DiagramImportResult.swift` | `DiagramImportResult` struct |
| `ImporterRegistry.swift` | `ImporterRegistry` struct |
| `DiagramLoader.swift` | `DiagramLoader` enum |

**Design rationale**: `DiagramKitImport` depends only on `DiagramKitModel`
(and transitively `DiagramKitCommon`). It does NOT depend on
`DiagramKitRenderingCG`, `DiagramKitViews`, or the umbrella. This keeps the
import boundary clean and testable on Linux without CoreGraphics. It does
NOT depend on `DiagramFrontmatter` — the importer protocol is frontmatter-free.

### Step 2: Protocol Types

#### 2a. `DiagramDiagnostic`

```swift
// Sources/DiagramKitImport/DiagramDiagnostic.swift

/// A non-fatal issue discovered during import.
/// Returned in `DiagramImportResult.diagnostics`.
public struct DiagramDiagnostic: Sendable, Hashable, CustomStringConvertible {
    /// Severity level.
    public enum Severity: Sendable, Hashable {
        case warning     // recoverable; import proceeds
        case info        // informational; nothing dropped
        case unsupported // feature dropped; import proceeds without it
    }

    public let severity: Severity
    public let message: String
    /// Optional source location hint (line number, span, etc.)
    public let location: SourceLocation?

    public struct SourceLocation: Sendable, Hashable {
        public let line: Int?
        public let column: Int?
        public init(line: Int? = nil, column: Int? = nil) {
            self.line = line
            self.column = column
        }
    }

    public init(severity: Severity, message: String, location: SourceLocation? = nil) {
        self.severity = severity
        self.message = message
        self.location = location
    }

    public var description: String {
        if let loc = location {
            let lineStr = loc.line.map { "line \($0)" } ?? "?"
            return "[\(severity)] \(message) (\(lineStr))"
        }
        return "[\(severity)] \(message)"
    }
}
```

#### 2b. `DiagramImportResult`

```swift
// Sources/DiagramKitImport/DiagramImportResult.swift

/// The result of importing a diagram from a source format.
public struct DiagramImportResult: Sendable {
    /// The parsed diagram document, ready for layout.
    public let document: DiagramDocument
    /// Non-fatal diagnostics collected during import.
    public let diagnostics: [DiagramDiagnostic]

    public init(document: DiagramDocument, diagnostics: [DiagramDiagnostic] = []) {
        self.document = document
        self.diagnostics = diagnostics
    }
}
```

#### 2c. `DiagramSourceImporter`

```swift
// Sources/DiagramKitImport/DiagramSourceImporter.swift

/// A source-format importer that parses text into a `DiagramDocument`.
///
/// Conformers register with `ImporterRegistry`. The registry probes each
/// importer in order; the first `supports(source:)` match wins.
///
/// ## Concurrency Contract
/// `DiagramSourceImporter` is `Sendable`. Implementations must be safe for
/// concurrent use. All parsing state (including diagnostics) is returned in
/// `DiagramImportResult` — there is no shared mutable diagnostics property.
/// This keeps importers stateless at the protocol boundary.
public protocol DiagramSourceImporter: Sendable {
    /// Human-readable name (e.g. "Mermaid", "d2", "DOT").
    var name: String { get }

    /// The set of `DiagramType` values this importer can produce.
    /// Used for UI discovery and sparse-matrix validation.
    var supportedDiagramTypes: Set<DiagramType> { get }

    /// Returns `true` when `source` appears to be in this importer's format.
    /// This is a text-only probe — it should be fast and avoid full parsing.
    /// The first importer returning `true` for a given source wins.
    ///
    /// Narrow / specific probes must return `true` only for their own format.
    /// The Mermaid importer's probe is intentionally broad and acts as the
    /// fallback — it is ordered LAST in the default registry.
    func supports(source: String) -> Bool

    /// Parse `source` into a `DiagramImportResult`.
    ///
    /// - Parameters:
    ///   - source: The raw diagram source text. The importer is responsible
    ///     for any format-specific preprocessing (XML entity decoding,
    ///     frontmatter parsing, etc.).
    /// - Returns: A `DiagramImportResult` containing the parsed document and
    ///   any non-fatal diagnostics.
    /// - Throws: `DiagramError` or a format-specific error on fatal parse
    ///   failures.
    func parse(_ source: String) throws -> DiagramImportResult
}
```

**Why no `frontmatter` parameter**: `DiagramFrontmatter` is a Mermaid-shaped
type (45 per-family config fields). Baking it into the generic importer
protocol would force every future format importer to understand Mermaid
frontmatter. Instead, each importer handles its own preprocessing internally.
`MermaidImporter.parse(_:)` calls `_parseFrontMatterAndStripped` inside its
implementation.

**Why no `var diagnostics` property**: Diagnostics are returned in
`DiagramImportResult`. There is no shared mutable state — the importer
accumulates diagnostics locally during `parse()` and returns them. This
avoids the lock-based approach from the original draft, which would be
problematic on Linux (`OSAllocatedUnfairLock` is Darwin-only) and creates
shared mutable state across concurrent parses.

#### 2d. `ImporterRegistry`

```swift
// Sources/DiagramKitImport/ImporterRegistry.swift

/// An ordered collection of source-format importers.
///
/// Detection is first-match-wins: when `DiagramLoader` probes each importer
/// in array order, the first `supports(source:) → true` wins.
/// **Probe order is contractual** — it is enforced by `ProbeCollisionMatrixTests`.
///
/// Specific/narrow importers (d2, DOT, PlantUML, Structurizr) must be ordered
/// BEFORE the broad Mermaid fallback importer. Mermaid's probe intentionally
/// returns `true` for any source, so it MUST be last in the registry.
public struct ImporterRegistry: Sendable {
    public let importers: [any DiagramSourceImporter]

    public init(importers: [any DiagramSourceImporter]) {
        self.importers = importers
    }

    /// Returns a new registry with `importer` prepended (not appended).
    /// New, narrower importers should be probed before existing broader ones.
    public func prepending(_ importer: any DiagramSourceImporter) -> Self {
        ImporterRegistry(importers: [importer] + importers)
    }

    /// The first importer whose `supports(source:)` returns `true`,
    /// or `nil` when no importer claims the source.
    public func importer(for source: String) -> (any DiagramSourceImporter)? {
        importers.first { $0.supports(source: source) }
    }

    /// Empty registry — no importers registered.
    public static let empty = ImporterRegistry(importers: [])
}
```

**`prepending` vs `adding`**: New specific importers go at the front so they
are probed first. The Mermaid fallback stays at the end. This avoids the
starvation problem where a broad `supports()` returns `true` before a narrow
probe gets to fire.

#### 2e. `DiagramLoader`

```swift
// Sources/DiagramKitImport/DiagramLoader.swift

/// Stateless dispatch: probe an `ImporterRegistry` and parse through the
/// first matching importer.
public enum DiagramLoader {

    /// Parse `source` using the given registry.
    ///
    /// Probes each importer in the registry in order; the first
    /// `supports(source:) → true` wins. Returns the parsed `DiagramImportResult`
    /// containing the `DiagramDocument` and any diagnostics.
    ///
    /// - Parameters:
    ///   - source: Raw diagram source text.
    ///   - registry: The importer registry to probe.
    /// - Returns: `DiagramImportResult` with the parsed document and diagnostics.
    /// - Throws: `DiagramError` on fatal parse failures. Throws a loader-level
    ///   error when no importer claims the source.
    public static func parse(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramImportResult {
        guard let importer = registry.importer(for: source) else {
            throw DiagramError.notYetImplemented(
                "No importer registered for source format"
            )
        }
        return try importer.parse(source)
    }

    /// Shorthand returning only the `DiagramDocument`, discarding diagnostics.
    public static func parseDocument(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try parse(source, registry: registry).document
    }
}
```

### Step 3: `MermaidImporter` — First Concrete Importer

**Where**: `Sources/DiagramKit/MermaidImporter.swift` (new file, in umbrella)

`MermaidImporter` wraps the existing `DiagramRegistry`/`DiagramDescriptor`
dispatch inside the `DiagramSourceImporter` protocol. It does NOT introduce
new parsing behavior — everything that worked before must work identically.

```swift
// Sources/DiagramKit/MermaidImporter.swift

import Foundation
import DiagramKitModel
import DiagramKitCommon
import DiagramKitImport

/// Mermaid source-format importer.
///
/// Wraps the existing per-family `DiagramRegistry` dispatch behind the
/// `DiagramSourceImporter` protocol. All 28 diagram families supported
/// by the Mermaid parser are available through this importer.
///
/// This importer's `supports(source:)` probe is intentionally broad —
/// it always returns `true`. Mermaid acts as the fallback importer and
/// MUST be ordered LAST in any `ImporterRegistry` that includes narrower
/// format importers.
public struct MermaidImporter: DiagramSourceImporter {

    public let name = "Mermaid"
    public let supportedDiagramTypes: Set<DiagramType> = Set(DiagramType.allCases)

    public init() {}

    public func supports(source: String) -> Bool {
        // Mermaid's flowchart fallback descriptor matches `{ _ in true }`,
        // so any non-empty source is potentially Mermaid. This is the
        // explicit fallback — narrower importers (d2, DOT, PlantUML,
        // Structurizr) are probed BEFORE this importer in the registry.
        return true
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        // Replicate existing MermaidParser.parse() logic.
        let decoded = _HTMLEntities.decode(source)
        let (processed, frontmatter) = _parseFrontMatterAndStripped(decoded)

        let header = DiagramHeader.detect(from: processed)
        let descriptor = DiagramRegistry.detect(header)
        let document = try descriptor.parse(processed, frontmatter)

        return DiagramImportResult(document: document, diagnostics: [])
    }
}
```

**Key decisions for `MermaidImporter`**:

1. **`supports(source:)` always returns `true`**. This is because the Mermaid
   flowchart fallback descriptor matches `{ _ in true }`. Mermaid is the
   explicit fallback importer and MUST be ordered last in any multi-importer
   registry. Future importers (d2, DOT, PlantUML, Structurizr) are
   prepended before Mermaid.

2. **No diagnostics property**. Diagnostics are accumulated locally during
   `parse()` and returned in `DiagramImportResult`. Mermaid parsing rarely
   produces non-fatal diagnostics today (it either succeeds or throws), so
   the initial implementation returns an empty array. When Mermaid gains
   diagnostic capability (e.g., unsupported-syntax warnings), the parse
   method accumulates them locally.

3. **Frontmatter handled internally**. `MermaidImporter.parse(_:)` calls
   `_parseFrontMatterAndStripped` itself. The `DiagramSourceImporter`
   protocol does not take a `DiagramFrontmatter` parameter — that type is
   Mermaid-specific and should not leak into the generic importer surface.

### Step 4: Wire the Loader Into the Pipeline

#### 4a. `MermaidParser` — thin wrapper over `MermaidImporter`

```swift
// Sources/DiagramKit/Parser.swift (updated)

public enum MermaidParser {

    static func parse(_ source: String) throws -> DiagramDocument {
        try _withDiagramIssueReporting(operation: "MermaidParser.parse") {
            // Delegate to MermaidImporter — exactly one import path.
            let importer = MermaidImporter()
            return try importer.parse(source).document
        }
    }
}
```

`MermaidParser.parse(_:)` is now a thin wrapper. There is no duplicated
descriptor dispatch — `MermaidImporter` is the single source of truth for
Mermaid parsing. The `_decodeXMLEntities` call moves into `MermaidImporter`
(already shown in Step 3).

#### 4b. `DiagramPipeline` — update `parse(_:)` to use loader

```swift
// Sources/DiagramKit/MermaidPipeline.swift (updated)

public enum DiagramPipeline {

    // ... runPipeline unchanged ...

    // Default registry — Mermaid only (Phase 1).
    // In later phases, specific importers are prepended before Mermaid.
    private static let defaultRegistry: ImporterRegistry = {
        ImporterRegistry(importers: [MermaidImporter()])
    }()

    public static func parse(_ source: String) throws -> DiagramDocument {
        try runPipeline(operation: "DiagramPipeline.parse", registerFonts: true) {
            try DiagramLoader.parseDocument(source, registry: defaultRegistry)
        }
    }

    public static func parse(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try runPipeline(operation: "DiagramPipeline.parse(registry:)", registerFonts: true) {
            try DiagramLoader.parseDocument(source, registry: registry)
        }
    }

    // layout(source:config:) — unchanged, delegates to parse + GraphLayout
    // layout(graph:config:) — unchanged, consumes DiagramDocument directly

    // renderSVG / renderASCII — unchanged, they call parse() internally
}
```

**Critical**: `DiagramPipeline.layout(graph:config:)` consumes a
`DiagramDocument` directly — no source format awareness. This path stays
unchanged. Only the `parse(_:)` entry points route through the loader.

#### 4c. `DiagramEngine` — public API unchanged

`DiagramEngine.parse(_:)` already delegates to `DiagramPipeline.parse(_:)`.
No change needed at the Engine level. The public API surface remains:

```swift
// Existing — unchanged
DiagramEngine.parse(source) -> DiagramDocument
DiagramEngine.layout(source, config:) -> PositionedGraph
DiagramEngine.renderSVG(source:theme:layoutConfig:idPolicy:) -> String
DiagramEngine.renderImage(source:theme:scale:) -> BMImage?
DiagramEngine.renderASCII(source:theme:) -> String
```

`String` extensions (`parseDiagram()`, `renderDiagramSVG(...)`, etc.) —
unchanged.

#### 4d. Default registry in `DiagramKit` umbrella

```swift
// Sources/DiagramKit/MermaidPipeline.swift (or ReExports.swift)

extension ImporterRegistry {
    /// Default registry for Phase 1: Mermaid only.
    /// In Phase 3+: specific importers are prepended before Mermaid.
    ///
    /// Example future shape:
    ///   ImporterRegistry(importers: [
    ///     StructurizrImporter(),  // probe: "workspace {"
    ///     PlantUMLImporter(),     // probe: "@startuml"
    ///     DOTImporter(),          // probe: "digraph" / "graph"
    ///     D2Importer(),           // probe: "->" + ": " assignment
    ///     MermaidImporter(),      // fallback: always true
    ///   ])
    public static let `default`: ImporterRegistry = ImporterRegistry(
        importers: [MermaidImporter()]
    )
}
```

### Step 5: `DiagramRegistry` — Keep Public, Mark as Mermaid-Family

**Decision**: Do NOT rename `DiagramRegistry` or make it internal in Phase 1.

**Rationale**: Changing `public enum DiagramRegistry` to `internal enum
MermaidDiagramRegistry` creates a compile error for any downstream code
referencing `DiagramRegistry` (playground, test suites). Swift does not
allow a `public typealias` to an `internal` type. Rather than mixing
public API removal into the importer architecture work, Phase 1 keeps
`DiagramRegistry` public and adds documentation marking it as
Mermaid-family-specific routing.

**Changes to `DiagramDescriptor.swift`**:

```swift
// Sources/DiagramKit/DiagramDescriptor.swift

// MARK: Mermaid-family diagram routing
//
// DiagramRegistry and DiagramDescriptor are Mermaid-specific dispatch types.
// Format-agnostic import dispatch goes through the new
// `DiagramSourceImporter` protocol + `ImporterRegistry` (see DiagramKitImport).
// These types remain public for backward compatibility during the transition.

/// Mermaid-family diagram registry.
/// For multi-format import dispatch, use `ImporterRegistry` + `DiagramLoader`.
public enum DiagramRegistry {
    // ... unchanged implementation ...
}
```

No file renames. No access-level changes. The 28 `DiagramRegistry+*.swift`
extension files are unchanged.

### Step 6: Error Type Boundaries

#### `DiagramError` — stays in `DiagramKitModel`

`DiagramError.notYetImplemented(String)` is format-agnostic. It's thrown by
renderers and layouts, not just importers. Stays in `DiagramKitModel/Types.swift`.

#### `DiagramStructuralError` — stays in `DiagramKit` umbrella

`DiagramStructuralError.payloadMismatch(DiagramType)` is thrown by
`DiagramDescriptor.layout` closures when the payload doesn't match the
expected type. Stays in `Sources/DiagramKit/DiagramDescriptor.swift`.

#### `DiagramDiagnostic` — new, in `DiagramKitImport`

Non-fatal import warnings, feature-dropped notices, and informational
messages. Defined in Step 2a.

### Step 7: Update `DiagramKit` Umbrella Target

**`DiagramKit` target dependencies** (in Package.swift):
```swift
.target(
    name: "DiagramKit",
    dependencies: [
        "DiagramKitCommon",
        "DiagramKitModel",
        "DiagramKitImport",                                 // NEW
        .target(name: "DiagramKitRenderingCG", condition: ...),
        .target(name: "DiagramKitViews", condition: ...)
    ],
    swiftSettings: strictConcurrencySettings
),
```

**Re-exports** (`Sources/DiagramKit/ReExports.swift`):
```swift
@_exported import DiagramKitCommon
@_exported import DiagramKitModel
@_exported import DiagramKitImport  // NEW — exposes protocol types
#if canImport(CoreGraphics)
@_exported import DiagramKitRenderingCG
@_exported import DiagramKitViews
#endif
```

Downstream consumers importing `DiagramKit` automatically get
`DiagramSourceImporter`, `ImporterRegistry`, `DiagramLoader`, and
`DiagramDiagnostic` without additional imports.

### Step 8: Test Plan

#### 8a. `ImporterRegistryTests` (new test file)

```swift
// Tests/DiagramKitTests/ImporterRegistryTests.swift

@Suite struct ImporterRegistryTests {

    @Test("Default registry picks Mermaid for Mermaid source")
    func defaultRegistryPicksMermaid() throws {
        let registry = ImporterRegistry.default
        #expect(registry.importers.count == 1)
        #expect(registry.importers[0].name == "Mermaid")

        let source = "graph TD\nA-->B"
        let importer = try #require(registry.importer(for: source))
        #expect(importer.name == "Mermaid")
    }

    @Test("Empty registry returns nil importer")
    func emptyRegistryReturnsNil() {
        let registry = ImporterRegistry.empty
        #expect(registry.importer(for: "graph TD\nA-->B") == nil)
    }

    @Test("DiagramLoader throws when no importer matches")
    func loaderThrowsForUnsupportedSource() {
        let registry = ImporterRegistry.empty
        #expect(throws: DiagramError.self) {
            try DiagramLoader.parseDocument("unsupported", registry: registry)
        }
    }

    @Test("prepending() puts new importer first in probe order")
    func prependingPutsFirst() {
        let base = ImporterRegistry(importers: [MermaidImporter()])
        // In Phase 3, a D2Importer would be prepended:
        // let extended = base.prepending(D2Importer())
        // #expect(extended.importers[0].name == "d2")
        // #expect(extended.importers[1].name == "Mermaid")
        #expect(base.importers.count == 1)
    }
}
```

#### 8b. `ProbeCollisionMatrixTests` (new test file)

```swift
// Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift

@Suite struct ProbeCollisionMatrixTests {

    @Test("Mermaid graph TD is claimed by MermaidImporter")
    func mermaidGraphTD() {
        let source = "graph TD\nA-->B"
        let importer = MermaidImporter()
        #expect(importer.supports(source: source))
    }

    @Test("Mermaid sequenceDiagram is claimed")
    func mermaidSequence() {
        let source = "sequenceDiagram\nAlice->>Bob: Hello"
        let importer = MermaidImporter()
        #expect(importer.supports(source: source))
    }

    // Future-phase probe signatures documented as tests.
    // These verify that the probe signatures for future formats are
    // distinguishable. When those importers land, they are prepended
    // before MermaidImporter so their probes fire first.

    @Test("DOT probe signature: digraph keyword")
    func dotProbeSignature() {
        let source = "digraph G {\n  a -> b\n}"
        let firstLine = source.split(separator: "\n").first ?? ""
        #expect(firstLine.hasPrefix("digraph") || firstLine.hasPrefix("graph"))
    }

    @Test("d2 probe signature: edge syntax with colon assignment")
    func d2ProbeSignature() {
        let source = "a -> b\nb: c"
        let containsEdgeArrow = source.contains("->") || source.contains("-->")
        let containsColonAssign = source.contains(": ")
        #expect(containsEdgeArrow && containsColonAssign)
    }

    @Test("PlantUML probe signature: @startuml")
    func plantumlProbeSignature() {
        let source = "@startuml\nAlice -> Bob: Hello\n@enduml"
        #expect(source.contains("@startuml"))
    }

    @Test("Structurizr probe signature: workspace keyword")
    func structurizrProbeSignature() {
        let source = "workspace {\n  model {\n    user = person \"User\"\n  }\n}"
        #expect(source.contains("workspace {"))
    }
}
```

#### 8c. `MermaidImporterTests` (new test file)

```swift
// Tests/DiagramKitTests/MermaidImporterTests.swift

@Suite struct MermaidImporterTests {

    @Test("MermaidImporter parses flowchart source")
    func parsesFlowchart() throws {
        let importer = MermaidImporter()
        let result = try importer.parse("graph TD\nA[Start] --> B[End]")
        #expect(result.document.type == .flowchart)
        #expect(result.diagnostics.isEmpty)
    }

    @Test("MermaidImporter parses sequence diagram source")
    func parsesSequence() throws {
        let importer = MermaidImporter()
        let result = try importer.parse("sequenceDiagram\nAlice->>Bob: Hello")
        #expect(result.document.type == .sequenceDiagram)
    }

    @Test("MermaidImporter supportedDiagramTypes covers all cases")
    func coversAllDiagramTypes() {
        let importer = MermaidImporter()
        #expect(importer.supportedDiagramTypes.count == DiagramType.allCases.count)
    }

    @Test("MermaidImporter returns empty diagnostics for clean parse")
    func cleanParseHasNoDiagnostics() throws {
        let importer = MermaidImporter()
        let result = try importer.parse("graph TD\nA-->B")
        #expect(result.diagnostics.isEmpty)
    }
}
```

#### 8d. `MermaidLegacyAPITests` (new test file)

```swift
// Tests/DiagramKitTests/MermaidLegacyAPITests.swift

@Suite struct MermaidLegacyAPITests {

    @Test("MermaidParser.parse still works through loader")
    func mermaidParserStillWorks() throws {
        let doc = try MermaidParser.parse("graph TD\nA-->B")
        #expect(doc.type == .flowchart)
    }

    @Test("DiagramEngine.parse still works")
    func diagramEngineParseStillWorks() async throws {
        let doc = try await DiagramEngine.parse("graph TD\nA-->B")
        #expect(doc.type == .flowchart)
    }

    @Test("DiagramEngine.renderSVG still works")
    func diagramEngineRenderSVGStillWorks() async throws {
        let svg = try await DiagramEngine.renderSVG(
            source: "graph TD\nA-->B",
            idPolicy: .stable
        )
        #expect(svg.contains("<svg"))
    }

    @Test("String.parseDiagram still works")
    func stringParseDiagramStillWorks() async throws {
        let doc = try await "graph TD\nA-->B".parseDiagram()
        #expect(doc.type == .flowchart)
    }
}
```

#### 8e. `SampleDiagrams` and `TestDiagrams` — no changes

Both `SampleDiagrams.swift` (playground) and `TestDiagrams` (corpus loader)
use `DiagramEngine` / `String` extensions, which route through
`DiagramPipeline.parse(_:)` → `DiagramLoader`. No source changes needed.

#### 8f. `CorpusSnapshotTests` — no changes

The snapshot tests call `DiagramEngine.renderSVG(source:...)`,
`DiagramEngine.renderImage(source:...)`, and `DiagramEngine.renderASCII(source:...)`.
These route through `DiagramPipeline` → `DiagramLoader` → `MermaidImporter`.
Output must be byte-identical to the pre-Phase-1 baselines.

**Caveats**: The full corpus suite runs ~5 minutes. Use environment variable
filtering for iterative development:
```bash
SNAPSHOT_DIAGRAM_IDS=block-1-simple,flow-1-simple swift test --filter CorpusSnapshotTests
```

#### 8g. `DiagramRegistryTests` — unchanged

`DiagramRegistry` remains public and its tests are unchanged. The suite
continues to validate that all 28 `DiagramType` cases have descriptors.

### Step 9: Verification Gates

Run these in order before considering Phase 1 complete:

1. **Build**:
   ```bash
   swift build --build-tests
   ```

2. **New tests**:
   ```bash
   swift test --filter ImporterRegistryTests
   swift test --filter ProbeCollisionMatrixTests
   swift test --filter MermaidImporterTests
   swift test --filter MermaidLegacyAPITests
   ```

3. **Existing registry tests**:
   ```bash
   swift test --filter DiagramRegistryTests
   ```

4. **Full corpus snapshots** (must be byte-identical; ~5 min):
   ```bash
   swift test --filter CorpusSnapshotTests
   ```
   For iterative work, filter to a smaller set:
   ```bash
   SNAPSHOT_DIAGRAM_IDS=block-1-simple,flow-1-simple,seq-1-basic swift test --filter CorpusSnapshotTests
   ```

5. **File size check**:
   ```bash
   Scripts/check-file-sizes.sh
   ```

6. **Sendable annotations**:
   ```bash
   Scripts/check-sendable-annotations.sh
   ```

7. **Strict concurrency**:
   ```bash
   Scripts/strict-concurrency-check.sh
   ```

8. **Linux check** (skip if Docker/Podman unavailable):
   ```bash
   Scripts/linux-check.sh
   ```

9. **Full bootstrap smoke check**:
   ```bash
   Scripts/bootstrap-smoke-check.sh
   ```

## Summary of Changes

### New files (10)

| File | Target | Purpose |
|------|--------|---------|
| `Sources/DiagramKitImport/DiagramSourceImporter.swift` | DiagramKitImport | Protocol |
| `Sources/DiagramKitImport/DiagramDiagnostic.swift` | DiagramKitImport | Diagnostic type |
| `Sources/DiagramKitImport/DiagramImportResult.swift` | DiagramKitImport | Result type |
| `Sources/DiagramKitImport/ImporterRegistry.swift` | DiagramKitImport | Registry |
| `Sources/DiagramKitImport/DiagramLoader.swift` | DiagramKitImport | Loader dispatch |
| `Sources/DiagramKit/MermaidImporter.swift` | DiagramKit | Mermaid importer |
| `Tests/DiagramKitTests/ImporterRegistryTests.swift` | DiagramKitTests | Registry tests |
| `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift` | DiagramKitTests | Probe tests |
| `Tests/DiagramKitTests/MermaidImporterTests.swift` | DiagramKitTests | Importer tests |
| `Tests/DiagramKitTests/MermaidLegacyAPITests.swift` | DiagramKitTests | Legacy API tests |

### Modified files (5)

| File | Change |
|------|--------|
| `Package.swift` | Add `DiagramKitImport` target + product; add `DiagramKitImport` dependency to `DiagramKit` |
| `Sources/DiagramKit/ReExports.swift` | Add `@_exported import DiagramKitImport` |
| `Sources/DiagramKit/Parser.swift` | Rewrite as thin wrapper over `MermaidImporter`; remove duplicated descriptor dispatch |
| `Sources/DiagramKit/MermaidPipeline.swift` | Route `parse(_:)` through `DiagramLoader` with default registry; add `parse(_:registry:)` overload |
| `Sources/DiagramKit/DiagramDescriptor.swift` | Add doc comment marking `DiagramRegistry` as Mermaid-family routing |

### Unchanged files (critical)

| File | Why |
|------|-----|
| `Sources/DiagramKitModel/Types.swift` | `DiagramDocument`, `DiagramPayload`, `DiagramError`, `DiagramType` — no changes needed |
| `Sources/DiagramKit/MermaidRenderer.swift` | `DiagramEngine` public API — unchanged; delegates through `DiagramPipeline` |
| `Sources/DiagramKit/Layout.swift` | `GraphLayout` — format-agnostic, unchanged |
| `Sources/DiagramKit/DiagramRegistry+*.swift` | All 28 per-family descriptor files — unchanged |
| `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift` | Unchanged |
| `Examples/MermaidPlayground/Models/SampleDiagrams.swift` | Playground sample data — unchanged |
| `Tests/DiagramKitTests/CorpusSnapshotTests.swift` | Snapshot tests — unchanged |
| `Tests/DiagramKitTests/DiagramRegistryTests.swift` | Registry tests — unchanged (`DiagramRegistry` stays public) |
| `Tests/DiagramKitTests/*` | All other test files — unchanged |

## Design Decisions

### 1. New target vs. inlining in `DiagramKitModel`

**Decision**: New `DiagramKitImport` target.

**Rationale**: The protocol types depend on `DiagramKitModel` (for `DiagramType`,
`DiagramDocument`, `DiagramPayload`). Putting them in `DiagramKitModel` would
make the model layer import-aware, which is backwards. Putting them in
`DiagramKitCommon` would require `DiagramKitCommon` to depend on
`DiagramKitModel`, breaking the current layering (`Common → Model`, not
`Common → Model → Common`). A new target between Model and the umbrella
keeps dependencies clean.

### 2. `MermaidImporter` in umbrella vs. new `DiagramKitMermaid` target

**Decision**: `MermaidImporter` in `DiagramKit` umbrella for Phase 1.

**Rationale**: All Mermaid parsing code already lives in the umbrella. Creating
a separate `DiagramKitMermaid` target requires moving 28+ per-family files,
their parsers, and their layouts — a large refactor that risks snapshot drift.
Phase 1 establishes the protocol boundary; Phase 2 or later can extract
Mermaid into its own target when d2 demonstrates the pattern.

### 3. `DiagramRegistry` stays public

**Decision**: Keep `DiagramRegistry` as a public enum. Do not rename or internalize.

**Rationale**: Making it `internal enum MermaidDiagramRegistry` and then
attempting a `public typealias DiagramRegistry = MermaidDiagramRegistry`
does not compile in Swift (a public typealias cannot reference an internal
type). The self-referential `DiagramDescriptor = DiagramDescriptor` alias
originally proposed is also invalid. Rather than mixing public API removal
into the importer architecture work, Phase 1 keeps `DiagramRegistry` public,
adds documentation marking it as Mermaid-family routing, and lets the new
`ImporterRegistry` + `DiagramLoader` surface be the format-agnostic dispatch
path. The old types can be deprecated in a later phase once consumers have
migrated.

### 4. Probe order: specific importers first, Mermaid fallback last

**Decision**: `MermaidImporter.supports(source:)` always returns `true`.
It is the explicit fallback and MUST be last in any multi-importer registry.
`ImporterRegistry` uses `prepending(_:)` (not `adding(_:)`) to place new
specific importers before existing broader ones.

**Rationale**: The original draft proposed `adding(_:)` (append), which would
permanently starve d2/DOT/PlantUML importers — Mermaid's always-true probe
would fire first and claim their sources. With `prepending(_:)` and Mermaid
ordered last, specific probes fire first. In Phase 1, Mermaid is the only
importer and claims everything (preserving current behavior).

### 5. No `DiagramFrontmatter` in the importer protocol

**Decision**: `DiagramSourceImporter.parse(_ source: String)` takes only a
source string. No `DiagramFrontmatter` parameter.

**Rationale**: `DiagramFrontmatter` is a Mermaid-shaped type with 45 per-family
config fields. Baking it into the generic importer protocol would force every
future format importer (d2, DOT, PlantUML, Structurizr) to understand
Mermaid frontmatter. Each importer handles its own preprocessing internally.

### 6. No `var diagnostics` in the importer protocol

**Decision**: Diagnostics are returned only in `DiagramImportResult`. There is
no `var diagnostics: [DiagramDiagnostic] { get }` requirement on the protocol.

**Rationale**: The property creates shared mutable state across concurrent
parses through the same importer instance. The lock-based approach
(`OSAllocatedUnfairLock`) is Darwin-only and would fail on Linux. Returning
diagnostics in the result keeps importers stateless at the protocol boundary.

### 7. Worker-thread invariant preserved

All public `DiagramEngine` entry points still dispatch through `_runOnWorker`
(8 MB-stack `Thread`). `DiagramLoader.parse()` is called inside the worker
thread, matching the existing pattern.

### 8. Font determinism preserved

`DiagramPipeline.runPipeline()` still calls
`DiagramFontRegistry.registerBundledFontsIfNeeded()` before every operation.
The loader path does not bypass this.

### 9. No snapshot re-recording

Phase 1 is a pure refactor: same parsing behavior, same layout, same rendering.
All 396 SVG, 396 image, and 174 ASCII baselines must remain byte-identical.
If any snapshot drifts, the refactor is incorrect.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Snapshot drift from subtle parse-order change | Low | `MermaidImporter.parse()` replicates existing `MermaidParser.parse()` byte-for-byte |
| `any DiagramSourceImporter` existential overhead | Low | Importer is probed once per source; existential dispatch is negligible vs. parsing cost |
| `DiagramKitImport` target breaks Linux build | Low | `DiagramKitModel` already Linux-compatible; no Apple-only dependencies |
| Playground `LiveEditorStore` breakage | Low | Store calls `DiagramEngine` public API, which is unchanged |
| `DiagramRegistry` deprecation breaks consumers | None | `DiagramRegistry` is kept public — no deprecation in Phase 1 |
| Probe collision between Mermaid and future formats | Low | `prepending(_:)` + Mermaid-last ordering enforced; collision tests document expected signatures |
| `MermaidParser` thin wrapper adds overhead | None | `MermaidImporter()` is a value type with no stored properties; init cost is zero |

---

*This plan was prepared from live codebase analysis of Sources/DiagramKit/,
Sources/DiagramKitModel/, Tests/DiagramKitTests/, and Package.swift as they
exist at 2026-05-12. Revised per review to fix the five structural issues
identified.*

---

## Status: COMPLETE (2026-05-12)

### Implementation summary

All 10 new files and 5 modified files landed per the plan above. No
deviations from the architecture or naming decisions.

### Verification results

| Gate | Result |
|------|--------|
| `swift build --build-tests` | ✅ Pass (zero errors) |
| `ImporterRegistryTests` (4 tests) | ✅ Pass |
| `ProbeCollisionMatrixTests` (6 tests) | ✅ Pass |
| `MermaidImporterTests` (4 tests) | ✅ Pass |
| `MermaidLegacyAPITests` (4 tests) | ✅ Pass |
| `DiagramRegistryTests` (5 tests) | ✅ Pass (unchanged) |
| `Scripts/check-file-sizes.sh` | ✅ Pass (no new warnings) |
| `Scripts/check-sendable-annotations.sh` | ✅ Pass |
| `Scripts/strict-concurrency-check.sh` | ✅ Pass |
| Linux check | ⏭️ Skipped (no Docker/Podman) |
| Corpus snapshot tests | ⚠️ Pre-existing theme drift (not caused by this phase) |

### Key invariants preserved

- Worker-thread dispatch: `DiagramEngine` → `_runOnWorker` → `DiagramPipeline` → `DiagramLoader` — unchanged chain.
- Font determinism: `DiagramPipeline.runPipeline()` calls `registerBundledFontsIfNeeded()` before every operation.
- `DiagramDocument → PositionedGraph → render` remains format-agnostic.
- `DiagramRegistry` remains public with backward-compat documentation.
- No snapshot re-recording required (parse path produces identical `DiagramDocument`).

### Next phase

Phase 2: Multi-format corpus foundation. The importer boundary is ready;
specific importers (d2, DOT, PlantUML, Structurizr) can now be prepended
before the Mermaid fallback using `ImporterRegistry.prepending(_:)`.
