# Phase 5: Structurizr Importer Vertical Slice — Plan (Revised)

Date: 2026-05-12 (revised 2026-05-12 per review). **Status: COMPLETE** — all
work streams implemented; local non-snapshot verification passes, with Linux
skipped because Docker/Podman is unavailable. Phase 5 of the DiagramKit
multi-format roadmap is done. It follows Phase 4 (complete: Graphviz DOT
importer) and precedes Phase 6 (PlantUML importer).

**Implementation notes (2026-05-12)**:
- `StructurizrParserState.swift` was extracted from `StructurizrParser.swift`
  to keep the parser under 500 lines (308 lines); State type and block-skipping
  helpers live in the separate file (130 lines).
- `StructurizrLayoutSmokeTests.swift` was split from `StructurizrImporterTests.swift`
  to keep the latter under 500 lines.
- The focused Structurizr suite now has 96 tests in 10 suites, including
  post-review regression coverage for unsupported-statement skipping,
  relationship descriptions, deployment-node filtering, missing-alias
  diagnostics, and probe/parser agreement.
- `StructurizrImporter` is prepended first in `defaultRegistry`; probe order:
  Structurizr → Graphviz → D2 → Mermaid.

**Revision notes (2026-05-12)**:
- Element argument order corrected to Structurizr DSL convention:
  `container <name> [description] [technology]`, not name/technology/description.
- `C4Boundary` entries are now explicitly created for parent elements whose
  children are in the view scope; `parentBoundary` alone is insufficient.
- Tag syntax changed from `{tag}` braces to `tags "..."` child statements
  (Structurizr braces always open child blocks).
- `StructurizrLexer.swift` added to the architecture; parser is token-driven.
- `StructurizrModelRegistryTests.swift` added for independent registry coverage.
- Probe tightened to require `{` after optional workspace name, matching the
  stated "requires `workspace {` structure" contract.
- `name: String?` field added to `StructurizrWorkspace`.
- Scoped relationships inside element blocks are now explicitly supported.
- Diagnostics extended for `exclude`, `tags`, per-element description/technology,
  scoped `->`, and unknown view statements.
- `include *` semantics revised: scope element is a rendered shape in
  systemContext views, a boundary in container/component views.
- Test fixtures revised to include complete scoped elements and at least one
  relationship proving wildcard resolution.
- Post-review remediation tightened unsupported statement skipping so `tags`
  and `!directive` diagnostics no longer consume following supported model
  statements.
- Relationship third-string descriptions are preserved, deployment nodes are
  diagnostic-only and not rendered as fallback system shapes, and missing view
  scope/include aliases emit diagnostics.

---

## Goal

Support the C4-shaped subset where Structurizr DSL maps cleanly to the
existing `C4Diagram` model. Add Structurizr as the first non-Mermaid importer
that targets `DiagramPayload.c4(C4Diagram)`, proving that the C4 payload path
works across the importer boundary.

## Architecture Overview

```
Sources/DiagramKitStructurizr/
├── StructurizrImporter.swift       DiagramSourceImporter conformance
├── StructurizrAST.swift            Minimal Structurizr DSL AST types
├── StructurizrLexer.swift          Tokenizer (comment stripping, token stream)
├── StructurizrParserState.swift    Parse state, token navigation, block-skip helpers
├── StructurizrParser.swift         Recursive-descent parser (consumes tokens)
├── StructurizrMapper.swift         StructurizrAST → C4Diagram mapping
├── StructurizrModelRegistry.swift  Model element lookup table
└── StructurizrProbe.swift          Narrow probe function
```

The Structurizr importer follows the same pattern as D2 and Graphviz: parse a
subset of the Structurizr DSL, map to DiagramKit's existing payload type
(`C4Diagram`), emit diagnostics for unsupported constructs, and reuse the
existing C4 layout and render pipelines. There are no new diagram types, no
layout changes, no renderer changes, no snapshot baselines, and no real corpus
edits.

The parser is token-driven (not purely line-oriented) so that compact forms
like `workspace{model{user=person"U"}}` are handled uniformly. The lexer
(`StructurizrLexer.swift`) strips comments, collapses whitespace, and emits
a token stream consumed by the parser.

### How Structurizr differs from D2/DOT

D2 and DOT both map to `DiagramPayload.flowchart` — a graph with nodes, edges,
and subgraphs. Structurizr maps to `DiagramPayload.c4(C4Diagram)` — a
semantically richer model with typed shapes (`C4ShapeType`: person, system,
container, component, etc.), boundaries (`C4Boundary`), and relationships
(`C4Relationship`) with explicit direction and technology fields. The C4
layout (`layoutC4Diagram`) and SVG/CG renderers already handle this payload,
so the Structurizr importer only needs to produce valid `C4Diagram` values.

### Structurizr DSL structure (narrow slice)

```
workspace "My Workspace" "Description" {
    model {
        user = person "User Name" "A user of the system"
        app  = softwareSystem "My App" "Core application" {
            web  = container "Web App" "Public-facing web UI" "Spring Boot"
            auth = component "Auth Service" "Handles authentication"
        }
        ext  = softwareSystem "External CRM" "Third-party"
        user -> app  "Uses" "HTTPS"
        user -> ext  "Accesses" "REST"
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
  type keyword, a name string, an optional description string, and an optional
  technology string. **Per Structurizr DSL convention**: `container <name>
  [description] [technology]`, not name/technology/description.
- **Nested elements**: containers and components can be defined inside
  `softwareSystem { ... }` or `container { ... }` blocks. The parser tracks
  parent-child relationships.
- **Relationships**: explicit `source -> target "Label" "Technology"
  "Description"` syntax, defined at the model level or inside element blocks
  (scoped relationships).
- **Views**: `systemContext`, `container`, `component` — each names a scoping
  element and includes a subset of model elements. `include *` means "include
  all elements visible from the scoping element's perspective."
- **Tags**: `tags "Tag1,Tag2"` child statements — deferred with diagnostics
  (no `{tag}` brace syntax; braces always open child blocks in Structurizr).

For the vertical slice, the importer parses a complete workspace, extracts all
model elements/relationships, processes the **first** view definition only,
resolves it against the model registry, and produces a single `C4Diagram`.
Additional views emit diagnostics. `deployment` and `dynamic` views are
deferred entirely.

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

## Work Stream 2: Lexer (`StructurizrLexer.swift`)

A tokenizer that consumes raw Structurizr DSL source and produces a stream
of tokens for the parser. Splitting the lexer from the parser keeps both
files under the 500-line threshold and enables independent unit testing.

### Token types

```swift
public enum StructurizrToken: Sendable, Equatable {
    case identifier(String)          // unquoted identifiers: workspace, model, person, etc.
    case string(String)              // quoted string, quotes stripped: "User Name"
    case openBrace                   // {
    case closeBrace                  // }
    case equals                      // =
    case arrow                       // ->
    case star                        // * (wildcard include)
    case bang                        // ! (directive prefix)
}
```

### Lexer behavior

```swift
public struct StructurizrLexer: Sendable {
    /// Tokenize raw Structurizr DSL source.
    /// Strips `//` and `#` single-line comments, `/* ... */` block comments.
    /// Returns `[StructurizrToken]`.
    public func tokenize(_ source: String) -> [StructurizrToken]
}
```

- Strips `// ...` and `# ...` end-of-line comments.
- Strips `/* ... */` block comments (nesting not required for this slice).
- Collapses whitespace runs — token boundaries are derived from punctuation
  (`{`, `}`, `=`, `->`, `*`, `!`) and quoted strings.
- Quoted strings (`"..."`) produce `.string(content)` with quotes stripped and
  no escape processing beyond `\"`.
- Identifiers are alphanumeric plus `_`, `.`, `/`, `:`, and `-`, case-sensitive.
  The path characters keep directive arguments such as `!include shared.dsl`
  together while preserving a narrow Structurizr probe.
- The `*` token is emitted as `.star` for wildcard include statements
  (i.e., `include *`).

## Work Stream 3: Structurizr DSL AST Types (`StructurizrAST.swift`)

All types are value types (`Sendable`). The AST models the narrow DSL subset
we parse — not the full Structurizr DSL language.

### Top-level types

```swift
/// Top-level: a complete Structurizr workspace definition.
public struct StructurizrWorkspace: Sendable {
    public var name: String?               // optional workspace name
    public var description: String?        // optional workspace description
    public var model: StructurizrModel?
    public var views: [StructurizrView]

    public init(
        name: String? = nil,
        description: String? = nil,
        model: StructurizrModel? = nil,
        views: [StructurizrView] = []
    ) {
        self.name = name
        self.description = description
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
    public var tags: [String]               // from tags "..." child (deferred)
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
/// An explicit relationship definition from the model section or element block.
public struct StructurizrRelationshipDef: Sendable {
    public var source: String              // alias of source element
    public var target: String              // alias of target element
    public var label: String?              // relationship label
    public var technology: String?         // technology annotation
    public var description: String?        // description annotation
    public var tags: [String]              // from tags "..." child (deferred)

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
    public var description: String?        // optional view description
    public var includes: [StructurizrViewInclude]
    public var autoLayout: Bool            // autoLayout child (deferred)

    public init(
        kind: StructurizrViewKind,
        scopeAlias: String,
        title: String? = nil,
        description: String? = nil,
        includes: [StructurizrViewInclude] = [],
        autoLayout: Bool = false
    ) {
        self.kind = kind
        self.scopeAlias = scopeAlias
        self.title = title
        self.description = description
        self.includes = includes
        self.autoLayout = autoLayout
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
}
```

## Work Stream 4: Structurizr DSL Parser (`StructurizrParser.swift`)

A recursive-descent parser consuming the token stream from `StructurizrLexer`.
Produces `(StructurizrWorkspace, [DiagramDiagnostic])`.

### Grammar subset

```
workspace       := "workspace" (STRING STRING?)? "{" section* "}"

section        := model_section
               | views_section
               | "!" identifier ...       → emit diagnostic
               | "tags" ...               → emit diagnostic (top-level tags)
               | <unknown>                → emit diagnostic

model_section  := "model" "{" model_stmt* "}"

model_stmt     := element_def
               | relationship_def
               | "tags" ...               → emit diagnostic

element_def    := IDENT "=" element_kind STRING (STRING)? (STRING)?
                  ("{" (element_def | relationship_def)* "}")?

element_kind   := "person"
               | "softwareSystem"
               | "container"
               | "component"
               | "deploymentNode"         → parsed, deferred

relationship_def := IDENT "->" IDENT (STRING)? (STRING)? (STRING)?

views_section  := "views" "{" view_def* "}"

view_def       := view_kind IDENT (STRING)? (STRING)? "{" view_stmt* "}"

view_kind      := "systemContext"
               | "container"
               | "component"
               | "dynamic"                → deferred
               | "deployment"             → deferred

view_stmt      := include_stmt
               | "autoLayout" "{" ... "}" → deferred, emit diagnostic
               | "animation" "{" ... "}"  → deferred, emit diagnostic
               | "styles" "{" ... "}"     → deferred, emit diagnostic
               | "exclude" ...            → deferred, emit diagnostic
               | "tags" "..."             → deferred, emit diagnostic
               | <unknown>                → emit diagnostic

include_stmt   := "include" "*"
               | "include" IDENT
```

### Parse rules (narrow slice)

| Input pattern | AST output |
|---|---|
| `workspace { model { } views { } }` | `StructurizrWorkspace` with nil name, empty model + views |
| `workspace "Name" { ... }` | Workspace with `name: "Name"` |
| `workspace "Name" "Desc" { ... }` | Workspace with `name: "Name"`, `description: "Desc"` |
| `user = person "User Name"` | `StructurizrModelElement(alias: "user", kind: .person, name: "User Name")` |
| `user = person "User Name" "A user"` | Element with description "A user" |
| `app = softwareSystem "My App"` | Element kind `.softwareSystem`, name "My App" |
| `db = container "Database" "PostgreSQL"` | Element kind `.container`, name "Database", **description** "PostgreSQL" |
| `db = container "Database" "PostgreSQL" "Stores data"` | Element with description "PostgreSQL", **technology** "Stores data" |
| `auth = component "Auth Service"` | Element kind `.component` |
| `app = softwareSystem "My App" { web = container "Web" }` | Element with nested child |
| `app = softwareSystem "App" { web = container "Web" user -> web "Uses" }` | Scoped relationship inside element block |
| `user -> app "Uses"` | `StructurizrRelationshipDef(source: "user", target: "app", label: "Uses")` |
| `user -> app "Uses" "HTTPS"` | Relationship with label + technology |
| `user -> app "Uses" "HTTPS" "Over TLS"` | Relationship with label + tech + description |
| `systemContext app "Context" { include * }` | `StructurizrView(kind: .systemContext, scopeAlias: "app", title: "Context", includes: [.wildcard])` |
| `container app { include * }` | View with nil title, nil description |
| `component web { include user include db }` | View with explicit element includes |
| `deploymentNode "AWS" { ... }` | Parsed as AST element, deferred with diagnostic |
| `dynamic app { ... }` | Parsed as view, deferred with diagnostic |
| `!include url` | Emitted `.unsupported` diagnostic |
| `tags "Tag1,Tag2"` in model | Tags consumed with diagnostic; tag refinement is deferred |
| `autoLayout { ... }` in view | Parsed, deferred with diagnostic |
| `exclude user` in view | Parsed, deferred with diagnostic |
| `styles { ... }` in view | Parsed, deferred with diagnostic |
| `animation { ... }` in view | Parsed, deferred with diagnostic |

### Key parser behaviors

1. **Identifier-first assignment**: Structurizr uses `alias = elementType ...`
   rather than bare keywords. The parser reads an identifier token, then `=`,
   then the element kind keyword. This distinguishes `user = person` (element
   def) from bare `person` (would be a parse error).

2. **Quoted strings**: Names, descriptions, and technologies are quoted
   strings (`"..."`). The lexer strips quotes; the parser sees `.string`
   tokens. Optional strings: if fewer than 3 strings are provided after the
   element kind, the later positional slots are nil.

3. **Argument order (Structurizr DSL convention)**:
   - `person <name> [description]` (2 positional strings max)
   - `softwareSystem <name> [description]` (2 positional strings max)
   - `container <name> [description] [technology]` (3 positional strings max)
   - `component <name> [description] [technology]` (3 positional strings max)
   - `deploymentNode <name> [description] [technology]` (3 positional strings max)
   - Relationship: `source -> target [description] [technology]` (2 optional strings after target)

   **This is the corrected order.** The prior version incorrectly put
   technology before description.

4. **Nested element blocks**: `softwareSystem { container = container ...
   component = component ... }` — children are parsed recursively. The parent
   alias is tracked via a stack.

5. **Scoped relationships**: Inside an element block (`{ ... }`), both
   element definitions and relationship definitions are allowed. A scoped
   relationship like `user -> web "Uses"` inside `app = softwareSystem { ... }`
   is a valid Structurizr construct and is parsed into the model's
   relationship list. The source/target aliases are resolved at model scope
   (not scoped to the block).

6. **Relationship arrow**: `->` separates source from target. Labels,
   technology, and description are optional quoted strings after the target.
   Relationship argument order: `source -> target [description]? [technology]?`.

7. **Views section**: Parsed after the model section. View definitions specify
   the view kind, the scoping element alias, an optional title string, an
   optional description string, and include directives plus optional child
   blocks (`autoLayout`, `animation`, `styles`).

8. **Include `*`**: A bare `*` token after `include` means "include all
   visible elements." The parser captures this as `.wildcard`. Explicit
   element includes (`include user`) are captured as `.element("user")`.

9. **Deferred constructs**: `deploymentNode`, `dynamic` views, `deployment`
   views, `!include`, `!docs`, `!adrs`, `!decisions`, `tags "..."`,
   `properties { ... }`, `autoLayout { ... }`, `animation { ... }`,
   `styles { ... }`, `exclude`, and any unknown view statements are parsed
   into the AST (or their blocks consumed) but the mapper emits
   `.unsupported` diagnostics rather than producing C4 model entries.

10. **Brace balancing**: The parser validates that `{` and `}` are balanced.
    Unbalanced braces produce `DiagramError`.

## Work Stream 5: Model Registry (`StructurizrModelRegistry.swift`)

A lookup table built from the parsed model elements, used during view
resolution.

```swift
/// Registry that indexes model elements by alias for fast lookup.
/// Supports hierarchical parent-child traversal for view scoping.
public struct StructurizrModelRegistry: Sendable {
    /// All model elements indexed by alias (flattened: includes nested children).
    public let elementsByAlias: [String: StructurizrModelElement]
    /// All explicit relationships (model-level + scoped).
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

    /// All aliases connected to `alias` via any relationship (source or target).
    public func connectedAliases(to alias: String) -> Set<String> {
        var result: Set<String> = []
        for rel in relationships {
            if rel.source == alias { result.insert(rel.target) }
            if rel.target == alias { result.insert(rel.source) }
        }
        return result
    }
}
```

**Resolve `include *` for a view:**

For the vertical slice, `include *` semantics are simplified but follow
Structurizr's C4 scoping rules:

| View kind | Scope element | Scope rendered as | Include * resolves to |
|---|---|---|---|
| `systemContext <alias>` | softwareSystem | `C4Shape` (system box) | The scope softwareSystem (as shape), all persons related to it, and all softwareSystems related to it. Excludes containers, components, deployment nodes. |
| `container <alias>` | softwareSystem | `C4Boundary` (system boundary) | The scope softwareSystem (as boundary), all its direct container children (as shapes inside boundary), all persons related to the scope or its containers, and all external softwareSystems related to the scope or its containers. |
| `component <alias>` | container | `C4Boundary` (container boundary) | The parent softwareSystem (as shape or top-level context), the scope container (as boundary), all its direct component children (as shapes inside boundary), and all persons/containers related to the scope or its components. |

The resolution walks explicit relationships to discover connected elements.
Elements not referenced by any relationship that touches the scope element or
its children are excluded from the view.

**Boundary creation rule**: When a scope element is rendered as a boundary
(container and component views), the mapper creates a `C4Boundary` entry in
`C4Diagram.boundaries` with `alias` matching the scope element's alias. Child
shapes receive `parentBoundary` set to the scope alias. The C4 layout engine
(`_drawInsideBoundary`) requires both the boundary entry and the matching
`parentBoundary` on shapes — `parentBoundary` alone is insufficient.

## Work Stream 6: Structurizr → C4Diagram Mapper (`StructurizrMapper.swift`)

Converts `StructurizrWorkspace` → `C4Diagram` plus diagnostics. The mapper
builds a model registry from the `model` section, then resolves the first
view against it.

### Core mapping table

| Structurizr construct | C4Diagram / C4Shape / C4Boundary field |
|---|---|
| `person` element | `C4Shape(alias:, label:, typeC4Shape: .person, description:)` |
| `softwareSystem` element | `C4Shape(alias:, label:, typeC4Shape: .system, description:)` |
| `container` element | `C4Shape(alias:, label:, typeC4Shape: .container, technology:, description:)` |
| `component` element | `C4Shape(alias:, label:, typeC4Shape: .component, technology:, description:)` |
| `deploymentNode` element | Diagnostic only — no shape |
| Element `name` | `C4Shape.label` |
| Element `description` | `C4Shape.description` |
| Element `technology` | `C4Shape.technology` |
| Element `alias` | `C4Shape.alias` |
| Scope element as boundary (container/component views) | `C4Boundary(alias:, label: element.name, type:, description: element.description)` |
| Child element of boundary | `C4Shape.parentBoundary` set to parent's alias |
| `source -> target` relationship | `C4Relationship(kind: .rel, from:, to:, label:, technology:, description:)` |
| `systemContext` view | `C4Diagram.kind = .context` |
| `container` view | `C4Diagram.kind = .container` |
| `component` view | `C4Diagram.kind = .component` |
| `dynamic` / `deployment` view | Diagnostic only |
| View `title` | `C4Diagram.title` |
| View `description` | `C4Diagram.accDescr` |
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
   slice. Tags on elements emit diagnostics — the element is mapped to its
   base type.

2. **Boundary creation (critical — revised)**:

   For **container** views: the mapper creates a `C4Boundary` for the scope
   softwareSystem:
   ```swift
   C4Boundary(
       alias: scopeElement.alias,
       label: scopeElement.name,
       type: "system",
       description: scopeElement.description,
       parentBoundary: "global"
   )
   ```
   Child containers become `C4Shape` entries with `parentBoundary` set to the
   scope alias. The scope element itself is **not** added as a `C4Shape`.

   For **component** views: the mapper creates a `C4Boundary` for the scope
   container with `type: "container"`. Child components become `C4Shape`
   entries with `parentBoundary` set to the scope container's alias. The
   scope container's parent softwareSystem is added as a `C4Shape` (at global
   level) unless it has containers outside the component view scope.

   For **systemContext** views: the scope softwareSystem is rendered as a
   `C4Shape` (at global level). No boundary is created.

   **Why this matters**: The C4 layout engine (`layoutC4Diagram` →
   `_drawInsideBoundary`) only positions shapes within boundaries that exist
   in `C4Diagram.boundaries`. A shape with `parentBoundary: "app"` but no
   `C4Boundary(alias: "app")` in the diagram will never be positioned inside
   any boundary — it falls to the global level and displays incorrectly.
   Creating explicit `C4Boundary` entries is mandatory for correct C4
   rendering.

3. **Relationship resolution**: Explicit model relationships map directly to
   `C4Relationship` entries. The `kind` defaults to `.rel` (directed). Arrow
   direction is always source → target in Structurizr, with no explicit
   bidirectional syntax in the DSL. Bidirectional relationships (`.birel`)
   are deferred.

4. **View resolution — `include *`**: The mapper resolves which model
   elements are visible from the scope element's perspective:

   - **systemContext**: Include the scope softwareSystem (as shape), all
     persons that have a relationship TO or FROM the scope, and all
     softwareSystems that have a relationship TO or FROM the scope. Exclude
     containers, components, and deployment nodes.
   - **container**: CREATE a boundary for the scope softwareSystem. Include
     all its direct container children (as shapes with `parentBoundary` =
     scope alias), all persons related to the scope or its containers, all
     external softwareSystems related to the scope or its containers, and all
     relationships among those elements. Exclude components.
   - **component**: CREATE a boundary for the scope container. Include its
     parent softwareSystem (as global shape), the scope container (as
     boundary), all its direct component children (as shapes with
     `parentBoundary` = scope alias), all persons and other containers that
     relate to the scope container or its components, and all relationships
     among those.

   Elements not referenced by any relationship that touches the scope element
   or its direct children are excluded from the view.

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

9. **Title and description from view**: The view's optional title string
   populates `C4Diagram.title`. The view's optional description populates
   `C4Diagram.accDescr`. If the view has no title, the scope alias is used as
   a fallback title.

## Work Stream 7: Structurizr Probe (`StructurizrProbe.swift`)

A narrow probe function that requires `workspace` followed by an opening
brace (with optional name/description in between). It must NOT false-match
on Mermaid, D2, DOT, or PlantUML source.

```swift
/// Returns true when `source` appears to be Structurizr DSL rather than any
/// other known format. This is a narrow probe — it requires `workspace`
/// followed by `{` (with optional name/description strings between).
public func isStructurizrSource(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    let firstLine = trimmed.split(separator: "\n").first?
        .trimmingCharacters(in: .whitespaces) ?? ""

    // PlantUML guard — @startuml/@startxxx blocks
    if trimmed.contains("@startuml") || trimmed.contains("@start") {
        return false
    }

    // Mermaid guard — first-line diagram headers
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

    // D2 guard — d2 uses `:` and `->` without workspace wrapper
    // (Structurizr requires workspace keyword; D2 never starts with it)

    // Positive: workspace keyword at start, followed by { somewhere
    let wsTokens = lowerLine.split(separator: " ", omittingEmptySubsequences: true)
    guard let firstWS = wsTokens.first, firstWS == "workspace" else {
        // Compact form: workspace{...} or workspace"Name"{...}
        if lowerLine.hasPrefix("workspace{") || lowerLine.hasPrefix("workspace\"") {
            // Must eventually contain { to be valid
            return trimmed.contains("{")
        }
        return false
    }

    // Must contain an opening brace (may be on first line or subsequent lines)
    return trimmed.contains("{")
}
```

**Probe design rationale**:

- Structurizr DSL always starts with `workspace` (optionally followed by
  quoted name/description strings, then `{`). No other diagram format uses
  `workspace` as a top-level keyword.
- The probe now requires `{` somewhere in the source — `"workspace "` alone
  without `{` returns false. This matches the stated contract that the probe
  requires "`workspace {` structure."
- Mermaid, DOT, PlantUML, and D2 are all explicitly rejected before the
  positive check, providing defense-in-depth.
- Compact forms like `workspace{model{user=person"U"}}` are accepted.

## Work Stream 8: StructurizrImporter (`StructurizrImporter.swift`)

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
        let lexer = StructurizrLexer()
        let tokens = lexer.tokenize(source)

        let parser = StructurizrParser()
        let (workspace, parseDiagnostics) = try parser.parse(tokens)

        let mapper = StructurizrMapper()
        let (c4Diagram, mapDiagnostics) = mapper.map(workspace)

        let allDiagnostics = parseDiagnostics + mapDiagnostics
        let payload = DiagramPayload.c4(c4Diagram)
        let document = DiagramDocument(payload: payload)

        return DiagramImportResult(document: document, diagnostics: allDiagnostics)
    }
}
```

## Work Stream 9: Registry Integration

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

## Work Stream 10: Diagnostics for Unsupported DSL Constructs

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
| `tags "..."` on elements | "tag-based shape refinement not yet supported; rendered as base type" |
| `tags "..."` on relationships | "tag-based relationship styling not yet supported" |
| `properties { ... }` block | "custom properties not yet supported" |
| `!identifiers` (hierarchical/ flat) | "identifier strategy not yet supported" |
| `!impliedRelationships` | "implied relationships not yet supported" |
| `autoLayout { ... }` | "autoLayout configuration not yet supported" |
| `themes <url>` | "remote themes not yet supported" |
| `branding { ... }` | "branding not yet supported" |
| `terminology { ... }` | "terminology customization not yet supported" |
| `configuration { ... }` | "configuration block not yet supported" |
| `styles { ... }` (element/ relationship) | "custom styles not yet supported" |
| `perspectives { ... }` | "perspectives not yet supported" |
| `model { ... }` block inside view | "inline model in views not yet supported" |
| `group` / `groups` | "element groups not yet supported" |
| `url` attribute on elements | "URL attribute not yet supported" |
| `!ref` / `!extend` | "reference/include extension not yet supported" |
| `exclude` in view | "exclude directive not yet supported" |
| Unknown directive (`!foo`) | "unknown directive: !foo" |
| Unknown view statement | "unsupported view statement" |

### Diagnostic emission strategy

- **Lexer emits no diagnostics** — unrecognized tokens are passed through as
  `.identifier` for the parser to handle.
- **Parser emits diagnostics** for unsupported top-level directives
  (`!include`, `!docs`, `!adrs`, `!decisions`), deployment node definitions,
  dynamic/deployment views, `properties` blocks, `tags` statements,
  `autoLayout`/`animation`/`styles`/`exclude` in views, and unknown
  directives or view statements.
- **Mapper emits diagnostics** for multiple views, tag-based shape
  refinements, boundary-scope mismatches, and missing views.
- **Diagnostics carry line information** when available from the parser.
  Mapper-level diagnostics carry no line info (they fire during AST walk).
- **Never silent no-op**: every unrecognized construct produces a diagnostic.
  Valid constructs that map to supported C4 types produce no diagnostics.

## Work Stream 11: Tests

### 11a. `StructurizrLexerTests` (new file: `Tests/DiagramKitTests/StructurizrLexerTests.swift`)

Lexer unit tests. At least 8 tests:

| Test name | Description |
|---|---|
| `tokenizeEmptySource` | `""` → empty token array |
| `tokenizeIdentifiers` | `workspace model views` → three `.identifier` tokens |
| `tokenizeStrings` | `"Hello" "World"` → two `.string` tokens with quotes stripped |
| `tokenizeBraces` | `{ }` → `.openBrace`, `.closeBrace` |
| `tokenizeEquals` | `=` → `.equals` |
| `tokenizeArrow` | `->` → `.arrow` |
| `tokenizeStar` | `*` → `.star` (standalone) |
| `tokenizeLineComments` | `// comment\nworkspace` → only `.identifier("workspace")` |
| `tokenizeBlockComments` | `/* comment */workspace` → only `.identifier("workspace")` |
| `tokenizeHashComments` | `# comment\nworkspace` → only `.identifier("workspace")` |

### 11b. `StructurizrParserTests` (new file: `Tests/DiagramKitTests/StructurizrParserTests.swift`)

Parser unit tests for the recursive-descent parser. At least 20 tests:

| Test name | Description |
|---|---|
| `parseEmptyWorkspace` | `workspace { }` → workspace with nil name, nil model, empty views |
| `parseNamedWorkspace` | `workspace "Name" { }` → `name == "Name"` |
| `parseNamedWorkspaceWithDescription` | `workspace "N" "Desc" { }` → `name == "N"`, `description == "Desc"` |
| `parsePersonElement` | `workspace { model { u = person "User" } }` → element with alias "u", kind .person, name "User" |
| `parsePersonWithDescription` | `workspace { model { u = person "User" "A user" } }` → description "A user" |
| `parseSoftwareSystem` | `workspace { model { app = softwareSystem "My App" } }` → element kind .softwareSystem, name "My App" |
| `parseSoftwareSystemWithDescription` | `workspace { model { app = softwareSystem "My App" "Core" } }` → description "Core" |
| `parseContainer` | `workspace { model { db = container "DB" "PostgreSQL" } }` → name "DB", **description** "PostgreSQL", technology nil |
| `parseContainerWithTechnology` | `workspace { model { db = container "DB" "PostgreSQL" "Stores data" } }` → description "PostgreSQL", **technology** "Stores data" |
| `parseComponent` | `workspace { model { auth = component "Auth" } }` → element kind .component |
| `parseComponentWithDescriptionAndTech` | `workspace { model { auth = component "Auth" "Handles login" "OAuth2" } }` → description "Handles login", technology "OAuth2" |
| `parseNestedElements` | `workspace { model { app = softwareSystem "App" { web = container "Web" } } }` → child container with parentAlias "app" |
| `parseScopedRelationship` | `workspace { model { app = softwareSystem "App" { user -> web "Uses" } } }` → relationship in model.relationships with source "user", target "web" |
| `parseRelationship` | `workspace { model { u -> app "Uses" } }` → relationship with label "Uses" |
| `parseRelationshipWithAllArgs` | `workspace { model { u -> app "Uses" "HTTPS" "Over TLS" } }` → label "Uses", technology "HTTPS", description "Over TLS" |
| `parseMultipleElements` | `workspace { model { u = person "U"; app = softwareSystem "A" } }` → two model elements |
| `parseSystemContextView` | `workspace { views { systemContext app { include * } } }` → view with kind .systemContext, scopeAlias "app" |
| `parseContainerView` | `workspace { views { container app { include * } } }` → view kind .container |
| `parseComponentView` | `workspace { views { component web { include u include db } } }` → view with explicit element includes |
| `parseViewWithTitleAndDescription` | `workspace { views { systemContext app "Title" "Desc" { include * } } }` → view title "Title", description "Desc" |
| `parseComments` | `workspace { // comment\nmodel { u = person "U" }\n}` — comments stripped |
| `parseThrowsOnUnbalancedBraces` | `workspace { model { u = person "U"` → throws `DiagramError` |

### 11c. `StructurizrModelRegistryTests` (new file: `Tests/DiagramKitTests/StructurizrModelRegistryTests.swift`)

Model registry unit tests. At least 6 tests:

| Test name | Description |
|---|---|
| `lookupElementByAlias` | Register elements, verify `element(for:)` returns correct element |
| `lookupMissingAliasReturnsNil` | `element(for: "nonexistent")` → nil |
| `collectsNestedChildren` | Element with children → both parent and children in `elementsByAlias` |
| `topLevelElementsExcludesChildren` | `topLevelElements` returns only elements with nil parentAlias |
| `connectedAliasesFindsBothDirections` | Relationship A→B → `connectedAliases(to: "A")` includes "B" and vice versa |
| `connectedAliasesEmptyForIsolatedElement` | Element with no relationships → empty set |

### 11d. `StructurizrImporterTests` (new file: `Tests/DiagramKitTests/StructurizrImporterTests.swift`)

Importer unit tests. At least 28 tests:

**supports tests:**

| Test name | Description |
|---|---|
| `supportsWorkspace` | `workspace { model { } views { } }` → true |
| `supportsCompactWorkspace` | `workspace{model{u=person"U"}}` → true |
| `supportsNamedWorkspace` | `workspace "Name" { }` → true |
| `rejectsWorkspaceWithoutBrace` | `workspace` (no `{`) → false |
| `rejectsWorkspaceNameWithoutBrace` | `workspace "Name"` (no `{`) → false |
| `rejectsMermaidSource` | `graph TD\nA-->B` → false |
| `rejectsMermaidC4` | `C4Context\nPerson(user, "User")` → false |
| `rejectsD2Source` | `A: Start\nA -> B` → false |
| `rejectsDOTSource` | `digraph G { A -> B }` → false |
| `rejectsPlantUML` | `@startuml\nAlice -> Bob: Hello\n@enduml` → false |
| `rejectsEmptySource` | `""` → false |

**parse tests:**

| Test name | Description |
|---|---|
| `parsePersonMapsToC4Shape` | Person element → shape with typeC4Shape .person |
| `parseSoftwareSystemMapsToSystem` | softwareSystem element → shape typeC4Shape .system |
| `parseContainerMapsToContainer` | container element → shape typeC4Shape .container |
| `parseComponentMapsToComponent` | component element → shape typeC4Shape .component |
| `parseTechnologyIsPreserved` | Container with technology "PostgreSQL" → C4Shape.technology = "PostgreSQL" |
| `parseDescriptionIsPreserved` | Element with description → C4Shape.description populated |
| `parseContainerDescriptionNotTechnology` | `container "DB" "PostgreSQL"` → description "PostgreSQL", technology nil (not the reverse) |
| `parseViewTitleBecomesDiagramTitle` | View with title "My Context" → C4Diagram.title = "My Context" |
| `parseViewDescriptionBecomesAccDescr` | View with description → C4Diagram.accDescr populated |
| `parseSystemContextViewCreatesNoBoundary` | systemContext view → scope softwareSystem is a C4Shape, no C4Boundary for it |
| `parseContainerViewCreatesBoundary` | container view → C4Boundary created for scope softwareSystem, containers are child shapes |
| `parseComponentViewCreatesBoundary` | component view → C4Boundary created for scope container, components are child shapes |
| `parseBoundaryHasChildrenWithMatchingParentBoundary` | Container view → child shapes have parentBoundary matching boundary alias |
| `parseRelationshipMapsToC4Relationship` | `u -> app "Uses"` → C4Relationship with label "Uses" |
| `parseRelationshipWithTechnology` | Relationship with technology → C4Relationship.technology populated |
| `wildcardIncludeIncludesScopeElement` | systemContext view → scope softwareSystem in shapes |
| `wildcardIncludeIncludesRelatedElements` | Related persons + systems included in view |
| `wildcardIncludeExcludesUnrelatedElements` | Unrelated elements not included in view |
| `emitsDiagnosticForDeploymentNode` | `deploymentNode "AWS" { }` → diagnostic |
| `emitsDiagnosticForDynamicView` | `dynamic app { }` → diagnostic |
| `emitsDiagnosticForTags` | `tags "Tag1"` on element → diagnostic |
| `emitsDiagnosticForExcludeInView` | `exclude user` in view → diagnostic |
| `emitsDiagnosticForUnknownDirective` | `!foo` → diagnostic |
| `emitsDiagnosticForMultipleViews` | workspace with 2+ views → diagnostic |
| `emitsDiagnosticForNoViews` | workspace with model but no views → diagnostic |

**layout smoke tests:**

| Test name | Description |
|---|---|
| `structurizrLayoutSmoke` | Parse structurizr workspace, run `DiagramPipeline.layout`, verify non-empty positioned output |
| `structurizrContainerViewLayoutSmoke` | Parse container view workspace, layout, verify boundaries present in positioned output |
| `structurizrComponentViewLayoutSmoke` | Parse component view workspace, layout, verify boundaries present |

### 11e. Probe Collision Tests (edit `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift`)

Add Structurizr probe collision tests. At least 16 new tests:

| Test name | Description |
|---|---|
| `structurizrProbeAcceptsWorkspace` | `StructurizrImporter().supports(source: "workspace { }")` → true |
| `structurizrProbeAcceptsNamedWorkspace` | `StructurizrImporter().supports(source: "workspace \"N\" { }")` → true |
| `structurizrProbeAcceptsCompact` | `StructurizrImporter().supports(source: "workspace{model{}}")` → true |
| `structurizrProbeAcceptsMultilineWorkspace` | `StructurizrImporter().supports(source: "workspace\n{ model {} }")` → true |
| `structurizrProbeRejectsWorkspaceWithoutBrace` | `StructurizrImporter().supports(source: "workspace")` → false |
| `structurizrProbeRejectsWorkspaceNameWithoutBrace` | `StructurizrImporter().supports(source: "workspace \"N\"")` → false |
| `structurizrProbeRejectsMermaidGraphTD` | `StructurizrImporter().supports(source: "graph TD\nA-->B")` → false |
| `structurizrProbeRejectsMermaidFlowchart` | `StructurizrImporter().supports(source: "flowchart LR\nA-->B")` → false |
| `structurizrProbeRejectsMermaidC4` | `StructurizrImporter().supports(source: "C4Context\nPerson(user, \"U\")")` → false |
| `structurizrProbeRejectsD2Source` | `StructurizrImporter().supports(source: "A: Start\nA -> B")` → false |
| `structurizrProbeRejectsDOTSource` | `StructurizrImporter().supports(source: "digraph G { A -> B }")` → false |
| `structurizrProbeRejectsPlantUML` | `StructurizrImporter().supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml")` → false |
| `structurizrProbeRejectsEmptyString` | `StructurizrImporter().supports(source: "")` → false |
| `registryPrependsStructurizrFirst` | `registry.importer(for: "workspace { model { } views { } }")?.name == "Structurizr"` |
| `registryFallsBackToGraphvizForDigraph` | `registry.importer(for: "digraph G { A -> B }")?.name == "Graphviz"` |
| `registryFallsBackToMermaidForGraphTD` | `registry.importer(for: "graph TD\nA-->B")?.name == "Mermaid"` |

### 11f. `StructurizrCorpusFixtureTests` (new file: `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift`)

Inline corpus fixtures with `skipSnapshots: ["structurizr"]`. At least 7 tests.
**Each fixture must include a complete scoped element and at least one
relationship that proves wildcard resolution works.**

| Test name | Description |
|---|---|
| `structurizrSystemContextFixtureDecodes` | Inline fixture: person + softwareSystem + relationship + systemContext view with `include *`. Verify shapes include person and both systems; verify no boundary created. |
| `structurizrContainerViewFixtureDecodes` | Inline fixture: softwareSystem with 2 containers, person, relationship, container view with `include *`. Verify boundary created for softwareSystem; container shapes have parentBoundary matching boundary. |
| `structurizrComponentViewFixtureDecodes` | Inline fixture: softwareSystem → container with 2 components, person, relationships, component view with `include *`. Verify boundary for container; component shapes have parentBoundary. |
| `structurizrScopedRelationshipFixtureDecodes` | Inline fixture: relationship defined inside element block, verify it appears in C4Diagram.relationships. |
| `structurizrUnsupportedFixtureHasDiagnostics` | Inline fixture with deploymentNode + `tags "db"` + `!include x` → `expectedDiagnostics` checking all three categories. |
| `structurizrSourceForFormat` | `entry.source(for: "structurizr")` returns the Structurizr source |
| `structurizrParseThroughImporter` | Parse Structurizr source via `StructurizrImporter`, layout via `DiagramPipeline.layout`, verify non-empty positioned graph |

### 11g. Registry Tests (edit `Tests/DiagramKitTests/ImporterRegistryTests.swift`)

Update existing registry tests for the new four-importer order:

| Test | Change |
|---|---|
| `defaultRegistryOrder` | Assert `registry.importers[0].name == "Structurizr"`, `[1] == "Graphviz"`, `[2] == "D2"`, `[3] == "Mermaid"` |
| `prependingPutsFirst` | Extend to show `StructurizrImporter()` prepended before Graphviz+D2+Mermaid |
| `structurizrFirstRouting` | Verify Structurizr claims `workspace { ... }` source |

### 11h. Existing Test Regressions

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
| `Package.swift` | Add `DiagramKitStructurizr` target, product, deps. Add to umbrella + test target deps | Complete |
| `Sources/DiagramKitStructurizr/StructurizrAST.swift` | New — Structurizr DSL AST types (151 lines) | Complete |
| `Sources/DiagramKitStructurizr/StructurizrLexer.swift` | New — tokenizer (comment stripping, token stream) (243 lines) | Complete |
| `Sources/DiagramKitStructurizr/StructurizrParserState.swift` | New — parse state, token navigation, block-skipping helpers (130 lines) | Complete |
| `Sources/DiagramKitStructurizr/StructurizrParser.swift` | New — recursive-descent parser (consumes tokens) (308 lines) | Complete |
| `Sources/DiagramKitStructurizr/StructurizrModelRegistry.swift` | New — model element lookup table (178 lines) | Complete |
| `Sources/DiagramKitStructurizr/StructurizrMapper.swift` | New — StructurizrAST → C4Diagram mapping (creates boundaries) (270 lines) | Complete |
| `Sources/DiagramKitStructurizr/StructurizrProbe.swift` | New — narrow Structurizr probe (requires `{` after optional quoted workspace strings) (64 lines) | Complete |
| `Sources/DiagramKitStructurizr/StructurizrImporter.swift` | New — `DiagramSourceImporter` conformance (38 lines) | Complete |
| `Sources/DiagramKit/MermaidPipeline.swift` | Edit — add `StructurizrImporter()` to `defaultRegistry` + `import DiagramKitStructurizr` | Complete |
| `Tests/DiagramKitTests/StructurizrLexerTests.swift` | New — 10 lexer unit tests | Complete |
| `Tests/DiagramKitTests/StructurizrParserTests.swift` | New — 22 parser unit tests | Complete |
| `Tests/DiagramKitTests/StructurizrModelRegistryTests.swift` | New — 6 registry unit tests | Complete |
| `Tests/DiagramKitTests/StructurizrImporterTests.swift` | New — 36 importer unit tests (496 lines) | Complete |
| `Tests/DiagramKitTests/StructurizrLayoutSmokeTests.swift` | New — 3 layout smoke tests (split from ImporterTests) | Complete |
| `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift` | Edit — 16 Structurizr probe collision tests + `import DiagramKitStructurizr` | Complete |
| `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift` | New — 7 inline Structurizr fixture tests that parse fixtures and inspect C4 payloads | Complete |
| `Tests/DiagramKitTests/StructurizrRegressionTests.swift` | New — 7 post-review regression tests | Complete |
| `Tests/DiagramKitTests/ImporterRegistryTests.swift` | Edit — Structurizr-first registry assertion + `import DiagramKitStructurizr` | Complete |

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

### 2. Explicit `C4Boundary` entries for container/component views (REVISED)

**Decision**: For container and component views, the mapper creates
`C4Boundary` entries for the scope element (softwareSystem for container
views, container for component views). Child shapes have `parentBoundary` set
to the boundary's alias.

**Rationale**: The C4 layout engine (`_drawInsideBoundary`) only positions
shapes within boundaries that exist in `C4Diagram.boundaries`. A shape with
`parentBoundary: "app"` but no `C4Boundary(alias: "app")` will not be
positioned inside any boundary — it falls to the global level. Setting
`parentBoundary` on shapes without a matching boundary is a silent rendering
bug. Creating explicit boundaries is mandatory for correct C4 output.

In systemContext views, the scope softwareSystem is rendered as a `C4Shape`
(no boundary) — matching C4 convention where system context diagrams show the
system as a box among other boxes, not as a container.

### 3. Element argument order: description before technology (REVISED)

**Decision**: `container <name> [description] [technology]` and
`component <name> [description] [technology]` per Structurizr DSL convention,
NOT `name/technology/description`.

**Rationale**: Official Structurizr DSL reference:
- `person <name> [description] [tags]`
- `softwareSystem <name> [description] [tags]`
- `container <name> [description] [technology] [tags]`
- `component <name> [description] [technology] [tags]`

The previous plan had the argument order reversed. This correction is critical
for parser test fidelity — incorrect argument order would bake wrong behavior
into the parser tests, causing the importer to swap description and technology
on every container/component element.

### 4. Tag syntax: `tags "..."` child statements, not `{tag}` braces (REVISED)

**Decision**: Tags are parsed from `tags "Tag1,Tag2"` child statements inside
element/relationship blocks. The `{` `}` brace syntax is reserved for child
blocks in Structurizr DSL (e.g., `softwareSystem "App" { container = ... }`).
No `{tag}` annotation syntax exists.

**Rationale**: Structurizr DSL uses braces exclusively to open child blocks.
Tags come from explicit `tags "..."` statements, `+tag` syntax (rare), or
trailing string arguments in some DSL versions. The `{tag}` notation was a
misreading of the DSL. The correct path for this vertical slice is to parse
`tags "..."` statement, emit a diagnostic saying tag-based shape refinement is
deferred, and continue parsing later model statements. The vertical slice does
not map tag values into shapes yet. No brace-based tag parsing is needed.

### 5. Scoped relationships inside element blocks are supported

**Decision**: The parser accepts relationship definitions inside element
blocks (`softwareSystem "App" { user -> web "Uses" }`). These are collected
into the model's `relationships` list at model scope.

**Rationale**: Scoped relationships are a common Structurizr DSL pattern and
require only a small grammar change (allow `relationship_def` inside element
blocks alongside `element_def`). Supporting them avoids a common diagnostic
on valid DSL and improves real-world workspace compatibility.

### 6. First view only — single `DiagramImportResult`

**Decision**: The importer returns only the first view from a multi-view
workspace. Additional views beyond the first emit diagnostics.

**Rationale**: `DiagramSourceImporter.parse()` returns a single
`DiagramImportResult` with one `DiagramDocument`. Multi-diagram output
from a single source is a future concern (Phase 7 or beyond).

### 7. Probe requires `{` after workspace

**Decision**: The probe returns false for `"workspace"` or `"workspace \"Name\""`
without a following `{`. The source must contain `{` to pass the probe.

**Rationale**: The stated probe contract is "requires `workspace {` structure."
Without a brace check, `"workspace"` alone would pass, which is too broad.
Requiring `{` keeps the probe narrow and honest about its contract.

### 8. Lexer separated from parser

**Decision**: `StructurizrLexer.swift` is a separate file from
`StructurizrParser.swift`. The lexer owns token type definitions and
preprocessing (comment stripping, tokenization). The parser consumes
`[StructurizrToken]` and emits `StructurizrWorkspace` + diagnostics.

**Rationale**: Keeps both files under the 500-line threshold, enables
independent unit testing of the lexer (10+ tests), and matches the DOT
Phase 4 pattern (`DOTLexer.swift` + `DOTParser.swift`). The parser is
token-driven, not purely line-oriented — this handles compact forms
uniformly.

### 9. Model registry independently testable

**Decision**: `StructurizrModelRegistryTests.swift` is a separate test file
with 6 tests covering alias lookup, nested child collection, top-level
filtering, and connected-alias resolution.

**Rationale**: View resolution is the hardest part of the mapper. Being able
to test the registry's `connectedAliases(to:)` and `topLevelElements`
independently of the mapper catches logic bugs before they propagate to
integration tests. The registry's `include *` resolution logic is the most
likely source of subtle C4 scoping errors.

### 10. Complete test fixtures with relationships

**Decision**: Every corpus fixture test includes at least one relationship
definition and a wildcard include view that exercises the resolution path.

**Rationale**: A fixture that only defines model elements without
relationships cannot prove that `include *` resolution works — there are no
connections to traverse. Each fixture must include the scoped element, at
least one related element, and at least one explicit relationship so that
the wildcard resolution produces a non-trivial set of shapes. This catches
the boundary-vs-shape distinction (Design Decision 2) early.

---

## Verification Gates

```bash
swift package dump-package
swift build --build-tests
swift test --filter StructurizrLexerTests
swift test --filter StructurizrParserTests
swift test --filter StructurizrModelRegistryTests
swift test --filter StructurizrImporterTests
swift test --filter StructurizrLayoutSmokeTests
swift test --filter StructurizrCorpusFixtureTests
swift test --filter StructurizrRegressionTests
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

`Scripts/check-file-sizes.sh` reports no Phase 5 source or test files over the
500-line warning threshold. All remaining warnings are pre-existing.

Focused Structurizr verification passes (96 tests in 10 suites).
No snapshot recording. No Linux check performed (Docker/Podman not available).

---

## Deferred to Later Phases

- `deploymentNode`, `infrastructureNode`, `softwareSystemInstance`,
  `containerInstance` element types
- `dynamic` and `deployment` views
- Multiple views from a single workspace (multi-diagram output)
- Tag-based shape refinement (mapping `tags "external"` → `.external_system`,
  `tags "database"` → `.system_db`, `tags "queue"` → `.system_queue`, etc.)
- Implicit relationships (`!impliedRelationships` directive)
- `!include`, `!docs`, `!adrs`, `!decisions` directives
- `properties { ... }` blocks on elements and relationships
- `!identifiers` (hierarchical vs. flat identifier strategy)
- `autoLayout { ... }` configuration
- `themes`, `branding`, `terminology`, `configuration` blocks
- `styles { ... }` (per-element and per-relationship custom styles)
- `perspectives { ... }`
- `group` / `groups` element grouping
- `url` attribute on elements
- `!ref` / `!extend` / `!plugin` / `!script` directives
- `exclude` in views
- `animation { ... }` in views
- Inline model elements within views
- Inline relationship definitions within views
- Round-trip export (StructurizrExporter)
- Real `test-diagrams.json` multi-format entries
- Structurizr snapshot baselines (SVG, image)

---

*This plan (revised) was prepared from live codebase analysis of Package.swift,
Sources/DiagramKitModel/src_c4_types.swift, Sources/DiagramKitModel/src_c4_layout.swift,
Sources/DiagramKitD2/, Sources/DiagramKitGraphviz/, Sources/DiagramKit/,
Sources/DiagramKitImport/, Tests/DiagramKitTests/, ANALYSIS.md, PHASES.md,
PHASE-3.md, and PHASE-4.md as they exist at 2026-05-12. The official
Structurizr DSL language reference was consulted for argument order and tag
syntax corrections.*
