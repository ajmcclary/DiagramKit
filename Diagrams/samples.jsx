// Sample diagram sources + history + diagnostics
// Each sample has:
//   - id, title, family, format, kind glyph
//   - source (with line-by-line tokenization)
//   - diagnostics (line + severity + message)
//   - history entries
//   - stats (nodes, edges, layout time, paint time)

// ─────────────────────────────────────────────────────────────
// Token model: an array of arrays-of-tokens, one row per line.
// Each token is [class, text].
// ─────────────────────────────────────────────────────────────

const SAMPLES = [
  {
    id: "pipeline-flow",
    title: "DiagramKit pipeline",
    family: "flowchart",
    format: "mermaid",
    fileName: "Pipeline.mmd",
    glyph: "⌬",
    diagnostics: [
      { line: 12, severity: "warn", code: "DK1208", msg: "Label “positioned” is wider than node — wrapping" },
    ],
    stats: { nodes: 9, edges: 11, layout: "1.8 ms", paint: "6.4 ms", svg: "12.3 KB" },
    source: [
      [["tk-cmnt", "%% DiagramKit pipeline — source → parser → renderers"]],
      [["tk-kw", "flowchart"], ["tk-text", " "], ["tk-dir", "LR"]],
      [],
      [["tk-text", "  "], ["tk-id", "Source"], ["tk-shape", "[\""], ["tk-lbl", "Source"], ["tk-shape", "\"]"], ["tk-op", " "], ["tk-arrow", "-->"], ["tk-op", " "], ["tk-id", "P"], ["tk-shape", "(\""], ["tk-lbl", "MermaidParser.parse"], ["tk-shape", "\")"]],
      [["tk-text", "  "], ["tk-id", "P"], ["tk-op", " "], ["tk-arrow", "-->"], ["tk-op", " "], ["tk-id", "D"], ["tk-shape", "[\""], ["tk-lbl", "DiagramDocument"], ["tk-shape", "\"]"]],
      [["tk-text", "  "], ["tk-id", "D"], ["tk-op", " "], ["tk-arrow", "-->"], ["tk-op", " "], ["tk-id", "L"], ["tk-shape", "(\""], ["tk-lbl", "GraphLayout"], ["tk-shape", "\")"]],
      [["tk-text", "  "], ["tk-id", "L"], ["tk-op", " "], ["tk-arrow", "-->"], ["tk-op", " "], ["tk-id", "G"], ["tk-shape", "(("], ["tk-lbl", "PositionedGraph"], ["tk-shape", "))"]],
      [],
      [["tk-text", "  "], ["tk-id", "G"], ["tk-op", " "], ["tk-arrow", "-->|"], ["tk-lbl", "renderImage"], ["tk-arrow", "|"], ["tk-op", " "], ["tk-id", "I"], ["tk-shape", "[\""], ["tk-lbl", "BMImage"], ["tk-shape", "\"]"]],
      [["tk-text", "  "], ["tk-id", "G"], ["tk-op", " "], ["tk-arrow", "-->|"], ["tk-lbl", "renderSVG"], ["tk-arrow", "|"], ["tk-op", " "], ["tk-id", "S"], ["tk-shape", "[\""], ["tk-lbl", "SVG String"], ["tk-shape", "\"]"]],
      [["tk-text", "  "], ["tk-id", "G"], ["tk-op", " "], ["tk-arrow", "-->|"], ["tk-lbl", "renderASCII"], ["tk-arrow", "|"], ["tk-op", " "], ["tk-id", "A"], ["tk-shape", "[\""], ["tk-lbl", "positioned"], ["tk-shape", "\"]"]],
      [["tk-text", "  "], ["tk-id", "G"], ["tk-op", " "], ["tk-arrow", "-->"], ["tk-op", " "], ["tk-id", "V"], ["tk-shape", "[\""], ["tk-lbl", "DiagramView"], ["tk-shape", "\"]"]],
      [],
      [["tk-text", "  "], ["tk-id", "P"], ["tk-op", " "], ["tk-arrow", "-.->|"], ["tk-lbl", "throws"], ["tk-arrow", "|"], ["tk-op", " "], ["tk-id", "E"], ["tk-shape", "[["], ["tk-lbl", "DiagramError"], ["tk-shape", "]]"]],
      [],
      [["tk-text", "  "], ["tk-kw", "classDef"], ["tk-text", " "], ["tk-id", "ok"], ["tk-text", " "], ["tk-op", "fill:"], ["tk-num", "#30D158"], ["tk-op", ",stroke:"], ["tk-num", "#30D158"], ["tk-op", ",color:"], ["tk-num", "#fff"]],
      [["tk-text", "  "], ["tk-kw", "class"], ["tk-text", " "], ["tk-id", "I,S,A,V"], ["tk-text", " "], ["tk-id", "ok"]],
    ],
    history: [
      { ts: "now",       msg: "Reuse `positioned` label in renderASCII branch", current: true },
      { ts: "2 min ago", msg: "Add DiagramView destination" },
      { ts: "8 min ago", msg: "Split renderers into labelled edges" },
      { ts: "21 min ago", msg: "Initial DiagramKit pipeline import" },
    ],
  },
  {
    id: "phases-timeline",
    title: "Phase roadmap",
    family: "timeline",
    format: "mermaid",
    fileName: "Roadmap.mmd",
    glyph: "⌗",
    diagnostics: [
      { line: 6, severity: "info", code: "DK0901", msg: "Section span exceeds 4 events — consider splitting" },
    ],
    stats: { nodes: 12, edges: 0, layout: "1.1 ms", paint: "4.9 ms", svg: "9.1 KB" },
    source: [
      [["tk-kw", "timeline"]],
      [["tk-text", "    "], ["tk-kw", "title"], ["tk-text", " "], ["tk-lbl", "DiagramKit · multi-format port roadmap"]],
      [],
      [["tk-text", "    "], ["tk-shape", "section "], ["tk-id", "Foundations"]],
      [["tk-text", "      "], ["tk-num", "P0"], ["tk-op", " : "], ["tk-text", "Rename plan"]],
      [["tk-text", "      "], ["tk-num", "P1"], ["tk-op", " : "], ["tk-text", "Mermaid port "], ["tk-op", ": "], ["tk-text", "28 families"]],
      [["tk-text", "      "], ["tk-num", "P2"], ["tk-op", " : "], ["tk-text", "Backends "], ["tk-op", ": "], ["tk-text", "SVG · CG · ASCII"]],
      [["tk-text", "      "], ["tk-num", "P3"], ["tk-op", " : "], ["tk-text", "Snapshot harness "], ["tk-op", ": "], ["tk-text", "1044 baselines"]],
      [],
      [["tk-text", "    "], ["tk-shape", "section "], ["tk-id", "Multi-format"]],
      [["tk-text", "      "], ["tk-num", "P4"], ["tk-op", " : "], ["tk-text", "Importer boundary "], ["tk-op", ": "], ["tk-text", "13 products"]],
      [["tk-text", "      "], ["tk-num", "P5"], ["tk-op", " : "], ["tk-text", "D2 · DOT · Structurizr"]],
      [["tk-text", "      "], ["tk-num", "P6"], ["tk-op", " : "], ["tk-text", "PlantUML sequence"]],
      [],
      [["tk-text", "    "], ["tk-shape", "section "], ["tk-id", "Polish"]],
      [["tk-text", "      "], ["tk-num", "P7"], ["tk-op", " : "], ["tk-text", "Linux-portable parse + layout"]],
      [["tk-text", "      "], ["tk-num", "P8"], ["tk-op", " : "], ["tk-text", "Strict Sendable · Swift 6"]],
      [["tk-text", "      "], ["tk-num", "P9"], ["tk-op", " : "], ["tk-text", "DiagramEditor · mutations"]],
      [["tk-text", "      "], ["tk-num", "P10"], ["tk-op", " : "], ["tk-text", "Diagram-prefix API (2026-05-13)"]],
    ],
    history: [
      { ts: "now",       msg: "P10 marked NOW · default cursor", current: true },
      { ts: "15 min ago", msg: "Move PlantUML 6B–E to Next" },
      { ts: "1 hr ago",  msg: "Add P9 DiagramEditor" },
      { ts: "yesterday", msg: "Restructured into three sections" },
    ],
  },
  {
    id: "phases-gantt",
    title: "Phase Gantt",
    family: "gantt",
    format: "mermaid",
    fileName: "Phases.mmd",
    glyph: "▤",
    diagnostics: [],
    stats: { nodes: 13, edges: 0, layout: "2.3 ms", paint: "7.8 ms", svg: "14.7 KB" },
    source: [
      [["tk-kw", "gantt"]],
      [["tk-text", "    "], ["tk-kw", "title"], ["tk-text", " "], ["tk-lbl", "DiagramKit · Phases 0–10 + roadmap"]],
      [["tk-text", "    "], ["tk-kw", "dateFormat"], ["tk-text", " "], ["tk-id", "YYYY-MM-DD"]],
      [["tk-text", "    "], ["tk-kw", "axisFormat"], ["tk-text", " "], ["tk-id", "w%U"]],
      [],
      [["tk-text", "    "], ["tk-shape", "section "], ["tk-id", "Foundations"]],
      [["tk-text", "      "], ["tk-text", "Tokens · Parser core           :"], ["tk-id", "done"], ["tk-op", ", "], ["tk-num", "2025-09-01"], ["tk-op", ", "], ["tk-num", "18w"]],
      [["tk-text", "      "], ["tk-text", "Layouts                        :"], ["tk-id", "done"], ["tk-op", ", "], ["tk-num", "2025-10-01"], ["tk-op", ", "], ["tk-num", "22w"]],
      [],
      [["tk-text", "    "], ["tk-shape", "section "], ["tk-id", "Renderers"]],
      [["tk-text", "      "], ["tk-text", "SVG backend                    :"], ["tk-id", "done"], ["tk-op", ", "], ["tk-num", "2026-01-04"], ["tk-op", ", "], ["tk-num", "14w"]],
      [["tk-text", "      "], ["tk-text", "CG image backend               :"], ["tk-id", "done"], ["tk-op", ", "], ["tk-num", "2026-02-01"], ["tk-op", ", "], ["tk-num", "16w"]],
      [["tk-text", "      "], ["tk-text", "ASCII backend                  :"], ["tk-id", "done"], ["tk-op", ", "], ["tk-num", "2026-03-08"], ["tk-op", ", "], ["tk-num", "10w"]],
      [],
      [["tk-text", "    "], ["tk-shape", "section "], ["tk-id", "Importers"]],
      [["tk-text", "      "], ["tk-text", "D2 + DOT                       :"], ["tk-id", "done"], ["tk-op", ", "], ["tk-num", "2026-04-01"], ["tk-op", ", "], ["tk-num", "12w"]],
      [["tk-text", "      "], ["tk-text", "Structurizr                    :"], ["tk-id", "done"], ["tk-op", ", "], ["tk-num", "2026-04-19"], ["tk-op", ", "], ["tk-num", "8w"]],
      [["tk-text", "      "], ["tk-text", "PlantUML · sequence            :"], ["tk-id", "done"], ["tk-op", ", "], ["tk-num", "2026-04-27"], ["tk-op", ", "], ["tk-num", "10w"]],
      [["tk-text", "      "], ["tk-text", "PlantUML · class/state         :"], ["tk-id", "active"], ["tk-op", ", "], ["tk-num", "2026-05-04"], ["tk-op", ", "], ["tk-num", "12w"]],
    ],
    history: [
      { ts: "now",       msg: "Mark PlantUML class/state active", current: true },
      { ts: "5 min ago", msg: "Re-baseline 1044 → 1057 snapshots" },
      { ts: "1 hr ago",  msg: "Extend exporter coverage row" },
    ],
  },
];

// Sample tree for the Library sidebar
const SAMPLE_TREE = [
  { sec: "DiagramKit", items: [
    { id: "pipeline-flow",   title: "DiagramKit pipeline",   family: "flowchart", badge: "mmd" },
    { id: "phases-timeline", title: "Phase roadmap",         family: "timeline",  badge: "mmd" },
    { id: "phases-gantt",    title: "Phase Gantt",           family: "gantt",     badge: "mmd" },
  ] },
  { sec: "Architecture", items: [
    { id: "arch-c4",     title: "C4 · Bridge context",   family: "c4Context",  badge: "mmd" },
    { id: "arch-beta",   title: "Workspace targets",     family: "architecture", badge: "d2"  },
    { id: "seq-render",  title: "renderImage path",      family: "sequence",   badge: "mmd" },
  ] },
  { sec: "Kubernetes (Bridge)", items: [
    { id: "k8s-pod",     title: "Pod lifecycle",         family: "stateDiagram", badge: "mmd" },
    { id: "k8s-svc",     title: "Service topology",      family: "flowchart",  badge: "dot" },
    { id: "k8s-deploy",  title: "Deployment ER",         family: "erDiagram",  badge: "mmd" },
  ] },
  { sec: "Mermaid corpus", items: [
    { id: "corpus-class",   title: "Class diagram · TCA reducers", family: "classDiagram", badge: "mmd" },
    { id: "corpus-git",     title: "gitGraph · main+feature",       family: "gitGraph", badge: "mmd" },
    { id: "corpus-mind",    title: "Mindmap · pipeline stages",     family: "mindmap", badge: "mmd" },
    { id: "corpus-sankey",  title: "Sankey · snapshot bytes",       family: "sankey", badge: "mmd" },
    { id: "corpus-quad",    title: "Quadrant · diagram families",   family: "quadrant", badge: "mmd" },
    { id: "corpus-pie",     title: "Pie · phase share",             family: "pie", badge: "mmd" },
  ] },
];

const FAMILY_ICON_MAP = {
  flowchart: "⌬",
  timeline: "⌗",
  gantt: "▤",
  c4Context: "▥",
  architecture: "▦",
  sequence: "⇄",
  stateDiagram: "◉",
  erDiagram: "▢",
  classDiagram: "▩",
  gitGraph: "⌥",
  mindmap: "✦",
  sankey: "≋",
  quadrant: "⊞",
  pie: "◐",
};

window.SAMPLES = SAMPLES;
window.SAMPLE_TREE = SAMPLE_TREE;
window.FAMILY_ICON_MAP = FAMILY_ICON_MAP;
