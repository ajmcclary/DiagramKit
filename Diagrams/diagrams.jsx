// Diagram renderers — static, hand-laid-out SVG that emulates DiagramKit's
// SVG backend output. Each renderer returns a <svg> tree.

const { useState } = React;

// ============================================================
// Shared building blocks
// ============================================================

function NodeRect({ x, y, w, h, label, sub, kind = "process", accent }) {
  const corner =
    kind === "decision" ? 4 :
    kind === "rounded" ? 14 :
    kind === "circle" ? 999 :
    6;
  const fill = accent === "accent" ? "var(--accent-15)" :
               accent === "success" ? "rgba(48,209,88,0.12)" :
               accent === "warn" ? "rgba(255,159,10,0.12)" :
               kind === "decision" ? "#1C1C1E" :
               "#2C2C2E";
  const stroke = accent === "accent" ? "var(--accent)" :
                 accent === "success" ? "var(--status-success)" :
                 accent === "warn" ? "var(--status-warning)" :
                 "rgba(255,255,255,0.20)";
  if (kind === "decision") {
    const cx = x + w / 2, cy = y + h / 2;
    const pts = `${cx},${y} ${x + w},${cy} ${cx},${y + h} ${x},${cy}`;
    return (
      <g>
        <polygon points={pts} fill={fill} stroke={stroke} strokeWidth="1" />
        <text x={cx} y={cy + (sub ? -2 : 4)} textAnchor="middle" className="node-text">{label}</text>
        {sub && <text x={cx} y={cy + 12} textAnchor="middle" className="node-sub">{sub}</text>}
      </g>
    );
  }
  return (
    <g>
      <rect x={x} y={y} width={w} height={h} rx={corner} ry={corner}
            fill={fill} stroke={stroke} strokeWidth="1" />
      <text x={x + w / 2} y={y + h / 2 + (sub ? -2 : 4)} textAnchor="middle" className="node-text">{label}</text>
      {sub && <text x={x + w / 2} y={y + h / 2 + 12} textAnchor="middle" className="node-sub">{sub}</text>}
    </g>
  );
}

function Arrow({ d, label, dashed, color = "rgba(255,255,255,0.40)", labelXY }) {
  return (
    <g>
      <path d={d} stroke={color} strokeWidth="1.25" fill="none"
            strokeDasharray={dashed ? "4 3" : undefined}
            markerEnd="url(#dk-arrow)" />
      {label && labelXY && (
        <g>
          <rect x={labelXY[0] - label.length * 3.2} y={labelXY[1] - 7} width={label.length * 6.4 + 4} height={13}
                rx={3} className="edge-bg" />
          <text x={labelXY[0]} y={labelXY[1] + 3} textAnchor="middle" className="edge-label">{label}</text>
        </g>
      )}
    </g>
  );
}

function ArrowDefs() {
  return (
    <defs>
      <marker id="dk-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto">
        <path d="M 0 0 L 10 5 L 0 10 z" fill="rgba(255,255,255,0.50)" />
      </marker>
      <marker id="dk-arrow-accent" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto">
        <path d="M 0 0 L 10 5 L 0 10 z" fill="var(--accent)" />
      </marker>
    </defs>
  );
}

// ============================================================
// 1. FLOWCHART — DiagramKit pipeline
// ============================================================
function FlowchartDiagram() {
  return (
    <svg className="diagram-svg" viewBox="0 0 880 460" width="880" height="460">
      <ArrowDefs />

      {/* Group label */}
      <text x="20" y="20" className="node-sub" fill="rgba(235,235,245,0.45)">subgraph: pipeline</text>
      <rect x="14" y="28" width="852" height="280" rx="14" fill="rgba(255,255,255,0.02)" stroke="rgba(255,255,255,0.06)" strokeDasharray="2 3" />

      {/* Row 1: Source -> Parser -> Document */}
      <NodeRect x={32}  y={88}  w={150} h={56} kind="rounded" label="Source" sub="String" />
      <NodeRect x={232} y={88}  w={170} h={56} kind="process" label="Parser" sub="MermaidParser" />
      <NodeRect x={452} y={88}  w={180} h={56} kind="process" label="DiagramDocument" sub="typed enum payload" />
      <NodeRect x={682} y={88}  w={170} h={56} kind="process" label="GraphLayout" sub=".layout(_:)" />

      <Arrow d="M182 116 L232 116" />
      <Arrow d="M402 116 L452 116" />
      <Arrow d="M632 116 L682 116" />

      {/* Row 2: PositionedGraph (decision-ish hub) */}
      <NodeRect x={344} y={196} w={196} h={64} kind="rounded" label="PositionedGraph" sub="scene graph · laid out" accent="accent" />

      {/* Down from GraphLayout */}
      <Arrow d="M767 144 C 767 174, 540 174, 540 196" labelXY={[680, 178]} label="positioned" />

      {/* Row 3: three renderers */}
      <NodeRect x={32}  y={332} w={170} h={64} kind="rounded" label="renderImage" sub="CoreGraphics · BMImage" accent="success" />
      <NodeRect x={232} y={332} w={170} h={64} kind="rounded" label="renderSVG" sub="String" accent="accent" />
      <NodeRect x={432} y={332} w={170} h={64} kind="rounded" label="renderASCII" sub="String" accent="warn" />
      <NodeRect x={632} y={332} w={222} h={64} kind="rounded" label="DiagramView" sub="SwiftUI · UIKit · AppKit" />

      <Arrow d="M422 260 C 422 286, 117 286, 117 332" />
      <Arrow d="M442 260 L 317 332" />
      <Arrow d="M462 260 L 517 332" />
      <Arrow d="M482 260 C 482 286, 743 286, 743 332" />

      {/* Side note: error path */}
      <NodeRect x={720} y={196} w={132} h={48} kind="rounded" label="DiagramError" sub=".throws" accent="warn" />
      <Arrow d="M460 226 L 720 220" dashed label="throws" labelXY={[590, 215]} />
    </svg>
  );
}

// ============================================================
// 2. TIMELINE — Phases 0–10 roadmap
// ============================================================
function TimelineDiagram() {
  const phases = [
    { id: "0", title: "Rename plan", group: "Phase 0", note: "ff2622b · done", color: "var(--status-success)" },
    { id: "1", title: "Mermaid port", group: "Phase 1", note: "28 families", color: "var(--status-success)" },
    { id: "2", title: "SVG/CG/ASCII", group: "Phase 2", note: "3 backends", color: "var(--status-success)" },
    { id: "3", title: "Snapshot harness", group: "Phase 3", note: "1044 baselines", color: "var(--status-success)" },
    { id: "4", title: "Importer split", group: "Phase 4", note: "13 products", color: "var(--status-success)" },
    { id: "5", title: "D2 · DOT", group: "Phase 5", note: "+ Structurizr", color: "var(--status-success)" },
    { id: "6", title: "PlantUML", group: "Phase 6", note: "sequence ✓", color: "var(--status-success)" },
    { id: "7", title: "Linux portable", group: "Phase 7", note: "parse + layout", color: "var(--status-success)" },
    { id: "8", title: "Strict Sendable", group: "Phase 8", note: "Swift 6 mode", color: "var(--status-success)" },
    { id: "9", title: "Interactive", group: "Phase 9", note: "DiagramEditor", color: "var(--status-success)" },
    { id: "10", title: "Diagram-prefix API", group: "Phase 10", note: "2026-05-13", color: "var(--accent)" },
    { id: "11", title: "PlantUML 6B–E", group: "Next", note: "in flight", color: "var(--status-warning)" },
  ];
  const X0 = 40, X1 = 850;
  const Y = 220;
  const dx = (X1 - X0) / (phases.length - 1);
  return (
    <svg className="diagram-svg" viewBox="0 0 880 360" width="880" height="360">
      <ArrowDefs />

      {/* Title */}
      <text x="40" y="36" className="node-text" style={{ fontSize: 14, fontWeight: 600 }}>DiagramKit · multi-format port roadmap</text>
      <text x="40" y="54" className="node-sub">timeline-beta · 12 events</text>

      {/* Axis */}
      <line x1={X0 - 8} y1={Y} x2={X1 + 8} y2={Y} stroke="rgba(255,255,255,0.22)" strokeWidth="1.25" />
      {/* Ticks */}
      {phases.map((p, i) => (
        <g key={p.id}>
          <line x1={X0 + i * dx} y1={Y - 4} x2={X0 + i * dx} y2={Y + 4} stroke="rgba(255,255,255,0.18)" strokeWidth="1" />
        </g>
      ))}

      {/* Events */}
      {phases.map((p, i) => {
        const x = X0 + i * dx;
        const above = i % 2 === 0;
        const cardY = above ? Y - 100 : Y + 28;
        const cardH = 68;
        return (
          <g key={p.id}>
            {/* Marker */}
            <circle cx={x} cy={Y} r={6.5} fill="var(--bg-app)" stroke={p.color} strokeWidth="2" />
            {p.id === "10" && (
              <circle cx={x} cy={Y} r={11} fill="none" stroke={p.color} strokeOpacity="0.30" strokeWidth="1" />
            )}
            {/* Connector */}
            <line x1={x} y1={above ? Y - 6 : Y + 6} x2={x} y2={above ? cardY + cardH : cardY} stroke="rgba(255,255,255,0.15)" strokeWidth="1" strokeDasharray="2 2" />
            {/* Card */}
            <g transform={`translate(${x - 56}, ${cardY})`}>
              <rect width="112" height={cardH} rx="6" fill="#2C2C2E" stroke="rgba(255,255,255,0.14)" />
              <text x="10" y="16" className="node-sub" fill="rgba(235,235,245,0.55)">{p.group}</text>
              <text x="10" y="36" className="node-text" style={{ fontSize: 12, fontWeight: 600 }}>{p.title}</text>
              <text x="10" y="54" className="node-sub" style={{ fontSize: 9.5 }} fill={p.color} fillOpacity="0.85">{p.note}</text>
            </g>
          </g>
        );
      })}

      {/* "now" cursor */}
      <g>
        <line x1={X0 + 10 * dx} y1={36} x2={X0 + 10 * dx} y2={Y + 80} stroke="var(--accent)" strokeOpacity="0.45" strokeDasharray="3 3" />
        <rect x={X0 + 10 * dx - 18} y={26} width="36" height="14" rx="3" fill="var(--accent)" />
        <text x={X0 + 10 * dx} y={36} textAnchor="middle" fill="#fff" fontFamily="var(--font-mono)" fontSize="9.5" fontWeight="700">NOW</text>
      </g>
    </svg>
  );
}

// ============================================================
// 3. GANTT — release plan
// ============================================================
function GanttDiagram() {
  const rows = [
    { sec: "Foundations", t: "Tokens · Parser core", start: 0, len: 18, status: "done" },
    { sec: "Foundations", t: "Layouts (flowchart, seq, state)", start: 4, len: 22, status: "done" },
    { sec: "Renderers",   t: "SVG backend",              start: 18, len: 14, status: "done" },
    { sec: "Renderers",   t: "CG image backend",         start: 22, len: 16, status: "done" },
    { sec: "Renderers",   t: "ASCII backend",            start: 30, len: 10, status: "done" },
    { sec: "Importers",   t: "D2 + DOT",                 start: 40, len: 12, status: "done" },
    { sec: "Importers",   t: "Structurizr",              start: 48, len: 8,  status: "done" },
    { sec: "Importers",   t: "PlantUML · sequence",      start: 54, len: 10, status: "done" },
    { sec: "Importers",   t: "PlantUML · class/state",   start: 64, len: 12, status: "active" },
    { sec: "Polish",      t: "Diagram-prefix rename",    start: 70, len: 6,  status: "done" },
    { sec: "Polish",      t: "Snapshot baselines · 1044",start: 76, len: 8,  status: "active" },
    { sec: "Next",        t: "Exporter coverage · 28",   start: 84, len: 16, status: "pending" },
    { sec: "Next",        t: "Portable text shim",       start: 86, len: 14, status: "pending" },
  ];
  const X0 = 200, X1 = 860;
  const colors = {
    done:    { fill: "rgba(48,209,88,0.30)",    stroke: "var(--status-success)" },
    active:  { fill: "var(--accent-25)",        stroke: "var(--accent)" },
    pending: { fill: "rgba(255,255,255,0.06)",  stroke: "rgba(255,255,255,0.25)" },
  };
  const total = 100;
  const xOf = (n) => X0 + (n / total) * (X1 - X0);

  // Section bands
  const sections = [];
  let prevSec = null;
  rows.forEach((r, i) => {
    if (r.sec !== prevSec) { sections.push({ sec: r.sec, start: i }); prevSec = r.sec; }
  });
  sections.forEach((s, i) => {
    s.end = (i + 1 < sections.length ? sections[i + 1].start : rows.length) - 1;
  });

  const rowH = 22;
  const top = 70;

  return (
    <svg className="diagram-svg" viewBox="0 0 880 380" width="880" height="380">
      <ArrowDefs />
      {/* Header */}
      <text x="40" y="32" className="node-text" style={{ fontSize: 14, fontWeight: 600 }}>DiagramKit · Phases 0–10 + roadmap</text>
      <text x="40" y="50" className="node-sub">gantt · weeks (relative)</text>

      {/* Date axis */}
      <line x1={X0} y1={64} x2={X1} y2={64} stroke="rgba(255,255,255,0.18)" />
      {[0, 20, 40, 60, 80, 100].map((t) => (
        <g key={t}>
          <line x1={xOf(t)} y1={60} x2={xOf(t)} y2={68} stroke="rgba(255,255,255,0.22)" />
          <text x={xOf(t)} y={56} textAnchor="middle" className="node-sub" fontSize="9.5">w{t}</text>
        </g>
      ))}

      {/* Vertical grid */}
      {[20, 40, 60, 80].map((t) => (
        <line key={t} x1={xOf(t)} y1={70} x2={xOf(t)} y2={70 + rows.length * rowH + 10} stroke="rgba(255,255,255,0.06)" />
      ))}

      {/* Section bands & labels */}
      {sections.map((s, i) => {
        const y0 = top + s.start * rowH;
        const h  = (s.end - s.start + 1) * rowH;
        const sectionFill = i % 2 === 0 ? "rgba(255,255,255,0.02)" : "transparent";
        return (
          <g key={s.sec}>
            <rect x={20} y={y0} width={X1 - 20} height={h} fill={sectionFill} />
            <text x={32} y={y0 + 14} className="node-sub" fill="rgba(235,235,245,0.85)" style={{ fontWeight: 600 }}>{s.sec}</text>
          </g>
        );
      })}

      {/* Rows */}
      {rows.map((r, i) => {
        const y = top + i * rowH + 4;
        const c = colors[r.status];
        const x = xOf(r.start);
        const w = xOf(r.start + r.len) - x;
        return (
          <g key={i}>
            <text x={196} y={y + 12} textAnchor="end" className="node-text" style={{ fontSize: 11 }}>{r.t}</text>
            <rect x={x} y={y + 2} width={w} height={14} rx={3}
                  fill={c.fill} stroke={c.stroke} strokeWidth="1" />
            {r.status === "active" && (
              <rect x={x} y={y + 2} width={w * 0.65} height={14} rx={3} fill="var(--accent)" fillOpacity="0.55" />
            )}
          </g>
        );
      })}

      {/* Today line */}
      <line x1={xOf(82)} y1={64} x2={xOf(82)} y2={top + rows.length * rowH + 8}
            stroke="var(--accent)" strokeOpacity="0.7" strokeDasharray="3 3" />
      <rect x={xOf(82) - 22} y={64 - 14} width="44" height="13" rx="3" fill="var(--accent)" />
      <text x={xOf(82)} y={64 - 4} textAnchor="middle" fill="#fff" fontFamily="var(--font-mono)" fontSize="9.5" fontWeight="700">TODAY</text>
    </svg>
  );
}

// ============================================================
// ASCII fallbacks
// ============================================================
const ASCII_OUT = {
  flowchart: `┌────────────┐    ┌────────────────┐    ┌──────────────────┐    ┌──────────────┐
│   Source   │───▶│ MermaidParser  │───▶│ DiagramDocument  │───▶│ GraphLayout  │
└────────────┘    └────────────────┘    └──────────────────┘    └──────┬───────┘
                                                                       │
                                                       ┌───────────────▼──────────────┐
                                                       │       PositionedGraph        │
                                                       └───┬───────────┬──────────┬───┘
                                                           │           │          │
                                              ┌────────────▼──┐  ┌─────▼─────┐ ┌──▼────────────┐
                                              │  renderImage  │  │ renderSVG │ │  renderASCII  │
                                              │  CoreGraphics │  │   String  │ │     String    │
                                              └───────────────┘  └───────────┘ └───────────────┘`,
  timeline: `DiagramKit  ·  multi-format port roadmap
═══════════════════════════════════════════════════════════════════════════════

   P0       P1       P2       P3       P4       P5       P6
   ●────────●────────●────────●────────●────────●────────●─────
   │        │        │        │        │        │        │
 Rename    Mermaid  SVG/CG   Snapshot  Split   D2 DOT   PlantUML
 plan      port     ASCII    1044      13      Struct   sequence

   P7       P8       P9      P10  ◀── NOW             Next
   ●────────●────────●────────●─────────────────────────○─────
   │        │        │        │                         │
 Linux    Strict  Editor   Diagram-prefix              PlantUML
 portable Sendable mutate  API · 2026-05-13            6B–E`,
  gantt: `Foundations
  Tokens · Parser core           ███████████████░░░░░░░░░░░░░░░░░░  done
  Layouts                        ░░░███████████████████░░░░░░░░░░░  done
Renderers
  SVG backend                    ░░░░░░░░░░░░░░░░░░██████████░░░░░  done
  CG image backend               ░░░░░░░░░░░░░░░░░░░░░██████████░░  done
  ASCII backend                  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████  done
Importers
  D2 + DOT                       ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  done
  PlantUML class/state           ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ▓▓▓▓▓ active`,
};

// ============================================================
// PNG mock — just a static frame around the SVG with a checksum bar
// ============================================================
function PngBackend({ DiagramComp }) {
  return (
    <div className="png-chrome">
      <div className="png-meta">
        <span>PNG · @2x</span>
        <span style={{ color: "var(--fg2)" }}>·</span>
        <span className="pix">1760 × 920 px</span>
        <span style={{ color: "var(--fg2)" }}>·</span>
        <span>scale 2.0</span>
        <span style={{ color: "var(--fg2)" }}>·</span>
        <span>Noto Sans</span>
        <span style={{ color: "var(--fg2)" }}>·</span>
        <span>34.2 KB</span>
        <span style={{ marginLeft: "auto", color: "var(--status-success)" }}>● rendered on worker</span>
      </div>
      <div style={{ background: "#1C1C1E", borderRadius: 8, padding: 14 }}>
        <DiagramComp />
      </div>
    </div>
  );
}

// Export
Object.assign(window, {
  FlowchartDiagram, TimelineDiagram, GanttDiagram, PngBackend, ASCII_OUT,
  // Shared SVG primitives — visual.jsx and surfaces.jsx render their own diagrams
  ArrowDefs, NodeRect, Arrow,
});
