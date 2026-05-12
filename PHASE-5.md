# Phase 5: Structurizr Importer Vertical Slice — Plan

Date: 2026-05-12. **Status: PLANNING** — this document is the executable plan
for Phase 5 of the DiagramKit multi-format roadmap. It follows Phase 4
(complete: Graphviz DOT importer) and precedes Phase 6 (PlantUML importer).

## Goal

Support the C4-shaped subset where Structurizr DSL maps cleanly to the
existing `C4Diagram` model. Add Structurizr as the first non-Mermaid importer
that targets `DiagramPayload.c4(C4Diagram)`, proving that the C4 payload path
works across the importer boundary.

## Architecture Overview

```
Sources/DiagramKitStructurizr/
├── StructurizrImporter.swift   DiagramSourceImporter conformance
├── StructurizrAST.swift        Minimal Structurizr DSL AST types
├── StructurizrParser.swift     Recursive-descent parser
├── StructurizrMapper.swift     StructurizrAST → C4Diagram mapping
├── StructurizrProbe.swift      Narrow probe function
└── StructurizrModelRegistry.swift  Model element lookup table
```

The Structurizr importer follows the same pattern as D2 and Graphviz: parse a
subset of the Structurizr DSL, map to DiagramKit's existing payload type
(`C4Diagram`), emit diagnostics for unsupported constructs, and reuse the
existing C4 layout and render pipelines. There are no new diagram types, no
layout changes, no renderer changes, no snapshot baselines, and no real corpus
edits.

### How Structurizr differs from D2/DOT

D2 and DOT both map to `DiagramPayload.flowchart` — a graph with nodes, edges,
and subgraphs. Structurizr maps to `DiagramPayload.c4(C4Diagram)` — a
semantically richer model with typed shapes (`C4ShapeType`: person, system,
container, component, etc.), boundaries, and relationships with explicit
direction and technology fields. The C4 layout (`layoutC4Diagram`) and SVG/CG
renderers already handle this payload, so the Structurizr importer only needs
to produce valid `C4Diagram` values.

### Structurizr DSL structure (narrow slice)

```
workspace {
    model {
        user = person "User Name" "Description"
        app = softwareSystem "My App" "Description" {
            web = container "Web App" "Spring Boot" "Description"
            auth = component "Auth Service" "Description"
        }
        user -> app "Uses" "HTTPS"
    }
    views {
        systemContext app "System Context" {
            include *
        }
        container app "Container View" {
            include *
        }
        component web "Component View" {
            include *
        }
    }
}
```

**Key concepts for the vertical slice:**

- **Model elements**: `person`, `softwareSystem`, `container`, `component` —
  defined with `=` assignment syntax. Each carries an identifier (alias), a
  type keyword, a name string, an optional description string, and optional
  technology string.
- **Nested elements**: containers and components can be defined inside
  `softwareSystem { ... }` or `container { ... }` blocks. The parser tracks
  parent-child relationships.
- **Relationships**: explicit `source -> target "Label" "Technology"` syntax,
  defined at the model level or inside element blocks.
- **Views**: `systemContext`, `container`, `component` — each names a scoping
  element and includes a subset of model elements. `include *` means "include
  all elements visible from the scoping element's perspective."
- **Tags**: `{tag1 tag2}` annotations after elements — deferred with diagnostics.

For the vertical slice, the importer parses a complete workspace, extracts all
model elements/relationships, processes the **first** view definition only,
resolves it against the model registry, and produces a single `C4Diagram`.
Additional views emit `.unsupported` diagnostics. `deployment` and `dynamic`
views are deferred entirely.

---

## Work Stream 1: `DiagramKitStructurizr` Target

Add a single new SPM target and product. Follows the `DiagramKitD2` and
`DiagramKitGraphviz` patterns exactly.

### Package.swift changes

**Products** — add:

```swift
.library(name: "DiagramKitStructurizr", targets: ["DiagramKitStructurizr"]),
```

**Targets** — add:

```swift
.target(
    name: "DiagramKitStructurizr",
    dependencies: ["DiagramKitModel", "DiagramKitImport"],
    swiftSettings: strictConcurrencySettings
),
```

**Umbrella target** — add `DiagramKitStructurizr` as a dependency of `DiagramKit`:

```swift
.target(
    name: "DiagramKit",
    dependencies: [
        // ... existing deps ...
        .target(name: "DiagramKitD2"),
        .target(name: "DiagramKitGraphviz"),
        .target(name: "DiagramKitStructurizr"),   // NEW
        // ...
    ]
),
```

**Test target** — add `DiagramKitStructurizr` as a dependency of `DiagramKitTests`:

```swift
.testTarget(
    name: "DiagramKitTests",
    dependencies: [
        // ... existing deps ...
        "DiagramKitD2",
        "DiagramKitGraphviz",
        "DiagramKitStructurizr",                  // NEW
        // ...
    ]
),
```

## Work Stream 2: Structurizr DSL AST Types (`StructurizrAST.swift`)

All types are value types (`Sendable`). The AST models the narrow DSL subset
we parse — not the full Structurizr DSL language.

### Top-level types

```swift
/// Top-level: a complete Structurizr workspace definition.
public struct StructurizrWorkspace: Sendable {
    public var model: StructurizrModel?
    public var views: [StructurizrView]

    public init(model: StructurizrModel? = nil, views: [StructurizrView] = []) {
        self.model = model
        self.views = views
    }
}

/// The model section: all element definitions and relationships.
public struct StructurizrModel: Sendable {
    public var elements: [StructurizrModelElement]
    public var relationships: [StructurizrRelationshipDef]

    public init(
        elements: [StructurizrModelElement] = [],
        relationships: [StructurizrRelationshipDef] = []
    ) {
        self.elements = elements
        self.relationships = relationships
    }
}
```

### Model element types

```swift
/// A single model element (person, softwareSystem, container, component).
public struct StructurizrModelElement: Sendable {
    public var alias: String                // e.g., "user", "app", "web"
    public var kind: StructurizrElementKind
    public var name: String                 // display name, e.g., "User Name"
    public var description: String?         // optional description string
    public var technology: String?          // optional technology string
    public var tags: [String]               // tag annotations (deferred)
    public var parentAlias: String?         // nil for top-level, alias of parent
    public var children: [StructurizrModelElement]  // nested elements defined in block

    public init(
        alias: String,
        kind: StructurizrElementKind,
        name: String,
        description: String? = nil,
        technology: String? = nil,
        tags: [String] = [],
        parentAlias: String? = nil,
        children: [StructurizrModelElement] = []
    ) {
        self.alias = alias
        self.kind = kind
        self.name = name
        self.description = description
        self.technology = technology
        self.tags = tags
        self.parentAlias = parentAlias
        self.children = children
    }
}

public enum StructurizrElementKind: Sendable, Equatable {
    case person
    case softwareSystem
    case container
    case component
    case deploymentNode           // parsed but deferred with diagnostics
}
```

**Design note**: `deploymentNode` and its children (`infrastructureNode`,
`softwareSystemInstance`, `containerInstance`) are parsed into the AST but the
mapper emits `.unsupported` diagnostics for them. This avoids parser crashes
on valid Structurizr DSL that uses deployment constructs.

### Relationship types

```swift
/// An explicit relationship definition from the model section.
public struct StructurizrRelationshipDef: Sendable {
    public var source: String              // alias of source element
    public var target: String              // alias of target element
    public var label: String?              // relationship label
    public var technology: String?         // technology annotation
    public var description: String?        // description annotation
    public var tags: [String]              // tag annotations (deferred)

    public init(
        source: String,
        target: String,
        label: String? = nil,
        technology: String? = nil,
        description: String? = nil,
        tags: [String] = []
    ) {
        self.source = source
        self.target = target
        self.label = label
        self.technology = technology
        self.description = description
        self.tags = tags
    }
}
```

### View types

```swift
/// A single view definition from the views section.
public struct StructurizrView: Sendable {
    public var kind: StructurizrViewKind
    public var scopeAlias: String          // softwareSystem/container being viewed
    public var title: String?              // optional view title
    public var includes: [StructurizrViewInclude]

    public init(
        kind: StructurizrViewKind,
        scopeAlias: String,
        title: String? = nil,
        includes: [StructurizrViewInclude] = []
    ) {
        self.kind = kind
        self.scopeAlias = scopeAlias
        self.title = title
        self.includes = includes
    }
}

public enum StructurizrViewKind: Sendable, Equatable {
    case systemContext
    case container
    case component
    case dynamic           // deferred with diagnostics
    case deployment        // deferred with diagnostics
}

/// A single include directive within a view.
public enum StructurizrViewInclude: Sendable, Equatable {
    case wildcard                       // `include *`
    case element(String)                // `include elementAlias`
    case relationship(String, String)   // `include source -> target`
}
```

## Work Stream 3: Model Registry (`StructurizrModelRegistry.swift`)

A lookup table built from the parsed model elements, used during view
resolution.

```swift
/// Registry that indexes model elements by alias for fast lookup.
/// Supports hierarchical parent-child traversal for view scoping.
public struct StructurizrModelRegistry: Sendable {
    /// All model elements indexed by alias.
    public let elementsByAlias: [String: StructurizrModelElement]
    /// All explicit relationships.
    public let relationships: [StructurizrRelationshipDef]

    public init(
        elements: [StructurizrModelElement],
        relationships: [StructurizrRelationshipDef] = []
    ) {
        var byAlias: [String: StructurizrModelElement] = [:]
        func collect(_ el: StructurizrModelElement) {
            byAlias[el.alias] = el
            for child in el.children { collect(child) }
        }
        for el in elements { collect(el) }
        self.elementsByAlias = byAlias
        self.relationships = relationships
    }

    /// Look up an element by alias.
    public func element(for alias: String) -> StructurizrModelElement? {
        elementsByAlias[alias]
    }

    /// All top-level elements (no parentAlias).
    public var topLevelElements: [StructurizrModelElement] {
        elementsByAlias.values.filter { $0.parentAlias == nil }
    }
}
```

**Resolve `include *` for a view:**

For the vertical slice, `include *` semantics are simplified:

| View kind | Scope element | Include * resolves to |
|---|---|---|
| `systemContext <alias>` | softwareSystem | The softwareSystem itself, all persons that relate to it, and all external softwareSystems it relates to |
| `container <alias>` | softwareSystem | The softwareSystem, all its containers, all persons that relate to it, and all relationships among those elements |
| `component <alias>` | container | The parent softwareSystem + the container, all its components, all persons/containers that relate to it, and all relationships among those |

The resolution walks explicit relationships to discover connected elements.
Elements not referenced by any relationship that touches the scope element are
excluded (matching C4 "include *" semantics where only related elements appear).

## Work Stream 4: Structurizr DSL Parser (`StructurizrParser.swift`)

A recursive-descent parser that consumes raw Structurizr DSL source and
produces `(StructurizrWorkspace, [DiagramDiagnostic])`. The parser is
line-oriented with brace-tracking for nested blocks.

### Lexing / preprocessing

- Strip `// ...` single-line comments and `/* ... */` block comments.
- Strip `#` line comments (Structurizr DSL supports `#` for comments).
- Tokenize lines: identifiers, quoted strings (`"..."`), braces (`{`, `}`),
  arrow (`->`), equals (`=`).

### Grammar subset

```
workspace       := "workspace"  "{" section* "}"
               |  "workspace"  IDENT "{" section* "}"    // named workspace

section        := model_section
               | views_section
               | "!include" ...            → emit diagnostic
               | "!docs" ...               → emit diagnostic
               | "!adrs" ...               → emit diagnostic
               | "!decisions" ...          → emit diagnostic
               | properties_block           → emit diagnostic

model_section  := "model" "{" model_stmt* "}"

model_stmt     := element_def
               | relationship_def

element_def    := id "=" element_kind STRING (STRING)? (STRING)? tags_opt ("{" element_def* "}")?

element_kind   := "person"
               | "softwareSystem"
               | "container"
               | "component"
               | "deploymentNode"          → parsed, deferred

relationship_def := id "->" id (STRING)? (STRING)? (STRING)? tags_opt

tags_opt       := "{" tag (","? tag)* "}"
               | ε

views_section  := "views" "{" view_def* "}"

view_def       := view_kind id (STRING)? "{" include_stmt* "}"

view_kind      := "systemContext"
               | "container"
               | "component"
               | "dynamic"                 → deferred
               | "deployment"              → deferred

include_stmt   := "include" "*"
               | "include" id
               | "include" id "->" id
```

### Parse rules (narrow slice)

| Input pattern | AST output |
|---|---|
| `workspace { model { } views { } }` | `StructurizrWorkspace` with empty model + views |
| `workspace "Name" { ... }` | Named workspace (name captured but unused) |
| `user = person "User Name"` | `StructurizrModelElement(alias: "user", kind: .person, name: "User Name")` |
| `user = person "User Name" "A user"` | Element with description "A user" |
| `app = softwareSystem "My App"` | Element kind `.softwareSystem`, name "My App" |
| `db = container "Database" "PostgreSQL"` | Element kind `.container`, name "Database", technology "PostgreSQL" |
| `db = container "Database" "PostgreSQL" "Stores data"` | Element with technology + description |
| `auth = component "Auth Service"` | Element kind `.component` |
| `app = softwareSystem "My App" { web = container "Web" }` | Element with nested child |
| `user -> app "Uses"` | `StructurizrRelationshipDef(source: "user", target: "app", label: "Uses")` |
| `user -> app "Uses" "HTTPS"` | Relationship with label + technology |
| `user -> app "Uses" "HTTPS" "Over TLS"` | Relationship with label + technology + description |
| `systemContext app "Context" { include * }` | `StructurizrView(kind: .systemContext, scopeAlias: "app", title: "Context", includes: [.wildcard])` |
| `container app { include * }` | View with nil title |
| `component web { include user include db }` | View with explicit element includes |
| `deploymentNode "AWS" { ... }` | Parsed as AST element, deferred with diagnostic |
| `dynamic app { ... }` | Parsed as view, deferred with diagnostic |
| `!include url` | Emitted `.unsupported` diagnostic |
| `{tag1 tag2}` after element | Parsed tags, emitted `.unsupported` diagnostic |

### Key parser behaviors

1. **Identifier-first assignment**: Structurizr uses `alias = elementType ...`
   rather than bare keywords. The parser reads an identifier, then `=`, then
   the element kind keyword. This distinguishes `user = person` (element def)
   from bare `person` (would be a syntax error in our subset).

2. **Quoted strings**: Names, descriptions, and technologies are quoted
   strings (`"..."`). The parser strips quotes. Optional strings: if fewer
   than 3 strings are provided after the element kind, the later positional
   slots are nil.

3. **Nested element blocks**: `softwareSystem { container = container ... }`
   — children are parsed recursively. The parent alias is tracked via a stack.

4. **Relationship arrow**: `->` separates source from target. Labels,
   technology, and description are optional quoted strings after the target.

5. **Views section**: Parsed after the model section. View definitions specify
   the view kind, the scoping element alias, an optional title string, and
   include directives.

6. **Include `*`**: A bare `*` after `include` means "include all visible
   elements." The parser captures this as `.wildcard`.

7. **Deferred constructs**: `deploymentNode`, `dynamic` views, `!include`,
   `!docs`, `!adrs`, `!decisions` — parsed into the AST (to avoid crashing on
   valid Structurizr DSL) but mapper emits `.unsupported` diagnostics rather
   than producing `C4Shape` / `C4Relationship` / `C4Diagram` entries.

8. **Brace balancing**: The parser validates that `{` and `}` are balanced.
   Unbalanced braces produce `DiagramError`.

## Work Stream 5: Structurizr → C4Diagram Mapper (`StructurizrMapper.swift`)

Converts `StructurizrWorkspace` → `C4Diagram` plus diagnostics. The mapper
builds a model registry from the `model` section, then resolves the first
view against it.

### Core mapping table

| Structurizr construct | C4Diagram / C4Shape field |
|---|---|
| `person` element | `C4Shape(alias:, label:, typeC4Shape: .person)` |
| `softwareSystem` element | `C4Shape(alias:, label:, typeC4Shape: .system)` |
| `container` element | `C4Shape(alias:, label:, typeC4Shape: .container, technology:)` |
| `component` element | `C4Shape(alias:, label:, typeC4Shape: .component, technology:)` |
| `deploymentNode` element | Diagnostic only — no shape |
| Element `name` | `C4Shape.label` |
| Element `description` | `C4Shape.description` |
| Element `technology` | `C4Shape.technology` |
| Element `alias` | `C4Shape.alias` |
| Nested element parent | `C4Shape.parentBoundary` — mapped to parent's alias |
| `source -> target` relationship | `C4Relationship(kind: .rel, from:, to:, label:, technology:)` |
| `systemContext` view | `C4Diagram.kind = .context` |
| `container` view | `C4Diagram.kind = .container` |
| `component` view | `C4Diagram.kind = .component` |
| `dynamic` / `deployment` view | Diagnostic only |
| View `title` | `C4Diagram.title` |
| `include *` | All elements visible from scope element's perspective |

### Key mapper behaviors

1. **Element kind → C4ShapeType mapping**:

   | Structurizr | C4ShapeType |
   |---|---|
   | `person` | `.person` |
   | `softwareSystem` | `.system` |
   | `container` | `.container` |
   | `component` | `.component` |

   The `external_*` and `*_db`/`*_queue` variants are **not mapped** in this
   slice. Tags like `{external}` or `{database}` on a Structurizr element
   emit `.unsupported` diagnostics — the element is mapped to its base type
   (e.g., `softwareSystem {database}` → `.system` with a diagnostic saying
   "tag-based shape refinement not yet supported; rendered as base type").

2. **Parent boundary mapping**: Nested elements (container inside
   softwareSystem, component inside container) set `C4Shape.parentBoundary` to
   the parent's alias. The C4 layout/layout engine uses this to position
   shapes within boundaries.

3. **Relationship resolution**: Explicit model relationships map directly to
   `C4Relationship` entries. The `kind` defaults to `.rel` (directed). Arrow
   direction is always source → target in Structurizr, with no explicit
   bidirectional syntax in the DSL. Bidirectional relationships (`.birel`)
   are deferred.

4. **View resolution — `include *`**: The mapper resolves which model
   elements are visible from the scope element's perspective:

   - **systemContext**: Include the scope softwareSystem, all persons that have
     a relationship TO or FROM the scope, and all softwareSystems that have a
     relationship TO or FROM the scope. Exclude containers, components, and
     deployment nodes (those are lower-level details not visible at context
     level).
   - **container**: Include the scope softwareSystem, all its containers, all
     persons related to the scope, all softwareSystems related to the scope,
     and all relationships among those elements. Exclude components.
   - **component**: Include the scope container's parent softwareSystem, the
     scope container itself, all the container's components, all persons and
     other containers that relate to the scope container or its components,
     and all relationships among those.

   Elements not referenced by any relationship that touches the scope element
   are excluded from the view — this matches Structurizr's semantics where
   `include *` shows only *related* elements, not the entire model.

5. **Multiple views — first-view-only**: The mapper processes only
   `workspace.views.first`. Additional views emit diagnostics:
   "workspace contains N views; only the first view is imported in this
   release. N-1 additional views were not processed."

6. **No views at all**: When `workspace.views` is empty, the mapper emits a
   diagnostic and returns `C4Diagram.empty`.

7. **Relationship filtering for views**: Only relationships whose both
   endpoints are included in the view are mapped to `C4Relationship` entries.
   Relationships that reference excluded elements are dropped (with no
   diagnostic — they are structurally outside the view scope).

8. **Elements without relationships**: An element in a view scope that has no
   relationships to the scope element is included only if it is the scope
   element itself or a direct child of the scope element.

9. **Title from view**: The view's optional title string populates
   `C4Diagram.title`. If the view has no title, the scope alias is used as
   a fallback title.

## Work Stream 6: Structurizr Probe (`StructurizrProbe.swift`)

A narrow probe function that requires explicit `workspace {` structure. It
must NOT false-match on Mermaid, D2, DOT, or PlantUML source.

```swift
/// Returns true when `source` appears to be Structurizr DSL rather than any
/// other known format. This is a narrow probe — it requires `workspace {`
/// or `workspace <name> {` at the start of meaningful content.
public func isStructurizrSource(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    let firstLine = trimmed.split(separator: "\n").first?
        .trimmingCharacters(in: .whitespaces) ?? ""

    // PlantUML guard — @startuml/@startxxx before workspace
    if trimmed.contains("@startuml") || trimmed.contains("@start") {
        return false
    }

    // Mermaid guard — flowchart/graph/sequenceDiagram etc. first-line headers
    let mermaidHeaders = [
        "graph", "flowchart", "sequenceDiagram", "classDiagram",
        "stateDiagram", "erDiagram", "gantt", "pie", "mindmap",
        "timeline", "gitGraph", "block-beta", "quadrantChart",
        "xychart-beta", "sankey-beta", "journey", "requirementDiagram",
        "C4Context", "C4Container", "C4Component", "C4Dynamic", "C4Deployment",
        "zenuml"
    ]
    let lowerLine = firstLine.lowercased()
    for header in mermaidHeaders.map({ $0.lowercased() }) {
        if lowerLine.hasPrefix(header) { return false }
    }

    // DOT guard — digraph/graph/strict headers
    let tokens = lowerLine.split(separator: " ", omittingEmptySubsequences: true)
    if let first = tokens.first {
        if first == "digraph" || first == "strict" { return false }
        if first == "graph", tokens.count >= 2 {
            let second = tokens[1]
            if ["td", "lr", "bt", "rl", "tb"].contains(where: { second.hasPrefix($0) }) {
                return false  // Mermaid graph direction
            }
            return false  // DOT graph header
        }
    }

    // Positive: workspace keyword at start
    let wsTokens = lowerLine.split(separator: " ", omittingEmptySubsequences: true)
    guard let firstWS = wsTokens.first else { return false }

    if firstWS == "workspace" { return true }

    // Compact form: workspace{...} or workspace"Name"{...}
    if lowerLine.hasPrefix("workspace{") || lowerLine.hasPrefix("workspace\"") {
        return true
    }

    return false
}
```

**Probe design rationale**:

- Structurizr DSL always starts with `workspace` (optionally followed by a
  quoted name, then `{`). No other diagram format uses `workspace` as a
  top-level keyword.
- Mermaid, DOT, PlantUML, D2 are all explicitly rejected before the positive
  check, providing defense-in-depth.
- The probe requires `workspace` at the very start of the first line — it
  does not search for `workspace` deep in the source. This guards against
  false matches on large sources that happen to contain the word.
- Compact forms like `workspace{model{user=person"U"}}` are accepted.

## Work Stream 7: StructurizrImporter (`StructurizrImporter.swift`)

```swift
import Foundation
import DiagramKitModel
import DiagramKitImport

/// Structurizr DSL source-format importer.
///
/// Parses Structurizr workspace source into a `DiagramDocument` with
/// `DiagramPayload.c4` by mapping workspace model elements and the first
/// view to `C4Diagram`. Unsupported DSL features emit `.unsupported`
/// diagnostics.
public struct StructurizrImporter: DiagramSourceImporter {

    public let name = "Structurizr"
    public let supportedDiagramTypes: Set<DiagramType> = [.c4]

    public init() {}

    public func supports(source: String) -> Bool {
        isStructurizrSource(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        let parser = StructurizrParser()
        let (workspace, parseDiagnostics) = try parser.parse(source)

        let mapper = StructurizrMapper()
        let (c4Diagram, mapDiagnostics) = mapper.map(workspace)

        let allDiagnostics = parseDiagnostics + mapDiagnostics
        let payload = DiagramPayload.c4(c4Diagram)
        let document = DiagramDocument(payload: payload)

        return DiagramImportResult(document: document, diagnostics: allDiagnostics)
    }
}
```

## Work Stream 8: Registry Integration

Update `DiagramPipeline.defaultRegistry` to prepend `StructurizrImporter()`
before the existing importers:

```swift
import DiagramKitStructurizr

public static let defaultRegistry: ImporterRegistry = ImporterRegistry(
    importers: [
        StructurizrImporter(),
        GraphvizImporter(),
        D2Importer(),
        MermaidImporter()
    ]
)
```

**Probe order rationale**: Structurizr's probe requires `workspace` at the
start of the first line — as narrow as Graphviz's `digraph`/`graph`/`strict`
probe. They cannot collide (different keywords). Structurizr is prepended
first per the stated Phase 5 approach; if collision tests ever reveal
ambiguity, the order between Graphviz and Structurizr can be swapped without
impact since their probes are disjoint.

The import in `MermaidPipeline.swift`:

```swift
import DiagramKitStructurizr
```

## Work Stream 9: Diagnostics for Unsupported DSL Constructs

The parser and mapper emit `.unsupported` diagnostics for Structurizr DSL
features outside the narrow vertical slice. Categories:

| Structurizr feature | Diagnostic |
|---|---|
| `deploymentNode "..." { ... }` | "deployment nodes not yet supported" |
| `infrastructureNode` | "infrastructure nodes not yet supported" |
| `softwareSystemInstance` / `containerInstance` | "instance elements not yet supported" |
| `dynamic <scope> { ... }` view | "dynamic views not yet supported" |
| `deployment <scope> { ... }` view | "deployment views not yet supported" |
| Multiple views beyond first | "workspace contains N views; only the first view imported" |
| Zero views in workspace | "workspace contains no views; no diagram produced" |
| `!include <url>` | "!include directive not yet supported" |
| `!docs <path>` | "!docs directive not yet supported" |
| `!adrs <path>` | "!adrs directive not yet supported" |
| `!decisions <path>` | "!decisions directive not yet supported" |
| `{tag}` annotations on elements | "tag-based shape refinement not yet supported; rendered as base type" |
| `{tag}` annotations on relationships | "tag-based relationship styling not yet supported" |
| `properties { ... }` block | "custom properties not yet supported" |
| `!identifiers` (hierarchical/ flat) | "identifier strategy not yet supported" |
| `!impliedRelationships` | "implied relationships not yet supported" |
| `autoLayout { ... }` | "autoLayout configuration not yet supported" |
| `themes <url>` | "remote themes not yet supported" |
| `branding { ... }` | "branding not yet supported" |
| `terminology { ... }` | "terminology customization not yet supported" |
| `configuration { ... }` | "configuration block not yet supported" |
| `filtered { ... }` views | "filtered views not yet supported" |
| `animation { ... }` in views | "animation not yet supported" |
| `styles { ... }` (element/ relationship) | "custom styles not yet supported" |
| `perspectives { ... }` | "perspectives not yet supported" |
| `model { ... }` block inside view | "inline model in views not yet supported" |
| `group` / `groups` | "element groups not yet supported" |
| `url` on elements | "URL attribute not yet supported" |
| `!ref` / `!extend` | "reference/include extension not yet supported" |

### Diagnostic emission strategy

- **Parser emits diagnostics** for unsupported top-level directives
  (`!include`, `!docs`, `!adrs`, `!decisions`), deployment node definitions,
  dynamic/deployment views, properties blocks, and tag annotations.
- **Mapper emits diagnostics** for multiple views, tag-based shape
  refinements, and missing views.
- **Diagnostics carry line information** when available from the parser.
  Mapper-level diagnostics carry no line info (they fire during AST walk).
- **Never silent no-op**: every unrecognized construct produces a diagnostic.
  Valid constructs that map to supported C4 types produce no diagnostics.

## Work Stream 10: Tests

### 10a. `StructurizrParserTests` (new file: `Tests/DiagramKitTests/StructurizrParserTests.swift`)

Parser unit tests for the recursive-descent parser. At least 18 tests:

| Test name | Description |
|---|---|
| `parseEmptyWorkspace` | `workspace { }` → workspace with nil model, empty views |
| `parseNamedWorkspace` | `workspace "Name" { }` → workspace parsed, name captured |
| `parsePersonElement` | `workspace { model { u = person "User" } }` → element with alias "u", kind .person, name "User" |
| `parsePersonWithDescription` | `workspace { model { u = person "User" "A user" } }` → description "A user" |
| `parseSoftwareSystem` | `workspace { model { app = softwareSystem "My App" } }` → element kind .softwareSystem |
| `parseContainer` | `workspace { model { db = container "DB" "PostgreSQL" } }` → technology "PostgreSQL" |
| `parseContainerWithDescription` | `workspace { model { db = container "DB" "PG" "Stores data" } }` → technology + description |
| `parseComponent` | `workspace { model { auth = component "Auth" } }` → element kind .component |
| `parseNestedElements` | `workspace { model { app = softwareSystem "App" { web = container "Web" } } }` → child container with parentAlias "app" |
| `parseRelationship` | `workspace { model { u -> app "Uses" } }` → relationship with label "Uses" |
| `parseRelationshipWithTechnology` | `workspace { model { u -> app "Uses" "HTTPS" } }` → technology "HTTPS" |
| `parseMultipleElements` | `workspace { model { u = person "U" app = softwareSystem "A" } }` → two model elements |
| `parseSystemContextView` | `workspace { views { systemContext app { include * } } }` → view with kind .systemContext, scopeAlias "app" |
| `parseContainerView` | `workspace { views { container app { include * } } }` → view kind .container |
| `parseComponentView` | `workspace { views { component web { include u include db } } }` → view with explicit includes |
| `parseViewWithTitle` | `workspace { views { systemContext app "My Context" { include * } } }` → view title "My Context" |
| `parseComments` | `workspace { // comment\nmodel { u = person "U" }\n}` — comments stripped |
| `parseThrowsOnUnbalancedBraces` | `workspace { model { u = person "U"` → throws `DiagramError` |

### 10b. `StructurizrImporterTests` (new file: `Tests/DiagramKitTests/StructurizrImporterTests.swift`)

Importer unit tests. At least 24 tests:

**supports tests:**

| Test name | Description |
|---|---|
| `supportsWorkspace` | `workspace { model { } views { } }` → true |
| `supportsCompactWorkspace` | `workspace{model{u=person"U"}}` → true |
| `supportsNamedWorkspace` | `workspace "Name" { }` → true |
| `rejectsMermaidSource` | `graph TD\nA-->B` → false |
| `rejectsMermaidC4` | `C4Context\nPerson(user, "User")` → false |
| `rejectsD2Source` | `A: Start\nA -> B` → false |
| `rejectsDOTSource` | `digraph G { A -> B }` → false |
| `rejectsPlantUML` | `@startuml\nAlice -> Bob: Hello\n@enduml` → false |
| `rejectsEmptySource` | `""` → false |

**parse tests:**

| Test name | Description |
|---|---|
| `parsePersonMapsToC4Shape` | `workspace { model { u = person "User" } views { systemContext app { include * } } }` → shape with typeC4Shape .person |
| `parseSoftwareSystemMapsToSystem` | Element kind .softwareSystem → shape typeC4Shape .system |
| `parseContainerMapsToContainer` | Element kind .container → shape typeC4Shape .container |
| `parseComponentMapsToComponent` | Element kind .component → shape typeC4Shape .component |
| `parseTechnologyIsPreserved` | Container with technology "PostgreSQL" → C4Shape.technology = "PostgreSQL" |
| `parseDescriptionIsPreserved` | Element with description → C4Shape.description populated |
| `parseViewTitleBecomesDiagramTitle` | View with title "My Context" → C4Diagram.title = "My Context" |
| `parseSystemContextViewProducesContextKind` | systemContext view → C4Diagram.kind = .context |
| `parseContainerViewProducesContainerKind` | container view → C4Diagram.kind = .container |
| `parseComponentViewProducesComponentKind` | component view → C4Diagram.kind = .component |
| `parseRelationshipMapsToC4Relationship` | `u -> app "Uses"` → C4Relationship with label "Uses" |
| `parseRelationshipTechnology` | `u -> app "Uses" "HTTPS"` → C4Relationship.technology = "HTTPS" |
| `parseNestedElementSetsParentBoundary` | Container inside softwareSystem → C4Shape.parentBoundary = parent alias |
| `wildcardIncludeIncludesScopeElement` | systemContext view with include * → scope softwareSystem in shapes |
| `wildcardIncludeIncludesRelatedElements` | systemContext view with include * → related persons + systems included |
| `wildcardIncludeExcludesUnrelatedElements` | Unrelated elements not included in view |
| `emitsDiagnosticForDeploymentNode` | `deploymentNode "AWS" { }` → diagnostic |
| `emitsDiagnosticForDynamicView` | `dynamic app { }` → diagnostic |
| `emitsDiagnosticForIncludeDirective` | `!include url` → diagnostic |
| `emitsDiagnosticForTags` | `{database}` on element → diagnostic |
| `emitsDiagnosticForMultipleViews` | workspace with 2+ views → diagnostic about 1 view only |
| `emitsDiagnosticForNoViews` | workspace with model but no views → diagnostic |

**layout smoke tests:**

| Test name | Description |
|---|---|
| `structurizrLayoutSmoke` | Parse structurizr workspace, run `DiagramPipeline.layout`, verify non-empty positioned output |
| `structurizrLayoutWithBoundariesSmoke` | Parse workspace with nested containers, layout, verify boundaries present |

### 10c. Probe Collision Tests (edit `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift`)

Add Structurizr probe collision tests. At least 14 new tests:

| Test name | Description |
|---|---|
| `structurizrProbeAcceptsWorkspace` | `StructurizrImporter().supports(source: "workspace { }")` → true |
| `structurizrProbeAcceptsNamedWorkspace` | `StructurizrImporter().supports(source: "workspace \"N\" { }")` → true |
| `structurizrProbeAcceptsCompact` | `StructurizrImporter().supports(source: "workspace{model{}}")` → true |
| `structurizrProbeRejectsMermaidGraphTD` | `StructurizrImporter().supports(source: "graph TD\nA-->B")` → false |
| `structurizrProbeRejectsMermaidFlowchart` | `StructurizrImporter().supports(source: "flowchart LR\nA-->B")` → false |
| `structurizrProbeRejectsMermaidC4` | `StructurizrImporter().supports(source: "C4Context\nPerson(user, \"U\")")` → false |
| `structurizrProbeRejectsD2Source` | `StructurizrImporter().supports(source: "A: Start\nA -> B")` → false |
| `structurizrProbeRejectsDOTSource` | `StructurizrImporter().supports(source: "digraph G { A -> B }")` → false |
| `structurizrProbeRejectsPlantUML` | `StructurizrImporter().supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml")` → false |
| `structurizrProbeRejectsBareEdge` | `StructurizrImporter().supports(source: "A -> B")` → false |
| `structurizrProbeRejectsEmptyString` | `StructurizrImporter().supports(source: "")` → false |
| `registryPrependsStructurizrFirst` | `registry.importer(for: "workspace { model { } views { } }")?.name == "Structurizr"` |
| `registryFallsBackToGraphvizForDigraph` | `registry.importer(for: "digraph G { A -> B }")?.name == "Graphviz"` |
| `registryFallsBackToMermaidForGraphTD` | `registry.importer(for: "graph TD\nA-->B")?.name == "Mermaid"` |

### 10d. `StructurizrCorpusFixtureTests` (new file: `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift`)

Inline corpus fixtures with `skipSnapshots: ["structurizr"]`. At least 6 tests,
following the `D2CorpusFixtureTests.swift` and `DOTCorpusFixtureTests.swift`
pattern:

| Test name | Description |
|---|---|
| `structurizrSimpleWorkspaceFixtureDecodes` | Inline fixture with person + system + context view |
| `structurizrContainerViewFixtureDecodes` | Inline fixture with softwareSystem, containers, container view |
| `structurizrComponentViewFixtureDecodes` | Inline fixture with container, components, component view |
| `structurizrUnsupportedFixtureHasDiagnostics` | Inline fixture with deploymentNode + tags → `expectedDiagnostics` |
| `structurizrSourceForFormat` | `entry.source(for: "structurizr")` returns the Structurizr source |
| `structurizrParseThroughImporter` | Parse Structurizr source via `StructurizrImporter`, layout, verify non-empty |

### 10e. Registry Tests (edit `Tests/DiagramKitTests/ImporterRegistryTests.swift`)

Update existing registry tests for the new four-importer order:

| Test | Change |
|---|---|
| `defaultRegistryOrder` | Assert `registry.importers[0].name == "Structurizr"`, `[1] == "Graphviz"`, `[2] == "D2"`, `[3] == "Mermaid"` |
| `prependingPutsFirst` | Extend to show `StructurizrImporter()` prepended before Graphviz+D2+Mermaid |
| `structurizrFirstRouting` | Verify Structurizr claims `workspace { ... }` source |

### 10f. Existing Test Regressions

Run and verify no regressions:

```bash
swift test --filter DOTParserTests
swift test --filter DOTImporterTests
swift test --filter DOTFixtureTests
swift test --filter D2ParserTests
swift test --filter D2ImporterTests
swift test --filter D2FixtureTests
swift test --filter MermaidImporterTests
swift test --filter DiagramRegistryTests
swift test --filter MultiFormatDecodingTests
swift test --filter MultiFormatFixtureMetadataTests
swift test --filter MultiFormatBackwardCompatibilityTests
swift test --filter MultiFormatValidationTests
swift test --filter MultiFormatSparseMatrixTests
swift test --filter PlaygroundCorpusDecodingTests
```

---

## File Change Summary

| File | Action | Status |
|---|---|---|
| `Package.swift` | Add `DiagramKitStructurizr` target, product, deps. Add to umbrella + test target deps | Pending |
| `Sources/DiagramKitStructurizr/StructurizrAST.swift` | New — Structurizr DSL AST types | Pending |
| `Sources/DiagramKitStructurizr/StructurizrModelRegistry.swift` | New — model element lookup table | Pending |
| `Sources/DiagramKitStructurizr/StructurizrParser.swift` | New — recursive-descent parser | Pending |
| `Sources/DiagramKitStructurizr/StructurizrMapper.swift` | New — StructurizrAST → C4Diagram mapping | Pending |
| `Sources/DiagramKitStructurizr/StructurizrProbe.swift` | New — narrow Structurizr probe | Pending |
| `Sources/DiagramKitStructurizr/StructurizrImporter.swift` | New — `DiagramSourceImporter` conformance | Pending |
| `Sources/DiagramKit/MermaidPipeline.swift` | Edit — add `StructurizrImporter()` to `defaultRegistry` + `import DiagramKitStructurizr` | Pending |
| `Tests/DiagramKitTests/StructurizrParserTests.swift` | New — 18+ parser unit tests | Pending |
| `Tests/DiagramKitTests/StructurizrImporterTests.swift` | New — 24+ importer unit tests (includes 2 layout smoke tests) | Pending |
| `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift` | Edit — 14+ Structurizr probe collision tests + `import DiagramKitStructurizr` | Pending |
| `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift` | New — 6 inline Structurizr fixture tests | Pending |
| `Tests/DiagramKitTests/ImporterRegistryTests.swift` | Edit — Structurizr-first registry assertion + `import DiagramKitStructurizr` | Pending |

### Files intentionally NOT changed

- Rendering code (SVG, CG, ASCII) — unchanged
- Layout engine (`src_c4_layout.swift`, ELK) — unchanged
- `DiagramKitModel` types — no new payload cases needed (`.c4(C4Diagram)` exists)
- `DiagramKitImport` protocol/registry — already designed for this
- `DiagramKitTestSupport` — no new types needed
- `CorpusSnapshotTests.swift` — no Structurizr snapshot rendering in Phase 5
- `test-diagrams.json` — no new real entries
- D2 importer sources (`Sources/DiagramKitD2/`) — unchanged
- Graphviz importer sources (`Sources/DiagramKitGraphviz/`) — unchanged
- Mermaid parser/rendering sources — unchanged
- Snapshot baselines — no new baselines

---

## Design Decisions

### 1. Map to existing `C4Diagram` — no new payload cases

**Decision**: The Structurizr importer produces `DiagramPayload.c4(C4Diagram)`,
reusing the existing C4 model types, layout engine, and SVG/CG renderers. No
new `DiagramType`, `DiagramPayload`, or `PositionedContent` cases are needed.

**Rationale**: The `C4Diagram` model was designed for C4 semantics, which map
directly from Structurizr's domain. The layout engine (`layoutC4Diagram`) and
SVG renderer (`renderC4Svg`) already handle `C4Diagram` payloads. Adding new
payload cases for Structurizr would duplicate the C4 rendering path.

### 2. First view only — single `DiagramImportResult`

**Decision**: The importer returns only the first view from a multi-view
workspace. Additional views beyond the first emit `.unsupported` diagnostics.

**Rationale**: `DiagramSourceImporter.parse()` returns a single
`DiagramImportResult` with one `DiagramDocument`. Multi-diagram output
from a single source is a future concern (Phase 7 or beyond). Emitting
diagnostics for extra views keeps users informed without silently dropping
data. This matches the vertical-slice philosophy: prove the importer
boundary works, defer multi-view support.

### 3. Simplified `include *` semantics

**Decision**: `include *` resolves based on the scope element and explicit
model relationships. Elements not connected to the scope element via any
relationship are excluded from the resolved view.

**Rationale**: Full Structurizr `include *` semantics involve auto-detected
implied relationships, perspective-based filtering, and element property
matching — all deferred. The simplified semantics match the most common C4
usage pattern: define explicit relationships in the model, then use
`include *` to show the connected subgraph. This is sufficient for the
vertical slice and produces correct C4 diagrams for the supported use case.

### 4. `deploymentNode` and `dynamic` views parsed but deferred

**Decision**: The parser recognizes `deploymentNode` definitions and
`dynamic`/`deployment` view keywords, consuming their blocks without crashing.
The mapper emits `.unsupported` diagnostics for them.

**Rationale**: Valid Structurizr DSL documents often include deployment
definitions alongside model elements. Crashing on them would make the
importer unusable for real-world workspaces. By parsing the block structure
(consuming balanced braces) and emitting diagnostics, the importer
gracefully handles workspaces that mix supported and unsupported constructs.

### 5. Tag annotations parsed but deferred

**Decision**: Tags like `{database}`, `{external}`, `{queue}` after element
or relationship definitions are parsed into the AST but the mapper emits
`.unsupported` diagnostics and maps the element to its base `C4ShapeType`.

**Rationale**: Structurizr uses tags heavily for styling and shape refinement.
The Mermaid C4 model has distinct `C4ShapeType` variants for
`external_person`, `system_db`, `container_queue`, etc. Mapping these
requires a tag-to-shape-type mapping table and is deferred to keep the
vertical slice focused. Emitting diagnostics prevents silent information
loss.

### 6. Probe order: Structurizr first

**Decision**: `StructurizrImporter()` is prepended before `GraphvizImporter()`,
`D2Importer()`, and `MermaidImporter()` in the default registry.

**Rationale**: The Structurizr probe requires `workspace` at the start of the
source — a keyword no other format uses. It cannot false-match on DOT
(`digraph`/`graph`), D2 (`A: label`), or Mermaid (diagram-specific headers).
The probe is as narrow as Graphviz's. Prepending it first follows the stated
Phase 5 goal of "prepend before existing importers once the probe is proven
collision-safe." If future collision testing reveals order sensitivity, the
position relative to Graphviz can be swapped — they are disjoint.

### 7. No snapshot baselines

**Decision**: Structurizr fixtures carry `skipSnapshots: ["structurizr"]` and
do not produce snapshot baselines. No real `test-diagrams.json` entries are
added.

**Rationale**: Matches the D2 and Graphviz Phase 3/4 pattern. Snapshot
baselines are deferred to Phase 10 (final baseline pass). The C4 rendering
path is already tested by the existing Mermaid C4 corpus entries, so layout
and rendering regressions are already covered.

### 8. `StructurizrModelRegistry` as a separate file

**Decision**: The model registry types live in `StructurizrModelRegistry.swift`
rather than being embedded in the mapper.

**Rationale**: The registry has non-trivial logic (alias indexing, parent-child
traversal, `include *` resolution). Separating it from the mapper keeps both
files under the 500-line warning threshold and improves testability. The
registry can be unit-tested independently of the mapper.

### 9. Relationships at model level only (no inline relationships in views)

**Decision**: The parser handles relationship definitions in the `model { }`
section. Relationships defined inside view blocks (inline) are deferred with
diagnostics.

**Rationale**: In Structurizr DSL, relationships can appear in both model
and view sections. For the vertical slice, model-level relationships are
sufficient for the supported C4 use cases. View-inline relationships would
require dual-pass parsing (model first, then views with relationship
merging) and are deferred.

### 10. No implicit relationship detection

**Decision**: Only explicit `source -> target` relationships from the model
section are mapped to `C4Relationship` entries. Implicit relationships
(auto-detected from element nesting or naming conventions) are deferred.

**Rationale**: Structurizr has an `!impliedRelationships` directive that
auto-detects relationships based on element hierarchy and naming patterns.
This is deferred — only explicit relationships are supported in the
vertical slice. This simplifies the mapper and avoids false-positive
relationship generation.

---

## Verification Gates

```bash
swift package dump-package
swift build --build-tests
swift test --filter StructurizrParserTests
swift test --filter StructurizrImporterTests
swift test --filter StructurizrCorpusFixtureTests
swift test --filter ProbeCollisionMatrixTests
swift test --filter ImporterRegistryTests
swift test --filter D2ParserTests               # regression
swift test --filter D2ImporterTests             # regression
swift test --filter DOTParserTests              # regression
swift test --filter DOTImporterTests            # regression
swift test --filter MermaidImporterTests        # regression
swift test --filter DiagramRegistryTests        # regression
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
git diff --check
```

`Scripts/check-file-sizes.sh` may report pre-existing warnings. Phase 5
should not add new warnings; splitting parser, mapper, and registry files
keeps each new file under 500 lines.

No snapshot recording. No Linux check unless Docker/Podman is available
(record as skipped due to environment otherwise).

---

## Deferred to Later Phases

- `deploymentNode`, `infrastructureNode`, `softwareSystemInstance`,
  `containerInstance` element types
- `dynamic` and `deployment` views
- Multiple views from a single workspace (multi-diagram output)
- Tag-based shape refinement (mapping `{external}` → `.external_system`,
  `{database}` → `.system_db`, `{queue}` → `.system_queue`, etc.)
- Implicit relationships (`!impliedRelationships` directive)
- `!include`, `!docs`, `!adrs`, `!decisions` directives
- `properties { ... }` blocks on elements and relationships
- `!identifiers` (hierarchical vs. flat identifier strategy)
- `autoLayout { ... }` configuration
- `themes`, `branding`, `terminology`, `configuration` blocks
- Filtered views (`filtered { ... }`)
- `animation { ... }` in views
- `styles { ... }` (per-element and per-relationship custom styles)
- `perspectives { ... }`
- `group` / `groups` element grouping
- `url` attribute on elements
- `!ref` / `!extend` / `!plugin` / `!script` directives
- Inline model elements within views
- Inline relationship definitions within views
- Round-trip export (StructurizrExporter)
- Real `test-diagrams.json` multi-format entries
- Structurizr snapshot baselines (SVG, image)

---

## Implementation Notes (to be filled during/after implementation)

*This section will be populated with implementation deviations, parser fixes,
and test suite results once implementation begins.*

---

*This plan was prepared from live codebase analysis of Package.swift,
Sources/DiagramKitModel/src_c4_types.swift, Sources/DiagramKitD2/,
Sources/DiagramKitGraphviz/, Sources/DiagramKit/, Sources/DiagramKitImport/,
Tests/DiagramKitTests/, ANALYSIS.md, PHASES.md, PHASE-3.md, and
PHASE-4.md as they exist at 2026-05-12.*
