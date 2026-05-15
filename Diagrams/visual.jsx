// visual.jsx — Visual-mode editing surfaces
//
// Source citations:
//   DiagramEditor + selection      → Sources/DiagramKitInteractive/DiagramEditor.swift
//   Mutations (.setLabel/.delete)  → Sources/DiagramKitInteractive/DiagramMutation.swift
//   Flowchart-only mutations       → Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift
//   Undo stack + actionName        → Sources/DiagramKitInteractive/DiagramEditor+Undo.swift
//   PositionedGraph                → Sources/DiagramKitModel (src_layout.swift family)
//   DiagramDiagnostic.lossyTransform → Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift
//   DiagnosticCategory             → Sources/DiagramKitCommon/DiagnosticCategory.swift

// ─────────────────────────────────────────────────────────────
// Flowchart visual canvas — 5-state stepper:
//   idle → node-selected → label-edited → edge-drag → undone
// Renders against the same Pipeline.mmd source v1 shipped.
// ─────────────────────────────────────────────────────────────

// Geometry of nodes in the flowchart pipeline. Mirrors diagrams.jsx layout.
const FLOW_NODES = [
  { id: "Source",        x: 32,  y: 88,  w: 150, h: 56, label: "Source",          sub: "String",                  shape: "rounded" },
  { id: "P",             x: 232, y: 88,  w: 170, h: 56, label: "MermaidParser",   sub: "parse(_:)",               shape: "rect"    },
  { id: "D",             x: 452, y: 88,  w: 180, h: 56, label: "DiagramDocument", sub: "typed enum payload",      shape: "rect"    },
  { id: "L",             x: 682, y: 88,  w: 170, h: 56, label: "GraphLayout",     sub: ".layout(_:)",             shape: "rect"    },
  { id: "G",             x: 344, y: 196, w: 196, h: 64, label: "PositionedGraph", sub: "scene graph · laid out",  shape: "rounded", style: "ok" },
  { id: "I",             x: 32,  y: 332, w: 170, h: 64, label: "renderImage",     sub: "CoreGraphics · BMImage",  shape: "rounded", style: "ok" },
  { id: "S",             x: 232, y: 332, w: 170, h: 64, label: "renderSVG",       sub: "String",                  shape: "rounded", style: "ok" },
  { id: "A",             x: 432, y: 332, w: 170, h: 64, label: "positioned",      sub: "renderASCII · String",    shape: "rounded", style: "ok" },
  { id: "V",             x: 632, y: 332, w: 222, h: 64, label: "DiagramView",     sub: "SwiftUI · UIKit · AppKit",shape: "rounded", style: "ok" },
  { id: "E",             x: 720, y: 196, w: 132, h: 48, label: "DiagramError",    sub: ".throws",                 shape: "rounded", style: "warn" },
];

function nodeById(id) { return FLOW_NODES.find((n) => n.id === id); }
function nodeCenter(n) { return [n.x + n.w / 2, n.y + n.h / 2]; }

function FlowchartEditCanvas({ state, accent }) {
  // States: 0=idle, 1=node selected, 2=label edited, 3=edge drag,
  //         4=undone, 5=marquee select (I,S,A), 6=subgraph committed
  const isNodeSel = state === 1 || state === 2 || state === 4;
  const isLabelEdit = state === 2;
  const isEdgeDrag = state === 3;
  const isUndone = state === 4;
  const isMarquee = state === 5;
  const isGrouped = state === 6;
  // Three renderer nodes get a selection ring in states 5 and 6.
  const groupSel = isMarquee || isGrouped;
  // Waypoints on the edge-drag preview path (state 3).
  const waypoints = [
    { x: 600, y: 232 },
    { x: 680, y: 240, active: true }, // active = drag indicator
    { x: 750, y: 252 },
  ];

  // The "A" node is the focus of state 1–2 (it's the one with DK1208 warn).
  const selNode = nodeById("A");

  // For the edge-drag state: dragging an edge from G to a new floating "N" node.
  const dragTarget = { x: 770, y: 264 }; // appearing in blank area, lower-right of G

  // The label that gets edited in state 2
  const labelDuringEdit = isLabelEdit ? "positioned · ASCII" : (isUndone ? "positioned" : "positioned");
  const labelAfterEdit = state === 2 ? "positioned · ASCII" : "positioned";

  return (
    <div style={{ position: "relative", width: 880, height: 460 }}>
      <svg viewBox="0 0 880 460" width="880" height="460" className="diagram-svg">
        <ArrowDefs />
        {/* group container */}
        <text x="20" y="20" className="node-sub" fill="rgba(235,235,245,0.45)">subgraph: pipeline</text>
        <rect x="14" y="28" width="852" height="280" rx="14" fill="rgba(255,255,255,0.02)" stroke="rgba(255,255,255,0.06)" strokeDasharray="2 3" />

        {/* row 1 */}
        {FLOW_NODES.slice(0, 4).map((n) => <NodeRectV n={n} key={n.id} />)}
        {FLOW_NODES.slice(0, 3).map((n, i) => {
          const a = FLOW_NODES[i], b = FLOW_NODES[i + 1];
          return <Arrow key={i} d={`M${a.x + a.w} ${a.y + a.h / 2} L${b.x} ${b.y + b.h / 2}`} />;
        })}

        {/* hub */}
        <NodeRectV n={nodeById("G")} />
        <Arrow d="M767 144 C 767 174, 540 174, 540 196" labelXY={[680, 178]} label="positioned" />

        {/* Subgraph overlay for states 5/6 — drawn beneath nodes */}
        {(typeof SubgraphOverlaySVG !== "undefined") && <SubgraphOverlaySVG state={state} />}

        {/* row 3 — three renderers + view */}
        {["I", "S", "A", "V"].map((id) => {
          const n = nodeById(id);
          const overrideLabel = id === "A" ? (isLabelEdit ? labelAfterEdit : "positioned") : undefined;
          const selected = (isNodeSel && id === "A") || (groupSel && (id === "I" || id === "S" || id === "A"));
          return <NodeRectV key={id} n={n} overrideLabel={overrideLabel} selected={selected} />;
        })}
        <Arrow d="M422 260 C 422 286, 117 286, 117 332" />
        <Arrow d="M442 260 L 317 332" />
        <Arrow d="M462 260 L 517 332" />
        <Arrow d="M482 260 C 482 286, 743 286, 743 332" />

        {/* error path */}
        <NodeRectV n={nodeById("E")} />
        <Arrow d="M460 226 L 720 220" dashed label="throws" labelXY={[590, 215]} />

        {/* Edge-drag preview (state 3) — a tentative ghost connector from G to a blank-area cursor */}
        {isEdgeDrag && (
          <g>
            <path d={`M540 228 Q 700 244, ${dragTarget.x} ${dragTarget.y}`}
                  stroke="var(--accent)" strokeWidth="1.6" fill="none"
                  strokeDasharray="5 3" markerEnd="url(#dk-arrow-accent)" />
            {/* ghost target node */}
            <rect x={dragTarget.x - 80} y={dragTarget.y - 18} width="140" height="36"
                  rx="8" fill="rgba(10,132,255,0.10)" stroke="var(--accent)" strokeDasharray="3 3" strokeWidth="1.3" />
            <text x={dragTarget.x} y={dragTarget.y + 5} textAnchor="middle"
                  fill="var(--accent)" fontFamily="var(--font-mono)" fontSize="11" fontWeight="600">
              type a label…
            </text>
            <circle cx={540} cy={228} r="4" fill="var(--accent)" />
            {/* Waypoint drag handles along the polyline */}
            {waypoints.map((wp, i) => (
              <g key={i}>
                <circle cx={wp.x} cy={wp.y} r={wp.active ? 5.5 : 4}
                        fill={wp.active ? "var(--accent)" : "#1C1C1E"}
                        stroke="var(--accent)" strokeWidth={wp.active ? 2 : 1.2} />
                {wp.active && <circle cx={wp.x} cy={wp.y} r="10" fill="none" stroke="var(--accent)" strokeOpacity="0.4" strokeWidth="1" />}
              </g>
            ))}
          </g>
        )}
      </svg>

      {/* Selection ring around 'A' node (states 1, 2, 4) */}
      {isNodeSel && (
        <div className="sel-ring" style={{
          left: selNode.x - 4, top: selNode.y - 4,
          width: selNode.w + 8, height: selNode.h + 8,
        }}>
          <span className="corn tl" /><span className="corn tr" />
          <span className="corn bl" /><span className="corn br" />
        </div>
      )}
    </div>
  );
}

// Variant NodeRect that supports selection + label override
function NodeRectV({ n, overrideLabel, selected }) {
  const x = n.x, y = n.y, w = n.w, h = n.h;
  const corner = n.shape === "decision" ? 0 : n.shape === "rounded" ? 14 : 6;
  const fill =
    n.style === "ok" ? "rgba(48,209,88,0.12)" :
    n.style === "warn" ? "rgba(255,159,10,0.12)" :
    "#2C2C2E";
  const stroke =
    n.style === "ok" ? "var(--status-success)" :
    n.style === "warn" ? "var(--status-warning)" :
    "rgba(255,255,255,0.20)";
  const label = overrideLabel != null ? overrideLabel : n.label;
  return (
    <g>
      <rect x={x} y={y} width={w} height={h} rx={corner} ry={corner}
            fill={fill} stroke={selected ? "var(--accent)" : stroke}
            strokeWidth={selected ? 1.5 : 1} />
      <text x={x + w / 2} y={y + h / 2 - 2} textAnchor="middle" className="node-text">{label}</text>
      {n.sub && <text x={x + w / 2} y={y + h / 2 + 12} textAnchor="middle" className="node-sub">{n.sub}</text>}
    </g>
  );
}

// Floating node-edit popover (state 1, 2 — anchored to right of 'A')
function NodeEditPopover({ state, x, y }) {
  const editing = state === 2;
  return (
    <div className="node-popover" style={{ left: x, top: y }}>
      <div className="ttl">
        Node · selected
        <span className="grow" />
        <span className="stableid">node:A</span>
      </div>
      <label>Label</label>
      <input type="text" defaultValue={editing ? "positioned · ASCII" : "positioned"}
             style={editing ? { borderColor: "var(--accent)", boxShadow: "0 0 0 3px var(--accent-15)" } : undefined} />
      <label>Sub-label</label>
      <input type="text" defaultValue="renderASCII · String" />
      <label>Shape</label>
      <div className="shape-row">
        <div className="sh"><svg width="22" height="14" viewBox="0 0 22 14"><rect x="1" y="1" width="20" height="12" rx="1.5" fill="none" stroke="currentColor" strokeWidth="1.2" /></svg></div>
        <div className="sh on"><svg width="22" height="14" viewBox="0 0 22 14"><rect x="1" y="1" width="20" height="12" rx="5" fill="none" stroke="currentColor" strokeWidth="1.2" /></svg></div>
        <div className="sh"><svg width="22" height="14" viewBox="0 0 22 14"><polygon points="11,1 21,7 11,13 1,7" fill="none" stroke="currentColor" strokeWidth="1.2" /></svg></div>
        <div className="sh"><svg width="22" height="14" viewBox="0 0 22 14"><rect x="1" y="1" width="20" height="12" rx="6" fill="none" stroke="currentColor" strokeWidth="1.2" /><line x1="6" y1="1" x2="6" y2="13" stroke="currentColor" strokeWidth="0.5" /><line x1="16" y1="1" x2="16" y2="13" stroke="currentColor" strokeWidth="0.5" /></svg></div>
      </div>
      <label>Style class</label>
      <div className="style-row">
        <span className="cls">default</span>
        <span className="cls on">ok</span>
        <span className="cls">warn</span>
        <span className="cls">err</span>
        <span className="cls">muted</span>
      </div>
      <div className="popover-foot">
        <span>⌫ delete · ↵ commit</span>
        <span className="grow" />
        <span className="ed-pill">DiagramEditor.perform(.setLabel)</span>
      </div>
    </div>
  );
}

// Edge popover (state 3 — anchored to the dragged edge midpoint)
function EdgeEditPopover({ x, y }) {
  return (
    <div className="edge-popover" style={{ left: x, top: y }}>
      <div className="ttl" style={{ fontSize: 10, fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.5px", color: "var(--fg3)", marginBottom: 8, display: "flex", alignItems: "center", gap: 6 }}>
        Edge · new
        <span style={{ flex: 1 }} />
        <span className="stableid" style={{ fontFamily: "var(--font-mono)", fontSize: 9.5, color: "var(--fg2)", padding: "1px 5px", borderRadius: 3, background: "rgba(255,255,255,0.06)", textTransform: "none", letterSpacing: 0 }}>edge:G→…</span>
      </div>
      <label style={{ display: "block", fontSize: 10.5, color: "var(--fg2)", marginBottom: 4 }}>Style</label>
      <div className="seg">
        <button className="on">solid</button>
        <button>dashed</button>
        <button>dotted</button>
      </div>
      <label style={{ display: "block", fontSize: 10.5, color: "var(--fg2)", marginTop: 8, marginBottom: 4 }}>Arrowhead</label>
      <div className="seg">
        <button>none</button>
        <button className="on">→</button>
        <button>↔</button>
      </div>
      <label style={{ display: "block", fontSize: 10.5, color: "var(--fg2)", marginTop: 8, marginBottom: 4 }}>Waypoints</label>
      <div className="wp-row">
        <div className="wp-track">
          <span className="wp-line" />
          <span className="wp-pt" style={{ left: "6%" }} />
          <span className="wp-pt" style={{ left: "32%" }} />
          <span className="wp-pt active" style={{ left: "54%" }} />
          <span className="wp-pt" style={{ left: "94%" }} />
        </div>
        <button className="wp-auto" title="Reset waypoints">Auto-route</button>
      </div>
      <div className="wp-tip">waypoint 2/3 · (x: 612, y: 224)</div>
      <div className="popover-foot" style={{ marginTop: 10, paddingTop: 8, borderTop: "0.5px solid var(--border-hairline)", display: "flex", alignItems: "center", gap: 6, fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--fg3)" }}>
        <span>↵ commits as</span>
        <span className="ed-pill">FlowchartMutation.insertEdge</span>
      </div>
    </div>
  );
}

// State stepper at bottom of visual canvas
function StateStepper({ value, onChange }) {
  const steps = [
    { id: 0, label: "Idle", n: "0" },
    { id: 1, label: "Node sel", n: "1" },
    { id: 2, label: "Label edited", n: "2" },
    { id: 3, label: "Edge drag", n: "3" },
    { id: 4, label: "Undo", n: "4" },
    { id: 5, label: "Marquee", n: "5" },
    { id: 6, label: "Subgraph", n: "6" },
  ];
  return (
    <div className="state-stepper">
      <span className="lbl">State</span>
      <div className="steps">
        {steps.map((s) => (
          <span key={s.id} className={"step" + (value === s.id ? " on" : "")} onClick={() => onChange && onChange(s.id)}>
            <span className="n">{s.n}</span>{s.label}
          </span>
        ))}
      </div>
      <div className="nav">
        <button onClick={() => onChange && onChange(Math.max(0, value - 1))}>‹</button>
        <button onClick={() => onChange && onChange(Math.min(steps.length - 1, value + 1))}>›</button>
      </div>
    </div>
  );
}

// Undo/redo timeline scrubber
function UndoTimeline({ state }) {
  // Undo stack reflects current visual-mode state.
  // Past actions land left-of-cursor; redo is right-of-cursor.
  const entries = [
    { k: ".noop",     m: "open Pipeline.mmd",  ts: "21m" },
    { k: ".setLabel", m: "Source label fix",  ts: "8m" },
    { k: ".setLabel", m: 'rename "A" label',   ts: "2m" },
  ];
  if (state >= 2) entries.push({ k: ".setLabel", m: "positioned → positioned · ASCII", ts: "now" });
  if (state >= 3) entries.push({ k: ".insertEdge", m: "G → (new node)", ts: "now" });
  const cursor = state === 4 ? entries.length - 2 : entries.length - 1;

  return (
    <div className="undo-timeline">
      <span className="ttl">undoManager</span>
      {entries.map((e, i) => {
        const future = i > cursor;
        const cur = i === cursor;
        return (
          <React.Fragment key={i}>
            {i > 0 && <span className="arrow">›</span>}
            <span className={"ent" + (cur ? " cur" : "") + (future ? " future" : "")}>
              <span className="k">{e.k}</span>
              <span className="m">{e.m}</span>
            </span>
          </React.Fragment>
        );
      })}
    </div>
  );
}

// Floating tool palette on the canvas
function VisualToolPalette({ tool, onTool }) {
  const tools = [
    { id: "select",    Ic: Icon.Pointer,   t: "Select" },
    { id: "hand",      Ic: Icon.Hand,      t: "Pan" },
    { id: "marquee",   Ic: Icon.Marquee,   t: "Marquee (group)" },
    { id: "connector", Ic: Icon.Connector, t: "Drag edge from node" },
  ];
  return (
    <div className="visual-tool">
      {tools.map((tt) => (
        <button key={tt.id} className={tool === tt.id ? "on" : ""} onClick={() => onTool && onTool(tt.id)} title={tt.t}><tt.Ic /></button>
      ))}
      <div className="div" />
      <button title="Undo (⌘Z)"><Icon.Undo /></button>
      <button title="Redo (⇧⌘Z)"><Icon.Redo /></button>
    </div>
  );
}

// Diagnostic-driven quick-fix card (shown in states 1, 2)
function QuickFix({ x, y, applied }) {
  return (
    <div className="diag-hover" style={{ left: x, top: y, width: 320 }}>
      <div className="arrow" />
      <div>
        <span className="cat">.lossyTransform · DK1208</span>
        <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--fg3)" }}>Ln 12</span>
      </div>
      <div style={{ marginTop: 6, fontWeight: 500, color: "var(--fg1)" }}>
        Label "positioned" is wider than node — wrapping at render time.
      </div>
      <div className="code-line">
        <span style={{ color: "var(--fg3)" }}>// Source/A node</span><br />
        <span style={{ color: "#64D2FF" }}>A</span>[<span style={{ color: "#30D158" }}>"positioned"</span>]
      </div>
      <div className="actions">
        {applied ? (
          <span className="kpill ok" style={{ fontSize: 10 }}><span className="d" /> applied · rename</span>
        ) : (<>
          <button className="fixbtn">Rename label →</button>
          <button className="fixbtn alt">Widen node</button>
          <button className="fixbtn alt">Wrap text</button>
        </>)}
      </div>
    </div>
  );
}

// Sub-sample badge shown top-right of canvas — what tool / what's hot
function SelectionHUD({ state }) {
  const labels = {
    0: "Pointer · nothing selected",
    1: 'DiagramSelection · node:A',
    2: 'DiagramEditor.perform(.setLabel(of: node:A, …))',
    3: 'Dragging edge · G → newNode',
    4: 'undoManager.undo() · Set Label',
  };
  return (
    <div style={{ position: "absolute", top: 12, right: 14, zIndex: 4 }}>
      <KPill tone="accent" dot>{labels[state] || ""}</KPill>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// SEQUENCE DIAGRAM — message-drag visual editing
// ─────────────────────────────────────────────────────────────
function SequenceEditCanvas({ dragging }) {
  // 4 participants + 6 messages. We draw lifelines + messages, and show
  // a drag indicator hovering between messages 2 and 3 → reordering.
  const px = [60, 220, 380, 540, 720];
  const participants = ["Engine", "Pipeline", "Loader", "Parser", "Layout"];
  const baseY = 90;
  const rowH = 56;
  const messages = [
    { from: 0, to: 1, label: "render(source:)", note: ".async throws" },
    { from: 1, to: 2, label: "parseImportResult(_:)", note: "DiagramLoader" },
    { from: 2, to: 3, label: "probe → MermaidImporter", note: "first match wins" },
    { from: 3, to: 2, label: "DiagramImportResult", note: "{ document, diagnostics }", ret: true },
    { from: 1, to: 4, label: "GraphLayout.layout(_:)", note: "PositionedGraph" },
    { from: 4, to: 0, label: "PreparedDiagram", note: ".diagnostics aggregated", ret: true },
  ];
  // For drag state: pull msg index 2 down between msg 4 and 5 (ghost line at insertion point)
  const dragMsgIdx = 2;
  const ghostInsertAfter = 4; // ghost line sits after msg 4

  return (
    <div style={{ position: "relative", width: 800, height: 480 }}>
      <svg viewBox="0 0 800 480" width="800" height="480" className="diagram-svg">
        <ArrowDefs />
        {/* Lifelines */}
        {participants.map((p, i) => (
          <g key={p}>
            <rect x={px[i] - 50} y={32} width="100" height="32" rx="6"
                  fill="rgba(255,255,255,0.04)" stroke="rgba(255,255,255,0.18)" />
            <text x={px[i]} y={52} textAnchor="middle" className="node-text" style={{ fontSize: 12 }}>{p}</text>
            <line x1={px[i]} y1={64} x2={px[i]} y2={460}
                  stroke="rgba(255,255,255,0.18)" strokeWidth="0.8" strokeDasharray="3 3" />
          </g>
        ))}
        {/* Messages */}
        {messages.map((m, i) => {
          const y = baseY + i * rowH;
          const x1 = px[m.from], x2 = px[m.to];
          const dir = x2 >= x1 ? 1 : -1;
          const isDragged = dragging && i === dragMsgIdx;
          if (isDragged) return null;
          // shift messages 5+ down by one row if we're dragging
          const shift = (dragging && i > dragMsgIdx && i <= ghostInsertAfter) ? -rowH : 0;
          const drawY = y + shift;
          // arrow body
          const arrowD = `M${x1 + dir * 8} ${drawY} L${x2 - dir * 8} ${drawY}`;
          return (
            <g key={i}>
              {/* drag-handle hover ring around the row */}
              <rect x={Math.min(x1, x2) - 28} y={drawY - 14} width={Math.abs(x2 - x1) + 56} height={28}
                    rx="4" className="seq-msg-handle" />
              <path d={arrowD}
                    stroke={m.ret ? "rgba(255,255,255,0.55)" : "rgba(255,255,255,0.85)"}
                    strokeWidth={m.ret ? 1.2 : 1.4}
                    strokeDasharray={m.ret ? "4 3" : undefined}
                    markerEnd="url(#dk-arrow)" fill="none" />
              <text x={(x1 + x2) / 2} y={drawY - 6} textAnchor="middle" className="node-text" style={{ fontSize: 11.5 }}>
                {m.label}
              </text>
              <text x={(x1 + x2) / 2} y={drawY + 12} textAnchor="middle" className="node-sub" style={{ fontSize: 10 }}>
                {m.note}
              </text>
            </g>
          );
        })}

        {/* Ghost insertion line in drag state */}
        {dragging && (
          <g>
            <line x1={50} y1={baseY + ghostInsertAfter * rowH - 26}
                  x2={750} y2={baseY + ghostInsertAfter * rowH - 26}
                  className="seq-ghost-line" />
            <text x={400} y={baseY + ghostInsertAfter * rowH - 30}
                  textAnchor="middle"
                  fontFamily="var(--font-mono)" fontSize="10" fill="var(--accent)">
              insert "probe → MermaidImporter" here · reorders messages 2 ↔ 5
            </text>
          </g>
        )}
      </svg>

      {/* Drag pill follows the cursor */}
      {dragging && (
        <div className="seq-drag-pill" style={{ left: 380, top: baseY + ghostInsertAfter * rowH - 50 }}>
          ↕ probe → MermaidImporter
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// GANTT — date-bar drag-to-resize visual editing
// ─────────────────────────────────────────────────────────────
function GanttEditCanvas({ dragBar }) {
  const rows = [
    { sec: "Foundations", t: "Tokens · Parser core",     start: 0,  len: 18, status: "done" },
    { sec: "Foundations", t: "Layouts",                  start: 4,  len: 22, status: "done" },
    { sec: "Renderers",   t: "SVG backend",              start: 18, len: 14, status: "done" },
    { sec: "Renderers",   t: "CG image backend",         start: 22, len: 16, status: "done" },
    { sec: "Renderers",   t: "ASCII backend",            start: 30, len: 10, status: "done" },
    { sec: "Importers",   t: "D2 + DOT",                 start: 40, len: 12, status: "done" },
    { sec: "Importers",   t: "Structurizr",              start: 48, len: 8,  status: "done" },
    { sec: "Importers",   t: "PlantUML · sequence",      start: 54, len: 10, status: "done" },
    { sec: "Importers",   t: "PlantUML · class/state",   start: 64, len: 12, status: "active" },
    { sec: "Polish",      t: "Diagram-prefix rename",    start: 70, len: 6,  status: "done" },
    { sec: "Polish",      t: "Snapshot baselines",       start: 76, len: 8,  status: "active" },
    { sec: "Next",        t: "Exporter coverage · 28",   start: 84, len: 16, status: "pending" },
    { sec: "Next",        t: "Portable text shim",       start: 86, len: 14, status: "pending" },
  ];
  // Drag scenario: row 8 (PlantUML · class/state) being extended from 12w → 18w
  const dragRowIdx = 8;
  const dragExtensionWeeks = 6;

  const X0 = 200, X1 = 760;
  const total = 100;
  const xOf = (n) => X0 + (n / total) * (X1 - X0);
  const colors = {
    done:    { fill: "rgba(48,209,88,0.30)",    stroke: "var(--status-success)" },
    active:  { fill: "var(--accent-25)",        stroke: "var(--accent)" },
    pending: { fill: "rgba(255,255,255,0.06)",  stroke: "rgba(255,255,255,0.25)" },
  };

  const rowH = 24;
  const top = 70;

  // build section bands
  const sections = [];
  let prev = null;
  rows.forEach((r, i) => { if (r.sec !== prev) { sections.push({ sec: r.sec, start: i }); prev = r.sec; } });
  sections.forEach((s, i) => { s.end = (i + 1 < sections.length ? sections[i + 1].start : rows.length) - 1; });

  // For tooltip on drag row
  const draggedRow = rows[dragRowIdx];
  const dragNewLen = draggedRow.len + (dragBar ? dragExtensionWeeks : 0);
  const dragX = xOf(draggedRow.start);
  const dragW = xOf(draggedRow.start + dragNewLen) - dragX;

  return (
    <div style={{ position: "relative", width: 800, height: 440 }}>
      <svg viewBox="0 0 800 440" width="800" height="440" className="diagram-svg">
        <ArrowDefs />
        <text x="40" y="32" className="node-text" style={{ fontSize: 14, fontWeight: 600 }}>DiagramKit · Phases 0–10 + roadmap</text>
        <text x="40" y="50" className="node-sub">gantt · weeks (relative)</text>

        {/* axis */}
        <line x1={X0} y1={64} x2={X1} y2={64} stroke="rgba(255,255,255,0.18)" />
        {[0, 20, 40, 60, 80, 100].map((t) => (
          <g key={t}>
            <line x1={xOf(t)} y1={60} x2={xOf(t)} y2={68} stroke="rgba(255,255,255,0.22)" />
            <text x={xOf(t)} y={56} textAnchor="middle" className="node-sub" fontSize="9.5">w{t}</text>
          </g>
        ))}
        {[20, 40, 60, 80].map((t) => (
          <line key={t} x1={xOf(t)} y1={70} x2={xOf(t)} y2={70 + rows.length * rowH + 10} stroke="rgba(255,255,255,0.06)" />
        ))}

        {/* section bands */}
        {sections.map((s, i) => {
          const y0 = top + s.start * rowH;
          const h = (s.end - s.start + 1) * rowH;
          const fill = i % 2 === 0 ? "rgba(255,255,255,0.02)" : "transparent";
          return (
            <g key={s.sec}>
              <rect x={20} y={y0} width={X1 - 20} height={h} fill={fill} />
              <text x={32} y={y0 + 14} className="node-sub" fill="rgba(235,235,245,0.85)" style={{ fontWeight: 600 }}>{s.sec}</text>
            </g>
          );
        })}

        {/* rows */}
        {rows.map((r, i) => {
          const y = top + i * rowH + 4;
          const c = colors[r.status];
          let x = xOf(r.start);
          let w = xOf(r.start + r.len) - x;
          const isDragged = dragBar && i === dragRowIdx;
          if (isDragged) { w = dragW; }
          return (
            <g key={i} className={"gantt-bar" + (isDragged ? " dragging" : "")}>
              <text x={196} y={y + 12} textAnchor="end" className="node-text" style={{ fontSize: 11 }}>{r.t}</text>
              <rect x={x} y={y + 2} width={w} height={14} rx={3}
                    fill={c.fill} stroke={isDragged ? "var(--accent)" : c.stroke} strokeWidth={isDragged ? 1.5 : 1} />
              {r.status === "active" && (
                <rect x={x} y={y + 2} width={w * 0.65} height={14} rx={3} fill="var(--accent)" fillOpacity="0.55" />
              )}
              {/* End-resize handle */}
              <rect x={x + w - 4} y={y + 1} width={6} height={16} rx="1"
                    className={"gantt-bar-handle" + (isDragged ? " show" : "")} />
            </g>
          );
        })}

        {/* today */}
        <line x1={xOf(82)} y1={64} x2={xOf(82)} y2={top + rows.length * rowH + 8}
              stroke="var(--accent)" strokeOpacity="0.7" strokeDasharray="3 3" />
        <rect x={xOf(82) - 22} y={64 - 14} width="44" height="13" rx="3" fill="var(--accent)" />
        <text x={xOf(82)} y={64 - 4} textAnchor="middle" fill="#fff" fontFamily="var(--font-mono)" fontSize="9.5" fontWeight="700">TODAY</text>

        {/* Drag end-of-bar accent line (state: dragBar) */}
        {dragBar && (
          <g>
            <line x1={dragX + dragW} y1={top + dragRowIdx * rowH - 4}
                  x2={dragX + dragW} y2={top + dragRowIdx * rowH + 24}
                  stroke="var(--accent)" strokeWidth="1.2" />
          </g>
        )}
      </svg>

      {/* Drag tooltip */}
      {dragBar && (
        <div className="gantt-tooltip" style={{ left: dragX + dragW + 12, top: top + dragRowIdx * rowH }}>
          {draggedRow.t} · <span className="delta">+{dragExtensionWeeks}w</span>
          <div style={{ color: "var(--fg3)", marginTop: 2 }}>
            2026-05-04 → 2026-09-21
          </div>
        </div>
      )}
    </div>
  );
}

Object.assign(window, {
  FlowchartEditCanvas,
  NodeEditPopover,
  EdgeEditPopover,
  StateStepper,
  UndoTimeline,
  VisualToolPalette,
  QuickFix,
  SelectionHUD,
  SequenceEditCanvas,
  GanttEditCanvas,
  FLOW_NODES,
});
