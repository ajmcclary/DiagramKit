# Phase 6: PlantUML In Vertical Slices

Goal: support useful PlantUML subsets without attempting a full PlantUML clone.

Date: 2026-05-12. This is the implementation plan for Phase 6 of the DiagramKit
multi-format roadmap. It follows the completed Phase 5 (Structurizr importer)
and precedes Phase 7 (Exporter Protocol).

## Status

| Slice | Family     | Status    | Date       | Source Lines | Test Lines | Tests | Notes |
|-------|------------|-----------|------------|-------------|------------|-------|-------|
| 6A    | Sequence   | ✅ Done   | 2026-05-12 | ~1,060       | ~835        | 55    | See [Slice 6A Completion Notes](#slice-6a-completion-notes) |
| 6B    | Class      | 📋 Planned | —         | —           | —          | —     | — |
| 6C    | State/Activity | 📋 Planned | —     | —           | —          | —     | — |
| 6D    | Mindmap+Gantt | 📋 Planned | —      | —           | —          | —     | — |
| 6E    | C4         | 📋 Planned | —         | —           | —          | —     | — |

**Slice 6A completion notes:**
- 8 source files created under `Sources/DiagramKitPlantUML/`
- 55 tests split across `PlantUMLSequenceParserTests`,
  `PlantUMLSequenceMapperTests`, and `PlantUMLSequenceIntegrationTests` — all passing
- Registry: `PlantUMLImporter` inserted between `StructurizrImporter` and `GraphvizImporter`
- Probe collision: 44/44 `ProbeCollisionMatrixTests` pass (zero regressions)
- Importer regression: 98/98 tests pass across Structurizr, D2, DOT, Mermaid
- Plan deviations: `isPlantUMLStateBody` dropped bare `end` keyword (ambiguous with sequence block closers); `isPlantUMLClassBody` tightened to exclude `-->` from `--` match (prevents class probe intercepting sequence); State probe tests verify dispatch ordering rather than exclusive probe matching

**Gate verification (Slice 6A):**
- `swift package dump-package` — ✅
- `swift build --build-tests` — ✅ (zero warnings)
- `swift test --filter PlantUMLSequence` — ✅ 55/55
- `swift test --filter ImporterRegistryTests` — ✅ 7/7
- `swift test --filter ProbeCollisionMatrixTests` — ✅ 44/44
- `swift test --filter StructurizrImporterTests` — ✅ 36/36
- `swift test --filter D2ImporterTests` — ✅ 22/22
- `swift test --filter DOTImporterTests` — ✅ 36/36
- `swift test --filter MermaidImporterTests` — ✅ 4/4

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Slice 6A: Sequence Diagrams](#2-slice-6a-sequence-diagrams)
3. [Slice 6B: Class Diagrams](#3-slice-6b-class-diagrams)
4. [Slice 6C: State/Activity Diagrams](#4-slice-6c-stateactivity-diagrams)
5. [Slice 6D: Mindmap and Gantt](#5-slice-6d-mindmap-and-gantt)
6. [Slice 6E: C4-Flavored PlantUML](#6-slice-6e-c4-flavored-plantuml)
7. [Testing Strategy](#7-testing-strategy)
8. [Verification Gates](#8-verification-gates)
9. [Deferred / Out of Scope](#9-deferred--out-of-scope)
10. [Delivery Cadence](#10-delivery-cadence)

---

## 1. Architecture Overview

### 1.1 Target Structure

`DiagramKitPlantUML` is a single SPM target housing all PlantUML family parsers.
It is added to the package only when the first family slice (Sequence) is
accepted and its probe collides correctly with all existing importers.

```
Sources/DiagramKitPlantUML/
├── PlantUMLImporter.swift          // Outer probe + family dispatch
├── PlantUMLProbe.swift             // @startuml/@enduml detection
├── PlantUMLFamilyProbe.swift       // Family-specific routing probes
├── PlantUMLDiagnostics.swift       // Shared diagnostic helpers
├── Sequence/
│   ├── PlantUMLSequenceParser.swift
│   ├── PlantUMLSequenceAST.swift
│   ├── PlantUMLSequenceMapper.swift
│   └── PlantUMLSequenceProbe.swift
├── Class/
│   ├── PlantUMLClassParser.swift
│   ├── PlantUMLClassAST.swift
│   ├── PlantUMLClassMapper.swift
│   └── PlantUMLClassProbe.swift
├── StateActivity/
│   ├── PlantUMLStateParser.swift
│   ├── PlantUMLStateAST.swift
│   ├── PlantUMLStateMapper.swift
│   └── PlantUMLStateProbe.swift
├── MindmapGantt/
│   ├── PlantUMLMindmapParser.swift
│   ├── PlantUMLMindmapAST.swift
│   ├── PlantUMLMindmapMapper.swift
│   ├── PlantUMLGanttParser.swift
│   ├── PlantUMLGanttAST.swift
│   └── PlantUMLGanttMapper.swift
└── C4/
    ├── PlantUMLC4Parser.swift
    ├── PlantUMLC4AST.swift
    ├── PlantUMLC4Mapper.swift
    └── PlantUMLC4Probe.swift
```

### 1.2 Two-Level Dispatch

**Level 1 — Outer probe** (`PlantUMLProbe.isPlantUMLSource`):
- Returns `true` when the source contains `@startuml` or `@startxxx` with a
  corresponding `@enduml` / `@endxxx`.
- Sources from other formats fail this probe because they do not use matched
  PlantUML start/end tags.
- Does not scan the PlantUML body for other-format keywords. Labels and notes
  can legitimately contain strings such as `workspace {`, `digraph`, or D2-like
  text, and family routing happens after the body is extracted.

**Level 2 — Family routing** (`PlantUMLImporter.parse`):
- Extracts the body between `@startuml`/`@enduml` (or `@startxxx`/`@endxxx`),
  preserving the start-tag kind (`startuml`, `startmindmap`, `startgantt`,
  `startwbs`) as metadata for explicit-header families.
- Probes family-specific syntax in fixed order inside the PlantUML body:
  1. C4 (`!include <C4/...>`, `Person(`, `System(`, `Container(`) — narrowest
  2. Gantt (`@startgantt`) — explicit header
  3. Mindmap (`@startmindmap`) — explicit header
  4. State/Activity (`state `, `[*]`, `partition`) — syntactic signals
  5. Class (`class `, `interface `, `abstract class`, `enum `, `+`/`-`/`#`)
  6. Sequence (`participant`, `actor`, `->` arrows, `activate`/`deactivate`) —
     broadest fallback within PlantUML
- Each family probe is a free function, e.g. `isPlantUMLSequenceBody(_:)`,
  called on the inner body string (text between `@startuml` and `@enduml`).

If no family matches, the importer emits a `.unsupported` diagnostic and
throws `DiagramError.notYetImplemented("PlantUML family not recognized")` —
it never silently routes to a wrong family.

### 1.3 Mapping Targets

| PlantUML Family | `DiagramPayload` Target            | `DiagramType`       |
|-----------------|------------------------------------|---------------------|
| Sequence        | `.sequenceDiagram(SequenceDiagram)` | `.sequenceDiagram`  |
| Class           | `.classDiagram(ClassDiagram)`       | `.classDiagram`     |
| State/Activity  | `.stateDiagram(ParsedGraphModel)`   | `.stateDiagram`     |
| Mindmap         | `.mindmap(MindmapDiagram)`          | `.mindmap`          |
| Gantt           | `.gantt(GanttDiagram)`              | `.gantt`            |
| C4              | `.c4(C4Diagram)`                    | `.c4`               |

All existing layout and render paths consume these payload types, so no
layout or renderer changes are required for any slice.

### 1.4 Operating Constraints

- **Probe order is contractual.** `PlantUMLImporter` is prepended before
  `MermaidImporter()` and after `StructurizrImporter()` in
  `DiagramPipeline.defaultRegistry`. The Structurizr probe already rejects
  `@startuml`. PlantUML's outer probe only accepts matched PlantUML start/end
  tags; do not add broad body keyword guards for other formats.
  
  Final registry order after all slices:
  ```
  [StructurizrImporter(), PlantUMLImporter(), GraphvizImporter(),
   D2Importer(), MermaidImporter()]
  ```

- **Every unsupported syntax branch produces a `DiagramDiagnostic`.** No silent
  partial imports. No empty successful conversions.

- **Parser implementations are hand-written recursive-descent or line-based
  state machines.** PlantUML has no published EBNF; the Java reference is a
  collection of regex-based state machines. We do not port the Java code
  line-for-line. We implement focused parsers for each family's supported
  subset.

- **Fixtures are inline with `skipSnapshots`.** Real corpus entries and
  snapshot baselines are deferred to the final baseline pass (Phase 10).
  Inline fixtures live alongside the parser/importer tests.

- **File-size discipline.** No new `.swift` file exceeds 500 lines. Split
  parser helpers, AST types, and mapper logic by concern.

- **Worker-thread invariant preserved.** `PlantUMLImporter.parse` runs on the
  existing 8 MB-stack worker thread via `DiagramEngine._runOnWorker`.

### 1.5 `PlantUMLImporter` Sketch

```swift
public struct PlantUMLImporter: DiagramSourceImporter {
    public let name = "PlantUML"
    /// Grows per slice. In slice 6A, only sequence is implemented.
    /// Unsupported family dispatch throws `DiagramError.notYetImplemented`.
    public let supportedDiagramTypes: Set<DiagramType> = [
        .sequenceDiagram
        // .classDiagram     — added in 6B
        // .stateDiagram     — added in 6C
        // .mindmap, .gantt  — added in 6D
        // .c4               — added in 6E
    ]

    public init() {}

    public func supports(source: String) -> Bool {
        isPlantUMLSource(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        // 1. Extract body between @startuml/@enduml (or @startxxx/@endxxx)
        // 2. Probe family-specific syntax inside the body
        // 3. Dispatch to the matched family parser
        // 4. Map the family AST to DiagramPayload
        // 5. Return DiagramImportResult with document + diagnostics
    }
}
```

---

## 2. Slice 6A: Sequence Diagrams

**Slice goal**: parse a useful PlantUML sequence subset and map it to
`DiagramPayload.sequenceDiagram(SequenceDiagram)`. This slice is the first
PlantUML family and adds the `DiagramKitPlantUML` target.

**Implementation order**: start with the minimum viable subset — participants
(participant/actor), simple messages (`->`, `-->`), notes, and basic blocks
(alt/else/end). Then follow up within 6A with activations, boxes, loop/opt/
group, auto-numbering, and the remaining arrow types. This keeps the first
green-build milestone small while the target scaffolding is stabilizing.

### 2.1 Supported Syntax

#### Participants and Actors
```
@startuml
participant Alice
participant "Bob" as B
actor Charlie
actor "Dana" as D
@enduml
```
- `participant` / `actor` with optional display name (quoted) and optional
  `as` alias.
- Participants define the horizontal axis order. First declaration is
  leftmost. Aliases are used in arrow statements.

#### Messages (Arrows)
```
@startuml
Alice -> Bob: Hello
Alice --> Bob: Dotted
Alice ->> Bob: Async
Alice ->o Bob: Return
Alice <-> Bob: Bidirectional
Bob -> Bob: Self-message
@enduml
```
- Arrow types: `->` (solid), `-->` (dotted), `->>` (open), `->o` (circle),
  `<<->>` and similar combinations.
- Direction: `A -> B` (forward), `A <- B` or `B -> A` (both represent
  the same message direction).
- Message label: optional `: text` after the arrow.
- Self-messages: `A -> A: label` rendered as self-arrows.

#### Activations
```
@startuml
Alice -> Bob: do work
activate Bob
Bob --> Alice: result
deactivate Bob
@enduml
```
- `activate` / `deactivate` with optional target. Bare `activate` targets the
  previous message receiver; bare `deactivate` targets the previous message
  sender.
- `return` emits a dotted reverse message and sets the message's `deactivate`
  flag for the previous receiver.

#### Notes
```
@startuml
note left of Alice: This is a note
note right of Bob: Another note
note over Alice, Bob: Spanning note
@enduml
```
- `note left of`, `note right of`, `note over` followed by participant
  name(s) and `: text`.

#### Groups / Boxes
```
@startuml
box "Internal Systems" #LightBlue
participant Alice
participant Bob
end box
@enduml
```
- `box "title" [color] ... end box` — groups participants visually.

#### Grouping Constructs (alt/else/loop/opt/group)
```
@startuml
alt successful case
  Alice -> Bob: request
  Bob --> Alice: ok
else failure case
  Alice -> Bob: request
  Bob --> Alice: error
end
loop every 5 minutes
  Alice -> Bob: ping
end
opt optional
  Alice -> Bob: maybe
end
@enduml
```
- `alt ... else ... end`, `loop ... end`, `opt ... end`,
  `group label ... end`.
- Rendered as labeled boxes spanning the message region.

#### Auto-numbering
```
@startuml
autonumber
Alice -> Bob: request
Bob --> Alice: response
@enduml
```
- `autonumber` / `autonumber stop` / `autonumber resume`.

### 2.2 Unsupported Syntax → Diagnostics

Every unsupported sequence construct produces a `.unsupported` diagnostic
with a best-effort line number and a human-readable description. Examples:

| Construct               | Diagnostic                                         |
|------------------------|-----------------------------------------------------|
| `newpage`              | `.unsupported("PlantUML newpage is not supported")` |
| `title`                | `.unsupported("PlantUML title is not supported")`  |
| `footer`/`header`      | `.unsupported("PlantUML footer/header not supported")` |
| `skinparam`            | `.unsupported("PlantUML skinparam styling not supported")` |
| `hnote`/`rnote`        | `.unsupported("PlantUML hnote/rnote not supported")` |
| `create`/`destroy`     | `.unsupported("PlantUML create/destroy not supported")` |
| `ref over`             | `.unsupported("PlantUML ref over not supported")`  |
| Stereotypes (`<<...>>`)| `.unsupported("PlantUML stereotypes not supported")` |
| `||` separator         | `.unsupported("PlantUML separator lines not supported")` |
| Lifeline styling       | `.unsupported("PlantUML lifeline styling not supported")` |

### 2.3 AST Types

All AST types live in `Sources/DiagramKitPlantUML/Sequence/PlantUMLSequenceAST.swift`.

```swift
/// Root AST for a PlantUML sequence diagram body.
struct PlantUMLSequenceAST: Sendable, Equatable {
    var participants: [PlantUMLParticipant]
    var items: [PlantUMLSequenceItem]
    var hasAutoNumber: Bool
}

struct PlantUMLParticipant: Sendable, Equatable {
    var kind: PlantUMLParticipantKind    // .participant | .actor
    var alias: String                    // used in arrow statements
    var displayName: String?             // optional display name
    var boxName: String?                 // enclosing box name
    var boxFill: String?                 // optional enclosing box fill
}

enum PlantUMLSequenceItem: Sendable, Equatable {
    case message(PlantUMLSequenceMessage)
    case note(PlantUMLSequenceNote)
    case activate(String)                            // target alias
    case deactivate(String)                          // target alias
    case groupStart(String, kind: PlantUMLGroupKind)  // alt/loop/opt/group/box
    case groupEnd
    case divergent(String)                           // else
    case autoNumberStart
    case autoNumberStop
    case unsupported(String, line: Int)              // diagnostic placeholder
}

struct PlantUMLSequenceMessage: Sendable, Equatable {
    var from: String
    var to: String
    var arrow: PlantUMLArrowType
    var label: String?
    var activate: Bool
    var deactivate: Bool
}

enum PlantUMLArrowType: Sendable, Equatable {
    case solid          // ->
    case dotted         // -->
    case open           // ->>
    case circle         // ->o
    case cross          // ->x
    case bidirectional  // <->
}

enum PlantUMLGroupKind: Sendable, Equatable {
    case alt, loop, opt, group, box
}
```

### 2.4 Parser Approach

`PlantUMLSequenceParser` is a line-based parser operating on the body between
`@startuml` and `@enduml`.

**Algorithm**:
1. Tokenize into lines (preserving indentation for grouping constructs).
2. First pass: collect participant/actor declarations and build a participant
   table (alias → display name, ordering).
3. Second pass: walk lines, pattern-matching:
   - `participant ...` / `actor ...` → already collected
   - `A arrow B : label` → parse arrow, emit message if participants known,
     synthesize missing participants
   - `activate X` / `deactivate X` → emit activation item
   - `note left of X: text` / `note right of X: text` / `note over X,Y: text`
     → emit note item
   - `alt text` / `loop text` / `opt text` / `group text` → emit groupStart
   - `else text` → emit divergent
   - `end` → emit groupEnd
   - `box "title" [color]` → start box context
   - `end box` → end box context
   - `autonumber` / `autonumber stop` / `autonumber resume` → emit number
     control
   - Unrecognized lines → emit `.unsupported` diagnostic, continue parsing
4. Return `PlantUMLSequenceAST` with all items and diagnostics.

**Arrow parsing**: the arrow regex extracts `from`, arrow type, and `to`.
Direction detection: if the arrow is `<-`, swap from/to. Multiple arrow
chars are consumed greedily (`->>`, `->>>`, etc.).

### 2.5 Mapping to Existing Model

`PlantUMLSequenceMapper` maps `PlantUMLSequenceAST` to
`DiagramPayload.sequenceDiagram(SequenceDiagram)`.

**Mapping to real `SequenceItem` cases**:
- `PlantUMLParticipant` → `SequenceItem.actor(SequenceActor)`. Aliases become
  `SequenceActor.id`; display names become `SequenceActor.label`. Actor type
  maps to `ParticipantType.actor`, participant to `.participant`.
- `PlantUMLSequenceMessage` → `SequenceItem.message(SequenceMessage)`.
  Arrow types map to `SequenceArrowType` values (e.g., `-->` → `.dotted`,
  `->>` → `.dottedOpen`, `->o` → `.solidOpen`).
  `SequenceMessage.activate`/`.deactivate` booleans preserve inline activation
  markers and return-driven deactivation.
- `note left of` / `note right of` / `note over` →
  `SequenceItem.note(SequenceNote)`. `SequenceNote.actorIds` holds the
  participant IDs; `position` holds `"left"`, `"right"`, or `"over"`.
- `activate X` → `SequenceItem.activationStart(actorId: X)`.
  `deactivate X` → `SequenceItem.activationEnd(actorId: X)`.
- `alt`/`loop`/`opt`/`group` → `SequenceItem.blockStart(type:, label:)`.
  The block type string is `"alt"`, `"loop"`, `"opt"`, or `"group"`.
- `else` → `SequenceItem.blockDivider(type:, label:)` with the same type
  as the enclosing block.
- `end` → `SequenceItem.blockEnd(type:)`.
- `box "title"` → `SequenceItem.boxStart(fill:, title:, wrap:)`.
  `end box` → `SequenceItem.boxEnd`.
- `autonumber` / `autonumber stop` / `autonumber resume` →
  `SequenceItem.autonumberEvent(start:, step:, visible:)`.

**Participant synthesis**: messages referencing undeclared participant aliases
auto-synthesize `SequenceItem.actor(SequenceActor(id: alias, label: alias,
isExplicit: false))` at the point of first reference.

### 2.6 Files to Create

```
Sources/DiagramKitPlantUML/
├── PlantUMLImporter.swift              (~40 lines)
├── PlantUMLProbe.swift                 (~50 lines)
├── PlantUMLFamilyProbe.swift           (~60 lines)
├── PlantUMLDiagnostics.swift           (~30 lines)
└── Sequence/
    ├── PlantUMLSequenceParser.swift    (~300 lines)
    ├── PlantUMLSequenceAST.swift       (~80 lines)
    ├── PlantUMLSequenceMapper.swift    (~200 lines)
    └── PlantUMLSequenceProbe.swift     (~40 lines)
```

### 2.7 Package.swift Changes

```swift
// New target:
.target(
    name: "DiagramKitPlantUML",
    dependencies: ["DiagramKitModel", "DiagramKitImport"],
    swiftSettings: strictConcurrencySettings
),

// New product:
.library(name: "DiagramKitPlantUML", targets: ["DiagramKitPlantUML"]),

// Add to DiagramKit umbrella:
.target(name: "DiagramKitPlantUML"),

// Add to DiagramKitTests testTarget:
"DiagramKitPlantUML",
```

### 2.8 Default Registry Update

In `DiagramPipeline.swift` (or wherever `defaultRegistry` is defined):
```swift
public static let defaultRegistry = ImporterRegistry(importers: [
    StructurizrImporter(),
    PlantUMLImporter(),        // NEW — added in slice 6A
    GraphvizImporter(),
    D2Importer(),
    MermaidImporter()
])
```

### 2.9 Tests

**New test files**:
- `Tests/DiagramKitTests/PlantUMLSequenceParserTests.swift`
- `Tests/DiagramKitTests/PlantUMLSequenceMapperTests.swift`
- `Tests/DiagramKitTests/PlantUMLSequenceIntegrationTests.swift`

**Test structure**:
- `PlantUMLSequenceParsing` suite (~12 tests):
  - Parses single participant
  - Parses multiple participants with aliases
  - Parses actor declarations
  - Parses simple message (`->`)
  - Parses all arrow types (`-->`, `->>`, `->o`, `->x`, `<->`)
  - Parses message labels
  - Parses self-messages
  - Parses activate/deactivate
  - Parses notes (left, right, over)
  - Parses box groups
  - Parses alt/else/end
  - Parses loop/opt/group/end
  - Parses autonumber

- `PlantUMLSequenceDiagnostics` suite (~8 tests):
  - Emits diagnostic for `newpage`
  - Emits diagnostic for `title`
  - Emits diagnostic for `skinparam`
  - Emits diagnostic for stereotypes
  - Emits diagnostic for `ref over`
  - Emits diagnostic for `hnote`/`rnote`
  - Emits diagnostic for `create`/`destroy`
  - Emits diagnostic for `||` separators

- `PlantUMLSequenceMapping` suite (~6 tests):
  - Maps participants to SequenceActors
  - Maps messages to SequenceMessages with correct types
  - Maps notes to SequenceNotes
  - Maps groups to SequenceGroups
  - Synthesizes participants from undeclared message references
  - Explicit activation items map without implicit activation side effects

- `PlantUMLSequenceProbe` suite (~8 tests):
  - Recognizes `participant` in body
  - Recognizes `actor` in body
  - Recognizes `->` arrows in body
  - Recognizes `activate`/`deactivate` keywords
  - Rejects bare `@startuml` with no sequence content
  - Does not false-match on class syntax
  - Does not false-match on mindmap syntax
  - Verifies state syntax is routed by the narrower state probe first

- `PlantUMLSequenceIntegration` suite (~4 tests):
  - Full `@startuml/@enduml` round-trip through `PlantUMLImporter.parse`
  - Parse → `DiagramDocument` → check payload is `.sequenceDiagram`
  - Parse → layout smoke (produces positioned graph)
  - Multiple participants + messages + groups + notes in one diagram

**Probe collision tests** (in `ProbeCollisionMatrixTests`):
- PlantUML outer probe rejects D2, DOT, Structurizr, and Mermaid sources
- Structurizr, D2, DOT, and Mermaid probes reject `@startuml` sources
- PlantUML sequence probe fires before class/mindmap/state probes for
  sequence-only sources

**Inline corpus fixtures** (in the PlantUML sequence test files):
- 3-4 inline fixtures with `skipSnapshots`
- A simple two-participant message diagram
- A diagram with alt/else/end grouping
- A diagram with notes and activation
- A diagram with box grouping

---

### 2.10 Slice 6A Completion Notes

**Implemented 2026-05-12.** All planned features delivered:

| Feature | Status | Notes |
|---------|--------|-------|
| Participants / actors | ✅ | With `as` aliases and display names |
| Arrow types (`->`, `-->`, `->>`, `->o`, `->x`, `<->`) | ✅ | All six variants plus reverse direction |
| Message labels (`: text`) | ✅ | |
| Self-messages | ✅ | |
| Activations (`activate`/`deactivate`) | ✅ | With explicit target and bare previous-message context |
| Notes (left, right, over) | ✅ | With comma-separated multi-target |
| Grouping (alt/else/end, loop, opt, group) | ✅ | With diverge (else) support |
| Boxes (`box "title" ... end box`) | ✅ | Produces `SequenceBox` output |
| `return` keyword | ✅ | Dotted reverse message with deactivation |
| Autonumber | ✅ | start/stop |
| Unsupported syntax diagnostics | ✅ | 10 constructs emit `.unsupported` |

**Actual file inventory (vs estimated):**

| File | Actual lines | Est. lines |
|------|-------------|------------|
| `PlantUMLImporter.swift` | 86 | ~40 |
| `PlantUMLProbe.swift` | 35 | ~50 |
| `PlantUMLFamilyProbe.swift` | 69 | ~60 |
| `PlantUMLDiagnostics.swift` | 31 | ~30 |
| `Sequence/PlantUMLSequenceParser.swift` | 497 | ~300 |
| `Sequence/PlantUMLSequenceAST.swift` | 129 | ~80 |
| `Sequence/PlantUMLSequenceMapper.swift` | 150 | ~200 |
| `Sequence/PlantUMLSequenceProbe.swift` | 63 | ~40 |
| **Total** | **~1,060** | **~800** |

**Actual test coverage:** 55 tests (vs ~38 estimated) — the increase came from
family routing tests, registry tests, probe dispatch verification tests, and
post-review coverage for boxes, return, bare activation, and probe false
negatives.

**Plan deviations:**
1. `isPlantUMLStateBody` — removed bare `end` keyword detection. The keyword `end` is used for closing sequence blocks (`alt/else/end`), making it ambiguous with activity diagram end markers. The State probe now relies on `start`, `stop`, `state `, `[*]`, `partition`, and `:action;` for detection.
2. `isPlantUMLClassBody` — tightened `--` matching to exclude `-->` and `-->>` (sequence arrows). The original probe matched any `--`, which captured sequence messages like `A --> B`, causing the class probe to false-fire on sequence-only sources.
3. State probe tests — adjusted from asserting exclusive probe matching to verifying dispatch order correctness. The sequence probe is intentionally the broadest fallback and may match content that narrower probes also match; the family routing order in `PlantUMLImporter.parse` (C4 → State → Class → Sequence) is the contractual guarantee.

---

## 3. Slice 6B: Class Diagrams

**Slice goal**: parse a useful PlantUML class subset and map it to
`DiagramPayload.classDiagram(ClassDiagram)`.

### 3.1 Supported Syntax

#### Class Declarations
```
@startuml
class Animal {
  +name: String
  -age: Integer
  #protectedField
  ~packageField
  {static} staticField
  {abstract} abstractMethod()
}
@enduml
```
- `class ClassName { ... }` with member declarations.
- Visibility markers: `+` (public), `-` (private), `#` (protected),
  `~` (package).
- Modifiers: `{static}`, `{abstract}`.
- Two-line declaration: `class ClassName` on first line, members on
  subsequent lines.

#### Interface, Enum, Abstract, Annotation
```
@startuml
interface Flyable {
  +fly(): void
}
abstract class Shape {
  {abstract} +area(): float
}
enum Color {
  RED
  GREEN
  BLUE
}
annotation Entity {
  +tableName: String
}
@enduml
```
- `interface`, `abstract class`, `enum`, `annotation` with optional body.
- Enum values without visibility markers.

#### Relationships
```
@startuml
Dog --|> Animal : extends
Bird ..|> Flyable : implements
Person "1" -- "many" Address : lives at
Student --|> Person
Car *-- Wheel : composition
Library o-- Book : aggregation
@enduml
```
- `--|>` extension (inheritance).
- `..|>` implementation (realization).
- `--` association with optional multiplicities.
- `*--` composition.
- `o--` aggregation.
- `..>` dependency.
- Optional relationship labels and multiplicities.

#### Notes
```
@startuml
note top of Animal: Base class
note left of Dog : Canine
note bottom of Cat
  Multi-line
  note text
end note
@enduml
```
- `note top|bottom|left|right of ClassName : text`.
- Multi-line notes with `end note`.

### 3.2 Unsupported Syntax → Diagnostics

| Construct                     | Diagnostic |
|-------------------------------|------------|
| `skinparam` / styling         | `.unsupported("PlantUML class styling not supported")` |
| `package` / namespace         | `.unsupported("PlantUML package/namespace not supported")` |
| `together` block              | `.unsupported("PlantUML together block not supported")` |
| `hide` / `show` directives    | `.unsupported("PlantUML hide/show not supported")` |
| `url` / `link`                | `.unsupported("PlantUML URL links not supported")` |
| `page` / `newpage`            | `.unsupported("PlantUML page directives not supported")` |
| Methods with parameters       | Diagnostic — stored as raw string, not structured |
| `abstract` modifier on methods| `.unsupported("PlantUML abstract methods not supported")` |
| `<<stereotype>>`              | `.unsupported("PlantUML stereotypes not supported")` |
| `!include` / `!define`        | `.unsupported("PlantUML preprocessor directives not supported")` |

### 3.3 AST Types

```swift
struct PlantUMLClassAST: Sendable, Equatable {
    var declarations: [PlantUMLClassDeclaration]
    var relationships: [PlantUMLClassRelationship]
    var notes: [PlantUMLClassNote]
}

struct PlantUMLClassDeclaration: Sendable, Equatable {
    var name: String
    var kind: PlantUMLClassKind       // class, interface, enum, abstract, annotation
    var members: [PlantUMLClassMember]
}

enum PlantUMLClassKind: Sendable, Equatable {
    case `class`, interface, abstractClass, `enum`, annotation
}

struct PlantUMLClassMember: Sendable, Equatable {
    var visibility: PlantUMLVisibility?
    var name: String
    var type: String?                 // e.g., "String", "Integer"
    var modifiers: Set<PlantUMLMemberModifier>
    var isMethod: Bool                // true if name ends with "()"
}

enum PlantUMLVisibility: String, Sendable, Equatable {
    case `public` = "+"
    case `private` = "-"
    case `protected` = "#"
    case package = "~"
}

enum PlantUMLMemberModifier: String, Sendable, Equatable {
    case `static`, abstract
}

struct PlantUMLClassRelationship: Sendable, Equatable {
    var from: String
    var to: String
    var kind: PlantUMLRelationshipKind
    var fromMultiplicity: String?
    var toMultiplicity: String?
    var label: String?
}

enum PlantUMLRelationshipKind: Sendable, Equatable {
    case extension_     // --|> or <|--
    case realization    // ..|> or <|..
    case association    // --
    case composition    // *--
    case aggregation    // o--
    case dependency     // ..>
}

struct PlantUMLClassNote: Sendable, Equatable {
    var target: String               // class name
    var position: PlantUMLNotePosition
    var text: String
}
```

### 3.4 Parser Approach

**Algorithm**:
1. Tokenize into lines.
2. First pass: collect declarations by matching line patterns:
   - `class Name {` / `class Name`
   - `interface Name {` / `interface Name`
   - `abstract class Name`
   - `enum Name {` / `enum Name`
   - `annotation Name {` / `annotation Name`
3. Within a declaration body (between `{` and `}`), parse member lines:
   - Pattern: `[visibility][modifier] name[: type]`
   - Multi-word types are captured greedily.
4. Second pass: parse relationship lines:
   - Pattern: `[from] [multiplicity] arrow [multiplicity] [to] [: label]`
   - Arrow patterns: `--|>`, `..|>`, `--`, `*--`, `o--`, `..>` (and reversals
     like `<|--`).
5. Third pass: parse note lines:
   - `note position of Name : text`
   - Multi-line `note ... end note`.
6. Emit `.unsupported` diagnostics for unrecognized lines.

### 3.5 Mapping to Existing Model

`PlantUMLClassMapper` maps `PlantUMLClassAST` to
`DiagramPayload.classDiagram(ClassDiagram)`.

**Real model types**:
- `PlantUMLClassDeclaration` → `ClassNode`. Members with `+` visibility
  become `ClassMember(visibility: "+")`; `-` → `"-"`; `#` → `"#"`;
  `~` → `"~"`. Methods (`memberType: .method`) carry parameter/return type
  strings. Attributes are `memberType: .attribute`.
- `PlantUMLClassKind` → stored in `ClassNode.annotations` (e.g.,
  `["<<interface>>"]`) and/or `ClassNode.type` string.
- Enum members → `ClassMember(visibility: "", memberType: .attribute)`
  with the member name as the id.

**Relationship mapping** uses `ClassRelationEndpoint` with `type1: Int`,
`type2: Int`, and `lineType: Int`:
- Extension (`--|>` or `<|--`):
  `type1/type2` = `.inheritance.rawValue` (1) on the superclass end,
  `.none.rawValue` (-1) on the other; `lineType` = `.solid.rawValue` (0).
- Realization (`..|>` or `<|..`):
  `type1/type2` = `.inheritance.rawValue` (1) on the interface end,
  `.none.rawValue` (-1) on the other; `lineType` = `.dotted.rawValue` (1).
- Composition (`*--` or `--*`):
  `type1/type2` = `.composition.rawValue` (2) on the diamond end,
  `.none.rawValue` (-1) on the other; `lineType` = `.solid.rawValue` (0).
- Aggregation (`o--` or `--o`):
  `type1/type2` = `.aggregation.rawValue` (0) on the diamond end,
  `.none.rawValue` (-1) on the other; `lineType` = `.solid.rawValue` (0).
- Dependency (`..>` or `<..`):
  both `.none.rawValue` (-1); `lineType` = `.dotted.rawValue` (1).
- Association (`--`):
  both `.none.rawValue` (-1); `lineType` = `.solid.rawValue` (0).

The `ClassRelationship` stores cardinality/multiplicity strings in
`relationTitle1` and `relationTitle2`. Labels go in `title`.
Notes are mapped to `ClassNote` with `class_:` referencing the target class id.

### 3.6 Files to Create

```
Sources/DiagramKitPlantUML/Class/
├── PlantUMLClassParser.swift    (~250 lines)
├── PlantUMLClassAST.swift       (~100 lines)
├── PlantUMLClassMapper.swift    (~200 lines)
└── PlantUMLClassProbe.swift     (~40 lines)
```

### 3.7 Tests

**New test file**: `Tests/DiagramKitTests/PlantUMLClassImporterTests.swift`

**Suites**:
- `PlantUMLClassParsing` (~10 tests): class/interface/enum/abstract/annotation
  declarations, member parsing, visibility modifiers, method detection
- `PlantUMLClassRelationships` (~8 tests): all relationship types, labels,
  multiplicities, bidirectional arrows
- `PlantUMLClassNotes` (~4 tests): single-line notes, multi-line notes, all
  positions
- `PlantUMLClassDiagnostics` (~8 tests): skinparam, package, together, hide/show,
  stereotypes, preprocessor directives, URL links, page directives
- `PlantUMLClassMapping` (~6 tests): class → ClassNode, interface → ClassNode
  with interface flag, relationships → ClassRelationship, notes mapped correctly
- `PlantUMLClassProbe` (~8 tests): recognizes `class`, `interface`,
  `abstract class`, `enum`, `annotation`, `--|>`, `..|>`, rejects bare
  `@startuml` without class content
- `PlantUMLClassIntegration` (~4 tests): full parse→document→layout smoke,
  mixed declarations+relationships+notes

---

## 4. Slice 6C: State/Activity Diagrams

**Slice goal**: parse a useful PlantUML state/activity subset and map it to
`DiagramPayload.stateDiagram(ParsedGraphModel)`.

### 4.1 Supported Syntax

#### State Declarations and Transitions
```
@startuml
[*] --> Idle
Idle --> Processing : start
Processing --> Done : complete
Done --> [*]
@enduml
```
- `state Name` with optional body `{ ... }`.
- `[*]` (start/end pseudostates).
- `-->` transitions with optional `: label`.

#### Composite States
```
@startuml
state Processing {
  [*] --> Validating
  Validating --> Executing : valid
  Executing --> [*]
}
@enduml
```
- Nested states within `state Name { ... }`.

#### Choice / Fork / Join
```
@startuml
state choice_state <<choice>>
state fork_state <<fork>>
state join_state <<join>>
[*] --> fork_state
fork_state --> State1
fork_state --> State2
State1 --> join_state
State2 --> join_state
join_state --> [*]
@enduml
```
- `<<choice>>`, `<<fork>>`, `<<join>>` stereotypes on states.

#### Activity Constructs
```
@startuml
start
if (condition?) then (yes)
  :do something;
else (no)
  :do else;
endif
stop
@enduml
```
- `start` / `stop` / `end` keywords.
- `if (condition) then (yes) ... else (no) ... endif`.
- `while (condition) ... endwhile`.
- `repeat ... repeat while (condition)`.
- `fork ... fork again ... end fork`.
- Activity actions: `:action text;`.

#### Notes
```
@startuml
note right of State1 : Description
note left of Processing
  Multi-line note
end note
@enduml
```

#### Partitions / Swimlanes
```
@startuml
partition "Frontend" {
  :User action;
}
partition "Backend" {
  :Process request;
}
@enduml
```
- `partition "name" { ... }` — maps to swimlane/group.

### 4.2 Unsupported Syntax → Diagnostics

| Construct                    | Diagnostic |
|------------------------------|------------|
| `skinparam` / styling        | `.unsupported("PlantUML state styling not supported")` |
| Concurrent regions (`--`)    | `.unsupported("PlantUML concurrent regions not supported")` |
| History pseudostates (`[H]`)| `.unsupported("PlantUML history pseudostates not supported")` |
| Entry/exit/do activities     | `.unsupported("PlantUML state entry/exit/do not supported")` |
| `detach`                     | `.unsupported("PlantUML detach not supported")` |
| `newpage`                    | `.unsupported("PlantUML page directives not supported")` |
| `title`                      | `.unsupported("PlantUML title not supported")` |

### 4.3 AST Types

```swift
struct PlantUMLStateAST: Sendable, Equatable {
    var nodes: [PlantUMLStateNode]
    var transitions: [PlantUMLStateTransition]
    var partitions: [PlantUMLStatePartition]
    var notes: [PlantUMLStateNote]
}

struct PlantUMLStateNode: Sendable, Equatable {
    var name: String
    var label: String?
    var kind: PlantUMLStateNodeKind
    var parentName: String?          // for composite/nested states
    var stereotypes: [String]
}

enum PlantUMLStateNodeKind: Sendable, Equatable {
    case simple
    case start          // [*]
    case end            // [*] (context-dependent)
    case choice
    case fork
    case join
    case activity       // :action;
    case ifCondition(String)   // condition text
    case startActivity  // start keyword
    case stopActivity   // stop keyword
    case endActivity    // end keyword
    case composite([PlantUMLStateNode], [PlantUMLStateTransition])
}

struct PlantUMLStateTransition: Sendable, Equatable {
    var from: String
    var to: String
    var label: String?
}

struct PlantUMLStatePartition: Sendable, Equatable {
    var name: String
    var nodes: [PlantUMLStateNode]
}
```

### 4.4 Parser Approach

**Algorithm**:
1. Tokenize into lines. Detect family: `state ` keyword, `[*]` pseudostate,
   activity `start`/`stop`, or `:` action syntax.
2. First pass: collect state declarations, composite state bodies, and
   partition blocks.
3. Second pass: parse transition lines (`Name --> Name : label`).
4. Third pass: for activity constructs, map `if/then/else/endif`,
   `while/endwhile`, `fork/fork again/end fork` to composite nodes with
   internal transitions.
5. Emit `.unsupported` diagnostics for unrecognized lines.

### 4.5 Mapping to Existing Model

`PlantUMLStateMapper` maps `PlantUMLStateAST` to
`DiagramPayload.stateDiagram(ParsedGraphModel)`.

**Mapping strategy**:
- Each `PlantUMLStateNode` → a node in `ParsedGraphModel`.
- `PlantUMLStateTransition` → an edge in `ParsedGraphModel`.
- Composite states → groups in `ParsedGraphModel`.
- Partitions → subgraph groups.
- Activity `if`/`while`/`fork` constructs → nodes with special shapes.
- `[*]` start → `stateStart` shape; `[*]` end → `stateEnd` shape.

### 4.6 Files to Create

```
Sources/DiagramKitPlantUML/StateActivity/
├── PlantUMLStateParser.swift    (~250 lines)
├── PlantUMLStateAST.swift       (~100 lines)
├── PlantUMLStateMapper.swift    (~200 lines)
└── PlantUMLStateProbe.swift     (~40 lines)
```

### 4.7 Tests

**New test file**: `Tests/DiagramKitTests/PlantUMLStateActivityImporterTests.swift`

**Suites**:
- `PlantUMLStateParsing` (~10 tests): simple state, composite state, start/end
  pseudostates, transitions, labeled transitions, choice/fork/join stereotypes
- `PlantUMLActivityParsing` (~10 tests): start/stop, `:action;`, if/then/else,
  while/endwhile, repeat, fork/fork again/end fork, partitions
- `PlantUMLStateDiagnostics` (~6 tests): skinparam, concurrent regions, history
  pseudostates, entry/exit/do, detach, newpage
- `PlantUMLStateMapping` (~6 tests): nodes → ParsedGraphModel, transitions →
  edges, composite → groups, partitions → subgraphs
- `PlantUMLStateProbe` (~8 tests): recognizes `state`, `[*]`, `-->`,
  `:action;`, `start`/`stop`, `partition`, rejects bare `@startuml`
- `PlantUMLStateIntegration` (~4 tests): parse→document→layout smoke,
  state diagram + activity mixed diagram

---

## 5. Slice 6D: Mindmap and Gantt

**Slice goal**: parse PlantUML mindmap and Gantt diagrams, mapping to
`DiagramPayload.mindmap(MindmapDiagram)` and
`DiagramPayload.gantt(GanttDiagram)` respectively.

### 5.1 Mindmap

#### Supported Syntax

```
@startmindmap
* Root Node
** First Level
*** Second Level
**** Third Level
** Another Branch
*** Leaf
@endmindmap
```
- `@startmindmap` / `@startwbs` headers.
- `*` indentation-based hierarchy.
- Optional color/style markers: `* Root #color`.
- Optional icons: `*:icon` syntax → diagnostic for unsupported icons.

#### Mindmap AST

```swift
struct PlantUMLMindmapAST: Sendable, Equatable {
    var root: PlantUMLMindmapNode?
    var allNodes: [PlantUMLMindmapNode]
}

struct PlantUMLMindmapNode: Sendable, Equatable {
    var text: String
    var level: Int
    var children: [PlantUMLMindmapNode]
}
```

#### Parser Approach

Line-based. Count `*` characters at line start to determine depth. Build tree
by maintaining a stack of ancestors at each depth level.

#### Mapping

`PlantUMLMindmapMapper` maps `PlantUMLMindmapAST` to
`DiagramPayload.mindmap(MindmapDiagram)`. `PlantUMLMindmapNode` → `MindmapNode`
with children.

#### Files

```
Sources/DiagramKitPlantUML/MindmapGantt/
├── PlantUMLMindmapParser.swift    (~100 lines)
├── PlantUMLMindmapAST.swift       (~40 lines)
├── PlantUMLMindmapMapper.swift    (~80 lines)
├── PlantUMLGanttParser.swift      (~200 lines)
├── PlantUMLGanttAST.swift         (~80 lines)
└── PlantUMLGanttMapper.swift      (~150 lines)
```

### 5.2 Gantt

#### Supported Syntax

```
@startgantt
[Prototype design] lasts 15 days
[Test prototype] lasts 10 days
[Test prototype] starts at [Prototype design]'s end
-- Separator --
[Team 1] lasts 20 days
[Team 1] is colored in Blue
@endgantt
```
- `@startgantt` / `@endgantt` headers.
- `[Task name] lasts N days` — task with fixed duration.
- `[Task] starts at [OtherTask]'s end` — dependency.
- `[Task] starts D days after [OtherTask]'s start` — offset dependency.
- `-- text --` — separator/section marker.
- `[Task] is colored in Color` — task color.
- Print scale: `printscale daily` / `printscale weekly`.
- `Project starts the YYYY-MM-DD` — absolute date anchor.

#### Unsupported → Diagnostics

| Construct                 | Diagnostic |
|---------------------------|------------|
| `[Task] happens at ...`   | `.unsupported` |
| Resource assignments      | `.unsupported` |
| `[Task] requires N ...`   | `.unsupported` |
| `saturday are closed`     | `.unsupported` |
| `today is ...`            | `.unsupported` |
| `weeknumber are on`       | `.unsupported` |
| Hyperlinks                | `.unsupported` |

#### Gantt AST

```swift
struct PlantUMLGanttAST: Sendable, Equatable {
    var tasks: [PlantUMLGanttTask]
    var separators: [PlantUMLGanttSeparator]
    var projectStart: String?          // YYYY-MM-DD if specified
    var printScale: PlantUMLGanttScale?
}

struct PlantUMLGanttTask: Sendable, Equatable {
    var name: String
    var duration: Int?                 // days
    var color: String?
    var startAfter: String?            // dependency task name
    var startOffset: Int?              // days offset
}

struct PlantUMLGanttSeparator: Sendable, Equatable {
    var text: String
    var line: Int
}
```

#### Mapping

`PlantUMLGanttMapper` maps `PlantUMLGanttAST` to
`DiagramPayload.gantt(GanttDiagram)`.

**Real model constraint**: `GanttTask` requires concrete `startTime: Date` and
`endTime: Date`. The PlantUML Gantt AST stores durations (in days) and
dependency names. The mapper must include a **scheduling resolver** that:
1. Parses the optional `projectStart` string (e.g. `"2025-01-06"`) into a
   `Date` anchor via ISO 8601 or `YYYY-MM-DD` format.
2. Sorts tasks topologically by dependency graph.
3. Computes `startTime` for each task: for tasks with `startAfter` deps,
   use the predecessor's `endTime` (plus offset days if specified). For
   tasks without deps, use the project start date. For tasks with only a
   duration, use the project start date.
4. Computes `endTime` = `startTime + duration days`.
5. Tasks with unresolvable dependencies (missing predecessor, cycle) emit
   a `.warning` diagnostic and default to project start + cumulative offset.
- Separators → `GanttSection(name: separatorText, index:)`.
- Project start → used by the resolver, not directly stored in config.
- Print scale → stored in `GanttDiagram.axisFormat` and `tickInterval`.
- Colors → stored on `GanttTask` via future tag/class support; for now
  documented as an unsupported diagnostic on color assignment.

### 5.3 Tests

**New test files**:
- `Tests/DiagramKitTests/PlantUMLMindmapImporterTests.swift`
- `Tests/DiagramKitTests/PlantUMLGanttImporterTests.swift`

**Mindmap suites** (~20 tests total):
- `PlantUMLMindmapParsing`: 1-level, 2-level, 3-level trees, multiple branches
- `PlantUMLMindmapDiagnostics`: icons, unsupported markers
- `PlantUMLMindmapMapping`: tree → MindmapDiagram
- `PlantUMLMindmapProbe`: `@startmindmap` / `@startwbs` recognition, rejects
  `@startuml` without mindmap content
- `PlantUMLMindmapIntegration`: parse→document→layout smoke

**Gantt suites** (~25 tests total):
- `PlantUMLGanttParsing`: tasks with durations, dependencies, start offsets,
  colors, separators, print scale, project start date
- `PlantUMLGanttDiagnostics`: resource assignments, time constraints, hyperlinks
- `PlantUMLGanttMapping`: tasks → GanttTask, dependencies → task relationships,
  separators → section markers
- `PlantUMLGanttProbe`: `@startgantt` recognition, rejects standard `@startuml`
- `PlantUMLGanttIntegration`: parse→document→layout smoke

---

## 6. Slice 6E: C4-Flavored PlantUML

**Slice goal**: parse PlantUML C4 diagrams using the C4-PlantUML macro library
and map them to `DiagramPayload.c4(C4Diagram)`.

### 6.1 Supported Syntax

PlantUML C4 diagrams use include directives to load macro definitions, then
call those macros:

```
@startuml
!include <C4/C4_Container>

Person(personAlias, "Person Name", "Description")
System(systemAlias, "System Name", "Description")
System_Ext(extAlias, "External System", "Description")

Container(systemAlias, containerAlias, "Container Name", "Technology", "Description")
ContainerDb(systemAlias, dbAlias, "Database", "PostgreSQL", "Description")

Rel(personAlias, containerAlias, "Uses", "HTTPS")
Rel_D(containerAlias, dbAlias, "Reads/Writes")
Rel_U(dbAlias, containerAlias, "Returns data")

Boundary(containerAlias, "API Layer") {
  Container(systemAlias, apiAlias, "API Server", "Go", "Serves requests")
}

@enduml
```

- `!include <C4/C4_Container>` and `!include <C4/C4_Component>`.
- `Person(alias, name, description[, tags])`.
- `Person_Ext(alias, name, description[, tags])`.
- `System(alias, name, description[, tags])`.
- `System_Ext(alias, name, description[, tags])`.
- `Container(systemAlias, alias, name, technology, description[, tags])`.
- `ContainerDb(systemAlias, alias, name, technology, description[, tags])`.
- `Component(containerAlias, alias, name, technology, description[, tags])`.
- `Rel(from, to, label[, technology])`.
- `Rel_D(from, to, label)` / `Rel_U` / `Rel_L` / `Rel_R` for directional
  relationships.
- `Rel_Back(from, to, label)` / `Rel_Neighbor`.
- `Boundary(alias, "label") { ... }` — visual grouping.
- `System_Boundary(alias, "label") { ... }`.
- `Enterprise_Boundary(alias, "label") { ... }`.
- `Lay_D(from, to)` / `Lay_U` / `Lay_L` / `Lay_R` layout hints —
  silently ignored (no position constraint in current layout engine).

### 6.2 Unsupported Syntax → Diagnostics

| Construct                         | Diagnostic |
|-----------------------------------|------------|
| `!include <C4/C4_Deployment>`    | `.unsupported("C4 Deployment diagrams not supported")` |
| `!include <C4/C4_Dynamic>`       | `.unsupported("C4 Dynamic diagrams not supported")` |
| `Deployment_Node`                | `.unsupported("Deployment_Node not supported")` |
| `Container_Boundary`             | `.unsupported("Container_Boundary not supported")` |
| `AddElementTag`, `AddRelTag` with unsupported tags | `.unsupported("C4 styling directives not supported")` |
| `UpdateElementStyle` / `UpdateRelStyle` | `.unsupported("C4 styling not supported")` |
| `SHOW_LEGEND()` / `SHOW_DYNAMIC_LEGEND()` | `.unsupported("C4 legend not supported")` |
| `!include` non-C4 files          | `.unsupported("Non-C4 includes not supported")` |
| `!define`                        | `.unsupported("PlantUML preprocessor not supported")` |

### 6.3 AST Types

```swift
struct PlantUMLC4AST: Sendable, Equatable {
    var elements: [PlantUMLC4Element]
    var relationships: [PlantUMLC4Relationship]
    var boundaries: [PlantUMLC4Boundary]
    var includes: [String]              // C4 include directives recognized
    var diagramKind: PlantUMLC4DiagramKind
}

enum PlantUMLC4DiagramKind: Sendable, Equatable {
    case container           // !include <C4/C4_Container>
    case component           // !include <C4/C4_Component>
    case context             // default when no include
}

struct PlantUMLC4Element: Sendable, Equatable {
    var alias: String
    var name: String
    var kind: PlantUMLC4ElementKind
    var description: String?
    var technology: String?
    var tags: [String]
    var parentAlias: String?           // system or container alias
}

enum PlantUMLC4ElementKind: Sendable, Equatable {
    case person, personExternal, system, systemExternal
    case container, containerDb, component
    case boundary, enterpriseBoundary, systemBoundary
}

struct PlantUMLC4Relationship: Sendable, Equatable {
    var from: String
    var to: String
    var label: String?
    var technology: String?
    var direction: PlantUMLC4Direction?
}

enum PlantUMLC4Direction: Sendable, Equatable {
    case right, left, up, down, back, neighbor
}

struct PlantUMLC4Boundary: Sendable, Equatable {
    var alias: String
    var label: String
    var kind: PlantUMLC4ElementKind     // boundary type
}
```

### 6.4 Parser Approach

**Algorithm**:
1. Detect C4 family: source contains `!include <C4/` directive.
2. Determine diagram kind from the include path (Container, Component, Context).
3. Parse macro invocations:
   - `Person(`, `Person_Ext(` → element with appropriate kind
   - `System(`, `System_Ext(` → element
   - `Container(`, `ContainerDb(` → element (with system parent)
   - `Component(` → element (with container parent)
   - `Rel(`, `Rel_D(` etc. → relationship
   - `Boundary(` / `System_Boundary(` / `Enterprise_Boundary(` → boundary
     with nested elements
4. Collect all parsed elements, relationships, boundaries.
5. Emit `.unsupported` diagnostics for unrecognized macros and directives.

**Macro argument parsing**: arguments are comma-separated with optional
quoted strings. The parser handles nested parentheses for boundary bodies.

### 6.5 Mapping to Existing Model

`PlantUMLC4Mapper` maps `PlantUMLC4AST` to `DiagramPayload.c4(C4Diagram)`.

**Real model types** (see `Sources/DiagramKitModel/src_c4_types.swift`):

The C4 model uses a unified `C4Shape` with `typeC4Shape: C4ShapeType` to
represent all element kinds. There are no separate `C4Person` or
`C4SoftwareSystem` types.

- `Person(alias, name, description)` →
  `C4Shape(alias:, label: name, typeC4Shape: .person, description:)`.
- `Person_Ext(alias, name, description)` →
  `C4Shape(alias:, label: name, typeC4Shape: .external_person, description:)`.
- `System(alias, name, description)` →
  `C4Shape(alias:, label: name, typeC4Shape: .system, description:)`.
- `System_Ext(alias, name, description)` →
  `C4Shape(alias:, label: name, typeC4Shape: .external_system, description:)`.
- `Container(systemAlias, alias, name, technology, description)` →
  `C4Shape(alias:, label: name, typeC4Shape: .container, technology:,
  description:, parentBoundary: systemAlias)`.
- `ContainerDb(...)` → `.container_db`; `Component(...)` → `.component`.
- `Rel(from, to, label[, technology])` →
  `C4Relationship(kind: .rel, from:, to:, label:, technology:)`.
- `Rel_D` → `C4RelationshipKind.rel_d`; `Rel_U` → `.rel_u`;
  `Rel_L` → `.rel_l`; `Rel_R` → `.rel_r`;
  `Rel_Back` → `.rel_b`; bidirectional → `.birel`.
- `Boundary(alias, "label") { ... }` →
  `C4Boundary(alias:, label:)`. Nested elements get
  `parentBoundary: alias` linking them to the boundary.
- `System_Boundary` / `Enterprise_Boundary` →
  `C4Boundary` with `type:` string (`"System_Boundary"`, etc.).
- Diagram kind: `!include <C4/C4_Container>` → `.container`;
  `!include <C4/C4_Component>` → `.component`;
  default (Context) → `.context`.

### 6.6 Files to Create

```
Sources/DiagramKitPlantUML/C4/
├── PlantUMLC4Parser.swift       (~250 lines)
├── PlantUMLC4AST.swift          (~120 lines)
├── PlantUMLC4Mapper.swift       (~200 lines)
└── PlantUMLC4Probe.swift        (~50 lines)
```

### 6.7 Tests

**New test file**: `Tests/DiagramKitTests/PlantUMLC4ImporterTests.swift`

**Suites**:
- `PlantUMLC4Parsing` (~10 tests): Person, System, System_Ext, Container,
  ContainerDb, Component, Rel/Rel_D/Rel_U/Rel_L/Rel_R, Boundary with nested
  elements, System_Boundary, multiple relationships
- `PlantUMLC4Diagnostics` (~8 tests): Deployment includes, Dynamic includes,
  Deployment_Node, unsupported macros, styling directives, legend, non-C4
  includes, preprocessor
- `PlantUMLC4Mapping` (~8 tests): Person → C4Shape(.person), System →
  C4Shape(.system), Container → C4Shape(.container) with parentBoundary,
  Component → C4Shape(.component), Rel → C4Relationship, boundaries →
  C4Boundary, diagram kind detection, external elements flagged via shape type
- `PlantUMLC4Probe` (~6 tests): recognizes `!include <C4/`, recognizes
  `Person(`, `System(`, `Container(`, rejects `@startuml` without C4 content,
  does not false-match on sequence with `->` arrows
- `PlantUMLC4Integration` (~4 tests): Container diagram parse→document→layout,
  Component diagram, Context diagram, mixed with boundaries

---

## 7. Testing Strategy

### 7.1 Test File Inventory

| Test File                                          | Slice | Est. Tests |
|----------------------------------------------------|-------|------------|
| `PlantUMLSequenceParserTests.swift`                | 6A    | ~32        |
| `PlantUMLSequenceMapperTests.swift`                | 6A    | ~8         |
| `PlantUMLSequenceIntegrationTests.swift`           | 6A    | ~15        |
| `PlantUMLClassImporterTests.swift`                 | 6B    | ~40        |
| `PlantUMLStateActivityImporterTests.swift`         | 6C    | ~44        |
| `PlantUMLMindmapImporterTests.swift`               | 6D    | ~20        |
| `PlantUMLGanttImporterTests.swift`                 | 6D    | ~25        |
| `PlantUMLC4ImporterTests.swift`                    | 6E    | ~36        |
| `ProbeCollisionMatrixTests.swift` (extensions)     | all   | ~30        |
| `PlantUMLImporterSmokeTests.swift`                 | all   | ~15        |
| **Total**                                          |       | **~248**   |

### 7.2 Probe Collision Matrix

Every slice adds probe collision tests. The outer PlantUML probe must reject
all other formats, and all existing importers must reject PlantUML sources.

**Probe rejection tests** (added incrementally across slices):

| Test                                  | Phase    |
|---------------------------------------|----------|
| PlantUML outer probe rejects D2       | 6A       |
| PlantUML outer probe rejects DOT      | 6A       |
| PlantUML outer probe rejects Structurizr | 6A    |
| PlantUML outer probe rejects Mermaid  | 6A       |
| D2 probe rejects PlantUML @startuml   | pre-exists |
| DOT probe rejects PlantUML @startuml  | pre-exists |
| Structurizr probe rejects PlantUML    | pre-exists |
| Mermaid probe accepts PlantUML (fallback) | 6A verification |
| PlantUML family routing: sequence not confused with class | 6B |
| PlantUML family routing: class not confused with state | 6C |
| PlantUML family routing: @startmindmap routes to mindmap | 6D |
| PlantUML family routing: @startgantt routes to gantt | 6D |
| PlantUML family routing: !include C4 routes to C4 | 6E |
| Probe ordering: PlantUML before Mermaid in registry | 6A |

### 7.3 Inline Corpus Fixtures

Each slice includes 3-4 inline fixtures in test source files, marked as
`skipSnapshots`. These are text constants parsed through the importer and
inspected programmatically. No real `test-diagrams.json` entries are added,
and no snapshot baselines are recorded.

### 7.4 Regression Tests

Each slice addition runs the full test suite to verify:
- No Mermaid parsing regressions.
- No D2, DOT, or Structurizr routing regressions.
- No `CorpusSnapshotTests` regressions (all 396 Mermaid entries still render).
- No layout regressions in format-agnostic paths.

### 7.5 Parse-to-Layout Smoke

Every slice includes at least one test that:
1. Parses PlantUML source through `PlantUMLImporter.parse`
2. Feeds the resulting `DiagramDocument` through `GraphLayout.layout` (or
   the family-specific layout path)
3. Asserts a non-zero-positioned graph is produced
4. Asserts the correct `PositionedContent` case

---

## 8. Verification Gates

For each slice, before marking the slice complete:

```bash
swift package dump-package
swift build --build-tests
swift test --filter <phase-specific PlantUML suites>
swift test --filter ProbeCollisionMatrixTests
swift test --filter ImporterRegistryTests
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
git diff --check
```

**CorpusSnapshotTests are only required per-slice if a slice touches
shared layout or rendering code.** PlantUML slices only touch the import
boundary (parser → mapper → DiagramPayload). They do not modify layout,
renderers, or shared model types. If `swift build --build-tests` succeeds
and the PlantUML-specific test suites pass, the 396 existing Mermaid
snapshots are unaffected.

Run `swift test --filter CorpusSnapshotTests` as a sanity check at the end
of each slice, but do not treat expected mechanical success as a gate
failure — only treat snapshot diffs or crashes as blockers.

For the final slice (6E) or when the full Phase 6 is complete, run:
```bash
swift test                    # full suite
Scripts/bootstrap-smoke-check.sh
Scripts/linux-check.sh        # skip if Docker/Podman unavailable
```

**File-size constraint**: no new/touched `.swift` file exceeds 500 lines.
Split files by concern before they approach the threshold.

**Sendable annotation**: all public types in `DiagramKitPlantUML` must conform
to `Sendable`. Structs with only `Sendable` fields are implicitly `Sendable`.
Any `@unchecked Sendable` must carry a "Concurrency Contract" banner.

---

## 9. Deferred / Out of Scope

The following PlantUML features are **explicitly deferred** from Phase 6:

- **`skinparam` and full styling** across all families. Styling is deferred to
  a post-exporter rendering pass.
- **`!include` resolution for non-C4 files.** Only C4 includes are recognized;
  all other includes emit diagnostics.
- **Preprocessor (`!define`, `!ifdef`, `!ifndef`, `!procedure`).** Not supported.
- **`newpage`, `title`, `header`, `footer`** across all families. Emit
  diagnostics.
- **URL links and tooltips.** Not supported.
- **Stereotypes (`<<...>>`) with semantic meaning.** Stored as raw strings in
  diagnostics.
- **Full class method signatures with parameter types.** Stored as strings
  rather than structured types.
- **PlantUML themes.** Not supported.
- **`@startgantt` resource management and calendar configuration.**
- **`@startmindmap` with icons, images, or Markdown formatting.**
- **C4 Deployment and Dynamic views.**
- **Deployment diagrams** (`Deployment_Node` in C4 or PlantUML).
- **Real `test-diagrams.json` entries and snapshot baselines** for PlantUML.
  These are deferred to Phase 10 (Release and Deprecation Cleanup).
- **Exporting PlantUML.** Deferred to Phase 7 (Exporter Protocol).
- **ASCII rendering from PlantUML source.** The current `DiagramPipeline.
  renderASCII` is Mermaid-specific. PlantUML ASCII support is deferred.

**Scope boundary rule**: if the PlantUML Java reference implementation has more
than 50 lines of source for a given feature, and that feature is not listed in
the "Supported Syntax" sections above, it is deferred.

---

## 10. Delivery Cadence

Each slice is independently shippable. A slice is complete when:
1. All files are created and compile.
2. All tests in the slice's suite pass.
3. All probe collision tests pass (existing + new).
4. All regression suites pass (Mermaid, D2, DOT, Structurizr).
5. `swift test --filter CorpusSnapshotTests` shows no snapshot diffs or
   crashes (expected: all 396 Mermaid entries pass; PlantUML import-only
   work does not affect snapshots).
6. Verification gates pass.

**Slice order and estimated effort:**

| Slice | Family             | Est. Source | Est. Test | Est. Tests | Done | Actual Src | Actual Test | Act. Tests |
|-------|--------------------|------------|-----------|------------|------|-----------|------------|-----------|
| 6A    | Sequence           | ~800        | ~650      | ~38        | ✅ | ~1,060 | ~835 | 55 |
| 6B    | Class              | ~600        | ~700      | ~40        |   | —      | —    | —  |
| 6C    | State/Activity     | ~600        | ~750      | ~44        |   | —      | —    | —  |
| 6D    | Mindmap + Gantt    | ~650        | ~800      | ~45        |   | —      | —    | —  |
| 6E    | C4                 | ~620        | ~650      | ~36        |   | —      | —    | —  |
|       | Shared infra       | ~200        | ~200      | ~15        |   | —      | —    | —  |
|       | Probe extensions   | —           | ~400      | ~30        |   | —      | —    | —  |
| **Total** |               | **~3,470**  | **~4,150** | **~248**  |   | **~1,060** | **~835** | **55** |

**Dependencies between slices**:
- Slice 6A creates the `DiagramKitPlantUML` target and shared infrastructure.
  It is a hard prerequisite for all subsequent slices.
- Slices 6B-6E are independent of each other. They can be implemented in any
  order after 6A, though the recommended order follows increasing complexity
  of the family-specific probe logic.
- Slice 6D (Mindmap + Gantt) is bundled because both use explicit
  `@startmindmap`/`@startgantt` headers with no body-level ambiguity, making
  the combined probe trivial.
- Slice 6E (C4) is last because it adds `!include` awareness, which may
  require minor adjustments to the family probe dispatch if `!include`
  directives appear before family-specific syntax.

---

*This plan was written against the Phase 5 completed state described in
`PHASES.md` and `PHASE-5.md`. The PlantUML reference repository is at
`~/Dev/Research/DiagramKit/plantuml`. The existing multi-format architecture
described in `ANALYSIS.md` sections 1-6 is the foundation for all slices.*
