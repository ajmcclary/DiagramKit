// surfaces.jsx — Secondary screens (Convert, Coverage, Diagnostics, Export, Corpus)
//
// Source citations:
//   Convert sheet         → Sources/DiagramKitTestSupport/RoundTripHarness.swift
//                           Sources/DiagramKitTestSupport/RoundTripLoss.swift
//                           Sources/DiagramKitExport/DiagramExportResult.swift
//   Coverage matrix       → Sources/DiagramKit{Mermaid,D2,Graphviz,Structurizr,PlantUML}/
//                           cells driven by .featureDropped(.diagramFamilyUnsupported)
//   Diagnostics drawer    → Sources/DiagramKitCommon/DiagramDiagnostic.swift + DiagnosticCategory.swift
//                           Sources/DiagramKitImport/DiagramImportResult.swift (parse-tier)
//                           Sources/DiagramKitModel/.../PositionedGraph.swift (layout-tier)
//   Export sheet          → Sources/DiagramKitExport/DiagramExporter + ExporterRegistry
//                           Round-trip toggle → RoundTripHarness.runSameFormatRoundTrip
//   Corpus browser        → Examples/DiagramPlayground/Resources/test-diagrams.json
//                           Tests/DiagramKitTests/__Snapshots__/

// ─────────────────────────────────────────────────────────────
// 28 diagram families (registry order, from DiagramRegistry+Family.swift)
// ─────────────────────────────────────────────────────────────
const FAMILIES_28 = [
  { id: "flowchart",     gl: "⌬", entries: 36 },
  { id: "sequence",      gl: "⇄", entries: 28 },
  { id: "classDiagram",  gl: "▩", entries: 24 },
  { id: "erDiagram",     gl: "▢", entries: 18 },
  { id: "stateDiagram",  gl: "◉", entries: 16 },
  { id: "gantt",         gl: "▤", entries: 14 },
  { id: "pie",           gl: "◐", entries: 9 },
  { id: "journey",       gl: "↝", entries: 7 },
  { id: "gitGraph",      gl: "⌥", entries: 12 },
  { id: "mindmap",       gl: "✦", entries: 11 },
  { id: "timeline",      gl: "⌗", entries: 10 },
  { id: "sankey",        gl: "≋", entries: 6 },
  { id: "xyChart",       gl: "⊟", entries: 9 },
  { id: "quadrantChart", gl: "⊞", entries: 8 },
  { id: "requirement",   gl: "❑", entries: 5 },
  { id: "block",         gl: "▦", entries: 12 },
  { id: "packet",        gl: "▢", entries: 4 },
  { id: "kanban",        gl: "☷", entries: 6 },
  { id: "architecture",  gl: "▥", entries: 7 },
  { id: "c4",            gl: "▣", entries: 14 },
  { id: "radar",         gl: "◈", entries: 5 },
  { id: "treemap",       gl: "◰", entries: 6 },
  { id: "venn",          gl: "◎", entries: 4 },
  { id: "ishikawa",      gl: "⌖", entries: 5 },
  { id: "treeView",      gl: "⊳", entries: 6 },
  { id: "eventModeling", gl: "▭", entries: 5 },
  { id: "wardley",       gl: "⊿", entries: 4 },
  { id: "zenuml",        gl: "⌘", entries: 4 },
];
// Counts sum to ~313 (placeholder per-family split — actual JSON corpus has 422 entries total).

// Coverage matrix. ok / lossy / unsupported / partial / host
// Format columns: mermaid, d2, graphviz (DOT), structurizr, plantuml
// Sourced from DiagramKitMermaid (full), DiagramKitD2 (flowchart only), DiagramKitGraphviz
// (DOTExporter — flowchart only, others .unsupported), DiagramKitStructurizr, DiagramKitPlantUML
// (sequence + class + state/activity + mindmap + gantt + C4).
const COVERAGE = {
  flowchart:     ["host", "ok",         "ok",          "lossy",      "unsupported"],
  sequence:      ["host", "unsupported","unsupported", "unsupported","ok"],
  classDiagram:  ["host", "unsupported","unsupported", "unsupported","ok"],
  erDiagram:     ["host", "unsupported","unsupported", "lossy",      "unsupported"],
  stateDiagram:  ["host", "unsupported","unsupported", "unsupported","ok"],
  gantt:         ["host", "unsupported","unsupported", "unsupported","ok"],
  pie:           ["host", "unsupported","unsupported", "unsupported","unsupported"],
  journey:       ["host", "unsupported","unsupported", "unsupported","unsupported"],
  gitGraph:      ["host", "unsupported","unsupported", "unsupported","unsupported"],
  mindmap:       ["host", "unsupported","unsupported", "unsupported","ok"],
  timeline:      ["host", "unsupported","unsupported", "unsupported","unsupported"],
  sankey:        ["host", "unsupported","unsupported", "unsupported","unsupported"],
  xyChart:       ["host", "unsupported","unsupported", "unsupported","unsupported"],
  quadrantChart: ["host", "unsupported","unsupported", "unsupported","unsupported"],
  requirement:   ["host", "unsupported","unsupported", "unsupported","unsupported"],
  block:         ["host", "lossy",      "unsupported", "unsupported","unsupported"],
  packet:        ["host", "unsupported","unsupported", "unsupported","unsupported"],
  kanban:        ["host", "unsupported","unsupported", "unsupported","unsupported"],
  architecture:  ["host", "lossy",      "unsupported", "lossy",      "unsupported"],
  c4:            ["host", "unsupported","unsupported", "lossy",      "ok"],
  radar:         ["host", "unsupported","unsupported", "unsupported","unsupported"],
  treemap:       ["host", "unsupported","unsupported", "unsupported","unsupported"],
  venn:          ["host", "unsupported","unsupported", "unsupported","unsupported"],
  ishikawa:      ["host", "unsupported","unsupported", "unsupported","unsupported"],
  treeView:      ["host", "unsupported","unsupported", "unsupported","unsupported"],
  eventModeling: ["host", "unsupported","unsupported", "unsupported","unsupported"],
  wardley:       ["host", "unsupported","unsupported", "unsupported","unsupported"],
  zenuml:        ["host", "unsupported","unsupported", "unsupported","unsupported"],
};
const FORMAT_COLS = [
  { id: "mermaid",     l: "Mermaid",     sub: "host" },
  { id: "d2",          l: "D2",          sub: "DiagramKitD2" },
  { id: "graphviz",    l: "DOT",         sub: "DiagramKitGraphviz" },
  { id: "structurizr", l: "Structurizr", sub: "DiagramKitStructurizr" },
  { id: "plantuml",    l: "PlantUML",    sub: "DiagramKitPlantUML" },
];

// ─────────────────────────────────────────────────────────────
// Convert sheet (modal overlay)
// ─────────────────────────────────────────────────────────────
function ConvertSheet({ sourceFmt, targetFmt }) {
  // Use placeholder Mermaid (flowchart) → D2 export.
  // The "right" pane shows D2 source after parse → export. Adds/removes
  // tagged with green/red gutters. Losses listed underneath.
  const leftLines = [
    { l: "%% DiagramKit pipeline — Mermaid", k: "rm" },
    { l: "flowchart LR", k: "ctx" },
    { l: "  Source[\"Source\"] --> P(\"MermaidParser.parse\")", k: "ctx" },
    { l: "  P --> D[\"DiagramDocument\"]", k: "ctx" },
    { l: "  D --> L(\"GraphLayout\")", k: "ctx" },
    { l: "  L --> G((\"PositionedGraph\"))", k: "ctx" },
    { l: "", k: "ctx" },
    { l: "  G -->|renderImage| I[\"BMImage\"]", k: "ctx" },
    { l: "  G -->|renderSVG| S[\"SVG String\"]", k: "ctx" },
    { l: "  G -->|renderASCII| A[\"positioned\"]", k: "ctx" },
    { l: "  G --> V[\"DiagramView\"]", k: "rm" },
    { l: "", k: "ctx" },
    { l: "  classDef ok fill:#30D158,stroke:#30D158,color:#fff", k: "rm" },
    { l: "  class I,S,A,V ok", k: "rm" },
  ];
  const rightLines = [
    { l: "# DiagramKit pipeline — D2", k: "ad" },
    { l: "direction: right", k: "ad" },
    { l: "Source -> P: ", k: "ad" },
    { l: "Source.label: Source", k: "ad" },
    { l: "P.label: MermaidParser.parse", k: "ad" },
    { l: "P -> D", k: "ad" },
    { l: "D.label: DiagramDocument", k: "ad" },
    { l: "D -> L; L.label: GraphLayout", k: "ad" },
    { l: "L -> G; G.label: PositionedGraph; G.shape: oval", k: "ad" },
    { l: "G -> I: renderImage", k: "ad" },
    { l: "G -> S: renderSVG", k: "ad" },
    { l: "G -> A: renderASCII   # idSanitization: positioned → positioned", k: "ch" },
    { l: "  # classDef ok dropped (.styleDrop)", k: "ch" },
  ];

  const losses = [
    {
      cat: ".lossyTransform · .styleDrop",
      msg: 'classDef "ok" + class I,S,A,V — D2 has no classDef analogue',
      src: "Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidFlowchartExport.swift",
    },
    {
      cat: ".lossyTransform · .styleDrop",
      msg: 'styleDrop(target: "V", attribute: "class")',
      src: "Sources/DiagramKitTestSupport/RoundTripLoss.swift · .styleDrop",
    },
    {
      cat: ".info · .commentPreserved",
      msg: 'Comment "%% DiagramKit pipeline — Mermaid" preserved as # in D2',
      src: "Sources/DiagramKitCommon/DiagnosticCategory.swift",
    },
  ];

  return (
    <>
      <div className="sheet-backdrop" />
      <div className="sheet" style={{ left: 60, right: 60, top: 78, bottom: 96 }}>
        <div className="sheet-head">
          <span className="title">Convert · {sourceFmt || "mermaid"} → {targetFmt || "d2"}</span>
          <span className="sub">RoundTripHarness · parse → export → parse → diff</span>
          <span className="grow" />
          <KPill tone="accent" dot>structurally equal · 2 typed losses</KPill>
          <button className="x"><Icon.Close /></button>
        </div>
        <div className="sheet-body">
          {/* Target format picker */}
          <div className="convert-fmt-row">
            <span style={{ fontSize: 10.5, color: "var(--fg3)", textTransform: "uppercase", letterSpacing: "0.4px", marginRight: 4 }}>Convert to</span>
            <div className="convert-fmt-pick">
              {FORMAT_COLS.map((f) => (
                <span key={f.id} className={"ch" + ((targetFmt || "d2") === f.id ? " on" : "")}>
                  <span className="dot" style={{ background: f.id === "mermaid" ? "#FF9F0A" : f.id === "d2" ? "#5E5CE6" : f.id === "graphviz" ? "#BF5AF2" : f.id === "structurizr" ? "#64D2FF" : "#FF375F" }} />
                  {f.l}
                </span>
              ))}
            </div>
            <span className="grow" style={{ flex: 1 }} />
            <span style={{ fontSize: 10.5, color: "var(--fg3)" }}>
              <span style={{ fontFamily: "var(--font-mono)" }}>DiagramExportResult.source</span> · <span style={{ fontFamily: "var(--font-mono)" }}>diagnostics</span>
            </span>
          </div>

          {/* Diff */}
          <div className="convert-diff">
            <div className="convert-pane">
              <div className="convert-pane-head">
                <span className="fmt-pill">mermaid</span>
                <span style={{ fontSize: 12, color: "var(--fg1)", fontWeight: 500 }}>Pipeline.mmd</span>
                <span className="meta">14 lines · 612 B</span>
              </div>
              <div className="convert-pane-body">
                {leftLines.map((l, i) => (
                  <span key={i} className={"ln " + (l.k === "rm" ? "removed" : l.k === "ad" ? "added" : l.k === "ch" ? "changed" : "ln-gut")}>
                    {l.l || "\u200b"}
                  </span>
                ))}
              </div>
            </div>
            <div className="convert-pane">
              <div className="convert-pane-head">
                <span className="fmt-pill" style={{ color: "#8E8CFF" }}>d2</span>
                <span style={{ fontSize: 12, color: "var(--fg1)", fontWeight: 500 }}>Pipeline.d2</span>
                <span className="meta">13 lines · 528 B</span>
              </div>
              <div className="convert-pane-body">
                {rightLines.map((l, i) => (
                  <span key={i} className={"ln " + (l.k === "ad" ? "added" : l.k === "ch" ? "changed" : "ln-gut")}>
                    {l.l || "\u200b"}
                  </span>
                ))}
              </div>
            </div>
          </div>

          {/* Round-trip assertion */}
          <div className="rt-bar">
            <span className="ok">RoundTripHarness.runCrossFormatRoundTrip · parse(mmd) → export(d2) → parse(d2) → export(mmd) → parse — structurally equal</span>
            <span className="grow" />
            <span className="meta">8 unordered pairs · 16 ordered directions</span>
          </div>

          {/* Losses */}
          <div className="loss-list">
            <div className="hd">
              <span>RoundTripLoss · 2 typed entries · 1 informational</span>
              <span style={{ flex: 1 }} />
              <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--fg3)" }}>diagnosticsCover(loss:in:) · paired</span>
            </div>
            {losses.map((l, i) => (
              <div key={i} className="item">
                <span className="ic">▲</span>
                <div>
                  <div className="msg">{l.msg}</div>
                  <div className="cat">{l.cat}</div>
                  <div className="src">{l.src}</div>
                </div>
                <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--fg3)", paddingTop: 2 }}>go →</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
}

// ─────────────────────────────────────────────────────────────
// Coverage matrix — 28 × 5
// ─────────────────────────────────────────────────────────────
function CoverageMatrix({ hover, setHover }) {
  const cellIco = {
    ok: "✓",
    lossy: "⚠",
    unsupported: "✕",
    partial: "◑",
    host: "★",
  };
  return (
    <div className="coverage-stack" style={{ flex: 1, height: "100%" }}>
      <div className="coverage-head">
        <div style={{ display: "flex", flexDirection: "column", lineHeight: 1.2 }}>
          <span className="h1">Exporter coverage · 28 families × 5 formats</span>
          <span className="sub">Cells sourced from each <span style={{ color: "var(--fg2)" }}>DiagramExporter</span>'s <span style={{ color: "var(--status-warning)" }}>.featureDropped(.diagramFamilyUnsupported)</span> diagnostics</span>
        </div>
        <div style={{ flex: 1 }} />
        <KPill tone="ok" dot>{Object.values(COVERAGE).flat().filter((c) => c === "ok").length} fully covered</KPill>
        <KPill tone="warn" dot>{Object.values(COVERAGE).flat().filter((c) => c === "lossy").length} lossy</KPill>
        <KPill dot>{Object.values(COVERAGE).flat().filter((c) => c === "unsupported").length} unsupported</KPill>
      </div>

      <div className="coverage-grid-wrap">
        <div className="coverage-grid" style={{ position: "relative" }}>
          <div className="h-cell fmly">Family</div>
          {FORMAT_COLS.map((f) => (
            <div key={f.id} className="h-cell">{f.l}<span className="fmt-sub">{f.sub}</span></div>
          ))}
          {FAMILIES_28.map((fam) => (
            <React.Fragment key={fam.id}>
              <div className="fam-cell">
                <span className="gl">{fam.gl}</span>
                <span>{fam.id}</span>
                <span className="num">{fam.entries}</span>
              </div>
              {COVERAGE[fam.id].map((state, ci) => (
                <div key={ci}
                     className={"cell " + state}
                     onMouseEnter={() => setHover({ family: fam.id, fmt: FORMAT_COLS[ci].id, state, ci, ri: FAMILIES_28.indexOf(fam) })}
                     onMouseLeave={() => setHover(null)}>
                  <span className="ico">{cellIco[state]}</span>
                </div>
              ))}
            </React.Fragment>
          ))}
          {hover && <CoverageTip h={hover} />}
        </div>
      </div>

      <div className="coverage-legend">
        <span className="swatch host"><span className="ico">★</span><span>host format</span></span>
        <span className="swatch ok"><span className="ico">✓</span><span>full coverage</span></span>
        <span className="swatch lossy"><span className="ico">⚠</span><span><span style={{ fontFamily: "var(--font-mono)" }}>.lossyTransform</span> — emits one or more allow-listed losses</span></span>
        <span className="swatch unsupported"><span className="ico">✕</span><span><span style={{ fontFamily: "var(--font-mono)" }}>.featureDropped(.diagramFamilyUnsupported)</span></span></span>
        <span style={{ marginLeft: "auto", color: "var(--fg3)", fontFamily: "var(--font-mono)", fontSize: 11 }}>
          Source · per-exporter <span style={{ color: "var(--fg2)" }}>DiagramExportResult.diagnostics</span>
        </span>
      </div>
    </div>
  );
}

function CoverageTip({ h }) {
  const fam = FAMILIES_28.find((f) => f.id === h.family);
  const fmt = FORMAT_COLS.find((f) => f.id === h.fmt);
  const blurbs = {
    host: { ttl: "Host format", body: "Mermaid is the canonical source. All 28 families parse natively.", cat: ".informational · commentPreserved" },
    ok: { ttl: "Full coverage", body: "Exporter emits a structurally-equivalent target. Round-trip clean.", cat: ".info · no losses" },
    lossy: { ttl: "Lossy export", body: "Round-trip emits an allow-listed RoundTripLoss. Paired diagnostic on DiagramExportResult.", cat: ".lossyTransform · paired" },
    unsupported: { ttl: "Unsupported family", body: "Exporter returns empty source + .featureDropped diagnostic. Import returns nil document.", cat: ".unsupported · .diagramFamilyUnsupported" },
  };
  const b = blurbs[h.state];
  // place tooltip near the cell
  const top = 56 + h.ri * 32 + 30;
  const left = 220 + h.ci * 164 + 80;
  return (
    <div className="cov-tip" style={{ top, left }}>
      <div className="ttl">{b.ttl}<br /><span className="fam">{fam.id} → {fmt.l}</span></div>
      <div style={{ fontSize: 10.5, color: "var(--fg2)", marginTop: 4 }}>{b.body}</div>
      <div className={"cat-row" + (h.state === "host" ? " info" : "")}>{b.cat}</div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Diagnostics drawer (expanded — bottom-of-window)
// ─────────────────────────────────────────────────────────────
const DIAGNOSTIC_CATS = [
  { sec: ".warning — lossyTransform", cats: [
    { id: "idSanitization",         ct: 3 },
    { id: "shapeDowngrade",         ct: 2 },
    { id: "subgraphFlatten",        ct: 1 },
    { id: "boundaryFlatten",        ct: 0 },
    { id: "c4SlotDrop",             ct: 1 },
    { id: "titleDrop",              ct: 0 },
    { id: "configDrop",             ct: 1 },
    { id: "styleDrop",              ct: 4 },
    { id: "accessibilityDrop",      ct: 0 },
    { id: "anonymousSubgraphRename",ct: 0 },
    { id: "d2DuplicateOverride",    ct: 0 },
    { id: "labelNewlineEscape",     ct: 0 },
    { id: "d2InlineCommentStripped",ct: 1 },
  ]},
  { sec: ".unsupported — featureDropped", cats: [
    { id: "diagramFamilyUnsupported", ct: 2 },
    { id: "slotUnsupported",          ct: 1 },
    { id: "boundaryTypeUnsupported",  ct: 0 },
    { id: "c4ShapeUnsupported",       ct: 0 },
  ]},
  { sec: ".info — informational", cats: [
    { id: "identifierEscape",  ct: 2 },
    { id: "commentPreserved",  ct: 6 },
  ]},
];

const DIAGNOSTICS_BAG = [
  { sev: "warn",  code: "DK1208", cat: "labelNewlineEscape", msg: 'Label "positioned" is wider than node — wrapping at render time.', src: "Pipeline.mmd:12", tier: "layout", phase: "PositionedGraph.diagnostics" },
  { sev: "warn",  code: "DK0701", cat: "styleDrop",          msg: 'classDef "ok" + class I,S,A,V — D2 has no classDef analogue.', src: "Pipeline.mmd:15-16", tier: "export", phase: "DiagramExportResult.diagnostics" },
  { sev: "warn",  code: "DK0701", cat: "styleDrop",          msg: 'styleDrop(target: "V", attribute: "class") — DOT exporter doesn\'t round-trip classes.', src: "Pipeline.mmd:16", tier: "export" },
  { sev: "warn",  code: "DK1101", cat: "idSanitization",     msg: 'idSanitization(original: "render-image", sanitized: "render_image") for DOT target.', src: "Pipeline.mmd:8", tier: "export" },
  { sev: "warn",  code: "DK1101", cat: "idSanitization",     msg: 'idSanitization(original: "render-svg",  sanitized: "render_svg") for DOT target.', src: "Pipeline.mmd:9", tier: "export" },
  { sev: "warn",  code: "DK1101", cat: "idSanitization",     msg: 'idSanitization(original: "Diagram View", sanitized: "DiagramView") for D2 target.', src: "Pipeline.mmd:11", tier: "export" },
  { sev: "warn",  code: "DK1404", cat: "shapeDowngrade",     msg: "shapeDowngrade(nodeID: \"G\", from: .circle, to: .stadium) — D2 has no perfect circle.", src: "Pipeline.mmd:6", tier: "export" },
  { sev: "warn",  code: "DK1404", cat: "shapeDowngrade",     msg: "shapeDowngrade(nodeID: \"P\", from: .stadium, to: .rectangle) — DOT minor.", src: "Pipeline.mmd:5", tier: "export" },
  { sev: "warn",  code: "DK0904", cat: "subgraphFlatten",    msg: "subgraphFlatten(subgraphID: \"pipeline\", depth: 2) — Structurizr container nesting.", src: "Pipeline.mmd:4", tier: "export" },
  { sev: "warn",  code: "DK0512", cat: "c4SlotDrop",         msg: "c4SlotDrop(shapeID: \"BridgeMac\", slot: .technology) — PlantUML C4 has no `technology` slot.", src: "Bridge.mmd:24", tier: "export" },
  { sev: "warn",  code: "DK0814", cat: "configDrop",         msg: "configDrop(key: \"flowchart.curve\") — D2 ignores Mermaid init directives.", src: "Pipeline.mmd:1", tier: "export" },
  { sev: "warn",  code: "DK0815", cat: "d2InlineCommentStripped", msg: 'D2 inline comment `# pipeline` stripped on re-import.', src: "Pipeline.mmd:7", tier: "import" },
  { sev: "unsup", code: "DK2001", cat: "diagramFamilyUnsupported", msg: "PlantUML target has no journey-family exporter.", src: "Roadmap.mmd:1", tier: "export" },
  { sev: "unsup", code: "DK2001", cat: "diagramFamilyUnsupported", msg: "DOT exporter doesn't yet emit gantt — open in PLAN.md Phase 2.", src: "Phases.mmd:1", tier: "export" },
  { sev: "unsup", code: "DK2004", cat: "slotUnsupported",        msg: "Structurizr container has no `tags` slot in classDiagram round-trip.", src: "Reducers.mmd:14", tier: "export" },
  { sev: "info",  code: "DK0210", cat: "commentPreserved",       msg: '"%% DiagramKit pipeline — Mermaid" → "# DiagramKit pipeline — D2".', src: "Pipeline.mmd:1", tier: "export" },
  { sev: "info",  code: "DK0210", cat: "commentPreserved",       msg: "Block comments survive round-trip via .info chip.", src: "Pipeline.mmd:7", tier: "export" },
  { sev: "info",  code: "DK0303", cat: "identifierEscape",       msg: 'Identifier "Bridge.Mac" escaped to "Bridge\\u002EMac" in DOT target.', src: "Bridge.mmd:8", tier: "export" },
];

function DiagnosticsDrawer({ open, severityFilter, setSeverity, catFilter, setCat, onClose }) {
  if (!open) return null;
  const matches = DIAGNOSTICS_BAG.filter((d) => {
    if (severityFilter && severityFilter !== "all" && d.sev !== severityFilter) return false;
    if (catFilter && d.cat !== catFilter) return false;
    return true;
  });
  const total = DIAGNOSTICS_BAG.length;
  const warnCt = DIAGNOSTICS_BAG.filter((d) => d.sev === "warn").length;
  const unsupCt = DIAGNOSTICS_BAG.filter((d) => d.sev === "unsup").length;
  const infoCt = DIAGNOSTICS_BAG.filter((d) => d.sev === "info").length;

  return (
    <div className="diag-drawer">
      <div className="diag-drawer-head">
        <span className="ttl">Diagnostics</span>
        <span className="cnt">{matches.length} of {total}</span>
        <span style={{ fontFamily: "var(--font-mono)", fontSize: 10.5, color: "var(--fg3)" }}>
          parse-tier · DiagramImportResult.diagnostics + layout-tier · PositionedGraph.diagnostics
        </span>
        <span className="grow" />
        <button className="x" onClick={onClose}><Icon.Close /></button>
      </div>

      <div className="diag-filters">
        <span className="label">Severity</span>
        <span className={"ch" + (severityFilter === "all" ? " on" : "")} onClick={() => setSeverity && setSeverity("all")}>all <span className="ct">{total}</span></span>
        <span className={"ch warn" + (severityFilter === "warn" ? " on" : "")} onClick={() => setSeverity && setSeverity("warn")}>▲ .warning <span className="ct">{warnCt}</span></span>
        <span className={"ch unsup" + (severityFilter === "unsup" ? " on" : "")} onClick={() => setSeverity && setSeverity("unsup")}>✕ .unsupported <span className="ct">{unsupCt}</span></span>
        <span className={"ch info" + (severityFilter === "info" ? " on" : "")} onClick={() => setSeverity && setSeverity("info")}>● .info <span className="ct">{infoCt}</span></span>
        <span className="div" />
        <span className="label">Tier</span>
        <span className="ch">parse</span>
        <span className="ch on">layout</span>
        <span className="ch">export</span>
        <span className="div" />
        <span className="label">Pairing</span>
        <span className="ch">all</span>
        <span className="ch on">paired ✓</span>
        <span className="ch">unpaired ▲</span>
      </div>

      <div className="diag-drawer-body">
        <div className="diag-cat">
          {DIAGNOSTIC_CATS.map((sec) => (
            <React.Fragment key={sec.sec}>
              <div className="csec">{sec.sec}</div>
              {sec.cats.map((c) => (
                <div key={c.id}
                     className={"crow" + (catFilter === c.id ? " on" : "")}
                     onClick={() => setCat && setCat(catFilter === c.id ? null : c.id)}>
                  .{c.id}
                  <span className="ct">{c.ct}</span>
                </div>
              ))}
            </React.Fragment>
          ))}
        </div>

        <div className="diag-table" style={{ position: "relative" }}>
          {matches.map((d, i) => (
            <div key={i} className={"row " + d.sev}>
              <span className="sev">{d.sev === "warn" ? "▲" : d.sev === "unsup" ? "✕" : "●"}</span>
              <div className="body">
                <span className="msg">{d.msg}</span>
                <span className="meta">
                  <span>{d.code}</span>
                  <span className="cat">.{d.cat}</span>
                  <span>{d.src}</span>
                  <span style={{ color: "var(--fg3)" }}>{d.phase || (d.tier === "import" ? "DiagramImportResult.diagnostics" : d.tier === "layout" ? "PositionedGraph.diagnostics" : "DiagramExportResult.diagnostics")}</span>
                </span>
              </div>
              <button className="jump">jump</button>
              <button className="expl">explain</button>
            </div>
          ))}
          {/* Floating explanation popover anchored to first matching DK1208 row */}
          {(severityFilter === "warn" || severityFilter === "all") && !catFilter && (
            <DiagnosticExplain top={6} />
          )}
        </div>
      </div>
    </div>
  );
}

function DiagnosticExplain({ top }) {
  return (
    <div className="diag-explain" style={{ top, right: 22 }}>
      <div className="ttl">
        DK1208 · labelNewlineEscape
        <span className="grow" style={{ flex: 1 }} />
        <span className="code">.lossyTransform</span>
      </div>
      <div style={{ fontSize: 11.5, color: "var(--fg2)" }}>
        Promoted from <code>.info</code> per <code>docs/diagnostic-severity-discipline.md §1</code>. A label
        wider than its node forces wrap at render time, which is a structural
        rather than encoding transform — escalates to <code>.warning</code>.
      </div>
      <p>
        Fix paths: rename the label, widen the node via <code>:::wide</code> class,
        or wrap explicitly with <code>&lt;br/&gt;</code> in the source.
      </p>
      <div className="src">
        Sources/DiagramKitCommon/DiagnosticCategory.swift — case .labelNewlineEscape
      </div>
      <div className="actions">
        <button className="fixbtn">Rename label</button>
        <button className="fixbtn alt">Widen node</button>
        <button className="fixbtn alt">Wrap with &lt;br/&gt;</button>
        <span className="grow" style={{ flex: 1 }} />
        <button className="fixbtn alt" style={{ background: "transparent" }}>open Sources/* →</button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Export sheet (full-bleed sheet over Visual mode)
// ─────────────────────────────────────────────────────────────
const EXPORT_TARGETS = [
  { id: "svg",  l: "SVG",       gr: "Render", ic: "&lt;/&gt;", meta: "renderSVG · String",       sz: "12.3 KB" },
  { id: "png1", l: "PNG @1x",   gr: "Render", ic: "PNG",   meta: "DiagramImageRenderer · BMImage", sz: "18.4 KB" },
  { id: "png2", l: "PNG @2x",   gr: "Render", ic: "PNG",   meta: "DiagramImageRenderer · @2x",     sz: "34.2 KB" },
  { id: "png3", l: "PNG @3x",   gr: "Render", ic: "PNG",   meta: "DiagramImageRenderer · @3x",     sz: "61.8 KB" },
  { id: "ascii",l: "ASCII",     gr: "Render", ic: "▦",     meta: "AsciiRenderOutput",              sz: "1.1 KB"  },
  { id: "mer",  l: "Mermaid",   gr: "Source", ic: "mmd",   meta: "DiagramKitMermaid · MermaidExporter", sz: "612 B" },
  { id: "d2",   l: "D2",        gr: "Source", ic: "d2",    meta: "DiagramKitD2 · D2Exporter",          sz: "528 B" },
  { id: "dot",  l: "DOT",       gr: "Source", ic: "dot",   meta: "DiagramKitGraphviz · DOTExporter",   sz: "490 B" },
  { id: "stz",  l: "Structurizr", gr: "Source", ic: "dsl", meta: "DiagramKitStructurizr · StructurizrExporter", sz: "—" },
  { id: "puml", l: "PlantUML",  gr: "Source", ic: "puml",  meta: "DiagramKitPlantUML · PlantUMLExporter", sz: "—" },
];

function ExportSheet({ target, setTarget, rtCheck, setRtCheck, onClose }) {
  const renderTargets = EXPORT_TARGETS.filter((t) => t.gr === "Render");
  const sourceTargets = EXPORT_TARGETS.filter((t) => t.gr === "Source");
  const sel = EXPORT_TARGETS.find((t) => t.id === target) || EXPORT_TARGETS[0];

  // Sample previews per target
  const previewByTarget = {
    svg: (
      <div className="preview-frame" style={{ padding: 18, margin: "0 auto", width: 720 }}>
        <FlowchartDiagram />
      </div>
    ),
    png1: <PngBackend DiagramComp={FlowchartDiagram} />,
    png2: <PngBackend DiagramComp={FlowchartDiagram} />,
    png3: <PngBackend DiagramComp={FlowchartDiagram} />,
    ascii: <pre className="ascii-view" style={{ margin: 0 }}>{ASCII_OUT.flowchart}</pre>,
    mer: <SourcePreview fmt="mermaid" lines={[
      "%% DiagramKit pipeline",
      "flowchart LR",
      "  Source --> P[\"MermaidParser.parse\"]",
      "  P --> D[\"DiagramDocument\"]",
      "  D --> L((\"GraphLayout\"))",
      "  L --> G((\"PositionedGraph\"))",
      "  G -->|renderImage|  I[\"BMImage\"]",
      "  G -->|renderSVG|    S[\"SVG String\"]",
      "  G -->|renderASCII|  A[\"positioned\"]",
      "  G --> V[\"DiagramView\"]",
    ]} />,
    d2: <SourcePreview fmt="d2" lines={[
      "# DiagramKit pipeline — D2",
      "direction: right",
      "Source -> P",
      "P.label: MermaidParser.parse",
      "D.label: DiagramDocument",
      "L.label: GraphLayout",
      "G.label: PositionedGraph; G.shape: oval",
      "G -> I: renderImage",
      "G -> S: renderSVG",
      "G -> A: renderASCII",
    ]} />,
    dot: <SourcePreview fmt="dot" lines={[
      "digraph DiagramKit {",
      "  rankdir = LR;",
      '  Source [label="Source"];',
      '  P [label="MermaidParser.parse"];',
      '  D [label="DiagramDocument"];',
      "  Source -> P -> D -> L -> G;",
      '  G -> I [label="renderImage"];',
      '  G -> S [label="renderSVG"];',
      '  G -> A [label="renderASCII"];',
      "}",
    ]} />,
    stz: <SourcePreview fmt="structurizr" lines={[
      "workspace { model {",
      "  diagramKit = softwareSystem \"DiagramKit\" {",
      "    parser = container \"MermaidParser\"",
      "    layout = container \"GraphLayout\"",
      "    parser -> layout \"DiagramDocument\"",
      "    layout -> renderers \"PositionedGraph\"",
      "  }",
      "} }",
    ]} />,
    puml: <SourcePreview fmt="plantuml" lines={[
      "@startuml",
      "package \"DiagramKit\" {",
      "  [Source] --> [MermaidParser]",
      "  [MermaidParser] --> [DiagramDocument]",
      "  [DiagramDocument] --> [GraphLayout]",
      "  [GraphLayout] --> [PositionedGraph]",
      "  [PositionedGraph] --> [renderSVG]",
      "}",
      "@enduml",
    ]} />,
  };

  const metaByTarget = {
    svg:  [["viewBox", "0 0 880 460"], ["size", "12.3 KB"], ["dimensions", "880 × 460 pt"], ["renderer", "renderSVG(_:options:)"]],
    png1: [["dimensions", "880 × 460 px"], ["scale", "1.0×"], ["size", "18.4 KB"], ["renderer", "DiagramImageRenderer"]],
    png2: [["dimensions", "1760 × 920 px"], ["scale", "2.0×"], ["size", "34.2 KB"], ["renderer", "DiagramImageRenderer"]],
    png3: [["dimensions", "2640 × 1380 px"], ["scale", "3.0×"], ["size", "61.8 KB"], ["renderer", "DiagramImageRenderer"]],
    ascii:[["cols", "80"], ["lines", "12"], ["size", "1.1 KB"], ["renderer", "AsciiRenderOutput"]],
    mer:  [["format", "mermaid"], ["lines", "14"], ["bytes", "612 B"], ["exporter", "MermaidExporter"]],
    d2:   [["format", "d2"], ["lines", "13"], ["bytes", "528 B"], ["exporter", "D2Exporter"]],
    dot:  [["format", "graphviz"], ["lines", "11"], ["bytes", "490 B"], ["exporter", "DOTExporter"]],
    stz:  [["format", "structurizr"], ["coverage", "container-only"], ["exporter", "StructurizrExporter"]],
    puml: [["format", "plantuml"], ["lines", "9"], ["exporter", "PlantUMLExporter"]],
  };

  const rtMessages = {
    svg: { ok: true, msg: "SVG export is rendering, not round-tripped." },
    png2: { ok: true, msg: "Image export is rendering, not round-tripped." },
    mer: { ok: true, msg: "parse → MermaidExporter.export → parse → equal · 0 losses" },
    d2: { ok: false, msg: "parse → D2Exporter.export → parse · 2 typed losses (.styleDrop · .shapeDowngrade) — paired ✓" },
    dot: { ok: false, msg: "parse → DOTExporter.export → parse · 3 typed losses (.idSanitization × 3) — paired ✓" },
    stz: { ok: false, msg: "Structurizr round-trip skipped — non-deterministic rendering per BASELINES.md." },
    puml: { ok: true, msg: "parse → PlantUMLExporter.export → parse · 0 losses" },
  };

  return (
    <>
      <div className="sheet-backdrop" />
      <div className="sheet" style={{ left: 60, right: 60, top: 78, bottom: 96 }}>
        <div className="sheet-head">
          <span className="title">Export · Pipeline.mmd</span>
          <span className="sub">DiagramExporter · ExporterRegistry</span>
          <span className="grow" />
          <KPill tone="accent" dot>5 render · 5 source targets</KPill>
          <button className="x" onClick={onClose}><Icon.Close /></button>
        </div>
        <div className="sheet-body">
          <div className="export-sheet">
            {/* Left aside: targets */}
            <div className="export-aside">
              <div className="grp-hd">Render</div>
              {renderTargets.map((t) => (
                <div key={t.id} className={"export-target" + (target === t.id ? " on" : "")} onClick={() => setTarget && setTarget(t.id)}>
                  <span className="ic" dangerouslySetInnerHTML={{ __html: t.ic }} />
                  <div style={{ display: "flex", flexDirection: "column" }}>
                    <span className="lbl">{t.l}</span>
                    <span className="meta">{t.meta}</span>
                  </div>
                  <span className="sz">{t.sz}</span>
                </div>
              ))}
              <div className="grp-hd">Source</div>
              {sourceTargets.map((t) => (
                <div key={t.id} className={"export-target" + (target === t.id ? " on" : "")} onClick={() => setTarget && setTarget(t.id)}>
                  <span className="ic">{t.ic}</span>
                  <div style={{ display: "flex", flexDirection: "column" }}>
                    <span className="lbl">{t.l}</span>
                    <span className="meta">{t.meta}</span>
                  </div>
                  <span className="sz">{t.sz}</span>
                </div>
              ))}
              <div style={{ flex: 1 }} />
            </div>

            {/* Right: preview + actions */}
            <div className="export-preview">
              <div className="export-preview-head">
                <span className="title">{sel.l}</span>
                <span style={{ fontFamily: "var(--font-mono)", fontSize: 10.5, color: "var(--fg3)" }}>{sel.meta}</span>
                <span className="grow" />
                <KPill tone="ok" dot>worker · 8 MB stack</KPill>
              </div>
              <div className="export-preview-body">
                {previewByTarget[target] || previewByTarget.svg}
                <div className="export-meta">
                  {(metaByTarget[target] || []).map(([k, v], i) => (
                    <React.Fragment key={i}>
                      <span className="k">{k}</span><span className="v">{v}</span>
                    </React.Fragment>
                  ))}
                </div>
              </div>
              <div className="export-action-bar">
                <div className="toggle-row">
                  <Toggle on={rtCheck} onClick={() => setRtCheck && setRtCheck(!rtCheck)} />
                  <span>Round-trip check</span>
                  {rtCheck && (
                    <span className={rtMessages[target]?.ok ? "ok" : "warn"} style={{ marginLeft: 8, fontFamily: "var(--font-mono)", fontSize: 10.5 }}>
                      {rtMessages[target]?.ok ? "● " : "▲ "}{rtMessages[target]?.msg}
                    </span>
                  )}
                </div>
                <span className="grow" />
                <button className="tb-btn"><Icon.Copy /> Copy</button>
                <button className="tb-btn"><Icon.Share /> Share…</button>
                <button className="tb-btn primary"><Icon.Play /> Save… <span className="kbd">⌘S</span></button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

function SourcePreview({ fmt, lines }) {
  return (
    <pre style={{
      margin: 0,
      background: "#161618",
      border: "0.5px solid var(--border-hairline)",
      borderRadius: 10,
      padding: "16px 20px",
      fontFamily: "var(--font-mono)",
      fontSize: 12,
      lineHeight: 1.6,
      color: "var(--fg1)",
      width: "100%",
      whiteSpace: "pre",
    }}>
      {lines.map((l, i) => <span key={i} style={{ display: "block" }}>{l}</span>)}
    </pre>
  );
}

// ─────────────────────────────────────────────────────────────
// Corpus browser
// ─────────────────────────────────────────────────────────────

// A small set of corpus thumbnails — actual snapshots live under
// Tests/DiagramKitTests/__Snapshots__/. We sketch each as a tiny SVG.
// linux: 'full' = parity, 'approximate' = char-count fallback (ishikawa/treeView/eventModeling), '—' = unmeasured.
const CORPUS_ITEMS = [
  { id: "flow-1-simple", title: "flow-1-simple", fam: "flowchart", badge: "mmd", diag: "clean", linux: "full" },
  { id: "flow-7-routing", title: "flow-7-routing", fam: "flowchart", badge: "mmd", diag: "clean", linux: "full" },
  { id: "flow-12-subgraphs", title: "flow-12-subgraphs", fam: "flowchart", badge: "mmd", diag: "warn", linux: "full" },
  { id: "seq-1-basic", title: "seq-1-basic", fam: "sequence", badge: "mmd", diag: "clean", linux: "full" },
  { id: "seq-4-loops", title: "seq-4-loops", fam: "sequence", badge: "mmd", diag: "clean", linux: "full" },
  { id: "seq-9-puml-mix", title: "seq-9-puml-mix", fam: "sequence", badge: "puml", diag: "warn", linux: "full" },
  { id: "class-1-basic", title: "class-1-basic", fam: "classDiagram", badge: "mmd", diag: "clean", linux: "full" },
  { id: "class-5-puml", title: "class-5-puml", fam: "classDiagram", badge: "puml", diag: "clean", linux: "full" },
  { id: "er-1-basic", title: "er-1-basic", fam: "erDiagram", badge: "mmd", diag: "clean", linux: "full" },
  { id: "er-3-multi-format", title: "er-3-multi-format", fam: "erDiagram", badge: "d2", diag: "warn", linux: "full" },
  { id: "state-1-basic", title: "state-1-basic", fam: "stateDiagram", badge: "mmd", diag: "clean", linux: "full" },
  { id: "gantt-1", title: "gantt-1", fam: "gantt", badge: "mmd", diag: "clean", linux: "full" },
  { id: "gantt-7", title: "gantt-7-today-marker", fam: "gantt", badge: "mmd", diag: "warn", linux: "full" },
  { id: "pie-1", title: "pie-1", fam: "pie", badge: "mmd", diag: "clean", linux: "full" },
  { id: "mindmap-3-puml", title: "mindmap-3-puml", fam: "mindmap", badge: "puml", diag: "clean", linux: "full" },
  { id: "c4-1-context", title: "c4-1-context", fam: "c4", badge: "mmd", diag: "clean", linux: "full" },
  { id: "c4-4-puml", title: "c4-4-puml", fam: "c4", badge: "puml", diag: "warn", linux: "full" },
  { id: "block-5-edges", title: "block-5-edges", fam: "block", badge: "mmd", diag: "warn", linux: "full" },
  { id: "block-7-architecture", title: "block-7-architecture", fam: "block", badge: "mmd", diag: "warn", linux: "full" },
  { id: "xychart-1-bar", title: "xychart-1-bar", fam: "xyChart", badge: "mmd", diag: "clean", linux: "full" },
  { id: "git-1-main-feature", title: "git-1-main-feature", fam: "gitGraph", badge: "mmd", diag: "clean", linux: "full" },
  { id: "sankey-1-bytes", title: "sankey-1-bytes", fam: "sankey", badge: "mmd", diag: "clean", linux: "full" },
  { id: "kanban-3-states", title: "kanban-3-states", fam: "kanban", badge: "mmd", diag: "warn", linux: "full" },
  { id: "arch-2-cloud", title: "arch-2-cloud", fam: "architecture", badge: "mmd", diag: "clean", linux: "full" },
  { id: "arch-4-d2", title: "arch-4-d2", fam: "architecture", badge: "d2", diag: "warn", linux: "full" },
  { id: "treemap-1-disk", title: "treemap-1-disk", fam: "treemap", badge: "mmd", diag: "clean", linux: "full" },
  { id: "venn-1-sets", title: "venn-1-sets", fam: "venn", badge: "mmd", diag: "clean", linux: "full" },
  { id: "timeline-1-roadmap", title: "timeline-1-roadmap", fam: "timeline", badge: "mmd", diag: "clean", linux: "full" },
  { id: "quad-1-priorities", title: "quad-1-priorities", fam: "quadrantChart", badge: "mmd", diag: "clean", linux: "full" },
  { id: "journey-1-onboarding", title: "journey-1-onboarding", fam: "journey", badge: "mmd", diag: "clean", linux: "full" },
  // The three families with approximate Linux text metrics (char-count fallback)
  { id: "ish-1-fish",            title: "ish-1-fishbone",            fam: "ishikawa",      badge: "mmd", diag: "warn", linux: "approx" },
  { id: "tree-2-folders",         title: "tree-2-folders",            fam: "treeView",      badge: "mmd", diag: "clean", linux: "approx" },
  { id: "event-1-checkout",       title: "event-1-checkout",          fam: "eventModeling", badge: "mmd", diag: "clean", linux: "approx" },
];

// Generate a tiny stylized thumbnail per family
function ThumbFor({ fam }) {
  if (fam === "flowchart") return <ThumbFlow />;
  if (fam === "sequence") return <ThumbSeq />;
  if (fam === "classDiagram") return <ThumbClass />;
  if (fam === "erDiagram") return <ThumbER />;
  if (fam === "stateDiagram") return <ThumbState />;
  if (fam === "gantt") return <ThumbGantt />;
  if (fam === "pie") return <ThumbPie />;
  if (fam === "mindmap") return <ThumbMindmap />;
  if (fam === "c4") return <ThumbC4 />;
  if (fam === "block") return <ThumbBlock />;
  if (fam === "xyChart") return <ThumbXY />;
  if (fam === "gitGraph") return <ThumbGit />;
  if (fam === "sankey") return <ThumbSankey />;
  if (fam === "kanban") return <ThumbKanban />;
  if (fam === "architecture") return <ThumbArch />;
  if (fam === "treemap") return <ThumbTreemap />;
  if (fam === "venn") return <ThumbVenn />;
  if (fam === "timeline") return <ThumbTimeline />;
  if (fam === "quadrantChart") return <ThumbQuad />;
  if (fam === "journey") return <ThumbJourney />;
  return <ThumbGeneric fam={fam} />;
}

const TH = { w: 200, h: 125, stroke: "rgba(255,255,255,0.32)", fill: "rgba(255,255,255,0.05)" };

function ThumbFlow() {
  return (
    <svg viewBox="0 0 200 125">
      <rect x="14" y="20" width="38" height="22" rx="3" fill={TH.fill} stroke={TH.stroke} />
      <rect x="76" y="20" width="48" height="22" rx="11" fill="rgba(10,132,255,0.10)" stroke="#0A84FF" />
      <rect x="148" y="20" width="38" height="22" rx="3" fill={TH.fill} stroke={TH.stroke} />
      <rect x="44" y="74" width="50" height="22" rx="3" fill={TH.fill} stroke={TH.stroke} />
      <rect x="106" y="74" width="50" height="22" rx="3" fill="rgba(48,209,88,0.12)" stroke="#30D158" />
      <line x1="52" y1="31" x2="76" y2="31" stroke={TH.stroke} strokeWidth="0.8" />
      <line x1="124" y1="31" x2="148" y2="31" stroke={TH.stroke} strokeWidth="0.8" />
      <path d="M100 42 L 69 74" stroke={TH.stroke} strokeWidth="0.8" fill="none" />
      <path d="M100 42 L 131 74" stroke={TH.stroke} strokeWidth="0.8" fill="none" />
    </svg>
  );
}
function ThumbSeq() {
  return (
    <svg viewBox="0 0 200 125">
      {[36, 84, 132, 176].map((x, i) => (
        <g key={i}>
          <rect x={x - 14} y="14" width="28" height="12" rx="2" fill={TH.fill} stroke={TH.stroke} />
          <line x1={x} y1="28" x2={x} y2="115" stroke={TH.stroke} strokeDasharray="2 2" strokeWidth="0.6" />
        </g>
      ))}
      <line x1="36" y1="44" x2="84" y2="44" stroke={TH.stroke} markerEnd="url(#dk-arrow)" />
      <line x1="84" y1="62" x2="132" y2="62" stroke={TH.stroke} markerEnd="url(#dk-arrow)" />
      <line x1="132" y1="80" x2="176" y2="80" stroke="#0A84FF" markerEnd="url(#dk-arrow-accent)" />
      <line x1="176" y1="98" x2="36" y2="98" stroke={TH.stroke} strokeDasharray="3 2" />
    </svg>
  );
}
function ThumbClass() {
  return (
    <svg viewBox="0 0 200 125">
      {[[18, 18], [110, 18], [62, 70]].map((p, i) => (
        <g key={i}>
          <rect x={p[0]} y={p[1]} width="72" height="34" rx="2" fill={TH.fill} stroke={TH.stroke} />
          <line x1={p[0]} y1={p[1] + 12} x2={p[0] + 72} y2={p[1] + 12} stroke={TH.stroke} strokeWidth="0.5" />
          <line x1={p[0]} y1={p[1] + 22} x2={p[0] + 72} y2={p[1] + 22} stroke={TH.stroke} strokeWidth="0.5" />
        </g>
      ))}
    </svg>
  );
}
function ThumbER() { return <ThumbGeneric fam="er" />; }
function ThumbState() {
  return (
    <svg viewBox="0 0 200 125">
      <circle cx="40" cy="62" r="22" fill={TH.fill} stroke={TH.stroke} />
      <circle cx="100" cy="36" r="22" fill="rgba(10,132,255,0.10)" stroke="#0A84FF" />
      <circle cx="100" cy="88" r="22" fill={TH.fill} stroke={TH.stroke} />
      <circle cx="160" cy="62" r="22" fill="rgba(48,209,88,0.12)" stroke="#30D158" />
      <path d="M62 60 L 80 40" stroke={TH.stroke} fill="none" />
      <path d="M122 38 L 140 58" stroke={TH.stroke} fill="none" />
      <path d="M62 64 L 80 86" stroke={TH.stroke} fill="none" />
      <path d="M122 86 L 140 66" stroke={TH.stroke} fill="none" />
    </svg>
  );
}
function ThumbGantt() {
  return (
    <svg viewBox="0 0 200 125">
      {[[14, 18, 60], [22, 36, 50], [40, 54, 80], [60, 72, 60], [56, 90, 100]].map((b, i) => (
        <g key={i}>
          <rect x="6" y={b[1] - 4} width="2" height="12" fill={TH.stroke} />
          <rect x={b[0]} y={b[1] - 4} width={b[2]} height="10" rx="2"
                fill={i === 2 ? "rgba(10,132,255,0.30)" : "rgba(48,209,88,0.25)"}
                stroke={i === 2 ? "#0A84FF" : "#30D158"} />
        </g>
      ))}
      <line x1="100" y1="6" x2="100" y2="118" stroke="#0A84FF" strokeDasharray="3 3" strokeOpacity="0.6" />
    </svg>
  );
}
function ThumbPie() {
  return (
    <svg viewBox="0 0 200 125">
      <g transform="translate(100,64)">
        <path d="M0 0 L 45 0 A 45 45 0 0 1 13.91 42.79 z" fill="#0A84FF" opacity="0.65" />
        <path d="M0 0 L 13.91 42.79 A 45 45 0 0 1 -36.41 26.46 z" fill="#30D158" opacity="0.65" />
        <path d="M0 0 L -36.41 26.46 A 45 45 0 0 1 -36.41 -26.46 z" fill="#FF9F0A" opacity="0.65" />
        <path d="M0 0 L -36.41 -26.46 A 45 45 0 0 1 45 0 z" fill="#BF5AF2" opacity="0.65" />
      </g>
    </svg>
  );
}
function ThumbMindmap() {
  return (
    <svg viewBox="0 0 200 125">
      <circle cx="100" cy="62" r="18" fill="rgba(10,132,255,0.15)" stroke="#0A84FF" />
      {[[34, 30], [34, 94], [166, 30], [166, 94]].map((p, i) => (
        <g key={i}>
          <path d={`M100 62 Q ${(100 + p[0]) / 2} ${p[1]}, ${p[0]} ${p[1]}`} stroke={TH.stroke} fill="none" strokeWidth="0.8" />
          <circle cx={p[0]} cy={p[1]} r="8" fill={TH.fill} stroke={TH.stroke} />
        </g>
      ))}
    </svg>
  );
}
function ThumbC4() {
  return (
    <svg viewBox="0 0 200 125">
      <rect x="14" y="14" width="172" height="98" rx="6" fill="none" stroke={TH.stroke} strokeDasharray="3 3" />
      <rect x="28" y="34" width="60" height="34" rx="3" fill={TH.fill} stroke={TH.stroke} />
      <rect x="116" y="34" width="60" height="34" rx="3" fill="rgba(10,132,255,0.15)" stroke="#0A84FF" />
      <rect x="76" y="76" width="48" height="22" rx="3" fill={TH.fill} stroke={TH.stroke} />
    </svg>
  );
}
function ThumbBlock() {
  return (
    <svg viewBox="0 0 200 125">
      {[[14, 14], [70, 14], [126, 14], [14, 50], [70, 50], [126, 50], [42, 86], [98, 86]].map((p, i) => (
        <rect key={i} x={p[0]} y={p[1]} width="48" height="28" rx="3" fill={i === 4 ? "rgba(10,132,255,0.10)" : TH.fill} stroke={i === 4 ? "#0A84FF" : TH.stroke} />
      ))}
    </svg>
  );
}
function ThumbXY() {
  return (
    <svg viewBox="0 0 200 125">
      <line x1="20" y1="100" x2="180" y2="100" stroke={TH.stroke} />
      <line x1="20" y1="20" x2="20" y2="100" stroke={TH.stroke} />
      <polyline points="30,80 60,50 90,68 120,30 150,42 170,22" stroke="#0A84FF" fill="none" strokeWidth="1.4" />
      <polyline points="30,90 60,76 90,80 120,60 150,68 170,50" stroke="#30D158" fill="none" strokeWidth="1.4" />
    </svg>
  );
}
function ThumbGit() {
  return (
    <svg viewBox="0 0 200 125">
      <line x1="20" y1="40" x2="180" y2="40" stroke="#0A84FF" />
      <line x1="60" y1="80" x2="160" y2="80" stroke="#FF9F0A" />
      {[40, 70, 100, 130, 160].map((x) => <circle key={x} cx={x} cy="40" r="5" fill="#0A84FF" />)}
      {[80, 110, 140].map((x) => <circle key={x} cx={x} cy="80" r="5" fill="#FF9F0A" />)}
      <line x1="70" y1="44" x2="80" y2="76" stroke={TH.stroke} />
      <line x1="140" y1="76" x2="160" y2="44" stroke={TH.stroke} />
    </svg>
  );
}
function ThumbSankey() {
  return (
    <svg viewBox="0 0 200 125">
      <path d="M 12 30 C 80 30, 110 80, 188 80 L 188 96 C 110 96, 80 46, 12 46 z" fill="rgba(10,132,255,0.20)" />
      <path d="M 12 60 C 80 60, 110 30, 188 30 L 188 50 C 110 50, 80 80, 12 80 z" fill="rgba(48,209,88,0.20)" />
      <rect x="12" y="20" width="4" height="80" fill={TH.stroke} />
      <rect x="184" y="20" width="4" height="80" fill={TH.stroke} />
    </svg>
  );
}
function ThumbKanban() {
  return (
    <svg viewBox="0 0 200 125">
      {[14, 70, 126].map((x, i) => (
        <g key={x}>
          <rect x={x} y="10" width="56" height="105" rx="4" fill="rgba(255,255,255,0.02)" stroke={TH.stroke} />
          {[22, 44, 66].map((y, j) => (
            <rect key={y} x={x + 6} y={y} width="44" height="14" rx="2"
                  fill={i === 1 && j === 0 ? "rgba(10,132,255,0.15)" : TH.fill}
                  stroke={i === 1 && j === 0 ? "#0A84FF" : TH.stroke} />
          ))}
        </g>
      ))}
    </svg>
  );
}
function ThumbArch() { return <ThumbBlock />; }
function ThumbTreemap() {
  return (
    <svg viewBox="0 0 200 125">
      <rect x="6" y="6" width="120" height="80" fill="rgba(10,132,255,0.20)" stroke={TH.stroke} />
      <rect x="6" y="92" width="60" height="28" fill="rgba(48,209,88,0.18)" stroke={TH.stroke} />
      <rect x="70" y="92" width="56" height="28" fill="rgba(255,159,10,0.18)" stroke={TH.stroke} />
      <rect x="130" y="6" width="64" height="50" fill="rgba(191,90,242,0.18)" stroke={TH.stroke} />
      <rect x="130" y="60" width="64" height="60" fill="rgba(255,255,255,0.04)" stroke={TH.stroke} />
    </svg>
  );
}
function ThumbVenn() {
  return (
    <svg viewBox="0 0 200 125">
      <circle cx="78" cy="62" r="38" fill="rgba(10,132,255,0.20)" stroke="#0A84FF" />
      <circle cx="122" cy="62" r="38" fill="rgba(48,209,88,0.20)" stroke="#30D158" />
    </svg>
  );
}
function ThumbTimeline() {
  return (
    <svg viewBox="0 0 200 125">
      <line x1="10" y1="62" x2="190" y2="62" stroke={TH.stroke} />
      {[24, 60, 96, 132, 168].map((x, i) => (
        <g key={x}>
          <circle cx={x} cy="62" r="4" fill={i === 3 ? "#0A84FF" : TH.stroke} />
          <rect x={x - 16} y={i % 2 === 0 ? 24 : 82} width="32" height="20" rx="2" fill={TH.fill} stroke={TH.stroke} />
        </g>
      ))}
    </svg>
  );
}
function ThumbQuad() {
  return (
    <svg viewBox="0 0 200 125">
      <line x1="100" y1="10" x2="100" y2="115" stroke={TH.stroke} />
      <line x1="10" y1="62" x2="190" y2="62" stroke={TH.stroke} />
      {[[36, 40, "#30D158"], [70, 30, "#0A84FF"], [140, 28, "#FF9F0A"], [150, 90, "#BF5AF2"], [40, 88, "#FF375F"]].map((p, i) => (
        <circle key={i} cx={p[0]} cy={p[1]} r="6" fill={p[2]} opacity="0.7" />
      ))}
    </svg>
  );
}
function ThumbJourney() {
  return (
    <svg viewBox="0 0 200 125">
      {[24, 60, 96, 132, 168].map((x, i) => (
        <g key={x}>
          <rect x={x - 14} y="40" width="28" height="44" rx="3" fill={i === 2 ? "rgba(10,132,255,0.15)" : TH.fill} stroke={i === 2 ? "#0A84FF" : TH.stroke} />
          <text x={x} y="60" textAnchor="middle" fontSize="9" fill="rgba(255,255,255,0.7)">●</text>
          <text x={x} y="76" textAnchor="middle" fontSize="9" fill="rgba(255,255,255,0.7)">{["☹", "○", "◐", "☺", "♥"][i]}</text>
        </g>
      ))}
    </svg>
  );
}
function ThumbGeneric({ fam }) {
  return (
    <svg viewBox="0 0 200 125">
      <rect x="14" y="14" width="172" height="96" rx="6" fill="rgba(255,255,255,0.02)" stroke={TH.stroke} strokeDasharray="3 3" />
      <text x="100" y="68" textAnchor="middle" fontFamily="var(--font-mono)" fontSize="13" fill="rgba(235,235,245,0.50)" fontWeight="600">{fam || "—"}</text>
    </svg>
  );
}

function CorpusBrowser({ familyFilter, setFamilyFilter, formatFilter, setFormatFilter, diagFilter, setDiagFilter, linuxFilter, setLinuxFilter, activeId, setActiveId }) {
  const items = CORPUS_ITEMS.filter((c) =>
    (!familyFilter || c.fam === familyFilter) &&
    (!formatFilter || c.badge === formatFilter) &&
    (!diagFilter || c.diag === diagFilter) &&
    (!linuxFilter || c.linux === linuxFilter)
  );
  const famCounts = {};
  CORPUS_ITEMS.forEach((c) => { famCounts[c.fam] = (famCounts[c.fam] || 0) + 1; });

  // Show top 12 families for the filter row to fit
  const topFams = Object.keys(famCounts).sort((a, b) => famCounts[b] - famCounts[a]).slice(0, 12);

  return (
    <div className="corpus-stack" style={{ flex: 1 }}>
      <div className="corpus-head">
        <div style={{ display: "flex", flexDirection: "column", lineHeight: 1.2 }}>
          <span className="h1">Corpus browser</span>
          <span className="sub">
            <Ph note="From BASELINES.md — 396 Mermaid + 26 multi-format">422 entries</Ph> · 28 families
            · <Ph note="From BASELINES.md">1044 baselines</Ph> (435 SVG · 435 image · 174 ASCII)
          </span>
        </div>
        <span className="grow" />
        <div className="corpus-search">
          <Icon.Search />
          <input placeholder="Search · ID · fixture name · diagnostic category" />
          <span className="kbd-hint">⌘K</span>
        </div>
      </div>

      <div className="corpus-filter-row">
        <span className="label">Family</span>
        <div className="grp">
          <span className={"ch" + (!familyFilter ? " on" : "")} onClick={() => setFamilyFilter && setFamilyFilter(null)}>all <span className="ct">{CORPUS_ITEMS.length}</span></span>
          {topFams.map((f) => (
            <span key={f} className={"ch" + (familyFilter === f ? " on" : "")} onClick={() => setFamilyFilter && setFamilyFilter(familyFilter === f ? null : f)}>{f} <span className="ct">{famCounts[f]}</span></span>
          ))}
        </div>
        <span className="div" />
        <span className="label">Format</span>
        {["mmd", "d2", "dot", "stz", "puml"].map((f) => (
          <span key={f} className={"ch" + (formatFilter === f ? " on" : "")} onClick={() => setFormatFilter && setFormatFilter(formatFilter === f ? null : f)}>{f}</span>
        ))}
        <span className="div" />
        <span className="label">Diagnostic state</span>
        <span className={"ch" + (diagFilter === "clean" ? " on" : "")} onClick={() => setDiagFilter && setDiagFilter(diagFilter === "clean" ? null : "clean")}>● clean</span>
        <span className={"ch" + (diagFilter === "warn" ? " on" : "")} onClick={() => setDiagFilter && setDiagFilter(diagFilter === "warn" ? null : "warn")}>▲ unsupportedFeature on export</span>
        <span className="div" />
        <span className="label">Linux</span>
        <span className={"ch" + (linuxFilter === "full" ? " on" : "")} onClick={() => setLinuxFilter && setLinuxFilter(linuxFilter === "full" ? null : "full")}><span className="linux-dot green" style={{ marginRight: 4 }} /> full</span>
        <span className={"ch" + (linuxFilter === "approx" ? " on" : "")} onClick={() => setLinuxFilter && setLinuxFilter(linuxFilter === "approx" ? null : "approx")}><span className="linux-dot amber" style={{ marginRight: 4 }} /> approximate</span>
        <span className={"ch" + (linuxFilter === "none" ? " on" : "")} onClick={() => setLinuxFilter && setLinuxFilter(linuxFilter === "none" ? null : "none")}><span className="linux-dot gray" style={{ marginRight: 4 }} /> —</span>
      </div>

      <div className="corpus-grid-wrap">
        <div className="corpus-grid">
          {items.map((c) => (
            <div key={c.id} className={"corpus-card" + (activeId === c.id ? " on" : "")} onClick={() => setActiveId && setActiveId(c.id)}>
              <div className="thumb"><ThumbFor fam={c.fam} /></div>
              <div className="meta">
                <span className="ttl">{c.title}</span>
                <span className="sub">
                  <span className="badge">{c.badge}</span>
                  {c.fam}
                  <span className={"linux-dot " + (c.linux === "approx" ? "amber" : c.linux === "full" ? "green" : "gray")}
                        title={c.linux === "approx" ? "Linux: text-metrics approximate · char-count fallback" : c.linux === "full" ? "Linux: full parity" : "Linux: not yet measured"} />
                  <span className={"diag-dot " + c.diag} title={c.diag === "clean" ? "no diagnostics" : c.diag === "warn" ? "emits .warning or .unsupported" : "unsupported family"} />
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  ConvertSheet,
  CoverageMatrix,
  DiagnosticsDrawer,
  DiagnosticExplain,
  ExportSheet,
  CorpusBrowser,
  FAMILIES_28,
  COVERAGE,
  FORMAT_COLS,
  DIAGNOSTICS_BAG,
});
