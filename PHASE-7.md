# Phase 7: Exporter Protocol

Goal: add source generation after multiple importers prove the canonical model.

Date: 2026-05-12. This is the implementation plan for Phase 7 of the DiagramKit
multi-format roadmap. It follows the in-progress Phase 6 (PlantUML importers)
and precedes Phase 8 (Interactivity Primitives).

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [New Target: DiagramKitExport](#2-new-target-diagramkitexport)
3. [Exporter Protocol Design](#3-exporter-protocol-design)
4. [Sparse Conversion Matrix](#4-sparse-conversion-matrix)
5. [Slice 7A: Mermaid Exporter](#5-slice-7a-mermaid-exporter)
6. [Slice 7B: D2 Exporter](#6-slice-7b-d2-exporter)
7. [Slice 7C: Structurizr Exporter](#7-slice-7c-structurizr-exporter)
8. [Slice 7D: PlantUML Exporter](#8-slice-7d-plantuml-exporter)
9. [Round-Trip Test Framework](#9-round-trip-test-framework)
10. [Verification Gates](#10-verification-gates)
11. [Deferred / Out of Scope](#11-deferred--out-of-scope)
12. [Delivery Cadence](#12-delivery-cadence)

---

## 1. Architecture Overview

### 1.1 Motivation

After Phase 1-6, five importers (Mermaid, D2, Graphviz, Structurizr, PlantUML)
can parse source text into the canonical `DiagramDocument`. The next logical
step is the reverse path: emit source text from a `DiagramDocument`.

Exporters unlock:
- **Source-pane sync** in editors: user edits the graphical view, and the
  source pane updates via exporter re-emit.
- **Format conversion**: parse D2 source, export as Mermaid, render.
- **Round-trip fidelity testing**: confirm that parse→export→parse→export is
  stable.
- **Format migration tooling**: bulk-convert diagrams between formats.

### 1.2 Target Structure

```
Sources/
├── DiagramKitExport              ← NEW — protocol, registry, loader
│   ├── DiagramExporter.swift
│   ├── DiagramExportResult.swift
│   ├── ExporterRegistry.swift
│   ├── DiagramExportLoader.swift
│   └── DiagramExportError.swift
│
├── DiagramKit                    ← umbrella: MermaidExporter lives here
│   └── Exporter/
│       ├── MermaidExporter.swift
│       ├── MermaidExport/        ← per-family emit functions
│       │   ├── MermaidFlowchartExport.swift
│       │   ├── MermaidSequenceExport.swift
│       │   ├── MermaidClassExport.swift
│       │   ├── ... (28 families over time; start with flowchart,
│       │   │        sequence, class, ER, state, gantt, mindmap, c4)
│       │   └── MermaidExportHelpers.swift
│       └── MermaidExportDiagnostics.swift
│
├── DiagramKitD2
│   └── D2Exporter.swift
│
├── DiagramKitStructurizr
│   └── StructurizrExporter.swift
│
└── DiagramKitPlantUML
    └── Exporter/
        ├── PlantUMLExporter.swift          ← family dispatch
        ├── PlantUMLSequenceExporter.swift
        ├── PlantUMLClassExporter.swift
        ├── PlantUMLC4Exporter.swift
        └── PlantUMLExportDiagnostics.swift
```

**Graphviz DOT is deferred from Phase 7** — the DOT exporter requires
reconstruction of DOT attribute syntax (`[label="...", shape=box]`) from the
flowchart model, which is lossy in reverse. DOT export joins later when the
sparse matrix is denser and the DOT importer has broader coverage.

### 1.3 Dependency Graph

```
DiagramKitCommon
  → DiagramKitModel
    → DiagramKitImport (DiagramSourceImporter, DiagramDiagnostic, ImporterRegistry)
    → DiagramKitExport (DiagramExporter, DiagramExportResult, ExporterRegistry)
      ↓ depends on DiagramKitImport for DiagramDiagnostic reuse

Per-format exporter targets:
  DiagramKit (umbrella)        → DiagramKitExport, DiagramKitModel
  DiagramKitD2                 → DiagramKitExport, DiagramKitModel
  DiagramKitStructurizr        → DiagramKitExport, DiagramKitModel
  DiagramKitPlantUML           → DiagramKitExport, DiagramKitModel
```

**No circularity**: `DiagramKitExport` → `DiagramKitImport` → `DiagramKitModel` →
`DiagramKitCommon`. All edges are one-way.

### 1.4 Symmetry with Importers

| Import Concept | Export Equivalent |
|---------------|-------------------|
| `DiagramSourceImporter` | `DiagramExporter` |
| `DiagramImportResult` | `DiagramExportResult` |
| `DiagramDiagnostic` | `DiagramDiagnostic` (reused, no new type) |
| `ImporterRegistry` | `ExporterRegistry` |
| `DiagramLoader.parse` | `DiagramExportLoader.export` |
| `supports(source:)` probe | `supportedDiagramTypes` set |
| `parse(_:) → DiagramImportResult` | `export(_:) → DiagramExportResult` |

The symmetry is deliberate — anyone who understands the importer boundary
understands the exporter boundary.

### 1.5 Rules

These rules are non-negotiable and apply to every exporter:

1. **Supported conversion emits source.** When an exporter's
   `supportedDiagramTypes` includes the `DiagramDocument`'s type, `export(_:)`
   returns a non-empty `DiagramExportResult.source` string.

2. **Unsupported conversion emits diagnostics.** When a diagram type is not
   in `supportedDiagramTypes`, the exporter returns an empty source string
   and a `.unsupported` diagnostic explaining which type is unsupported.

3. **No conversion silently produces empty output.** Every call to
   `export(_:)` either returns valid source or a diagnostic explaining the
   failure. An empty source with zero diagnostics is a bug.

4. **Exporters do not patch source strings by hand for editor sync.**
   Exporters operate from `DiagramDocument` only — no "original source" +
   "delta" patching. If the model is the source of truth, the exporter emits
   the full source.

5. **Export source is valid input for the same format's importer.**
   For any exporter and supported diagram type:
   `importer.supports(source: exporter.export(doc).source) == true`.
   The exporter must produce syntactically valid source that its own
   importer's probe accepts.

---

## 2. New Target: DiagramKitExport

### 2.1 Package.swift Changes

```swift
// New product:
.library(name: "DiagramKitExport", targets: ["DiagramKitExport"]),

// New target:
.target(
    name: "DiagramKitExport",
    dependencies: ["DiagramKitModel", "DiagramKitImport"],
    swiftSettings: strictConcurrencySettings
),

// Add to DiagramKit umbrella dependencies:
.target(
    name: "DiagramKit",
    dependencies: [
        // ... existing ...
        "DiagramKitExport",
    ],
    ...
),

// Add to DiagramKitD2 dependencies:
.target(
    name: "DiagramKitD2",
    dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
    ...
),

// Add to DiagramKitStructurizr dependencies:
.target(
    name: "DiagramKitStructurizr",
    dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
    ...
),

// Add to DiagramKitPlantUML dependencies:
.target(
    name: "DiagramKitPlantUML",
    dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
    ...
),

// Add to DiagramKitTests testTarget:
"DiagramKitExport",

// Add to DiagramKit re-exports:
@_exported import DiagramKitExport
```

### 2.2 Platform Compatibility

`DiagramKitExport` depends on `DiagramKitModel` and `DiagramKitImport`, both
of which are Linux + Apple compatible. No CoreGraphics, AppKit, or UIKit
dependencies. The new target inherits `[.macOS, .iOS, .tvOS, .visionOS,
.macCatalyst]` + Linux implicitly through the dependency chain.

---

## 3. Exporter Protocol Design

### 3.1 `DiagramExporter` Protocol

```swift
// Sources/DiagramKitExport/DiagramExporter.swift

/// A format exporter that emits source text from a `DiagramDocument`.
///
/// Conformers register with `ExporterRegistry`. Each exporter declares the
/// set of `DiagramType` values it can export.
///
/// ## Concurrency Contract
/// `DiagramExporter` is `Sendable`. Implementations must be safe for
/// concurrent use. All state (including diagnostics) is returned in
/// `DiagramExportResult` — there is no shared mutable diagnostics property.
/// This keeps exporters stateless at the protocol boundary.
public protocol DiagramExporter: Sendable {
    /// Human-readable name (e.g. "Mermaid", "D2", "PlantUML").
    var name: String { get }

    /// The set of `DiagramType` values this exporter can emit as source.
    /// Used for UI discovery and sparse-matrix validation.
    var supportedDiagramTypes: Set<DiagramType> { get }

    /// Emit source text for the given diagram document.
    ///
    /// - Parameter document: The diagram document to export.
    /// - Returns: A `DiagramExportResult` containing the source string and
    ///   any non-fatal diagnostics (e.g., dropped styling, unsupported
    ///   sub-features).
    /// - Throws: `DiagramExportError` on fatal export failures (e.g.,
    ///   impossible model state).
    ///
    /// When `document.type` is not in `supportedDiagramTypes`, the exporter
    /// returns a result with an empty source and a `.unsupported` diagnostic.
    func export(_ document: DiagramDocument) throws -> DiagramExportResult
}
```

### 3.2 `DiagramExportResult`

```swift
// Sources/DiagramKitExport/DiagramExportResult.swift

/// The result of exporting a `DiagramDocument` to a source format.
public struct DiagramExportResult: Sendable {
    /// The generated source text. Empty when the diagram type is not
    /// supported by the exporter. An empty source MUST be accompanied by
    /// at least one diagnostic.
    public let source: String

    /// Non-fatal diagnostics collected during export.
    public let diagnostics: [DiagramDiagnostic]

    public init(source: String, diagnostics: [DiagramDiagnostic] = []) {
        self.source = source
        self.diagnostics = diagnostics
    }
}
```

### 3.3 `DiagramExportError`

```swift
// Sources/DiagramKitExport/DiagramExportError.swift

/// A fatal error during export.
public struct DiagramExportError: Error, LocalizedError, Sendable {
    public let message: String
    public let diagnostics: [DiagramDiagnostic]

    public init(message: String, diagnostics: [DiagramDiagnostic] = []) {
        self.message = message
        self.diagnostics = diagnostics
    }

    public var errorDescription: String? { message }
}
```

### 3.4 `ExporterRegistry`

```swift
// Sources/DiagramKitExport/ExporterRegistry.swift

/// An ordered collection of format exporters.
///
/// Lookup is by diagram type: `exporter(for:)` returns the first exporter
/// whose `supportedDiagramTypes` includes the given type.
/// Order matters when multiple exporters support the same type.
public struct ExporterRegistry: Sendable {
    public let exporters: [any DiagramExporter]

    public init(exporters: [any DiagramExporter]) {
        self.exporters = exporters
    }

    /// Returns a new registry with `exporter` appended.
    public func appending(_ exporter: any DiagramExporter) -> Self {
        ExporterRegistry(exporters: exporters + [exporter])
    }

    /// The first exporter that supports the given diagram type, or `nil`.
    public func exporter(for type: DiagramType) -> (any DiagramExporter)? {
        exporters.first { $0.supportedDiagramTypes.contains(type) }
    }

    /// All diagram types supported by any exporter in this registry.
    public var supportedDiagramTypes: Set<DiagramType> {
        exporters.reduce(into: []) { $0.formUnion($1.supportedDiagramTypes) }
    }

    /// Empty registry — no exporters registered.
    public static let empty = ExporterRegistry(exporters: [])
}
```

**Why `appending` not `prepending`?** Unlike importers (where probe order is
contractual because `supports(source:)` can overlap), exporters declare an
exact `supportedDiagramTypes` set. No two exporters should claim the same
diagram type in the default registry. `appending` matches the expected mental
model: "add a new exporter to the list."

### 3.5 `DiagramExportLoader`

```swift
// Sources/DiagramKitExport/DiagramExportLoader.swift

/// Stateless dispatch: export a `DiagramDocument` through the first
/// matching exporter in an `ExporterRegistry`.
public enum DiagramExportLoader {

    /// Export `document` using the given registry.
    ///
    /// - Parameters:
    ///   - document: The diagram document to export.
    ///   - format: The target format name (e.g. "mermaid", "d2").
    ///     Used only for error messages when no exporter matches.
    ///   - registry: The exporter registry to search.
    /// - Returns: `DiagramExportResult` with the generated source and any
    ///   diagnostics.
    /// - Throws: `DiagramExportError` when no exporter supports the diagram
    ///   type, or when the matched exporter throws a fatal error.
    public static func export(
        _ document: DiagramDocument,
        format: String,
        registry: ExporterRegistry
    ) throws -> DiagramExportResult {
        guard let exporter = registry.exporter(for: document.type) else {
            throw DiagramExportError(
                message: "No exporter registered for \(document.type.rawValue) in format \(format)",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "Diagram type '\(document.type.rawValue)' cannot be exported to '\(format)'"
                    )
                ]
            )
        }
        return try exporter.export(document)
    }

    /// Convenience: export using a specific exporter by name.
    public static func export(
        _ document: DiagramDocument,
        using exporterName: String,
        registry: ExporterRegistry
    ) throws -> DiagramExportResult {
        guard let exporter = registry.exporters.first(where: { $0.name == exporterName }) else {
            throw DiagramExportError(
                message: "No exporter named '\(exporterName)' in registry"
            )
        }
        return try exporter.export(document)
    }
}
```

### 3.6 Default Registry

The default export registry lives on `DiagramPipeline`, matching the pattern
established for `defaultRegistry` on the import side:

```swift
// Sources/DiagramKit/MermaidPipeline.swift (addition)

extension DiagramPipeline {
    /// Default export registry.
    /// Mermaid covers all 28 diagram types and is the primary exporter.
    /// D2, Structurizr, and PlantUML are appended for format conversion.
    ///
    /// When multiple exporters support a type, the first in the registry
    /// wins. Mermaid is first because it has the broadest coverage.
    public static let defaultExportRegistry: ExporterRegistry = {
        var registry = ExporterRegistry(exporters: [MermaidExporter()])
        // Subsequent slices append here:
        // registry = registry.appending(D2Exporter())
        // registry = registry.appending(StructurizrExporter())
        // registry = registry.appending(PlantUMLExporter())
        return registry
    }()
}
```

As each exporter slice lands, the default registry grows.

---

## 4. Sparse Conversion Matrix

Not every exporter supports every diagram type. This is the architectural
constraint, not a bug. The matrix below shows which types each exporter
will support. ✅ = planned support in this phase; ❌ = unsupported (diagnostic).

| Diagram Type    | Mermaid | D2  | Structurizr | PlantUML |
|-----------------|---------|-----|-------------|----------|
| flowchart       | ✅      | ✅  | ❌          | ✅(act)  |
| stateDiagram    | ✅      | ❌  | ❌          | ✅       |
| sequenceDiagram | ✅      | ❌  | ❌          | ✅       |
| classDiagram    | ✅      | ❌  | ❌          | ✅       |
| erDiagram       | ✅      | ✅  | ❌          | ❌       |
| gantt           | ✅      | ❌  | ❌          | ✅       |
| mindmap         | ✅      | ❌  | ❌          | ✅       |
| c4              | ✅      | ❌  | ✅          | ✅       |
| pie             | ✅      | ❌  | ❌          | ❌       |
| xyChart         | ✅      | ❌  | ❌          | ❌       |
| journey         | ✅      | ❌  | ❌          | ❌       |
| quadrantChart   | ✅      | ❌  | ❌          | ❌       |
| requirement     | ✅      | ❌  | ❌          | ❌       |
| gitGraph        | ✅      | ❌  | ❌          | ❌       |
| timeline        | ✅      | ❌  | ❌          | ❌       |
| sankey          | ✅      | ❌  | ❌          | ❌       |
| block           | ✅      | ❌  | ❌          | ❌       |
| packet          | ✅      | ❌  | ❌          | ❌       |
| kanban          | ✅      | ❌  | ❌          | ❌       |
| architecture    | ✅      | ✅  | ❌          | ❌       |
| radar           | ✅      | ❌  | ❌          | ❌       |
| treemap         | ✅      | ❌  | ❌          | ❌       |
| venn            | ✅      | ❌  | ❌          | ❌       |
| ishikawa        | ✅      | ❌  | ❌          | ❌       |
| treeView        | ✅      | ❌  | ❌          | ❌       |
| eventModeling   | ✅      | ❌  | ❌          | ❌       |
| wardleyBeta     | ✅      | ❌  | ❌          | ❌       |
| zenuml          | ✅      | ❌  | ❌          | ❌       |

**Mermaid** exports all 28 types because the Mermaid parser already handles
all 28. The exporter reverses the parse path per-family.

**D2** exports flowchart, ER, and architecture — the diagram types D2
natively represents as graph structures with nodes, edges, and containers.

**Structurizr** exports only C4 — Structurizr DSL has no syntax for other
diagram families.

**PlantUML** exports sequence, class, state/activity, mindmap, gantt, C4,
and flowchart (via activity diagrams). The supported set matches the
PlantUML import slices implemented in Phase 6.

**Exporting to an unsupported format** produces:
```swift
DiagramExportResult(
    source: "",
    diagnostics: [
        DiagramDiagnostic(
            severity: .unsupported,
            message: "Diagram type 'gantt' is not supported for export to 'Structurizr'"
        )
    ]
)
```

### 4.1 Matrix Validation Tests

```swift
// Tests/DiagramKitTests/Export/ExportMatrixTests.swift

@Suite struct ExportMatrixTests {
    @Test("Mermaid exporter supports all 28 diagram types")
    func mermaidExporterSupportsAllTypes() {
        let exporter = MermaidExporter()
        #expect(exporter.supportedDiagramTypes.count == 28)
    }

    @Test("D2 exporter supports flowchart, ER, architecture")
    func d2ExporterSupportedTypes() {
        let exporter = D2Exporter()
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(exporter.supportedDiagramTypes.contains(.erDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.architecture))
        #expect(!exporter.supportedDiagramTypes.contains(.sequenceDiagram))
    }

    // ... per-exporter matrix verification for Structurizr, PlantUML ...

    @Test("Unsupported type produces diagnostic, not empty source")
    func unsupportedTypeProducesDiagnostic() throws {
        let exporter = StructurizrExporter() // c4 only
        let doc = DiagramDocument(type: .gantt) // gantt is not c4
        let result = try exporter.export(doc)
        #expect(result.source.isEmpty)
        #expect(!result.diagnostics.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }

    @Test("No exporter silently returns empty source with zero diagnostics")
    func noSilentEmptyOutput() throws {
        // Verify that every exporter's unsupported path produces a diagnostic.
        let exporters: [any DiagramExporter] = [
            MermaidExporter(),
            D2Exporter(),
            StructurizrExporter(),
            PlantUMLExporter()
        ]
        for exporter in exporters {
            for type in DiagramType.allCases
                where !exporter.supportedDiagramTypes.contains(type)
            {
                let doc = DiagramDocument(type: type)
                let result = try exporter.export(doc)
                #expect(!result.diagnostics.isEmpty,
                    "\(exporter.name) produced empty diagnostics for unsupported type \(type.rawValue)")
            }
        }
    }
}
```

---

## 5. Slice 7A: Mermaid Exporter

**Slice goal**: emit valid Mermaid source for all 28 diagram types from
`DiagramDocument`.

**Where**: `Sources/DiagramKit/Exporter/MermaidExporter.swift` and
per-family emit helpers under `Sources/DiagramKit/Exporter/MermaidExport/`.

### 5.1 Why Mermaid First

Mermaid is the highest-value exporter:
- All 28 diagram types have known Mermaid syntax.
- The round-trip test (parse Mermaid → export Mermaid → parse again) is the
  primary correctness gate.
- Editor source-pane sync requires Mermaid export before any other format.
- The Mermaid importer is already the fallback with the broadest coverage.

### 5.2 Exporter Architecture

```swift
// Sources/DiagramKit/Exporter/MermaidExporter.swift

public struct MermaidExporter: DiagramExporter {
    public let name = "Mermaid"
    public let supportedDiagramTypes = Set(DiagramType.allCases)

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .flowchart(let model):
            return try MermaidFlowchartExport.emit(model)
        case .stateDiagram(let model):
            return try MermaidStateExport.emit(model)
        case .sequenceDiagram(let model):
            return try MermaidSequenceExport.emit(model)
        case .classDiagram(let model):
            return try MermaidClassExport.emit(model)
        case .erDiagram(let model):
            return try MermaidERExport.emit(model)
        case .gantt(let model):
            return try MermaidGanttExport.emit(model)
        case .mindmap(let model):
            return try MermaidMindmapExport.emit(model)
        case .c4(let model):
            return try MermaidC4Export.emit(model)
        case .pie(let model):
            return try MermaidPieExport.emit(model)
        // ... remaining 19 cases ...
        case .zenuml(let model):
            // ZenUML within Mermaid — emit the Mermaid wrapper syntax
            return try MermaidZenUMLExport.emit(model)
        }
    }
}
```

### 5.3 Per-Family Emit Functions

Each family gets its own emit function in a separate file. These are
internal helper structs/enums, not public API. They operate solely on the
typed payload (e.g., `ParsedGraphModel`, `SequenceDiagram`, etc.).

**Priority order for family implementation:**

| Priority | Family       | Complexity | Reason                                  |
|----------|-------------|------------|------------------------------------------|
| P0       | flowchart   | Medium     | Most common type; D2 round-trip target   |
| P0       | sequence    | Medium     | PlantUML round-trip target; Structurizr adjacent |
| P0       | class       | Medium     | High usage; PlantUML round-trip target   |
| P0       | ER          | Low        | Simple model; D2 round-trip target       |
| P0       | c4          | Medium     | Structurizr round-trip target            |
| P1       | state       | Medium     | PlantUML round-trip target               |
| P1       | gantt       | Medium     | PlantUML round-trip target               |
| P1       | mindmap     | Low        | Simple model; PlantUML round-trip target |
| P2       | pie         | Low        | Simple model                             |
| P2       | xyChart     | Low        | Simple model                             |
| P2       | gitGraph    | Medium     | Unique syntax                            |
| P2       | requirement | Medium     | Unique syntax                            |
| P3       | All others  | Varies     | Long tail; not needed for initial round-trips |

**P0 families** are implemented before the Mermaid exporter is considered
"slice complete." P1 and P2 families are implemented within Phase 7 but can
be deferred past the initial D2/Structurizr/PlantUML exporter slices.
P3 families may be deferred to Phase 10 (Release and Deprecation Cleanup)
if they have no round-trip targets.

### 5.4 Flowchart Emit Design

`ParsedGraphModel` contains `nodesInOrder: [MermaidGraphNode]` and
`edges: [MermaidGraphEdge]`. The flowchart emit function reconstructs Mermaid
flowchart syntax:

```
graph TD
  A[Start]
  B[Process]
  C{Decision}
  A --> B
  B --> C
  C -->|yes| D[End]
  C -->|no| B
```

**Mapping rules**:

- `direction`: emits `graph TD`, `graph LR`, etc.
- `MermaidGraphNode`:
  - `id` → node identifier
  - `label` → `[label]`, `(rounded)`, `{diamond}`, `((circle))`, etc.
    based on the node's shape/style.
  - `inlineStyles` → `style id fill:#xxx,stroke:#xxx` line.
  - `parentId` / `cluster` → `subgraph parentId [title] ... end`.
- `MermaidGraphEdge`:
  - `source` → `target` with arrow type: `-->`, `---`, `-.->`, `==>`.
  - `label` → `|label|` inline.
  - `style` → linkStyle directive.
- `classDefs` → `classDef name fill:...,stroke:...` directives.
- `classes` → `class id classDefName` assignments.
- `direction` → first line.

**Unspported model features → diagnostics** (non-blocking, source still emits):
- Labels with embedded newlines → flattened, diagnostic emitted.
- Unrecognized shape markers → emit as `[]` default, diagnostic emitted.
- Style properties not representable → diagnostic, skip the property.

### 5.5 Sequence Emit Design

`SequenceDiagram` has `actors: [SequenceActor]`, `items: [SequenceItem]`.
The emit function reconstructs:

```
sequenceDiagram
  participant Alice
  actor Bob
  Alice->>Bob: Hello
  activate Bob
  Bob-->>Alice: Hi
  deactivate Bob
  alt success
    Alice->>Bob: great
  else failure
    Alice->>Bob: retry
  end
```

**Mapping rules**:
- `SequenceActor`:
  - `id` = alias, `label` = display name.
  - `type` determines `participant` vs `actor`.
  - `isExplicit` = `true` → emit declaration at top.
  - Implicit actors (from message references) → skip declaration, let
    Mermaid auto-create them.
- `SequenceItem`:
  - `.message` → `from -> to: label` with arrow type.
  - `.activationStart(id)` → `activate id`.
  - `.activationEnd(id)` → `deactivate id`.
  - `.blockStart(type, label)` → `type label` (`alt success`).
  - `.blockDivider(type, label)` → `else label`.
  - `.blockEnd(type)` → `end`.
  - `.boxStart(fill, title, wrap)` → `box "title" #fill`.
  - `.boxEnd` → `end`.
  - `.note(position, actorIds, text)` → `Note position of actorIds: text`.
  - `.autonumberEvent(start, step, visible)` → `autonumber`.
- Arrow type mapping: `->>` → `->>`, `-->>` → `-->>`, `->` → `->`,
  `-->` → `-->`, `-x` → `-x`, `-o` → `-o`.

### 5.6 Class Emit Design

```
classDiagram
  class Animal {
    +String name
    -int age
    #void eat()
  }
  <<interface>> Flyable
  Animal <|-- Dog
  Dog *-- Tail
```

### 5.7 ER Emit Design

```
erDiagram
  CUSTOMER ||--o{ ORDER : places
  ORDER ||--|{ LINE_ITEM : contains
  CUSTOMER {
    string name
    int age
  }
```

### 5.8 C4 Emit Design

```
C4Context
  Person(customer, "Customer", "A customer")
  System(system, "System", "Description")
  Rel(customer, system, "Uses")
```

### 5.9 State Emit Design

```
stateDiagram-v2
  [*] --> Idle
  Idle --> Processing : start
  state Processing {
    [*] --> Validating
    Validating --> Executing
    Executing --> [*]
  }
  Processing --> Done
  Done --> [*]
```

### 5.10 Files to Create

```
Sources/DiagramKit/Exporter/
├── MermaidExporter.swift              (~80 lines)
├── MermaidExport/
│   ├── MermaidExportHelpers.swift     (~60 lines, shared formatting)
│   ├── MermaidFlowchartExport.swift   (~200 lines)
│   ├── MermaidSequenceExport.swift    (~180 lines)
│   ├── MermaidClassExport.swift       (~150 lines)
│   ├── MermaidERExport.swift          (~120 lines)
│   ├── MermaidC4Export.swift          (~150 lines)
│   ├── MermaidStateExport.swift       (~130 lines)
│   ├── MermaidGanttExport.swift       (~180 lines)
│   ├── MermaidMindmapExport.swift     (~80 lines)
│   ├── MermaidPieExport.swift         (~80 lines)
│   ├── MermaidGitGraphExport.swift    (~120 lines)
│   ├── MermaidRequirementExport.swift (~120 lines)
│   └── MermaidZenUMLExport.swift      (~60 lines)
└── MermaidExportDiagnostics.swift     (~30 lines)
```

**Total estimated source**: ~1,720 lines across 14 files. All under 500 lines.

### 5.11 Tests

**New test files**:
- `Tests/DiagramKitTests/Export/MermaidExporterTests.swift`
- `Tests/DiagramKitTests/Export/MermaidFlowchartExportTests.swift`
- `Tests/DiagramKitTests/Export/MermaidSequenceExportTests.swift`
- `Tests/DiagramKitTests/Export/MermaidClassExportTests.swift`
- `Tests/DiagramKitTests/Export/MermaidERExportTests.swift`
- `Tests/DiagramKitTests/Export/MermaidC4ExportTests.swift`

**Test structure** (per family):
- **Round-trip**: parse Mermaid source → export to Mermaid → parse again →
  structural equality (same nodes, edges, labels, types).
- **Idempotency**: export → parse → export → parse. The second parse should
  produce the same `DiagramDocument` as the first.
- **Diagnostic emission**: unsupported styling constructs produce warnings
  but don't block export.
- **Empty model → valid source**: `DiagramDocument(type: .flowchart)` with
  empty graph → produces `graph TD\n` (or equivalent minimum valid source).
- **Source validity**: every exported source passes
  `MermaidImporter().supports(source:)`.

---

## 6. Slice 7B: D2 Exporter

**Slice goal**: emit valid D2 source for flowchart, ER, and architecture
diagrams from `DiagramDocument`.

**Where**: `Sources/DiagramKitD2/D2Exporter.swift`

### 6.1 Supported Types

```swift
public struct D2Exporter: DiagramExporter {
    public let name = "D2"
    public let supportedDiagramTypes: Set<DiagramType> = [
        .flowchart,
        .erDiagram,
        .architecture
    ]
```

### 6.2 Flowchart → D2 Mapping

`ParsedGraphModel` → D2 syntax:

```
direction: right
Start: "Start" {
  shape: rectangle
}
Process: "Process" {
  shape: rectangle
}
Decision: "Decision" {
  shape: diamond
}
Start -> Process
Process -> Decision: yes
Decision -> Process: no
```

**Mapping rules**:
- `direction`: `TD` → `direction: down`; `LR` → `direction: right`. Default is
  `direction: down` (D2's default).
- Nodes:
  - Each `MermaidGraphNode` → D2 node block: `id: "label" { shape: shapes }`.
  - Mermaid shape markers map to D2 `shape:` hints: `[]` → `rectangle`,
    `()` → `rectangle` (rounded, via `border-radius`), `{}` → `diamond`,
    `(())` → `circle`, `>]` → `rectangle` (async via styling).
  - Subgraphs → D2 nested blocks: `parentId: "label" { childId: ... }`.
- Edges:
  - `MermaidGraphEdge` → `source -> target` or `source -> target: label`.
  - Arrow types: `-->` → `->` (D2 only has directional), `---` → `--`.
- Styling: `classDef` fill/stroke → D2 style properties on nodes.
  Unsupported Mermaid styling constructs → diagnostic.

### 6.3 ER → D2 Mapping

`ErDiagram` → D2 SQL table shapes:

```
CUSTOMER: {
  shape: sql_table
  id int {constraint: primary_key}
  name varchar
}
ORDER: {
  shape: sql_table
  ...
}
CUSTOMER -> ORDER: places {constraint: foreign_key}
```

### 6.4 Architecture → D2 Mapping

`ArchitectureDiagram` → D2 container + edge syntax:

```
services: "Services" {
  api: "API Gateway" {
    shape: hexagon
  }
  auth: "Auth Service"
}
services.api -> services.auth
```

### 6.5 Files

```
Sources/DiagramKitD2/
├── D2Exporter.swift      (~120 lines)
├── D2ExportHelpers.swift  (~60 lines)
```

### 6.6 Tests

- `Tests/DiagramKitTests/Export/D2ExporterTests.swift`
- `Tests/DiagramKitTests/Export/D2FlowchartExportTests.swift`
- `Tests/DiagramKitTests/Export/D2ERExportTests.swift`

**Tests** (~30 total):
- Round-trip: parse Mermaid flowchart → export D2 → parse D2 → structural
  equality.
- Round-trip: parse Mermaid ER → export D2 → parse D2 → structural equality.
- Round-trip: parse D2 flowchart → export D2 → parse D2 → idempotent.
- Unsupported type → diagnostic.
- Empty model → valid D2 source.
- Source validity: exported D2 source passes `D2Importer().supports(source:)`.

---

## 7. Slice 7C: Structurizr Exporter

**Slice goal**: emit valid Structurizr DSL source for C4 diagrams from
`DiagramDocument`.

**Where**: `Sources/DiagramKitStructurizr/StructurizrExporter.swift`

### 7.1 Supported Types

```swift
public struct StructurizrExporter: DiagramExporter {
    public let name = "Structurizr"
    public let supportedDiagramTypes: Set<DiagramType> = [.c4]
```

### 7.2 C4 → Structurizr Mapping

`C4Diagram` → Structurizr DSL:

```
workspace {
  model {
    customer = person "Customer" "A customer"
    system = softwareSystem "System" "Description"
    container = container system "Container" "Go" "Serves requests"
  }
  views {
    container system {
      include *
    }
  }
}
```

**Mapping rules**:
- `C4Shape`:
  - `.person` → `person alias "name" "description"`.
  - `.external_person` → `person alias "name" "description"` (external
    flagged in description/tags but Structurizr DSL uses same `person`
    type — external is semantic, not syntactic).
  - `.system` → `softwareSystem alias "name" "description"`.
  - `.external_system` → `softwareSystem alias "name" "description"`.
  - `.container` → `container systemAlias alias "name" "technology" "description"`.
  - `.container_db` → `container systemAlias alias "name" "technology" "description"`.
  - `.component` → `component containerAlias alias "name" "technology" "description"`.
  - `.boundary`, `.enterprise_boundary` → Structurizr groups are visual-only;
    emitted as comments with a diagnostic: `# Boundary: name`.
- `C4Relationship`:
  - `.rel` → `alias1 -> alias2 "label" "technology"`.
  - Directional rels (`.rel_d`, `.rel_u`, etc.) → standard `->` arrow;
    direction is layout hint, not syntactic in Structurizr DSL.
- `C4Boundary` → grouping inferred from nested element positions; Structurizr
  DSL has `group` keyword in views but boundaries in the `model` section are
  implicit.
- Diagram kind: `.context` → `systemLandscape`, `.container` → `container`,
  `.component` → `component`. Emitted as the view type.

### 7.3 Files

```
Sources/DiagramKitStructurizr/
├── StructurizrExporter.swift      (~150 lines)
└── StructurizrExportHelpers.swift  (~50 lines)
```

### 7.4 Tests

- `Tests/DiagramKitTests/Export/StructurizrExporterTests.swift`

**Tests** (~25 total):
- Round-trip: parse Structurizr C4 → export Structurizr → parse Structurizr →
  structural equality.
- Round-trip: parse Mermaid C4 → export Structurizr → parse Structurizr →
  parse Structurizr again (cross-format round-trip).
- Unsupported type → diagnostic.
- Source validity: exported source passes `StructurizrImporter().supports(source:)`.

---

## 8. Slice 7D: PlantUML Exporter

**Slice goal**: emit valid PlantUML source for the diagram types covered by
Phase 6 PlantUML importers.

**Where**: `Sources/DiagramKitPlantUML/Exporter/`

### 8.1 Supported Types

```swift
public struct PlantUMLExporter: DiagramExporter {
    public let name = "PlantUML"
    public let supportedDiagramTypes: Set<DiagramType> = [
        .sequenceDiagram,
        .classDiagram,
        .stateDiagram,    // includes activity
        .mindmap,
        .gantt,
        .c4,
        .flowchart        // emitted as activity diagram
    ]
```

### 8.2 Sequence → PlantUML Mapping

```
@startuml
participant Alice
actor Bob
Alice -> Bob: Hello
activate Bob
Bob --> Alice: Hi
deactivate Bob
alt success
  Alice -> Bob: great
else failure
  Alice -> Bob: retry
end
@enduml
```

Reverse of the PlantUML sequence parser's mapping. Boxes, notes, autonumber
are all supported.

### 8.3 Class → PlantUML Mapping

```
@startuml
class Animal {
  +name: String
  -age: Integer
  #protectedField
}
interface Flyable
Animal <|-- Dog
Dog *-- Tail
@enduml
```

### 8.4 C4 → PlantUML Mapping

```
@startuml
!include <C4/C4_Container>
Person(customer, "Customer", "A customer")
System(system, "System", "Description")
Rel(customer, system, "Uses")
@enduml
```

### 8.5 Files

```
Sources/DiagramKitPlantUML/Exporter/
├── PlantUMLExporter.swift              (~100 lines, family dispatch)
├── PlantUMLSequenceExporter.swift      (~150 lines)
├── PlantUMLClassExporter.swift         (~150 lines)
├── PlantUMLStateExporter.swift         (~150 lines)
├── PlantUMLMindmapExporter.swift       (~60 lines)
├── PlantUMLGanttExporter.swift         (~150 lines)
├── PlantUMLC4Exporter.swift            (~120 lines)
└── PlantUMLExportDiagnostics.swift     (~30 lines)
```

**Total estimated source**: ~910 lines across 8 files.

### 8.6 Tests

- `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift`
- `Tests/DiagramKitTests/Export/PlantUMLSequenceExportTests.swift`

**Tests** (~40 total):
- Per-family round-trip: parse PlantUML → export PlantUML → parse PlantUML →
  structural equality.
- Cross-format round-trip: parse Mermaid sequence → export PlantUML →
  parse PlantUML → structural equality.
- Unsupported type → diagnostic.
- Source validity: exported source passes `PlantUMLImporter().supports(source:)`.

---

## 9. Round-Trip Test Framework

### 9.1 Round-Trip Definition

A **full round-trip** for format F is:
```
parse_F(source_F) → doc1 → export_F(doc1) → source_F' → parse_F(source_F') → doc2
```

Success condition: `doc1` and `doc2` are structurally equivalent per-family.

A **cross-format round-trip** for formats A → B is:
```
parse_A(source_A) → doc1 → export_B(doc1) → source_B → parse_B(source_B) → doc2 → export_B(doc2) → source_B'
```

Success condition: `source_B` and `source_B'` produce equivalent documents
when parsed through B (idempotency in the target format).

### 9.2 Structural Equality

For each diagram family, define `assertStructurallyEqual` helpers that compare
payloads ignoring whitespace, comment differences, and stylistic detail:

```swift
// Tests/DiagramKitTests/Export/RoundTripHelpers.swift

/// Compares two ParsedGraphModels, ignoring fields that are not preserved
/// through a round-trip (e.g., comment text, source line numbers).
func assertFlowchartEqual(
    _ a: ParsedGraphModel,
    _ b: ParsedGraphModel,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(a.direction == b.direction)
    #expect(a.nodesInOrder.map(\.id) == b.nodesInOrder.map(\.id))
    #expect(a.nodesInOrder.map(\.label) == b.nodesInOrder.map(\.label))
    #expect(a.edges.map(\.source) == b.edges.map(\.source))
    #expect(a.edges.map(\.target) == b.edges.map(\.target))
    // ... per-field assertions
}

/// Compares two SequenceDiagrams for structural equivalence.
func assertSequenceEqual(_ a: SequenceDiagram, _ b: SequenceDiagram) {
    #expect(a.actors.map(\.id) == b.actors.map(\.id))
    #expect(a.items.count == b.items.count)
    // ... per-item comparisons
}
```

### 9.3 Round-Trip Test Suite

```swift
// Tests/DiagramKitTests/Export/RoundTripTests.swift

@Suite struct RoundTripTests {

    // MARK: - Mermaid self round-trip

    @Test("Mermaid flowchart round-trip preserves structure")
    func mermaidFlowchartRoundTrip() throws {
        let source = "graph TD\nA[Start] --> B[End]"
        let doc1 = try MermaidImporter().parse(source).document
        let source2 = try MermaidExporter().export(doc1).source
        let doc2 = try MermaidImporter().parse(source2).document

        guard case .flowchart(let model1) = doc1.payload,
              case .flowchart(let model2) = doc2.payload
        else { Issue.record("Wrong payload type"); return }

        assertFlowchartEqual(model1, model2)
    }

    @Test("Mermaid sequence round-trip is idempotent")
    func mermaidSequenceIdempotent() throws {
        let source = "sequenceDiagram\nAlice->>Bob: Hello\nBob-->>Alice: Hi"
        let doc1 = try MermaidImporter().parse(source).document
        let source2 = try MermaidExporter().export(doc1).source
        let doc2 = try MermaidImporter().parse(source2).document
        let source3 = try MermaidExporter().export(doc2).source

        // Second and third exports should be identical (idempotent).
        #expect(source2 == source3)
    }

    // MARK: - Cross-format round-trip: Mermaid → D2 → Mermaid

    @Test("Mermaid flowchart → D2 → Mermaid preserves nodes and edges")
    func mermaidToD2ToMermaidFlowchart() throws {
        let mermaidSource = "graph LR\nA[Hello] --> B[World]"
        let doc1 = try MermaidImporter().parse(mermaidSource).document
        let d2Source = try D2Exporter().export(doc1).source
        let doc2 = try D2Importer().parse(d2Source).document
        let mermaidSource2 = try MermaidExporter().export(doc2).source
        let doc3 = try MermaidImporter().parse(mermaidSource2).document

        guard case .flowchart(let model1) = doc1.payload,
              case .flowchart(let model2) = doc3.payload
        else { Issue.record("Wrong payload type"); return }

        // After Mermaid→D2→Mermaid, nodes/edges should be preserved.
        // Labels may be normalized (D2 strips Mermaid shape markers).
        #expect(model1.nodesInOrder.map(\.id) == model2.nodesInOrder.map(\.id))
        #expect(model1.edges.count == model2.edges.count)
    }

    // MARK: - Cross-format: Mermaid C4 → Structurizr → Structurizr

    @Test("Mermaid C4 → Structurizr is idempotent in Structurizr")
    func mermaidC4ToStructurizrIdempotent() throws {
        let mermaidSource = """
        C4Context
        Person(customer, "Customer", "A customer")
        System(system, "System", "Description")
        Rel(customer, system, "Uses")
        """
        let doc1 = try MermaidImporter().parse(mermaidSource).document
        let structurizrSource = try StructurizrExporter().export(doc1).source
        let doc2 = try StructurizrImporter().parse(structurizrSource).document
        let structurizrSource2 = try StructurizrExporter().export(doc2).source
        let doc3 = try StructurizrImporter().parse(structurizrSource2).document

        guard case .c4(let model2) = doc2.payload,
              case .c4(let model3) = doc3.payload
        else { Issue.record("Wrong payload type"); return }

        #expect(model2.shapes.map(\.alias) == model3.shapes.map(\.alias))
        #expect(model2.relationships.count == model3.relationships.count)
    }

    // MARK: - PlantUML cross-format

    @Test("Mermaid sequence → PlantUML → PlantUML is idempotent")
    func mermaidSequenceToPlantUMLIdempotent() throws {
        let mermaidSource = """
        sequenceDiagram
        participant Alice
        actor Bob
        Alice->>Bob: Hello
        Bob-->>Alice: Hi
        """
        let doc1 = try MermaidImporter().parse(mermaidSource).document
        let plantumlSource = try PlantUMLExporter().export(doc1).source
        let doc2 = try PlantUMLImporter().parse(plantumlSource).document
        let plantumlSource2 = try PlantUMLExporter().export(doc2).source
        let doc3 = try PlantUMLImporter().parse(plantumlSource2).document

        guard case .sequenceDiagram(let model2) = doc2.payload,
              case .sequenceDiagram(let model3) = doc3.payload
        else { Issue.record("Wrong payload type"); return }

        assertSequenceEqual(model2, model3)
    }

    // MARK: - Edge cases

    @Test("Empty diagram exports minimum valid source")
    func emptyDiagramExportsValidSource() throws {
        let doc = DiagramDocument(type: .flowchart)
        let result = try MermaidExporter().export(doc)
        #expect(!result.source.isEmpty)
        #expect(MermaidImporter().supports(source: result.source))

        // Should parse successfully.
        let reparsed = try MermaidImporter().parse(result.source)
        #expect(reparsed.document.type == .flowchart)
    }

    @Test("Unsupported cross-format produces diagnostics")
    func unsupportedCrossFormatDiagnostics() throws {
        let mermaidSource = "gantt\ndateFormat YYYY-MM-DD\nsection S\nT1: done, 2024-01-01, 2024-01-05"
        let doc = try MermaidImporter().parse(mermaidSource).document

        // Structurizr doesn't support gantt.
        let result = try StructurizrExporter().export(doc)
        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }
}
```

### 9.4 Test File Inventory

```
Tests/DiagramKitTests/Export/
├── ExportMatrixTests.swift               (~80 tests, sparse matrix validation)
├── RoundTripTests.swift                  (~60 tests, cross-format round-trips)
├── RoundTripHelpers.swift                (~100 lines, structural equality helpers)
├── ExporterRegistryTests.swift           (~15 tests)
├── MermaidExporterTests.swift            (~30 tests)
├── MermaidFlowchartExportTests.swift     (~20 tests)
├── MermaidSequenceExportTests.swift      (~15 tests)
├── MermaidClassExportTests.swift         (~15 tests)
├── MermaidERExportTests.swift            (~10 tests)
├── MermaidC4ExportTests.swift            (~10 tests)
├── D2ExporterTests.swift                 (~15 tests)
├── D2FlowchartExportTests.swift          (~15 tests)
├── D2ERExportTests.swift                 (~10 tests)
├── StructurizrExporterTests.swift        (~15 tests)
├── PlantUMLExporterTests.swift           (~15 tests)
└── PlantUMLSequenceExportTests.swift     (~15 tests)
```

**Total estimated tests**: ~340 across 16 files.

---

## 10. Verification Gates

### 10.1 Per-Slice Gates

For each exporter slice, before marking complete:

```bash
swift package dump-package
swift build --build-tests
swift test --filter <slice-specific suites>
swift test --filter ExportMatrixTests
swift test --filter ExporterRegistryTests
swift test --filter RoundTripTests
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
git diff --check
```

### 10.2 Full Phase 7 Gate

When all four exporter slices are complete:

```bash
swift test                                              # full suite
swift test --filter Export                              # all export tests
swift test --filter CorpusSnapshotTests                  # no regressions
Scripts/bootstrap-smoke-check.sh
Scripts/linux-check.sh                                   # skip if Docker/Podman unavailable
```

### 10.3 File-Size Constraint

No new `.swift` file exceeds 500 lines. Per-family export files are split
by concern. The MermaidExporter itself is a thin dispatcher (~80 lines); each
family's emit logic lives in its own file.

### 10.4 Sendable Annotation

All public types in `DiagramKitExport` must conform to `Sendable`. Structs
with only `Sendable` fields are implicitly `Sendable`. Any `@unchecked
Sendable` must carry a "Concurrency Contract" banner.

### 10.5 Regression Constraint

Exporters are read-only consumers of `DiagramDocument`. They do not modify
parsing, layout, rendering, or any existing pipeline code. No importer
regressions. No snapshot baseline changes.

---

## 11. Deferred / Out of Scope

The following are **explicitly deferred** from Phase 7:

- **Exporter protocol extensions on String / DiagramEngine.** The public API
  for export (e.g., `DiagramEngine.export(_:format:)` or
  `DiagramDocument.exportAsD2()`) is deferred to Phase 10 when the export
  registry is stable and has multi-format coverage. Phase 7 focuses on the
  protocol, registry, and per-format implementations.
- **Graphviz DOT exporter.** Requires attribute reconstruction
  (`[label="...", shape=box]`) from the flowchart model, which is lossy.
  Deferred until the DOT importer has broader coverage.
- **ZenUML exporter.** ZenUML is partially integrated through Mermaid's
  ZenUML support. A native exporter is lower priority.
- **Export-driven editor source sync.** The exporter protocol is the
  foundation for editor sync, but the sync logic lives in the interactive
  model (Phase 9), not in the exporter itself.
- **Real `test-diagrams.json` entries for export.** Multi-format corpus
  entries with `sources` maps that enable format-parametrized round-trip
  testing are deferred to Phase 10.
- **Snapshot baseline recording.** Exporters produce source text, not
  rendered output. No snapshot baselines are created or modified.
- **DiagramPipeline.renderASCII from exported source.** ASCII rendering
  remains Mermaid-specific. Export-based ASCII is deferred.
- **Comprehensive styling round-trip.** Exporters preserve structural
  content (nodes, edges, labels, types). Style fidelity (colors, fonts,
  exact shape markers) is best-effort and may lose detail through
  cross-format round-trips. This is documented behavior.

---

## 12. Delivery Cadence

Each exporter slice is independently shippable. The Mermaid exporter (7A)
must be implemented first because it's the round-trip baseline for all
cross-format tests.

| Slice | Exporter     | Est. Source | Est. Test | Est. Tests | Depends On |
|-------|-------------|------------|-----------|------------|------------|
| 7A    | Mermaid     | ~1,720      | ~1,200    | ~150       | —          |
| 7B    | D2          | ~180        | ~400      | ~40        | 7A (for round-trip fixtures) |
| 7C    | Structurizr | ~200        | ~300      | ~25        | 7A (for round-trip fixtures) |
| 7D    | PlantUML    | ~910        | ~500      | ~40        | 7A (for round-trip fixtures) |
|       | Shared infra| ~350        | ~800      | ~85        | —          |
| **Total** |         | **~3,360**  | **~3,200** | **~340**  |            |

**Shared infra** includes the `DiagramKitExport` target, `ExporterRegistryTests`,
`ExportMatrixTests`, `RoundTripHelpers`, and the cross-format `RoundTripTests`.

**Slice order is sequential** because 7A establishes the round-trip pattern
and provides the Mermaid fixtures that 7B-7D use for cross-format tests.
Each subsequent slice adds ~1 day of implementation + ~1 day of review.

**Dependencies between slices**:
- 7A blocks 7B, 7C, 7D (cross-format round-trip tests need Mermaid as the
  source of truth for fixture generation).
- 7B, 7C, 7D are independent of each other and can be implemented in any
  order after 7A.

---

*This plan was written against the in-progress Phase 6 state described in
`PHASE-6.md` and `PHASES.md`. The importer architecture (Phase 1-6) provides
the `DiagramDocument` model that exporters consume. The sparse matrix
constraints in `ANALYSIS.md` §6 guide the `supportedDiagramTypes` sets.*
