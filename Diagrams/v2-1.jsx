// v2-1.jsx — DiagramKit Playground v2.1 additions
//
// All new surfaces, inspector cards, and the render-health pill.
// Wired into existing artboards via window globals.
//
// Source citations (verified against ajmcclary/DiagramKit @ main):
//   Cross-format          → Sources/DiagramKitMermaid/, DiagramKitD2/, DiagramKitGraphviz/
//   Subgraph grouping     → Sources/DiagramKitInteractive/DiagramMutation.swift (design fiction: .groupIntoSubgraph)
//   Importer registry     → Sources/DiagramKitImport/ImporterRegistry.swift + DiagramLoader.swift
//   Theme tokens          → Sources/DiagramKitCommon/src_theme.swift (DiagramColors struct)
//   Mutations catalog     → Sources/DiagramKitInteractive/DiagramMutation.swift
//                           Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift
//                           Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift
//   Linux text metrics    → Sources/DiagramKitCommon/src_text_metrics.swift
//                           (char-count width fallback for ishikawa, treeView, eventModeling)
//   Render-health worker  → Sources/DiagramKitRenderingCG/DiagramWorkerThread.swift
//                           DiagramEngine._runOnWorker · 8 MB stack

// ─────────────────────────────────────────────────────────────
// Render-health pill — replaces the static "1.8 ms · 6.4 ms" pill
// when t.renderHealth = "slow" or "failed".
// ─────────────────────────────────────────────────────────────
function RenderHealthPill({ renderHealth = "ok", layoutMs, paintMs }) {
  const [hover, setHover] = React.useState(false);
  const ok = renderHealth === "ok";
  const slow = renderHealth === "slow";
  const failed = renderHealth === "failed";

  if (ok) {
    return (
      <div className="pill-status">
        <span className="dot" /> {layoutMs || "1.8 ms"} layout · {paintMs || "6.4 ms"} paint
      </div>
    );
  }

  return (
    <div
      className={"pill-status rh " + (slow ? "rh-slow" : "rh-failed")}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{ position: "relative" }}
    >
      {slow && (<>
        <span className="rh-ic">⚠</span>
        <span>184 ms layout · 92 ms paint</span>
        <span className="rh-meta">exceeds 100 ms budget</span>
      </>)}
      {failed && (<>
        <span className="rh-ic">✕</span>
        <span style={{ fontFamily: "var(--font-mono)" }}>DiagramError.unsupportedOnPlatform</span>
      </>)}
      {hover && slow && (
        <div className="rh-popover">
          <div className="rh-popover-hd">Slowest pipeline steps</div>
          <div className="rh-step"><span className="step-k">MermaidParser.parse</span><span className="step-v">18 ms</span></div>
          <div className="rh-step danger"><span className="step-k">GraphLayout.layout</span><span className="step-v">152 ms</span></div>
          <div className="rh-step"><span className="step-k">renderSVG</span><span className="step-v">14 ms</span></div>
          <div className="rh-popover-ft">Budget: 100 ms · DiagramWorkerThread.swift</div>
        </div>
      )}
      {hover && failed && (
        <div className="rh-popover">
          <div className="rh-popover-hd">DiagramError thrown</div>
          <div style={{ fontFamily: "var(--font-mono)", fontSize: 10.5, color: "var(--fg2)", lineHeight: 1.5 }}>
            .unsupportedOnPlatform(family:&nbsp;.wardley)
            <br/>thrown from DiagramEngine._runOnWorker
          </div>
          <div className="rh-popover-ft">Sources/DiagramKitRenderingCG/DiagramWorkerThread.swift</div>
        </div>
      )}
    </div>
  );
}

// Error sheet shown when renderHealth === "failed"
function RenderFailedSheet() {
  return (
    <div className="rh-error-sheet">
      <div className="rh-error-hd">
        <span className="ic">✕</span>
        <span className="ttl">DiagramError · unsupportedOnPlatform</span>
        <span style={{ flex: 1 }} />
        <span className="cite">DiagramEngine._runOnWorker</span>
      </div>
      <div className="rh-error-body">
        <pre className="rh-stack">{`throw DiagramError.unsupportedOnPlatform(
    family: .wardley,
    platform: .linux,
    reason: "CGContext-only renderer not portable"
)
  at DiagramEngine._runOnWorker (DiagramEngine.swift:184)
  at DiagramPipeline.renderImage(_:) (DiagramPipeline.swift:96)
  at DiagramView.body (DiagramView.swift:42)`}</pre>
        <div className="rh-error-actions">
          <button className="tb-btn primary"><span className="kbd" style={{ marginRight: 6 }}>↻</span>Run on worker · 8 MB stack</button>
          <button className="tb-btn">Open Sources/DiagramKitRenderingCG/DiagramWorkerThread.swift</button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Three-format view — same flowchart in Mermaid, D2, DOT
// Used in DCArtboard K
// ─────────────────────────────────────────────────────────────
const FMT3_MERMAID = [
  "%% DiagramKit pipeline",
  "flowchart LR",
  "  Source[\"Source\"] --> P(\"MermaidParser.parse\")",
  "  P --> D[\"DiagramDocument\"]",
  "  D --> L((\"GraphLayout\"))",
  "  L --> G((\"PositionedGraph\"))",
  "  G -->|renderImage|  I[\"BMImage\"]",
  "  G -->|renderSVG|    S[\"SVG String\"]",
  "  G -->|renderASCII|  A[\"positioned\"]",
  "  G --> V[\"DiagramView\"]",
  "  classDef ok fill:#30D158",
  "  class I,S,A,V ok",
];
const FMT3_D2 = [
  "# DiagramKit pipeline — D2",
  "direction: right",
  "Source.label: Source",
  "P.label: MermaidParser.parse",
  "D.label: DiagramDocument",
  "L.label: GraphLayout; L.shape: oval",
  "G.label: PositionedGraph; G.shape: oval",
  "Source -> P -> D -> L -> G",
  "G -> I: renderImage",
  "G -> S: renderSVG",
  "G -> A: renderASCII",
  "G -> V",
  "# classDef \"ok\" dropped",
];
const FMT3_DOT = [
  "digraph DiagramKit {",
  "  rankdir = LR;",
  "  Source [label=\"Source\"];",
  "  P [label=\"MermaidParser.parse\"];",
  "  D [label=\"DiagramDocument\"];",
  "  L [label=\"GraphLayout\"];",
  "  G [label=\"PositionedGraph\"];",
  "  Source -> P -> D -> L -> G;",
  "  G -> render_image [label=\"renderImage\"];",
  "  G -> render_svg   [label=\"renderSVG\"];",
  "  G -> render_ascii [label=\"renderASCII\"];",
  "}",
];

function FormatColumn({ fmt, lines, fmtPillColor, exporterPath, diagnostics }) {
  return (
    <div className="fmt-col">
      <div className="fmt-col-hd">
        <span className="fmt-pill" style={{ color: fmtPillColor }}>{fmt}</span>
        <span className="fmt-col-meta">{lines.length} lines</span>
      </div>
      <pre className="fmt-col-body">
        {lines.map((l, i) => <span key={i} style={{ display: "block" }}>{l}</span>)}
      </pre>
      <div className="fmt-col-diag">
        {diagnostics.length === 0 ? (
          <span className="kpill ok"><span className="d" />0 typed losses · clean</span>
        ) : diagnostics.map((d, i) => (
          <span key={i} className={"kpill " + (d.tone || "warn")} title={d.title}>
            <span className="d" />{d.label}
          </span>
        ))}
      </div>
      <div className="fmt-col-src">{exporterPath}</div>
    </div>
  );
}

function ThreeFormatView() {
  return (
    <div className="three-fmt">
      <div className="three-fmt-hd">
        <div style={{ display: "flex", flexDirection: "column", lineHeight: 1.2 }}>
          <span className="h1">Three-format view · same flowchart · Mermaid · D2 · DOT</span>
          <span className="sub">RoundTripHarness · cross-format · 3 formats · 6 ordered directions · structurally equal</span>
        </div>
        <span style={{ flex: 1 }} />
        <KPill tone="accent" dot>parse → export · paired ✓</KPill>
      </div>
      <div className="three-fmt-grid">
        <FormatColumn
          fmt="mermaid"
          fmtPillColor="#FF9F0A"
          lines={FMT3_MERMAID}
          exporterPath="Sources/DiagramKitMermaid/Exporter/"
          diagnostics={[
            { label: "host · 0 losses", tone: "ok" },
            { label: ".commentPreserved · 1", tone: "info" },
          ]}
        />
        <FormatColumn
          fmt="d2"
          fmtPillColor="#8E8CFF"
          lines={FMT3_D2}
          exporterPath="Sources/DiagramKitD2/D2Exporter.swift"
          diagnostics={[
            { label: ".styleDrop · classDef ok", tone: "warn", title: "DiagramExportResult.diagnostics" },
            { label: ".shapeDowngrade · G .circle → .oval", tone: "warn" },
          ]}
        />
        <FormatColumn
          fmt="dot"
          fmtPillColor="#BF5AF2"
          lines={FMT3_DOT}
          exporterPath="Sources/DiagramKitGraphviz/DOTExporter.swift"
          diagnostics={[
            { label: ".idSanitization · render-image → render_image", tone: "warn" },
            { label: ".idSanitization · render-svg", tone: "warn" },
            { label: ".idSanitization · render-ascii", tone: "warn" },
          ]}
        />
      </div>
      <div className="three-fmt-foot">
        <span className="rt-pill">
          <span className="dot" />
          RoundTripHarness · 3 formats · 6 ordered directions · clean
        </span>
        <span style={{ flex: 1 }} />
        <span className="meta">Sources/DiagramKitTestSupport/RoundTripHarness.swift · <span className="mono">runCrossFormatRoundTrip</span></span>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Importer registry probe view (artboard N)
// Vertical pipeline: source string → 5 probes → DiagramImportResult.
// Side panel: tweak-driven sample picker (which probe wins).
// ─────────────────────────────────────────────────────────────
const PROBE_SAMPLES = {
  mermaid: {
    label: "Mermaid · Pipeline.mmd",
    badge: "mmd",
    badgeColor: "#FF9F0A",
    winner: "MermaidImporter",
    source: [
      "%% DiagramKit pipeline",
      "flowchart LR",
      "  Source --> P[\"MermaidParser.parse\"]",
      "  P --> D[\"DiagramDocument\"]",
    ],
    diagnostics: 0,
  },
  d2: {
    label: "D2 · Pipeline.d2",
    badge: "d2",
    badgeColor: "#8E8CFF",
    winner: "D2Importer",
    source: [
      "# DiagramKit pipeline — D2",
      "direction: right",
      "Source -> P",
      "P.label: MermaidParser.parse",
    ],
    diagnostics: 0,
  },
  dot: {
    label: "DOT · Pipeline.dot",
    badge: "dot",
    badgeColor: "#BF5AF2",
    winner: "GraphvizImporter",
    source: [
      "digraph DiagramKit {",
      "  rankdir = LR;",
      "  Source -> P -> D -> L -> G;",
      "}",
    ],
    diagnostics: 1,
  },
  structurizr: {
    label: "Structurizr · Workspace.dsl",
    badge: "stz",
    badgeColor: "#64D2FF",
    winner: "StructurizrImporter",
    source: [
      "workspace {",
      "  model {",
      "    diagramKit = softwareSystem \"DiagramKit\"",
      "  }",
      "}",
    ],
    diagnostics: 0,
  },
  plantuml: {
    label: "PlantUML · Pipeline.puml",
    badge: "puml",
    badgeColor: "#FF375F",
    winner: "PlantUMLImporter",
    source: [
      "@startuml",
      "package \"DiagramKit\" {",
      "  [Source] --> [MermaidParser]",
      "}",
      "@enduml",
    ],
    diagnostics: 0,
  },
};

// Registry order — narrower importers first, Mermaid (fallback) last.
const PROBE_REGISTRY = [
  { id: "D2Importer",          fmt: "d2",          file: "DiagramKitD2/D2Importer.swift",            note: "isFallback: false" },
  { id: "GraphvizImporter",    fmt: "dot",         file: "DiagramKitGraphviz/GraphvizImporter.swift", note: "isFallback: false" },
  { id: "StructurizrImporter", fmt: "structurizr", file: "DiagramKitStructurizr/StructurizrImporter.swift", note: "isFallback: false" },
  { id: "PlantUMLImporter",    fmt: "plantuml",    file: "DiagramKitPlantUML/PlantUMLImporter.swift",  note: "isFallback: false" },
  { id: "MermaidImporter",     fmt: "mermaid",     file: "DiagramKitMermaid/MermaidImporter.swift",    note: "isFallback: true · must be last" },
];

function ImporterRegistryProbeView({ activeSample = "d2", onChange }) {
  const sample = PROBE_SAMPLES[activeSample] || PROBE_SAMPLES.d2;
  const winnerIdx = PROBE_REGISTRY.findIndex((p) => p.id === sample.winner);

  return (
    <div className="probe-stack">
      <div className="probe-hd">
        <div style={{ display: "flex", flexDirection: "column", lineHeight: 1.2 }}>
          <span className="h1">DiagramLoader · probe sequence</span>
          <span className="sub">First-match-wins · ImporterRegistry order is contractual (ProbeCollisionMatrixTests)</span>
        </div>
        <span style={{ flex: 1 }} />
        <KPill tone="accent" dot>resolved · {sample.winner}</KPill>
      </div>

      <div className="probe-body">
        {/* Sample picker (left) */}
        <div className="probe-picker">
          <div className="picker-hd">Sample source</div>
          {Object.entries(PROBE_SAMPLES).map(([id, s]) => (
            <div key={id}
                 className={"picker-row" + (activeSample === id ? " on" : "")}
                 onClick={() => onChange && onChange(id)}>
              <span className="badge" style={{ color: s.badgeColor }}>{s.badge}</span>
              <span className="lbl">{s.label}</span>
            </div>
          ))}
          <div style={{ flex: 1 }} />
          <div className="picker-foot">
            <div className="key">DiagramLoader.load(source:)</div>
            <div className="path">Sources/DiagramKitImport/DiagramLoader.swift</div>
          </div>
        </div>

        {/* Pipeline (centre) */}
        <div className="probe-pipeline">
          {/* Source string at top */}
          <div className="probe-source">
            <div className="probe-source-hd">
              <span className="badge" style={{ color: sample.badgeColor }}>{sample.badge}</span>
              <span>source: String</span>
              <span style={{ flex: 1 }} />
              <span className="meta">{sample.label}</span>
            </div>
            <pre className="probe-source-body">
              {sample.source.map((l, i) => <span key={i} style={{ display: "block" }}>{l}</span>)}
            </pre>
          </div>

          <div className="probe-arrow" />

          {/* Probes */}
          <div className="probe-list">
            {PROBE_REGISTRY.map((p, i) => {
              const isWinner = i === winnerIdx;
              const isPast = i < winnerIdx; // skipped
              return (
                <div key={p.id} className={"probe-row" + (isWinner ? " win" : isPast ? " skip" : " future")}>
                  <span className="ord">#{i + 1}</span>
                  <span className="who">
                    <span className="nm">{p.id}.probe(source:)</span>
                    <span className="ft">{p.file}</span>
                  </span>
                  <span className="vrd">
                    {isWinner ? (
                      <><span className="ic ic-ok">✓</span> match</>
                    ) : isPast ? (
                      <><span className="ic ic-skip">·</span> skip</>
                    ) : (
                      <><span className="ic ic-mute">○</span> not reached</>
                    )}
                  </span>
                </div>
              );
            })}
          </div>

          <div className="probe-arrow" />

          {/* Result at bottom */}
          <div className="probe-result">
            <div className="probe-result-hd">
              <span className="kw">return</span>
              <span className="ret">DiagramImportResult</span>
              <span style={{ flex: 1 }} />
              <span className="meta">Sources/DiagramKitImport/DiagramImportResult.swift</span>
            </div>
            <div className="probe-result-body">
              <div className="r-row"><span className="k">document</span><span className="v">DiagramDocument · .flowchart</span></div>
              <div className="r-row"><span className="k">diagnostics</span><span className="v">[DiagramDiagnostic] · {sample.diagnostics}</span></div>
              <div className="r-row"><span className="k">resolved by</span><span className="v" style={{ color: "var(--accent)" }}>{sample.winner}</span></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Snippets library (artboard M)
// 9 snippet cards (one per family) with code preview + insert button.
// ─────────────────────────────────────────────────────────────
const SNIPPETS = [
  { id: "flow",   fam: "flowchart",    name: "Simple flowchart",       fmt: "mmd",  lines: [
      "flowchart LR",
      "  A[\"Start\"] --> B(\"Decide\")",
      "  B -->|yes| C[\"Apply\"]",
      "  B -->|no|  D[\"Skip\"]",
      "  C --> E[\"Done\"]",
      "  D --> E"] },
  { id: "seq",    fam: "sequence",     name: "Async API call",         fmt: "mmd",  lines: [
      "sequenceDiagram",
      "  Client->>Server: GET /diagrams",
      "  Server-->>Client: [Diagram] · 422",
      "  Note over Server: paged · 32/page",
      "  Client->>Server: GET /diagrams?cursor=…",
      "  Server-->>Client: continuation"] },
  { id: "class",  fam: "classDiagram", name: "Class with relations",   fmt: "mmd",  lines: [
      "classDiagram",
      "  class DiagramEditor {",
      "    +perform(_: DiagramMutation)",
      "    +canUndo: Bool",
      "  }",
      "  DiagramEditor --> DiagramDocument"] },
  { id: "state",  fam: "stateDiagram", name: "Three-state lifecycle",  fmt: "mmd",  lines: [
      "stateDiagram-v2",
      "  [*] --> idle",
      "  idle --> rendering : .perform",
      "  rendering --> idle : commit",
      "  rendering --> failed : throw",
      "  failed --> idle : recover"] },
  { id: "gantt",  fam: "gantt",        name: "Phases · today marker",  fmt: "mmd",  lines: [
      "gantt",
      "  title DiagramKit · roadmap",
      "  section Foundations",
      "  Parser :done, p1, 0w, 12w",
      "  Layouts :active, p2, 4w, 14w",
      "  section Renderers",
      "  SVG :svg, 18w, 14w"] },
  { id: "pie",    fam: "pie",          name: "Coverage breakdown",     fmt: "mmd",  lines: [
      "pie title Coverage · 28 families",
      "  \"Full\" : 5",
      "  \"Lossy\" : 4",
      "  \"Host (Mermaid)\" : 28",
      "  \"Unsupported\" : 105"] },
  { id: "mm",     fam: "mindmap",      name: "Mindmap with branches",  fmt: "mmd",  lines: [
      "mindmap",
      "  root((DiagramKit))",
      "    Importers",
      "      Mermaid · fallback",
      "      D2 · narrow",
      "    Exporters"] },
  { id: "c4",     fam: "c4",           name: "C4 context",             fmt: "mmd",  lines: [
      "C4Context",
      "  title DiagramKit · context",
      "  Person(user, \"Engineer\")",
      "  System(dk, \"DiagramKit\")",
      "  Rel(user, dk, \"renders\")"] },
  { id: "xy",     fam: "xyChart",      name: "Two-series xychart",     fmt: "mmd",  lines: [
      "xychart-beta",
      "  title \"Paint time · ms\"",
      "  x-axis [Q1, Q2, Q3, Q4]",
      "  y-axis \"ms\" 0 --> 20",
      "  bar  [6, 8, 11, 7]",
      "  line [4, 9, 12, 6]"] },
];

function SnippetsLibrary() {
  const [active, setActive] = React.useState("flow");
  return (
    <div className="snippets-stack">
      <div className="snippets-hd">
        <div style={{ display: "flex", flexDirection: "column", lineHeight: 1.2 }}>
          <span className="h1">Snippets library</span>
          <span className="sub">28 patterns · paste-ready · 9 shown · drag a card or use Insert at cursor</span>
        </div>
        <span style={{ flex: 1 }} />
        <div className="corpus-search" style={{ width: 260 }}>
          <Icon.Search />
          <input placeholder="Search · family · format" />
          <span className="kbd-hint">⌘K</span>
        </div>
      </div>
      <div className="snippets-grid">
        {SNIPPETS.map((s) => (
          <div key={s.id} className={"snippet-card" + (active === s.id ? " on" : "")} onClick={() => setActive(s.id)}>
            <div className="snippet-card-hd">
              <span className="famglyph">{(FAMILY_ICON_MAP && FAMILY_ICON_MAP[s.fam]) || "▢"}</span>
              <span className="snippet-name">{s.name}</span>
              <span style={{ flex: 1 }} />
              <span className="fmt">{s.fmt}</span>
            </div>
            <pre className="snippet-code">
              {s.lines.map((l, i) => <span key={i} style={{ display: "block" }}>{l}</span>)}
            </pre>
            <div className="snippet-card-ft">
              <span className="fam">{s.fam}</span>
              <span style={{ flex: 1 }} />
              <button className="ins-btn">Insert at cursor ↵</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// New Inspector cards — Edit theme · Platform · Mutations
// Rendered as `extras` after the existing theme grid.
// ─────────────────────────────────────────────────────────────

// Real theme tokens — extended from src_theme.swift's DiagramColors struct
// + AJ McClary semantic tokens (success/warning/error) and font slots.
const THEME_TOKENS = [
  { key: "bg",         label: "background",  hex: "#1C1C1E" },
  { key: "fg",         label: "foreground",  hex: "#FAFAFA" },
  { key: "surface",    label: "node-fill",   hex: "#2C2C2E" },
  { key: "border",     label: "node-stroke", hex: "#3A3A3C" },
  { key: "line",       label: "edge",        hex: "#6E6E73" },
  { key: "accent",     label: "accent",      hex: "#0A84FF" },
  { key: "muted",      label: "muted",       hex: "#8E8E93" },
  { key: "noteBkg",    label: "note-bkg",    hex: "#F5F0C8" },
  { key: "noteBorder", label: "note-border", hex: "#E0DEB5" },
  { key: "success",    label: "success",     hex: "#30D158", semantic: true },
  { key: "warning",    label: "warning",     hex: "#FF9F0A", semantic: true },
  { key: "error",      label: "error",       hex: "#FF453A", semantic: true },
];
const THEME_FONTS = [
  { key: "fontSans",  label: "font-sans",  val: "SF Pro Text" },
  { key: "fontMono",  label: "font-mono",  val: "SF Mono" },
];

function ThemeBuilderCard({ open, onToggle }) {
  return (
    <div className="insp-section">
      <div className="theme-builder-hd" onClick={() => onToggle && onToggle(!open)}>
        <span style={{ fontSize: 11, fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.4px", color: "var(--fg2)" }}>Edit theme</span>
        <span style={{ flex: 1 }} />
        <span className="cite-key" title="Sources/DiagramKitCommon/src_theme.swift · DiagramColors">DiagramColors</span>
        <span className="chev" style={{ transform: open ? "rotate(90deg)" : "rotate(0)" }}><Icon.Chevron /></span>
      </div>
      {open && (
        <div className="theme-builder">
          <div className="tb-grp">tokens</div>
          {THEME_TOKENS.map((t) => (
            <div key={t.key} className="tb-row">
              <span className="tb-key">{t.label}{t.semantic && <span className="tb-tag" title="AJ McClary semantic">sem</span>}</span>
              <span className="tb-sw" style={{ background: t.hex }} />
              <span className="tb-hex">{t.hex}</span>
              <span className="tb-reset" title="Reset to dark default">↺</span>
            </div>
          ))}
          <div className="tb-grp">fonts</div>
          {THEME_FONTS.map((f) => (
            <div key={f.key} className="tb-row">
              <span className="tb-key">{f.label}</span>
              <span style={{ flex: 1 }} />
              <span className="tb-val">{f.val}</span>
              <span className="tb-reset">↺</span>
            </div>
          ))}
          <div className="tb-ft">
            <span className="tb-name-key">name</span>
            <input className="tb-name" defaultValue="aj-dark · variant" />
            <button className="tb-save">Save as… <span className="kbd">⌘S</span></button>
          </div>
          <div className="tb-fiction">
            Writes <span className="mono">~/.diagramkit/themes/&lt;name&gt;.json</span> · design fiction — see <span className="mono">ThemeName.RawRepresentable</span>.
          </div>
        </div>
      )}
    </div>
  );
}

function PlatformRow({ family }) {
  // The three Linux-approximate families per BASELINES.md / Stage 2.5 work
  const approx = ["ishikawa", "treeView", "eventModeling"];
  const isApprox = family && approx.includes(family);
  return (
    <div className="kv-grid" style={{ marginTop: 2 }}>
      <span className="k">Linux support</span>
      <span className="v" style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
        {isApprox ? (
          <>
            <span className="linux-dot amber" />
            <span style={{ color: "var(--status-warning)" }}>⚠ approximate</span>
            <span style={{ color: "var(--fg3)", fontFamily: "var(--font-mono)", fontSize: 9.5 }}>char-count fallback</span>
          </>
        ) : (
          <>
            <span className="linux-dot green" />
            <span style={{ color: "var(--status-success)" }}>✓ full parity</span>
          </>
        )}
      </span>
      <span className="k" style={{ alignSelf: "start" }}>fallback file</span>
      <span className="v" style={{ fontSize: 10, lineHeight: 1.4 }}>
        Sources/DiagramKitCommon/<br/>src_text_metrics.swift
      </span>
    </div>
  );
}

// Real mutations enumerated from DiagramMutation.swift + DiagramEditor+Flowchart.swift
const MUTATIONS_CATALOG = [
  { group: "document", sig: ".setTitle(_:)", desc: "Replace the diagram's title or clear it.", state: 2, file: "DiagramMutation.swift" },
  { group: "node",     sig: ".setLabel(of: sel, to: label)", desc: "Rename a node's display label.", state: 2, file: "DiagramMutation.swift" },
  { group: "node",     sig: ".deleteElement(sel)", desc: "Delete element + incident edges (flow/state).", state: 4, file: "DiagramMutation.swift" },
  { group: "node",     sig: "FlowchartMutation.insertNode(id:label:type:)", desc: "Append a new node with shape alias.", state: 3, file: "DiagramEditor+Flowchart.swift" },
  { group: "edge",     sig: "FlowchartMutation.insertEdge(id:from:to:label:)", desc: "Add a directed edge between two existing selections.", state: 3, file: "DiagramEditor+Flowchart.swift" },
  { group: "edge",     sig: ".deleteElement(edge:sel)", desc: "Same .deleteElement case, routed via edge: prefix.", state: 4, file: "DiagramMutation.swift" },
  { group: "subgraph", sig: ".groupIntoSubgraph(selections:title:)", desc: "Wrap N selections in a subgraph container. Design fiction — Phase 9 candidate.", state: 6, file: "PLAN.md · open", fiction: true },
  { group: "sentinel", sig: ".noop", desc: "Undo grouping boundary — no document change.", state: 0, file: "DiagramMutation.swift" },
];

function MutationsCatalogCard({ open, onToggle, onDemo, currentState }) {
  const groups = [...new Set(MUTATIONS_CATALOG.map((m) => m.group))];
  return (
    <div className="insp-section">
      <div className="theme-builder-hd" onClick={() => onToggle && onToggle(!open)}>
        <span style={{ fontSize: 11, fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.4px", color: "var(--fg2)" }}>Mutations</span>
        <span style={{ flex: 1 }} />
        <span className="cite-key" title="Sources/DiagramKitInteractive/DiagramMutation.swift">DiagramMutation</span>
        <span className="chev" style={{ transform: open ? "rotate(90deg)" : "rotate(0)" }}><Icon.Chevron /></span>
      </div>
      {open && (
        <div className="mut-catalog">
          {groups.map((g) => (
            <React.Fragment key={g}>
              <div className="mut-grp">{g}</div>
              {MUTATIONS_CATALOG.filter((m) => m.group === g).map((m, i) => (
                <div key={i} className={"mut-row" + (m.fiction ? " fiction" : "")}>
                  <div className="mut-sig">
                    {m.sig}
                    {m.fiction && <span className="mut-fic" title="design fiction · not yet in repo">fic</span>}
                  </div>
                  <div className="mut-desc">{m.desc}</div>
                  <div className="mut-ft">
                    <span className="mut-file">{m.file}</span>
                    <span style={{ flex: 1 }} />
                    <button
                      className={"mut-demo" + (currentState === m.state ? " on" : "")}
                      onClick={(e) => { e.stopPropagation(); onDemo && onDemo(m.state); }}
                    >demo →</button>
                  </div>
                </div>
              ))}
            </React.Fragment>
          ))}
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Subgraph diff-hover preview (state 6)
// ─────────────────────────────────────────────────────────────
function SubgraphDiffHover() {
  return (
    <div className="diff-hover" style={{ left: 90, top: 488, width: 340 }}>
      <div className="diff-hd">
        <Icon.Visual /> Source diff · subgraph commit
        <span style={{ flex: 1 }} />
        <span style={{ color: "var(--fg3)", fontFamily: "var(--font-mono)", fontSize: 10 }}>perform(.groupIntoSubgraph)</span>
      </div>
      <div><span className="diff-add">+ subgraph renderers</span></div>
      <div><span className="diff-add">+   I["renderImage"]</span></div>
      <div><span className="diff-add">+   S["renderSVG"]</span></div>
      <div><span className="diff-add">+   A["renderASCII"]</span></div>
      <div><span className="diff-add">+ end</span></div>
      <div className="diff-ctx" style={{ marginTop: 6, fontSize: 10, fontFamily: "var(--font-sans)" }}>
        Wraps 3 selections · re-exported on commit · paired ✓ with no diagnostics.
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Subgraph commit toast (state 6)
// ─────────────────────────────────────────────────────────────
function SubgraphCommitToast() {
  return (
    <div className="commit-toast">
      <span className="toast-ic">✓</span>
      <div className="toast-body">
        <div className="toast-ttl">Subgraph created · "renderers"</div>
        <div className="toast-meta">DiagramEditor.perform(.groupIntoSubgraph) · 3 elements wrapped</div>
      </div>
      <span className="toast-kbd">⌘Z</span>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Sidebar Snippets row helper (rendered in shell.jsx)
// ─────────────────────────────────────────────────────────────
function SnippetsSidebarRow({ active, onOpen }) {
  return (
    <div className={"lib-row" + (active ? " active" : "")} onClick={onOpen}>
      <span className="ic"><Icon.Doc /></span>Snippets
      <span className="count">28</span>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Subgraph container SVG overlay — drawn into FlowchartEditCanvas
// when state === 5 or 6. Returns SVG <g> ready to drop into the
// parent <svg>.
// ─────────────────────────────────────────────────────────────
function SubgraphOverlaySVG({ state }) {
  if (state !== 5 && state !== 6) return null;
  // Bounding box for I (32,332,170,64), S (232,332,170,64), A (432,332,170,64)
  const pad = 10;
  const x = 32 - pad;
  const y = 332 - pad - 12;
  const w = (432 + 170) - 32 + pad * 2;
  const h = 64 + pad * 2 + 12;

  if (state === 5) {
    // Marquee rectangle — accent dashed
    return (
      <g>
        <rect x={x} y={y} width={w} height={h} rx="10"
              fill="var(--accent-10)" stroke="var(--accent)" strokeWidth="1.2"
              strokeDasharray="4 3" />
      </g>
    );
  }
  // state 6 — committed subgraph with title
  return (
    <g>
      <rect x={x} y={y + 14} width={w} height={h - 14} rx="12"
            fill="rgba(94,92,230,0.05)" stroke="rgba(94,92,230,0.6)" strokeWidth="1.2"
            strokeDasharray="6 4" />
      <rect x={x + 12} y={y + 6} width="92" height="20" rx="4"
            fill="rgba(94,92,230,0.18)" stroke="rgba(94,92,230,0.5)" />
      <text x={x + 18} y={y + 19} fill="#A8A6FF"
            fontFamily="var(--font-mono)" fontSize="11" fontWeight="600">
        subgraph: renderers
      </text>
    </g>
  );
}

Object.assign(window, {
  RenderHealthPill,
  RenderFailedSheet,
  ThreeFormatView,
  ImporterRegistryProbeView,
  PROBE_SAMPLES,
  SnippetsLibrary,
  ThemeBuilderCard,
  PlatformRow,
  MutationsCatalogCard,
  SubgraphDiffHover,
  SubgraphCommitToast,
  SubgraphOverlaySVG,
  SnippetsSidebarRow,
});
