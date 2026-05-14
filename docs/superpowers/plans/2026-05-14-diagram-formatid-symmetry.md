# DiagramFormatID Symmetric Importer Dispatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `DiagramFormatID` the shared dispatch key for both importers and exporters while preserving probe-based content-driven importer selection as the primary path.

**Architecture:** Move `DiagramFormatID` from `DiagramKitExport` to `DiagramKitCommon` so both `DiagramKitImport` and `DiagramKitExport` see it without circular dependencies. Add `var formatID: DiagramFormatID { get }` to `DiagramSourceImporter`; declare it on the five built-in importers (`MermaidImporter`, `D2Importer`, `GraphvizImporter`, `StructurizrImporter`, `PlantUMLImporter`). Add `ImporterRegistry.importer(for formatID:)` linear-scan lookup and `DiagramLoader.parse(_:as formatID:registry:)` typed dispatch. Migrate `CorpusEntry.expectedImporters` from `[String: String]?` to `[DiagramFormatID: DiagramFormatID]?` with decode/encode helpers; flip the 54 JSON value occurrences across 27 corpus entries. Deprecate `DiagramExportLoader.export(_:using exporterName:registry:)` in favor of the formatID-keyed entry point.

**Tech Stack:** Swift 6, swift-testing (`@Suite`, `@Test`, `#expect`, `#require`), SwiftPM. Library targets `DiagramKitCommon`, `DiagramKitImport`, `DiagramKitExport`, plus the five format slices (`DiagramKitMermaid` housed in the umbrella `DiagramKit` for the Mermaid importer, plus `DiagramKitD2`, `DiagramKitGraphviz`, `DiagramKitStructurizr`, `DiagramKitPlantUML`). Test target `DiagramKitTests`. Run tests with `swift test --filter <name>`.

**Spec reference:** `docs/superpowers/specs/2026-05-14-diagram-formatid-symmetry-design.md` (commit `4f6e02b`).

**Working directory:** `/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift`. Commit-by-commit on `main` — no branches, no worktrees (per project standing default).

**No snapshot rebaselining required.** None of these changes touches renderers, layouts, or geometry-producing paths.

---

## Task 1: Move `DiagramFormatID` to `DiagramKitCommon`

**Files:**
- Create: `Sources/DiagramKitCommon/DiagramFormatID.swift`
- Delete: `Sources/DiagramKitExport/DiagramFormatID.swift`
- Create: `Tests/DiagramKitTests/DiagramFormatIDLocationTests.swift`

- [ ] **Step 1: Write the failing test (compile-time location check)**

Create `Tests/DiagramKitTests/DiagramFormatIDLocationTests.swift`:

```swift
import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport

@Suite struct DiagramFormatIDLocationTests {

    @Test("DiagramFormatID resolves from DiagramKitCommon")
    func resolvesFromCommon() {
        let fromCommon: DiagramKitCommon.DiagramFormatID = .mermaid
        #expect(fromCommon.rawValue == "mermaid")
    }

    @Test("DiagramFormatID is a single type across Import and Export")
    func sameTypeAcrossModules() {
        let viaImport: DiagramFormatID = .d2
        let viaExport: DiagramFormatID = .d2
        #expect(viaImport == viaExport)
        #expect(type(of: viaImport) == type(of: viaExport))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DiagramFormatIDLocationTests`
Expected: build error — `DiagramKitCommon.DiagramFormatID` is not a known type (the move hasn't happened yet).

- [ ] **Step 3: Create `Sources/DiagramKitCommon/DiagramFormatID.swift`**

Write the file body verbatim (same content as the current `Sources/DiagramKitExport/DiagramFormatID.swift`):

```swift
/// Canonical identifier for a diagram source format.
///
/// Used to look up exporters by format in `ExporterRegistry` and importers
/// by format in `ImporterRegistry`. Matches the canonical lowercase IDs
/// already used in `CorpusEntry` (`DiagramKitTestSupport`) and the
/// `ProbeCollisionMatrixTests` collision matrix.
public struct DiagramFormatID: Sendable, Hashable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public var description: String { rawValue }

    public static let mermaid     = DiagramFormatID(rawValue: "mermaid")
    public static let d2          = DiagramFormatID(rawValue: "d2")
    public static let graphviz    = DiagramFormatID(rawValue: "graphviz")
    public static let structurizr = DiagramFormatID(rawValue: "structurizr")
    public static let plantuml    = DiagramFormatID(rawValue: "plantuml")
}
```

- [ ] **Step 4: Delete `Sources/DiagramKitExport/DiagramFormatID.swift`**

Run: `git rm Sources/DiagramKitExport/DiagramFormatID.swift`

- [ ] **Step 5: Verify build**

Run: `swift build`
Expected: PASS. `DiagramKitExport` continues to compile transparently because it already declares `import DiagramKitCommon` (verified in `Sources/DiagramKitExport/DiagramExporter.swift:1`, etc.).

- [ ] **Step 6: Run the location test plus the existing infrastructure test**

Run: `swift test --filter DiagramFormatIDLocationTests`
Expected: PASS (2 tests).

Run: `swift test --filter DiagramExportInfrastructureTests`
Expected: PASS — `DiagramFormatID.mermaid.rawValue == "mermaid"` etc. still resolve because public API is unchanged; only the declaring module shifted.

- [ ] **Step 7: Run smoke gates**

Run: `Scripts/check-sendable-annotations.sh`
Expected: green.

Run: `Scripts/check-file-sizes.sh`
Expected: no new yellow/red entries.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitCommon/DiagramFormatID.swift \
        Tests/DiagramKitTests/DiagramFormatIDLocationTests.swift
git rm Sources/DiagramKitExport/DiagramFormatID.swift
git commit -m "$(cat <<'EOF'
refactor(common): relocate DiagramFormatID into DiagramKitCommon

The exporter and importer modules both need a canonical format
identifier. Hosting the type in DiagramKitCommon — the lowest
shared layer — lets DiagramSourceImporter adopt the same key
without inverting the existing module layering. Public API
unchanged; the type still wraps a rawValue: String and carries
the same five canonical constants.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `formatID` to `DiagramSourceImporter` and the five built-in importers

**Files:**
- Modify: `Sources/DiagramKitImport/DiagramSourceImporter.swift` (protocol header + new requirement)
- Modify: `Sources/DiagramKit/MermaidImporter.swift` (add `formatID`)
- Modify: `Sources/DiagramKitD2/D2Importer.swift` (add `formatID`)
- Modify: `Sources/DiagramKitGraphviz/GraphvizImporter.swift` (add `formatID`)
- Modify: `Sources/DiagramKitStructurizr/StructurizrImporter.swift` (add `formatID`)
- Modify: `Sources/DiagramKitPlantUML/PlantUMLImporter.swift` (add `formatID`)
- Create: `Tests/DiagramKitTests/DiagramSourceImporterFormatIDTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/DiagramSourceImporterFormatIDTests.swift`:

```swift
import Testing
@testable import DiagramKit
import DiagramKitCommon
import DiagramKitImport
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

@Suite struct DiagramSourceImporterFormatIDTests {

    @Test("MermaidImporter declares formatID = .mermaid")
    func mermaidFormatID() {
        #expect(MermaidImporter().formatID == .mermaid)
    }

    @Test("D2Importer declares formatID = .d2")
    func d2FormatID() {
        #expect(D2Importer().formatID == .d2)
    }

    @Test("GraphvizImporter declares formatID = .graphviz")
    func graphvizFormatID() {
        #expect(GraphvizImporter().formatID == .graphviz)
    }

    @Test("StructurizrImporter declares formatID = .structurizr")
    func structurizrFormatID() {
        #expect(StructurizrImporter().formatID == .structurizr)
    }

    @Test("PlantUMLImporter declares formatID = .plantuml")
    func plantumlFormatID() {
        #expect(PlantUMLImporter().formatID == .plantuml)
    }

    @Test("Default registry importers all expose a non-empty formatID rawValue")
    func allDefaultRegistryImportersHaveNonEmptyRawValue() {
        for importer in DiagramPipeline.defaultRegistry.importers {
            #expect(!importer.formatID.rawValue.isEmpty, "\(importer.name) has empty formatID rawValue")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DiagramSourceImporterFormatIDTests`
Expected: build error — `formatID` is not a member of `MermaidImporter` (and the others), and the protocol does not yet declare it.

- [ ] **Step 3: Add the protocol requirement and rewrite the header**

In `Sources/DiagramKitImport/DiagramSourceImporter.swift`, replace the existing `/// ## Identity model` doc block (lines 8–15) with the symmetric version, and add the `formatID` requirement after `var name: String { get }`:

```swift
/// A source-format importer that parses text into a `DiagramDocument`.
///
/// Conformers register with `ImporterRegistry`. The registry probes each
/// importer in order; the first `supports(source:)` match wins.
///
/// ## Identity model
/// Importers carry both a `name: String` display label and a typed
/// `formatID: DiagramFormatID` dispatch key. The name is for UI /
/// diagnostics; the formatID is for typed registry lookup (e.g.
/// `ImporterRegistry.importer(for: .d2)`) and round-trip pairing with
/// the matching exporter. Probe-based first-match-wins selection on
/// `supports(source:)` remains the primary dispatch path for content-
/// driven detection — the typed by-ID lookup is an orthogonal,
/// caller-asserted path.
///
/// ## Concurrency Contract
/// `DiagramSourceImporter` is `Sendable`. Implementations must be safe for
/// concurrent use. All parsing state (including diagnostics) is returned in
/// `DiagramImportResult` — there is no shared mutable diagnostics property.
/// This keeps importers stateless at the protocol boundary.
public protocol DiagramSourceImporter: Sendable {
    /// Human-readable name (e.g. "Mermaid", "D2", "DOT").
    /// Display label only — not used for routing.
    var name: String { get }

    /// Canonical format identifier. Used by `ImporterRegistry.importer(for:)`
    /// and `DiagramLoader.parse(_:as:registry:)` for typed dispatch.
    var formatID: DiagramFormatID { get }

    /// The set of `DiagramType` values this importer can produce.
    /// Used for UI discovery and sparse-matrix validation.
    var supportedDiagramTypes: Set<DiagramType> { get }

    /// Whether this importer is the registry-wide fallback. Fallback
    /// importers MUST return `true` from `supports(source:)` for any
    /// non-empty input. `ImporterRegistry` enforces "at most one
    /// fallback, ordered last."
    ///
    /// Default: `false` (most importers are narrow / format-specific).
    var isFallback: Bool { get }

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

public extension DiagramSourceImporter {
    /// Default: narrow / format-specific importer (not a fallback).
    var isFallback: Bool { false }
}
```

Also add `import DiagramKitCommon` at the top of the file (right under the existing `import DiagramKitModel`):

```swift
import DiagramKitModel
import DiagramKitCommon
```

- [ ] **Step 4: Declare `formatID` on `MermaidImporter`**

In `Sources/DiagramKit/MermaidImporter.swift`, after the existing `public let name = "Mermaid"` line, add:

```swift
public let formatID = DiagramFormatID.mermaid
```

- [ ] **Step 5: Declare `formatID` on `D2Importer`**

In `Sources/DiagramKitD2/D2Importer.swift`, after the existing `public let name = "D2"` line, add:

```swift
public let formatID = DiagramFormatID.d2
```

Also add `import DiagramKitCommon` at the top if it's not already there.

- [ ] **Step 6: Declare `formatID` on `GraphvizImporter`**

In `Sources/DiagramKitGraphviz/GraphvizImporter.swift`, after the existing `public let name = "Graphviz"` line, add:

```swift
public let formatID = DiagramFormatID.graphviz
```

Also add `import DiagramKitCommon` at the top if it's not already there.

- [ ] **Step 7: Declare `formatID` on `StructurizrImporter`**

In `Sources/DiagramKitStructurizr/StructurizrImporter.swift`, after the existing `public let name = "Structurizr"` line, add:

```swift
public let formatID = DiagramFormatID.structurizr
```

Also add `import DiagramKitCommon` at the top if it's not already there.

- [ ] **Step 8: Declare `formatID` on `PlantUMLImporter`**

In `Sources/DiagramKitPlantUML/PlantUMLImporter.swift`, after the existing `public let name = "PlantUML"` line, add:

```swift
public let formatID = DiagramFormatID.plantuml
```

Also add `import DiagramKitCommon` at the top if it's not already there.

- [ ] **Step 9: Run the new test to verify it passes**

Run: `swift test --filter DiagramSourceImporterFormatIDTests`
Expected: PASS (6 tests).

- [ ] **Step 10: Run the existing importer-registry test to verify no regression**

Run: `swift test --filter ImporterRegistryTests`
Expected: PASS — no behavioral change; the existing tests probe by content, which still works.

- [ ] **Step 11: Run smoke gates**

Run: `Scripts/check-sendable-annotations.sh`
Expected: green (no new `@unchecked Sendable` annotations).

Run: `Scripts/check-file-sizes.sh`
Expected: no new yellow/red entries.

- [ ] **Step 12: Commit**

```bash
git add Sources/DiagramKitImport/DiagramSourceImporter.swift \
        Sources/DiagramKit/MermaidImporter.swift \
        Sources/DiagramKitD2/D2Importer.swift \
        Sources/DiagramKitGraphviz/GraphvizImporter.swift \
        Sources/DiagramKitStructurizr/StructurizrImporter.swift \
        Sources/DiagramKitPlantUML/PlantUMLImporter.swift \
        Tests/DiagramKitTests/DiagramSourceImporterFormatIDTests.swift
git commit -m "$(cat <<'EOF'
feat(import): add DiagramFormatID to DiagramSourceImporter protocol

Mirror the exporter side: importers now carry both a human-readable
name and a typed formatID dispatch key. Existing probe-based
first-match-wins selection is unchanged; the formatID exists for
typed registry lookup and round-trip pairing. Declared on the five
built-in importers (Mermaid/D2/Graphviz/Structurizr/PlantUML).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Typed by-ID lookup on `ImporterRegistry` and `DiagramLoader`

**Files:**
- Modify: `Sources/DiagramKitImport/ImporterRegistry.swift` (add typed lookup method)
- Modify: `Sources/DiagramKitImport/DiagramLoader.swift` (add typed parse entry points)
- Create: `Tests/DiagramKitTests/ImporterRegistryByIDTests.swift`
- Create: `Tests/DiagramKitTests/DiagramLoaderByIDTests.swift`

- [ ] **Step 1: Write the failing test for `ImporterRegistry.importer(for formatID:)`**

Create `Tests/DiagramKitTests/ImporterRegistryByIDTests.swift`:

```swift
import Testing
@testable import DiagramKit
import DiagramKitCommon
import DiagramKitImport
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

@Suite struct ImporterRegistryByIDTests {

    @Test("Default registry by-ID lookup returns the matching importer")
    func defaultRegistryByID() throws {
        let registry = DiagramPipeline.defaultRegistry

        let d2 = try #require(registry.importer(for: .d2))
        #expect(d2.name == "D2")
        #expect(d2.formatID == .d2)

        let mermaid = try #require(registry.importer(for: .mermaid))
        #expect(mermaid.name == "Mermaid")
        #expect(mermaid.formatID == .mermaid)

        let plantuml = try #require(registry.importer(for: .plantuml))
        #expect(plantuml.name == "PlantUML")

        let graphviz = try #require(registry.importer(for: .graphviz))
        #expect(graphviz.name == "Graphviz")

        let structurizr = try #require(registry.importer(for: .structurizr))
        #expect(structurizr.name == "Structurizr")
    }

    @Test("Unknown formatID returns nil")
    func unknownFormatIDReturnsNil() {
        let registry = DiagramPipeline.defaultRegistry
        #expect(registry.importer(for: DiagramFormatID(rawValue: "asciiart")) == nil)
    }

    @Test("Empty registry returns nil for any formatID")
    func emptyRegistryReturnsNil() {
        let registry = ImporterRegistry.empty
        #expect(registry.importer(for: .mermaid) == nil)
        #expect(registry.importer(for: .d2) == nil)
    }

    @Test("By-ID lookup survives prepending")
    func byIDAfterPrepending() throws {
        let base = ImporterRegistry(importers: [MermaidImporter()])
        let augmented = base.prepending(D2Importer())

        let d2 = try #require(augmented.importer(for: .d2))
        #expect(d2.formatID == .d2)

        let mermaid = try #require(augmented.importer(for: .mermaid))
        #expect(mermaid.formatID == .mermaid)
    }

    @Test("By-ID lookup survives appending (broad fallback case)")
    func byIDAfterAppending() throws {
        let base = ImporterRegistry(importers: [D2Importer()])
        let augmented = base.appending(MermaidImporter())

        let d2 = try #require(augmented.importer(for: .d2))
        #expect(d2.formatID == .d2)

        let mermaid = try #require(augmented.importer(for: .mermaid))
        #expect(mermaid.formatID == .mermaid)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ImporterRegistryByIDTests`
Expected: build error — `importer(for: DiagramFormatID)` has no overload taking `DiagramFormatID`.

- [ ] **Step 3: Add the typed lookup method**

In `Sources/DiagramKitImport/ImporterRegistry.swift`, ensure `import DiagramKitCommon` is at the top, then append a new method right before the `public static let empty = ImporterRegistry(importers: [])` line:

```swift
    /// The first importer in this registry whose `formatID` matches, or
    /// `nil` when none declares this format. Orthogonal to probe-based
    /// dispatch — does not call `supports(source:)`. Use this when the
    /// caller has already asserted the source format and wants typed
    /// routing instead of content-driven detection.
    public func importer(for formatID: DiagramFormatID) -> (any DiagramSourceImporter)? {
        importers.first { $0.formatID == formatID }
    }
```

- [ ] **Step 4: Run the registry-by-ID test to verify it passes**

Run: `swift test --filter ImporterRegistryByIDTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Write the failing test for `DiagramLoader.parse(_:as:registry:)`**

Create `Tests/DiagramKitTests/DiagramLoaderByIDTests.swift`:

```swift
import Testing
@testable import DiagramKit
import DiagramKitCommon
import DiagramKitImport
import DiagramKitModel
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

@Suite struct DiagramLoaderByIDTests {

    private static let mermaidSource = "graph TD\nA-->B"
    private static let d2Source = "A -> B"

    @Test("Typed parse with .mermaid returns a flowchart document")
    func parseAsMermaid() throws {
        let result = try DiagramLoader.parse(
            Self.mermaidSource,
            as: .mermaid,
            registry: DiagramPipeline.defaultRegistry
        )
        #expect(result.document.type == .flowchart)
    }

    @Test("Typed parse with .d2 returns a flowchart document on D2 source")
    func parseAsD2() throws {
        let result = try DiagramLoader.parse(
            Self.d2Source,
            as: .d2,
            registry: DiagramPipeline.defaultRegistry
        )
        #expect(result.document.type == .flowchart)
    }

    @Test("Typed parse bypasses supports(source:) probe")
    func typedParseBypassesProbe() throws {
        // The Mermaid source ("graph TD\nA-->B") would not pass the D2
        // importer's content-driven probe in normal probe-based dispatch.
        // By-ID dispatch asserts the format and feeds the source straight
        // to D2Importer.parse. The contract: the call either succeeds with
        // whatever D2 produces, or throws. It must not silently re-route.
        let registry = DiagramPipeline.defaultRegistry

        // We don't assert success or failure of D2 parsing on a Mermaid
        // source — that's an implementation detail of the D2 parser. We
        // only assert that the call routes to D2 and does not fall back
        // to the Mermaid importer.
        do {
            let result = try DiagramLoader.parse(
                Self.mermaidSource,
                as: .d2,
                registry: registry
            )
            // If D2 happens to accept Mermaid-shaped input, the document
            // still routes through D2 (not Mermaid). We can't observe
            // "which importer ran" from the document alone; the assertion
            // is that the by-ID dispatch path did not error with
            // "no importer registered."
            _ = result
        } catch let error as DiagramError {
            // Acceptable: D2 parser may reject the Mermaid-shaped source.
            // Reject the unrelated "no importer registered" form.
            #expect(!String(describing: error).contains("no importer registered"))
        }
    }

    @Test("Unknown formatID throws unrecognizedFormat")
    func unknownFormatIDThrows() {
        let registryWithoutD2 = ImporterRegistry(importers: [MermaidImporter()])
        #expect(throws: DiagramError.self) {
            _ = try DiagramLoader.parse(
                Self.mermaidSource,
                as: .d2,
                registry: registryWithoutD2
            )
        }
    }

    @Test("Unknown formatID error message names the missing format")
    func unknownFormatIDMessage() {
        let registryWithoutD2 = ImporterRegistry(importers: [MermaidImporter()])
        do {
            _ = try DiagramLoader.parse(
                Self.mermaidSource,
                as: .d2,
                registry: registryWithoutD2
            )
            Issue.record("expected DiagramError.unrecognizedFormat")
        } catch let error as DiagramError {
            #expect(String(describing: error).contains("d2"))
        } catch {
            Issue.record("expected DiagramError, got \(error)")
        }
    }

    @Test("parseDocument(_:as:registry:) shorthand returns the same document")
    func parseDocumentShorthand() throws {
        let viaFull = try DiagramLoader.parse(
            Self.mermaidSource,
            as: .mermaid,
            registry: DiagramPipeline.defaultRegistry
        )
        let viaShorthand = try DiagramLoader.parseDocument(
            Self.mermaidSource,
            as: .mermaid,
            registry: DiagramPipeline.defaultRegistry
        )
        #expect(viaFull.document.type == viaShorthand.type)
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `swift test --filter DiagramLoaderByIDTests`
Expected: build error — `parse(_:as:registry:)` has no such overload.

- [ ] **Step 7: Add the typed parse entry points to `DiagramLoader`**

In `Sources/DiagramKitImport/DiagramLoader.swift`, ensure `import DiagramKitCommon` is at the top (it likely already resolves through DiagramKitModel's transitive deps, but be explicit). After the existing `parseDocument(_:registry:)` method's closing brace, add:

```swift
    /// Parse `source` using the importer registered under `formatID`.
    /// Bypasses content-driven probing — the caller has asserted the
    /// format. If no importer in the registry declares this format,
    /// throws `DiagramError.unrecognizedFormat`.
    ///
    /// - Parameters:
    ///   - source: Raw diagram source text.
    ///   - formatID: The format to route through.
    ///   - registry: The importer registry to search.
    /// - Returns: `DiagramImportResult` with the parsed document and diagnostics.
    /// - Throws: `DiagramError.unrecognizedFormat` when no importer in the
    ///   registry declares `formatID`; otherwise whatever the matched
    ///   importer's `parse(_:)` throws on malformed input.
    public static func parse(
        _ source: String,
        as formatID: DiagramFormatID,
        registry: ImporterRegistry
    ) throws -> DiagramImportResult {
        guard let importer = registry.importer(for: formatID) else {
            throw DiagramError.unrecognizedFormat(
                "no importer registered for format '\(formatID.rawValue)' in registry"
            )
        }
        return try importer.parse(source)
    }

    /// Shorthand returning only the `DiagramDocument`, discarding diagnostics.
    public static func parseDocument(
        _ source: String,
        as formatID: DiagramFormatID,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try parse(source, as: formatID, registry: registry).document
    }
```

- [ ] **Step 8: Run the loader-by-ID test to verify it passes**

Run: `swift test --filter DiagramLoaderByIDTests`
Expected: PASS (6 tests).

- [ ] **Step 9: Run the wider import test sweep to verify no regression**

Run: `swift test --filter "ImporterRegistry|ProbeCollisionMatrix"`
Expected: PASS — probe-based dispatch is untouched.

- [ ] **Step 10: Run smoke gates**

Run: `Scripts/check-sendable-annotations.sh`
Expected: green.

Run: `Scripts/check-file-sizes.sh`
Expected: no new threshold crossings.

- [ ] **Step 11: Commit**

```bash
git add Sources/DiagramKitImport/ImporterRegistry.swift \
        Sources/DiagramKitImport/DiagramLoader.swift \
        Tests/DiagramKitTests/ImporterRegistryByIDTests.swift \
        Tests/DiagramKitTests/DiagramLoaderByIDTests.swift
git commit -m "$(cat <<'EOF'
feat(import): typed by-ID lookup on ImporterRegistry and DiagramLoader

ImporterRegistry.importer(for formatID:) does a linear scan over the
ordered importer list and returns the first formatID match. DiagramLoader
gains parse(_:as:registry:) and parseDocument(_:as:registry:) entry
points that bypass content-driven probing — the caller has asserted
the format. Unknown formatID surfaces as DiagramError.unrecognizedFormat
with a message naming the missing format. Probe-based dispatch is
unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `CorpusEntry.expectedImporters` typed migration

**Files:**
- Modify: `Sources/DiagramKitTestSupport/CorpusEntry.swift` (type change + decode/encode helpers)
- Modify: `Examples/DiagramPlayground/Resources/test-diagrams.json` (54 value replacements)
- Modify: `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift` (2 expect rewrites + 6 inline JSON blocks)
- Modify: `Tests/DiagramKitTests/DOTCorpusFixtureTests.swift` (1 expect rewrite + 4 inline JSON blocks)
- Modify: `Tests/DiagramKitTests/D2CorpusFixtureTests.swift` (1 expect rewrite + 4 inline JSON blocks)
- Modify: `Tests/DiagramKitTests/CorpusMultiFormatTests.swift` (4 expect rewrites + 2 inline JSON blocks)
- Create: `Tests/DiagramKitTests/CorpusEntryFormatIDTests.swift`

- [ ] **Step 1: Write the failing test for the typed migration**

Create `Tests/DiagramKitTests/CorpusEntryFormatIDTests.swift`:

```swift
import Foundation
import Testing
import DiagramKitCommon
import DiagramKitTestSupport

@Suite struct CorpusEntryFormatIDTests {

    private static let canonicalJSON = """
    {
      "id": "fixture-1",
      "category": "flowchart",
      "name": "Fixture 1",
      "source": "graph TD\\nA-->B",
      "sources": {
        "mermaid": "graph TD\\nA-->B",
        "d2": "A -> B"
      },
      "expectedImporters": {
        "mermaid": "mermaid",
        "d2": "d2"
      }
    }
    """

    @Test("Decodes typed expectedImporters from string keys/values")
    func decodesTyped() throws {
        let entry = try JSONDecoder().decode(
            CorpusEntry.self,
            from: Data(Self.canonicalJSON.utf8)
        )
        #expect(entry.expectedImporters?[.mermaid] == .mermaid)
        #expect(entry.expectedImporters?[.d2] == .d2)
    }

    @Test("Encodes typed expectedImporters back to JSON string map")
    func encodesTyped() throws {
        let entry = try JSONDecoder().decode(
            CorpusEntry.self,
            from: Data(Self.canonicalJSON.utf8)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let map = try #require(object?["expectedImporters"] as? [String: String])
        #expect(map["mermaid"] == "mermaid")
        #expect(map["d2"] == "d2")
    }

    @Test("Unknown formatID rawValue decodes as open RawRepresentable")
    func decodesUnknownRawValue() throws {
        let json = """
        {
          "id": "fixture-2",
          "category": "flowchart",
          "name": "Fixture 2",
          "source": "x",
          "expectedImporters": {
            "asciiart": "asciiart"
          }
        }
        """
        let entry = try JSONDecoder().decode(CorpusEntry.self, from: Data(json.utf8))
        let key = DiagramFormatID(rawValue: "asciiart")
        #expect(entry.expectedImporters?[key] == DiagramFormatID(rawValue: "asciiart"))
    }

    @Test("Round-trip decode → encode → decode preserves typed dictionary")
    func roundTrip() throws {
        let first = try JSONDecoder().decode(
            CorpusEntry.self,
            from: Data(Self.canonicalJSON.utf8)
        )
        let encoded = try JSONEncoder().encode(first)
        let second = try JSONDecoder().decode(CorpusEntry.self, from: encoded)
        #expect(first.expectedImporters == second.expectedImporters)
    }

    @Test("Duplicate normalized key surfaces CorpusEntryError")
    func duplicateKeyThrows() throws {
        // Two keys that normalize to the same lowercased form.
        let json = """
        {
          "id": "fixture-3",
          "category": "flowchart",
          "name": "Fixture 3",
          "source": "x",
          "expectedImporters": {
            "mermaid": "mermaid",
            "MERMAID": "mermaid"
          }
        }
        """
        #expect(throws: CorpusEntryError.self) {
            _ = try JSONDecoder().decode(CorpusEntry.self, from: Data(json.utf8))
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CorpusEntryFormatIDTests`
Expected: build error — `entry.expectedImporters?[.mermaid]` does not type-check because `expectedImporters` is currently `[String: String]?`.

- [ ] **Step 3: Migrate the `CorpusEntry.expectedImporters` field**

In `Sources/DiagramKitTestSupport/CorpusEntry.swift`:

(a) Add the import at the top, right under the existing `import Foundation`:

```swift
import DiagramKitCommon
```

(b) Change the field declaration (line 20) from:

```swift
public let expectedImporters: [String: String]?
```

to:

```swift
public let expectedImporters: [DiagramFormatID: DiagramFormatID]?
```

(c) Replace the decode call at lines 50–52:

```swift
expectedImporters = try Self.normalizedFormatMap(
    container.decodeIfPresent([String: String].self, forKey: .expectedImporters)
)
```

with:

```swift
expectedImporters = try Self.decodeFormatIDMap(
    container.decodeIfPresent([String: String].self, forKey: .expectedImporters)
)
```

(d) Replace the encode call at line 85:

```swift
try container.encodeIfPresent(expectedImporters, forKey: .expectedImporters)
```

with:

```swift
if let expectedImporters {
    let stringified = Dictionary(
        uniqueKeysWithValues: expectedImporters.map { ($0.key.rawValue, $0.value.rawValue) }
    )
    try container.encode(stringified, forKey: .expectedImporters)
}
```

(e) Add the new private helper at the bottom of the type body, right after the existing `normalizedFormatMap` static method:

```swift
    private static func decodeFormatIDMap(
        _ values: [String: String]?
    ) throws -> [DiagramFormatID: DiagramFormatID]? {
        guard let values else { return nil }
        var result: [DiagramFormatID: DiagramFormatID] = [:]
        for (key, value) in values {
            let normalizedKey = normalizedFormat(key)
            let formatKey = DiagramFormatID(rawValue: normalizedKey)
            let normalizedValue = normalizedFormat(value)
            let formatValue = DiagramFormatID(rawValue: normalizedValue)
            if result[formatKey] != nil {
                throw CorpusEntryError.duplicateFormatKey(key: normalizedKey)
            }
            result[formatKey] = formatValue
        }
        return result
    }
```

- [ ] **Step 4: Sweep the existing test sites — `StructurizrCorpusFixtureTests`**

In `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift`:

(a) Add `import DiagramKitCommon` if not already present.

(b) Replace both `#expect` lines (lines 52 and 275):

```swift
#expect(entry.expectedImporters?["structurizr"] == "Structurizr")
```

becomes:

```swift
#expect(entry.expectedImporters?[.structurizr] == .structurizr)
```

(c) In each of the 6 inline JSON literals at lines 41, 77, 110, 142, 175, 264, find the value strings inside `"expectedImporters": { … }` and lowercase them — `"Mermaid"` → `"mermaid"`, `"Structurizr"` → `"structurizr"`. Do not change the keys; they're already lowercase.

- [ ] **Step 5: Sweep `DOTCorpusFixtureTests`**

In `Tests/DiagramKitTests/DOTCorpusFixtureTests.swift`:

(a) Add `import DiagramKitCommon` if not already present.

(b) Replace the single `#expect` at line 38:

```swift
#expect(entry.expectedImporters?["graphviz"] == "Graphviz")
```

becomes:

```swift
#expect(entry.expectedImporters?[.graphviz] == .graphviz)
```

(c) In the 4 inline JSON literals at lines 26, 57, 86, 114, lowercase `"Mermaid"` → `"mermaid"` and `"Graphviz"` → `"graphviz"`.

- [ ] **Step 6: Sweep `D2CorpusFixtureTests`**

In `Tests/DiagramKitTests/D2CorpusFixtureTests.swift`:

(a) Add `import DiagramKitCommon` if not already present.

(b) Replace the single `#expect` at line 38:

```swift
#expect(entry.expectedImporters?["d2"] == "D2")
```

becomes:

```swift
#expect(entry.expectedImporters?[.d2] == .d2)
```

(c) In the 4 inline JSON literals at lines 26, 57, 86, 114, lowercase `"Mermaid"` → `"mermaid"` and `"D2"` → `"d2"`.

- [ ] **Step 7: Sweep `CorpusMultiFormatTests`**

In `Tests/DiagramKitTests/CorpusMultiFormatTests.swift`:

(a) Add `import DiagramKitCommon` if not already present.

(b) Replace the 4 `#expect` lines (lines 159, 160, 310, 311):

```swift
#expect(entry.expectedImporters?["mermaid"] == "Mermaid")
#expect(entry.expectedImporters?["d2"] == "D2")
```

becomes:

```swift
#expect(entry.expectedImporters?[.mermaid] == .mermaid)
#expect(entry.expectedImporters?[.d2] == .d2)
```

(c) In the 2 inline JSON literals at lines 149 and 294, lowercase `"Mermaid"` → `"mermaid"` and `"D2"` → `"d2"`.

- [ ] **Step 8: Sweep the corpus JSON**

In `Examples/DiagramPlayground/Resources/test-diagrams.json`, perform 5 distinct value replacements inside `"expectedImporters"` blocks only (do NOT touch keys, IDs, or anything outside `expectedImporters`):

- `"Mermaid"` → `"mermaid"` (27 occurrences)
- `"D2"` → `"d2"` (6 occurrences)
- `"Graphviz"` → `"graphviz"` (9 occurrences)
- `"PlantUML"` → `"plantuml"` (6 occurrences)
- `"Structurizr"` → `"structurizr"` (6 occurrences)

The fastest safe approach: walk each `"expectedImporters"` block in order (27 blocks total at lines tracked by `grep -n '"expectedImporters"'`) and replace the right-hand-side values. After editing, verify the totals:

Run: `grep -c '"Mermaid"' Examples/DiagramPlayground/Resources/test-diagrams.json`
Expected: `0`

Run: `grep -c '"D2"' Examples/DiagramPlayground/Resources/test-diagrams.json`
Expected: `0`

Run: `grep -c '"Graphviz"' Examples/DiagramPlayground/Resources/test-diagrams.json`
Expected: `0`

Run: `grep -c '"PlantUML"' Examples/DiagramPlayground/Resources/test-diagrams.json`
Expected: `0`

Run: `grep -c '"Structurizr"' Examples/DiagramPlayground/Resources/test-diagrams.json`
Expected: `0`

Run: `python3 -c "import json; d = json.load(open('Examples/DiagramPlayground/Resources/test-diagrams.json')); print(len(d['diagrams']))"`
Expected: integer count (should be 422 — unchanged).

- [ ] **Step 9: Run the new test to verify it passes**

Run: `swift test --filter CorpusEntryFormatIDTests`
Expected: PASS (5 tests).

- [ ] **Step 10: Run the corpus-fixture sweep tests to verify the rewrites compile and pass**

Run: `swift test --filter "StructurizrCorpusFixtureTests|DOTCorpusFixtureTests|D2CorpusFixtureTests|CorpusMultiFormatTests"`
Expected: PASS — every existing fixture test now uses typed equality and works against the typed JSON.

- [ ] **Step 11: Run the wider corpus / multi-format sweep**

Run: `swift test --filter "Corpus|MultiFormat"`
Expected: PASS — no other corpus consumers rely on the old string typing.

- [ ] **Step 12: Run smoke gates**

Run: `Scripts/check-sendable-annotations.sh`
Expected: green.

Run: `Scripts/check-file-sizes.sh`
Expected: no new threshold crossings (`CorpusEntry.swift` grows by ~15 lines; well under 500).

- [ ] **Step 13: Commit**

```bash
git add Sources/DiagramKitTestSupport/CorpusEntry.swift \
        Examples/DiagramPlayground/Resources/test-diagrams.json \
        Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift \
        Tests/DiagramKitTests/DOTCorpusFixtureTests.swift \
        Tests/DiagramKitTests/D2CorpusFixtureTests.swift \
        Tests/DiagramKitTests/CorpusMultiFormatTests.swift \
        Tests/DiagramKitTests/CorpusEntryFormatIDTests.swift
git commit -m "$(cat <<'EOF'
refactor(testsupport): type CorpusEntry.expectedImporters with DiagramFormatID

Migrate the routing-test field from [String: String]? to
[DiagramFormatID: DiagramFormatID]?. JSON shape is preserved
(string keys/values on disk); decoder normalizes through
DiagramFormatID(rawValue:), encoder writes back the rawValues.
Unknown rawValues land as open RawRepresentable values per the
type's documented semantics. 27 corpus entries' values flipped
from display-name form to formatID rawValue form (54 replacements);
8 expect-site rewrites + 16 inline JSON literal edits across the
four corpus-fixture test files.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Deprecate `DiagramExportLoader.export(_:using:registry:)` and migrate the two test call sites

**Files:**
- Modify: `Sources/DiagramKitExport/DiagramExportLoader.swift` (add `@available` annotation)
- Modify: `Tests/DiagramKitTests/Export/DiagramExportLoaderTests.swift` (suppress or migrate the two test cases that exercise the deprecated form)

- [ ] **Step 1: Confirm the existing two call sites**

Run: `grep -rn 'DiagramExportLoader.export.*using' Sources Tests --include='*.swift'`
Expected: exactly two lines, both in `Tests/DiagramKitTests/Export/DiagramExportLoaderTests.swift` at lines 67 and 78. These are the two tests that exercise the name-based path (`loaderByName` and `loaderUnknownName`).

- [ ] **Step 2: Add the deprecation annotation**

In `Sources/DiagramKitExport/DiagramExportLoader.swift`, prepend the `@available` annotation to the `export(_:using:registry:)` declaration (around line 61). The method body is unchanged:

```swift
    /// Convenience: export using a specific exporter by display name.
    /// Prefer `export(_:to:registry:)` with a format ID for type safety.
    @available(*, deprecated, renamed: "export(_:to:registry:)",
               message: "Use formatID-based dispatch instead of display-name lookup.")
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

        guard exporter.supportedDiagramTypes.contains(document.type) else {
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "Diagram type '\(document.type.rawValue)' is not supported by exporter '\(exporterName)'"
                    )
                ]
            )
        }

        return try exporter.export(document)
    }
```

- [ ] **Step 3: Suppress the deprecation in the two existing tests**

In `Tests/DiagramKitTests/Export/DiagramExportLoaderTests.swift`, wrap each of the two deprecated call sites with `@available(*, deprecated)` on the enclosing `@Test` so the test still exercises the legacy path without polluting the build with warnings. Add the annotation immediately above the `@Test` line in both cases.

The first site (around lines 61–70):

```swift
    @available(*, deprecated, message: "Tests legacy name-based export form.")
    @Test("Loader finds exporter by name")
    func loaderByName() throws {
        let exporter = FlowchartOnlyExporter()
        let registry = ExporterRegistry.empty.registering(exporter)

        let doc = DiagramDocument(type: .flowchart)
        let result = try DiagramExportLoader.export(doc, using: exporter.name, registry: registry)

        #expect(result.source == "graph TD\n")
    }
```

The second site (around lines 72–80):

```swift
    @available(*, deprecated, message: "Tests legacy name-based export form.")
    @Test("Loader throws for unknown exporter name")
    func loaderUnknownName() {
        let registry = ExporterRegistry.empty
        let doc = DiagramDocument(type: .flowchart)

        #expect(throws: DiagramExportError.self) {
            try DiagramExportLoader.export(doc, using: "Not exist", registry: registry)
        }
    }
```

- [ ] **Step 4: Run a targeted build to verify no deprecation warnings escape**

Run: `swift build --build-tests 2>&1 | grep -i 'deprecated' | grep -v '__Snapshots__'`
Expected: empty output (the two tests in `DiagramExportLoaderTests.swift` are marked `@available(*, deprecated)` themselves, suppressing the inner warning; no other call site exists).

- [ ] **Step 5: Run the export-loader tests to verify the deprecated path still works**

Run: `swift test --filter DiagramExportLoaderTests`
Expected: PASS — including the two tests that exercise the deprecated form.

- [ ] **Step 6: Run the wider export-side test sweep**

Run: `swift test --filter "DiagramExport|ExporterRegistry"`
Expected: PASS.

- [ ] **Step 7: Run smoke gates**

Run: `Scripts/check-sendable-annotations.sh`
Expected: green.

Run: `Scripts/check-file-sizes.sh`
Expected: no new threshold crossings.

Run: `Scripts/strict-concurrency-check.sh`
Expected: first-party clean.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitExport/DiagramExportLoader.swift \
        Tests/DiagramKitTests/Export/DiagramExportLoaderTests.swift
git commit -m "$(cat <<'EOF'
deprecate(export): DiagramExportLoader.export(_:using:registry:)

The display-name-keyed export entry point is superseded by the
formatID-keyed export(_:to:registry:). Runtime behavior preserved
verbatim; only the @available annotation changes. The two existing
tests that exercise the deprecated path are themselves marked
@available(*, deprecated) so they continue to validate the legacy
form without spilling deprecation warnings into the build log.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Sync `CLAUDE.md` test source count

**Files:**
- Modify: `CLAUDE.md` (one number)

- [ ] **Step 1: Count test files after the new additions**

Run: `find Tests/DiagramKitTests -type f -name '*.swift' | wc -l`
Expected: integer count. Currently `CLAUDE.md` claims `231`. After Tasks 1–4 we added five new test files (`DiagramFormatIDLocationTests.swift`, `DiagramSourceImporterFormatIDTests.swift`, `ImporterRegistryByIDTests.swift`, `DiagramLoaderByIDTests.swift`, `CorpusEntryFormatIDTests.swift`), so the new count should be `236`.

If the live count disagrees with `231 + 5 = 236`, prefer the live count from `find`.

- [ ] **Step 2: Update `CLAUDE.md`**

In `CLAUDE.md`, locate the line in the "Testing And Snapshots" section that reads:

```markdown
- Current test source count: 231 Swift files under `Tests/DiagramKitTests`.
```

Update it to:

```markdown
- Current test source count: 236 Swift files under `Tests/DiagramKitTests`.
```

(Substitute the actual live count if `find` reported a different number.)

- [ ] **Step 3: Verify no other count drift**

Run: `grep -n 'test source count' CLAUDE.md`
Expected: exactly one match.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(claude): sync test source count after DiagramFormatID symmetry work

Five new test files landed across Tasks 1-4 of the symmetric
importer dispatch plan: DiagramFormatIDLocationTests,
DiagramSourceImporterFormatIDTests, ImporterRegistryByIDTests,
DiagramLoaderByIDTests, CorpusEntryFormatIDTests. Bump the
"Current test source count" line accordingly.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## End-of-plan verification

After all six tasks are committed, run the discipline gates one final time and verify the touched test surfaces pass together:

- [ ] **Run the targeted test sweep**

```bash
swift test --filter "DiagramFormatID|DiagramSourceImporterFormatID|ImporterRegistry|DiagramLoader|CorpusEntryFormatID|StructurizrCorpusFixture|DOTCorpusFixture|D2CorpusFixture|CorpusMultiFormat|DiagramExport"
```

Expected: PASS across every suite touched by this plan.

- [ ] **Run the discipline gates**

```bash
Scripts/check-sendable-annotations.sh
Scripts/check-file-sizes.sh
Scripts/strict-concurrency-check.sh
```

Expected: green / no new threshold crossings / first-party clean.

- [ ] **Confirm no snapshot rebaselining needed**

Run: `swift test --filter CorpusSnapshotTests/svgSnapshot/mermaid-1-` (single fast snapshot probe)
Expected: PASS — renderers were not touched; baselines remain valid.

If any of the above fail unexpectedly, stop and investigate — do not roll forward.
