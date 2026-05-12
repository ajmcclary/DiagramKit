**Key Correction**
`MermaidRenderer -> DiagramRenderer` is not a safe mechanical rename as written because `DiagramRenderer` is already the public CG renderer in [DiagramRenderer.swift](/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift/Sources/DiagramKitRenderingCG/DiagramRenderer.swift:15). Either choose a different public facade name like `DiagramEngine` / `DiagramKitRenderer`, or first rename the CG renderer to something like `CGDiagramRenderer` with a compatibility plan.

**Phase 0: Stabilize And Decide Names**
Settle the public names before moving files. Decide:

- `MermaidGraph` new name: I’d use `DiagramDocument`.
- Public facade: avoid `DiagramRenderer` unless you rename the existing CG type.
- Diagnostics location: likely `DiagramKitModel` if diagnostics reference `DiagramType`.
- Registry ownership: format registry and Mermaid diagram-family registry should be separate.

Also fix the missing `BASELINES.md` reference or restore the file, since multiple docs cite it as a merge-gate source.

**Phase 1: Add The Format-Agnostic Surface Without Behavior Change**
Do this additively first, not as a giant rename.

- Add `DiagramDocument = MermaidGraph` typealias.
- Add `DiagramPipeline` wrapper around `MermaidPipeline`.
- Add new non-Mermaid facade name while keeping `MermaidRenderer`.
- Keep current worker-thread behavior from [MermaidRenderer.swift](/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift/Sources/DiagramKit/MermaidRenderer.swift:44): every public path still goes through the 8 MB worker thread.
- Keep bundled font registration at every pipeline boundary.

Goal: current Mermaid API still works, new names exist, snapshots unchanged.

**Phase 2: Split Import From Layout**
The current `DiagramDescriptor` combines detection, parse, and layout in one record ([DiagramDescriptor.swift](/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift/Sources/DiagramKit/DiagramDescriptor.swift:71)). For multi-format support, split that responsibility:

- `DiagramSourceImporter`: source probe + parse into `DiagramDocument`.
- `ImporterRegistry`: ordered source-format dispatch.
- `DiagramLoader`: loops registry and returns `DiagramDocument`.
- Keep layout dispatch separate: `DiagramDocument -> PositionedGraph` should not care whether the document came from Mermaid, d2, DOT, or PlantUML.

Create `DiagramKitImport` for importer protocols/registry, then create `DiagramKitMermaid` as the first concrete importer target.

**Phase 3: Extract Mermaid As The First Importer**
Move current Mermaid detection/parser routing behind `MermaidImporter`.

- Current `DiagramRegistry` becomes a Mermaid-internal family registry or gets renamed accordingly.
- `MermaidImporter.supports(source:)` uses the existing header detection.
- `DiagramPipeline.parse` calls `DiagramLoader.parse(..., registry: .default)`.
- Default registry lives in the umbrella target, because it needs to compose concrete format targets without creating dependency cycles.

Add `ProbeCollisionMatrixTests` here. This is essential because d2 and Mermaid both use arrow syntax, and DOT’s `graph` keyword can collide with Mermaid’s `graph TD`.

**Phase 4: Make The Corpus Multi-Format Early**
I would move part of ANALYSIS Phase 5 earlier.

Update `TestDiagram` in [SampleDiagrams.swift](/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift/Examples/MermaidPlayground/Models/SampleDiagrams.swift:243) and `CorpusSnapshotTests` in [CorpusSnapshotTests.swift](/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift/Tests/DiagramKitTests/CorpusSnapshotTests.swift:29) to decode both old and new schemas:

```json
{
  "source": "graph TD\nA-->B",
  "sources": {
    "mermaid": "graph TD\nA-->B",
    "d2": "A -> B"
  }
}
```

Keep `source` as Mermaid fallback. This lets each new format land with real corpus fixtures instead of inventing a second test system later.

**Phase 5: Add Format Importers In Vertical Slices**
Recommended order:

1. `DiagramKitD2`
   Highest ROI and clean grammar. Start with flowchart nodes/edges/groups, then styles, then ER/architecture/C4 partial support.

2. `DiagramKitGraphviz`
   DOT maps cleanly to flowchart only. Keep scope strict: parse DOT, map to flowchart, do not force other diagram types.

3. `DiagramKitStructurizr`
   I’d do this before PlantUML despite the ANALYSIS order. It is narrower, C4-only, and gives you a cleaner architecture-format story.

4. `DiagramKitPlantUML`
   Treat this as a set of sub-importers, not a full port. Sequence first, then class, state/activity, mindmap, gantt, C4. Unsupported syntax must produce diagnostics.

5. `DiagramKitZenUML`
   Lower urgency because ZenUML already exists through the Mermaid path, but extracting it later validates the one-format-per-target architecture.

**Phase 6: Add Exporters**
Only after multiple importers exist.

- Add `DiagramKitExport`.
- Add `DiagramExporter`, `DiagramExportResult`, diagnostics.
- Implement exporters in this order: Mermaid, d2, PlantUML, Structurizr/C4.
- Add sparse-matrix tests: unsupported conversions produce diagnostics, never silent no-ops.
- Add round-trip tests: `parse(formatA) -> export(formatB) -> parse(formatB) -> export(formatB)`.

**Phase 7: Add Interactivity Primitives**
Do this after import/export because stable identity matters more once documents can come from many formats.

- Add stable IDs for nodes, edges, groups across positioned payloads.
- Add `DiagramSelection`.
- Add `DiagramBoundsLookup`.
- Attach lookup to `PreparedDiagram`.
- Consider using a portable `DiagramRect` in `DiagramKitCommon` instead of exposing `CGRect` everywhere.

Start with flowchart/state/class/sequence/ER, then fill out the long tail.

**Phase 8: Optional Interactive Model**
Only after exporters and bounds lookup exist.

- New `DiagramKitInteractive` target.
- `@MainActor DiagramEditor`.
- Undo stack, selection state, typed mutations.
- Source sync through exporters.
- No turnkey editor view initially; ship primitives like MusicToolkit does.

**Phase 9: Release And Deprecation Cleanup**
Once the new API has lived for a release cycle:

- Deprecate old Mermaid-named facade/types.
- Keep compatibility aliases where cheap.
- Update README, ARCHITECTURE, CONTRIBUTING, and snapshots.
- Run `swift build --build-tests`, targeted corpus chunks, strict concurrency, sendable gate, file-size gate, Linux check, then bootstrap gate.

The main thing is to avoid starting with parser ports. First make the architecture capable of hosting multiple source formats, then add formats one at a time, with corpus and diagnostics proving the sparse matrix explicitly.
