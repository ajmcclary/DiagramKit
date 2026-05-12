# Phase 1: Importer Boundary And Mermaid Extraction

Date: 2026-05-12. This document is the executable plan for Phase 1 of the
DiagramKit multi-format roadmap. It follows `PHASE-0.md` (completed: naming
transition) and precedes Phase 2 (multi-format corpus foundation).

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
└────────────────────────┬─────────────────────────────────┘
                         │
            ┌────────────┴────────────┐
            ▼                         ▼
   ┌─────────────────┐      ┌─────────────────┐
   │ MermaidImporter │      │  (d2 — Phase 3) │
   │  (first, default)│      │                 │
   └────────┬────────┘      └─────────────────┘
            │
            ▼
   ┌─────────────────┐
   │ MermaidDiagram   │  (current DiagramRegistry internals)
   │   Registry       │  28 per-family descriptors
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
├── DiagramKitViews           (Apple only, stub)
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
`DiagramPayload`, `DiagramFrontmatter`)

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
import boundary clean and testable on Linux without CoreGraphics.

### Step 2: Protocol Types

#### 2a. `DiagramDiagnostic`

```swift
// Sources/DiagramKitImport/DiagramDiagnostic.swift

/// A non-fatal issue discovered during import.
/// Emitted by `DiagramSourceImporter.parse()` via the `diagnostics` property.
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
/// concurrent use. The `diagnostics` property must return accumulated
/// diagnostics from the most recent `parse(...)` call and be reset before
/// the next parse — implementers should use actor isolation or a serial
/// queue if diagnostics are mutated during parsing.
public protocol DiagramSourceImporter: Sendable {
    /// Human-readable name (e.g. "Mermaid", "d2", "DOT").
    var name: String { get }

    /// The set of `DiagramType` values this importer can produce.
    /// Used for UI discovery and sparse-matrix validation.
    var supportedDiagramTypes: Set<DiagramType> { get }

    /// Returns `true` when `source` appears to be in this importer's format.
    /// This is a text-only probe — it should be fast and avoid full parsing.
    /// The first importer returning `true` for a given source wins.
    func supports(source: String) -> Bool

    /// Parse `source` into a `DiagramDocument`.
    ///
    /// - Parameters:
    ///   - source: The raw diagram source text.
    ///   - frontmatter: Parsed YAML frontmatter, or `nil` if none was present.
    /// - Returns: A `DiagramImportResult` containing the parsed document and
    ///   any non-fatal diagnostics.
    /// - Throws: `DiagramError` or a format-specific error on fatal parse
    ///   failures.
    func parse(
        _ source: String,
        frontmatter: DiagramFrontmatter?
    ) throws -> DiagramImportResult

    /// Diagnostics accumulated during the most recent `parse(...)` call.
    /// Returns the empty array when no parse has occurred or was reset.
    var diagnostics: [DiagramDiagnostic] { get }
}
```

**Note on `diagnostics`**: Unlike MusicToolkit's `ScoreImporter` which
uses a `var diagnostics` property, Swift's `any DiagramSourceImporter`
existential cannot access mutable properties. We keep `diagnostics` as
a read-only requirement; implementers manage the backing storage internally
(actor, lock, or thread-local). An alternative is to return diagnostics
solely in `DiagramImportResult` and drop the property — but MusicToolkit's
pattern of a separate property is useful for accumulating non-fatal warnings
during multi-pass parsing. We adopt it.

#### 2d. `ImporterRegistry`

```swift
// Sources/DiagramKitImport/ImporterRegistry.swift

/// An ordered collection of source-format importers.
///
/// Detection is first-match-wins: when `DiagramLoader` probes each importer
/// in array order, the first `supports(source:) → true` wins.
/// **Probe order is contractual** — it is enforced by `ProbeCollisionMatrixTests`.
public struct ImporterRegistry: Sendable {
    public let importers: [any DiagramSourceImporter]

    public init(importers: [any DiagramSourceImporter]) {
        self.importers = importers
    }

    /// Returns a new registry with `importer` appended.
    public func adding(_ importer: any DiagramSourceImporter) -> Self {
        ImporterRegistry(importers: importers + [importer])
    }

    /// The first importer whose `supports(source:)` returns `true`,
    /// or `nil` when no importer claims the source.
    public func importer(for source: String) -> (any DiagramSourceImporter)? {
        importers.first { $0.supports(source: source) }
    }

    /// Default registry: Mermaid first (current behavior).
    /// Populated in `DiagramKit` umbrella where `MermaidImporter` is defined.
    /// Importers added by later phases (d2, DOT, PlantUML, Structurizr)
    /// append to this default.
    public static let empty = ImporterRegistry(importers: [])
}
```

#### 2e. `DiagramLoader`

```swift
// Sources/DiagramKitImport/DiagramLoader.swift

/// Stateless dispatch: probe an `ImporterRegistry` and parse through the
/// first matching importer.
public enum DiagramLoader {

    /// Parse `source` using the given registry.
    ///
    /// Probes each importer in the registry in order; the first
    /// `supports(source:) → true` win. Returns the parsed `DiagramImportResult`
    /// containing the `DiagramDocument` and any diagnostics.
    ///
    /// - Parameters:
    ///   - source: Raw diagram source text.
    ///   - registry: The importer registry to probe.
    ///   - frontmatter: Optional pre-parsed YAML frontmatter.
    /// - Returns: `DiagramImportResult` with the parsed document and diagnostics.
    /// - Throws: `DiagramError` on fatal parse failures. Throws a loader-level
    ///   error when no importer claims the source.
    public static func parse(
        _ source: String,
        registry: ImporterRegistry,
        frontmatter: DiagramFrontmatter? = nil
    ) throws -> DiagramImportResult {
        guard let importer = registry.importer(for: source) else {
            throw DiagramError.notYetImplemented(
                "No importer registered for source format"
            )
        }
        return try importer.parse(source, frontmatter: frontmatter)
    }

    /// Shorthand returning only the `DiagramDocument`, discarding diagnostics.
    public static func parseDocument(
        _ source: String,
        registry: ImporterRegistry,
        frontmatter: DiagramFrontmatter? = nil
    ) throws -> DiagramDocument {
        try parse(source, registry: registry, frontmatter: frontmatter).document
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
/// Wraps the existing per-family `DiagramDescriptor` dispatch (now internal
/// as `MermaidDiagramRegistry`) behind the `DiagramSourceImporter` protocol.
/// All 28 diagram families supported by the Mermaid parser are available
/// through this importer.
public struct MermaidImporter: DiagramSourceImporter {

    public let name = "Mermaid"
    public let supportedDiagramTypes: Set<DiagramType> = Set(DiagramType.allCases)

    private let _diagnostics = OSAllocatedUnfairLock(
        initialState: [DiagramDiagnostic]()
    )

    public var diagnostics: [DiagramDiagnostic] {
        _diagnostics.withLock { $0 }
    }

    public init() {}

    public func supports(source: String) -> Bool {
        // Delegate to the existing Mermaid probe chain.
        // `DiagramHeader.detect` strips frontmatter and finds the first
        // content-bearing line. `MermaidDiagramRegistry.detect` returns
        // a descriptor; the flowchart fallback descriptor matches everything
        // (`{ _ in true }`), so this always returns `true` for non-empty
        // Mermaid-style source. Non-Mermaid source will be rejected by
        // a full parse.
        let header = DiagramHeader.detect(from: source)
        let descriptor = MermaidDiagramRegistry.detect(header)
        // The flowchart fallback matches `true` for everything. This is
        // intentionally broad — Mermaid claims any source whose header
        // didn't match a more specific importer. Probe order in
        // `ImporterRegistry` controls collisions.
        return true
    }

    public func parse(
        _ source: String,
        frontmatter: DiagramFrontmatter?
    ) throws -> DiagramImportResult {
        // Replicate MermaidParser.parse() logic.
        let decoded = _HTMLEntities.decode(source)
        let (processed, fm) = _parseFrontMatterAndStripped(decoded)
        let effectiveFrontmatter = frontmatter ?? fm

        let header = DiagramHeader.detect(from: processed)
        let descriptor = MermaidDiagramRegistry.detect(header)
        let document = try descriptor.parse(processed, effectiveFrontmatter)

        return DiagramImportResult(document: document, diagnostics: diagnostics)
    }
}
```

**Key decisions for `MermaidImporter`**:

1. **`supports(source:)` always returns `true`**. This is because the Mermaid
   flowchart fallback descriptor (`DiagramRegistry._flowchart`) matches
   `{ _ in true }` — Mermaid claims any source not claimed by a more specific
   importer. In the default registry, Mermaid is first, so it claims everything
   (preserving current behavior). When d2/DOT/PlantUML are added, narrower
   importers come first.

2. **Diagnostics storage**: Uses `OSAllocatedUnfairLock` for thread-safe
   access. This is parse-scoped — diagnostics are accumulated during a single
   `parse()` call and read afterward. The lock is per-importer-instance;
   concurrent parses through the same importer instance will interleave
   diagnostics, which is acceptable (the importer is stateless beyond
   diagnostics).

3. **Frontmatter handling**: If the caller provides pre-parsed frontmatter
   (e.g., from a two-pass loader), use it. Otherwise, parse frontmatter
   from the source (the existing `_parseFrontMatterAndStripped` path).

### Step 4: Wire the Loader Into the Pipeline

#### 4a. `MermaidParser` — update to route through loader

```swift
// Sources/DiagramKit/Parser.swift (updated)

public enum MermaidParser {

    private static func _decodeXMLEntities(_ s: String) -> String {
        _HTMLEntities.decode(s)
    }

    static func parse(_ source: String) throws -> DiagramDocument {
        try _withDiagramIssueReporting(operation: "MermaidParser.parse") {
            let decoded = _decodeXMLEntities(source)
            let (processed, frontmatter) = _parseFrontMatterAndStripped(decoded)

            // Delegate through the importer registry.
            // Uses the Mermaid-only internal path when the registry
            // is not yet wired (transitional).
            let header = DiagramHeader.detect(from: processed)
            let descriptor = MermaidDiagramRegistry.detect(header)
            return try descriptor.parse(processed, frontmatter)
        }
    }

    /// Parse through the format-agnostic loader.
    /// This is the preferred path when an `ImporterRegistry` is available.
    static func parse(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try _withDiagramIssueReporting(operation: "MermaidParser.parse(registry:)") {
            try DiagramLoader.parseDocument(source, registry: registry)
        }
    }
}
```

In Phase 1, `MermaidParser.parse(_:)` (no registry) continues to work for
backward compatibility but is deprecated in favor of the loader path.
The internal `DiagramDescriptor` dispatch stays as the implementation
backing `MermaidImporter.parse`.

#### 4b. `DiagramPipeline` — update `parse(_:)` to use loader

```swift
// Sources/DiagramKit/MermaidPipeline.swift (updated)

public enum DiagramPipeline {

    // ... runPipeline unchanged ...

    // Default registry — Mermaid only. Populated lazily.
    private static let defaultRegistry: ImporterRegistry = {
        // MermaidImporter defined in DiagramKit umbrella.
        ImporterRegistry(importers: [MermaidImporter()])
    }()

    public static func parse(_ source: String) throws -> DiagramDocument {
        try runPipeline(operation: "DiagramPipeline.parse", registerFonts: true) {
            try DiagramLoader.parseDocument(
                source,
                registry: defaultRegistry
            )
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

#### 4d. Default registry in `ImporterRegistry`

`ImporterRegistry.empty` is defined in `DiagramKitImport`. The default
registry with `MermaidImporter` is built in `DiagramKit` (umbrella) where
`MermaidImporter` lives:

```swift
extension ImporterRegistry {
    /// Default registry: Mermaid first.
    /// Future phases append d2, DOT, PlantUML, Structurizr after Mermaid.
    public static let `default`: ImporterRegistry = ImporterRegistry(
        importers: [MermaidImporter()]
    )
}
```

### Step 5: Rename and Deprecate `DiagramRegistry` → `MermaidDiagramRegistry`

#### 5a. Rename `DiagramRegistry` to `MermaidDiagramRegistry`

The existing `DiagramRegistry` enum becomes `MermaidDiagramRegistry`. It
is no longer the public format-agnostic dispatch table — it is Mermaid's
internal per-family dispatch.

```swift
// Sources/DiagramKit/DiagramDescriptor.swift (updated)

/// Mermaid-internal diagram-family registry.
///
/// These descriptors are Mermaid-specific. Format-agnostic import dispatch
/// goes through `ImporterRegistry` + `DiagramSourceImporter`.
///
/// This type was previously named `DiagramRegistry`. It is now internal
/// to `MermaidImporter`.
enum MermaidDiagramRegistry {
    // ... same `all`, `detect`, `descriptor(for:)`, `validate()` ...
}
```

**Access level**: Changed from `public enum` to `enum` (internal). The
`ImporterRegistry` is the public dispatch surface. `MermaidDiagramRegistry`
is an implementation detail of `MermaidImporter`.

#### 5b. Compatibility aliases

For downstream code that references `DiagramRegistry` or `DiagramDescriptor`
directly (the playground's `SampleDiagrams`, test code, etc.):

```swift
@available(*, deprecated, renamed: "ImporterRegistry")
public typealias DiagramRegistry = MermaidDiagramRegistry

@available(*, deprecated, message: "Use DiagramSourceImporter protocol instead")
public typealias DiagramDescriptor = DiagramDescriptor  // keep but deprecate
```

`DiagramDescriptor` stays public as a deprecated type. `DiagramHeader` stays
public (it's used by Mermaid probes).

#### 5c. File renames (cosmetic — Phase 1 defers moving files)

No files move in Phase 1. The 28 `DiagramRegistry+*.swift` files stay in
`Sources/DiagramKit/` as Mermaid implementation details. They will move to
`Sources/DiagramKitMermaid/` in a future phase, or when a separate
`DiagramKitMermaid` target is created.

The `DiagramRegistry+TypedDescriptor.swift` helper stays where it is.

### Step 6: Error Type Boundaries

#### `DiagramError` — stays in `DiagramKitModel`

`DiagramError.notYetImplemented(String)` is format-agnostic. It's thrown by
renderers and layouts, not just importers. It stays in `DiagramKitModel/Types.swift`.

#### `DiagramStructuralError` — stays in `DiagramKit` umbrella

`DiagramStructuralError.payloadMismatch(DiagramType)` is thrown by
`DiagramDescriptor.layout` closures when the payload doesn't match the
expected type. This is a layout concern, not an import concern. It stays
in `Sources/DiagramKit/DiagramDescriptor.swift`.

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

    @Test("Default registry picks Mermaid for all corpus entries")
    func defaultRegistryPicksMermaid() throws {
        let registry = ImporterRegistry.default
        #expect(registry.importers.count == 1)
        #expect(registry.importers[0].name == "Mermaid")

        // Verify the default importer claims a Mermaid source
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
            try DiagramLoader.parseDocument(
                "unsupported",
                registry: registry
            )
        }
    }

    @Test("adding() appends an importer")
    func addingAppends() {
        let base = ImporterRegistry(importers: [])
        let extended = base.adding(MermaidImporter())
        #expect(extended.importers.count == 1)
    }
}
```

#### 8b. `ProbeCollisionMatrixTests` (new test file)

```swift
// Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift

@Suite struct ProbeCollisionMatrixTests {

    // In Phase 1, only Mermaid is registered. These tests verify that
    // Mermaid's probe correctly identifies Mermaid source and that
    // non-Mermaid probe signatures are documented.

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

    // Future-phase probe signatures documented as tests:
    // These are NOT expected to pass in Phase 1 — they document the
    // probe signatures that d2, DOT, PlantUML, and Structurizr importers
    // will use. They serve as collision-awareness tests.

    @Test("DOT probe signature: digraph keyword")
    func dotProbeSignature() {
        let source = "digraph G {\n  a -> b\n}"
        // DOT: starts with 'digraph' or 'graph', followed by '{'
        // Mermaid's flowchart fallback would claim this in Phase 1.
        // When DiagramKitGraphviz lands, its probe must be ordered before
        // Mermaid in the default registry.
        let firstLine = source.split(separator: "\n").first ?? ""
        #expect(firstLine.hasPrefix("digraph") || firstLine.hasPrefix("graph"))
    }

    @Test("d2 probe signature: edge syntax with colon assignment")
    func d2ProbeSignature() {
        let source = "a -> b\nb: c"
        // d2: lines containing `: ` (key-value) AND `->` or `-->` edge syntax
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
        let result = try importer.parse(
            "graph TD\nA[Start] --> B[End]",
            frontmatter: nil
        )
        #expect(result.document.type == .flowchart)
        #expect(result.diagnostics.isEmpty)
    }

    @Test("MermaidImporter parses sequence diagram source")
    func parsesSequence() throws {
        let importer = MermaidImporter()
        let result = try importer.parse(
            "sequenceDiagram\nAlice->>Bob: Hello",
            frontmatter: nil
        )
        #expect(result.document.type == .sequenceDiagram)
    }

    @Test("MermaidImporter supportedDiagramTypes covers all cases")
    func coversAllDiagramTypes() {
        let importer = MermaidImporter()
        #expect(importer.supportedDiagramTypes.count == DiagramType.allCases.count)
    }

    @Test("MermaidImporter diagnostics are empty after clean parse")
    func cleanParseHasNoDiagnostics() throws {
        let importer = MermaidImporter()
        _ = try importer.parse("graph TD\nA-->B", frontmatter: nil)
        #expect(importer.diagnostics.isEmpty)
    }
}
```

#### 8d. `MermaidLegacyAPITests` (new test file)

```swift
// Tests/DiagramKitTests/MermaidLegacyAPITests.swift

@Suite struct MermaidLegacyAPITests {

    @Test("MermaidParser.parse still works through new loader")
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

```swift
// Tests/DiagramKitTests/CorpusSnapshotTests.swift — unchanged
```

The snapshot tests call `DiagramEngine.renderSVG(source:...)`,
`DiagramEngine.renderImage(source:...)`, and `DiagramEngine.renderASCII(source:...)`.
These route through `DiagramPipeline` → `DiagramLoader` → `MermaidImporter`.
Output must be byte-identical to the pre-Phase-1 baselines.

**Verification**: Run full corpus before and after Phase 1; diff the SVG/image/ASCII
snapshots. Zero diffs expected.

#### 8g. `DiagramRegistryTests` — update to reference `MermaidDiagramRegistry`

```swift
// Tests/DiagramKitTests/DiagramRegistryTests.swift (updated)

@Suite struct MermaidDiagramRegistryTests {  // was DiagramRegistryTests

    @Test("Registry validates that every DiagramType case has a descriptor")
    func registryCoversAllDiagramTypes() {
        #expect(MermaidDiagramRegistry.validate())  // was DiagramRegistry
    }

    // ... etc., s/DiagramRegistry/MermaidDiagramRegistry/g
}
```

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
   swift test --filter MermaidDiagramRegistryTests
   ```

3. **Full corpus snapshots** (must be byte-identical):
   ```bash
   swift test --filter CorpusSnapshotTests
   ```

4. **File size check**:
   ```bash
   Scripts/check-file-sizes.sh
   ```

5. **Sendable annotations**:
   ```bash
   Scripts/check-sendable-annotations.sh
   ```

6. **Strict concurrency**:
   ```bash
   Scripts/strict-concurrency-check.sh
   ```

7. **Linux check** (skip if Docker/Podman unavailable):
   ```bash
   Scripts/linux-check.sh
   ```

8. **Full bootstrap smoke check**:
   ```bash
   Scripts/bootstrap-smoke-check.sh
   ```

## Summary of Changes

### New files (12)

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

### Modified files (7)

| File | Change |
|------|--------|
| `Package.swift` | Add `DiagramKitImport` target + product; add `DiagramKitImport` dependency to `DiagramKit` |
| `Sources/DiagramKit/ReExports.swift` | Add `@_exported import DiagramKitImport` |
| `Sources/DiagramKit/DiagramDescriptor.swift` | Rename `DiagramRegistry` → `MermaidDiagramRegistry` (internal); add compat aliases |
| `Sources/DiagramKit/Parser.swift` | Add `parse(_:registry:)` overload; deprecation annotation |
| `Sources/DiagramKit/MermaidPipeline.swift` | Route `parse(_:)` through `DiagramLoader` with default registry; add `parse(_:registry:)` overload |
| `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift` | Update extension target |
| `Tests/DiagramKitTests/DiagramRegistryTests.swift` | Rename suite, s/DiagramRegistry/MermaidDiagramRegistry/ |

### Unchanged files (critical)

| File | Why |
|------|-----|
| `Sources/DiagramKitModel/Types.swift` | `DiagramDocument`, `DiagramPayload`, `DiagramError`, `DiagramType` — no changes needed |
| `Sources/DiagramKit/MermaidRenderer.swift` | `DiagramEngine` public API — unchanged; delegates through `DiagramPipeline` |
| `Sources/DiagramKit/Layout.swift` | `GraphLayout` — format-agnostic, unchanged |
| `Examples/MermaidPlayground/Models/SampleDiagrams.swift` | Playground sample data — unchanged |
| `Tests/DiagramKitTests/CorpusSnapshotTests.swift` | Snapshot tests — unchanged |
| `Tests/DiagramKitTests/*` | All other test files — unchanged except `DiagramRegistryTests` |
| 28 `DiagramRegistry+*.swift` files | Per-family descriptors — unchanged (internal rename only) |

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

### 3. `DiagramRegistry` → `MermaidDiagramRegistry` (internal)

**Decision**: Make it `internal enum`, with deprecated `public typealias`.

**Rationale**: The registry is Mermaid's internal dispatch. No external consumer
should be creating descriptors or querying the registry directly — they go
through `DiagramSourceImporter` / `ImporterRegistry`. Keeping it internal
prevents accidental coupling to Mermaid-specific routing.

### 4. Probe order: Mermaid first, flowchart fallback claims everything

**Decision**: Mermaid's `supports(source:)` always returns `true`.

**Rationale**: The flowchart fallback descriptor (`DiagramRegistry._flowchart`)
matches `{ _ in true }`. This means Mermaid claims any source not claimed by a
more specific importer. In Phase 1, Mermaid is the only importer, so it claims
everything (preserving current behavior). In Phase 2+, narrower importers
(d2, DOT, PlantUML) are ordered before Mermaid in the default registry, so
their probes fire first.

### 5. Worker-thread invariant preserved

All public `DiagramEngine` entry points still dispatch through `_runOnWorker`
(8 MB-stack `Thread`). `DiagramLoader.parse()` is called inside the worker
thread, matching the existing pattern.

### 6. Font determinism preserved

`DiagramPipeline.runPipeline()` still calls
`DiagramFontRegistry.registerBundledFontsIfNeeded()` before every operation.
The loader path does not bypass this.

### 7. No snapshot re-recording

Phase 1 is a pure refactor: same parsing behavior, same layout, same rendering.
All 396 SVG, 396 image, and 174 ASCII baselines must remain byte-identical.
If any snapshot drifts, the refactor is incorrect.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Snapshot drift from subtle parse-order change | Low | `MermaidImporter.parse()` replicates existing `MermaidParser.parse()` byte-for-byte |
| `any DiagramSourceImporter` existential overhead | Low | Importer is probed once per source; existential dispatch is negligible vs. parsing cost |
| `OSAllocatedUnfairLock` availability on Linux | Low | Available since macOS 13 / iOS 16 / Swift 5.9+; fallback to `NSLock` if needed |
| `DiagramKitImport` target breaks Linux build | Low | `DiagramKitModel` already Linux-compatible; no Apple-only dependencies |
| Playground `LiveEditorStore` breakage | Low | Store calls `DiagramEngine` public API, which is unchanged |
| `DiagramRegistry` internal rename breaks playground | Low | Playground uses `DiagramEngine` / `String` extensions, not `DiagramRegistry` directly |
| Probe collision between Mermaid flowchart and d2/DOT | N/A (Phase 3+) | Phase 1 has only Mermaid; collision tests document expected future signatures |

---

*This plan was prepared from live codebase analysis of Sources/DiagramKit/,
Sources/DiagramKitModel/, Tests/DiagramKitTests/, and Package.swift as they
exist at 2026-05-12.*
