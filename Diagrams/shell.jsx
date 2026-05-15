// shell.jsx — Reusable playground chrome for v2 artboards
//
// Source citations (where each panel maps in ajmcclary/DiagramKit @ main):
//   Titlebar mode seg     → workspace state (artifact-only — not in repo)
//   Render-backend seg    → Sources/DiagramKit/DiagramPipeline.swift (renderImage/SVG/ASCII)
//   Library + format chips→ Sources/DiagramKitImport/ImporterRegistry + DiagramLoader
//   Inspector · Document  → Sources/DiagramKit/DiagramDocument.swift + DiagramImportResult
//   Inspector · Theme     → Sources/DiagramKitCommon/src_theme.swift
//   Inspector · Diagnostics → Sources/DiagramKitCommon/DiagramDiagnostic.swift
//   Status · 8MB worker   → Sources/DiagramKit/DiagramEngine.swift (_runOnWorker)
//   Status · fonts        → Sources/DiagramKitRenderingCG/FontRegistry (Noto Sans · Mono)

const { useState, useEffect, useMemo, useRef } = React;

// ====================== Icons (SF-shaped SVG substitutes) ======================
const Icon = {
  Search: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
      <circle cx="7" cy="7" r="4.5" /><line x1="10.5" y1="10.5" x2="14" y2="14" />
    </svg>
  ),
  Plus: () => (
    <svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
      <path d="M8 3v10M3 8h10" />
    </svg>
  ),
  Sidebar: () => (
    <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.2">
      <rect x="2" y="3" width="12" height="10" rx="1.5" /><line x1="6.5" y1="3" x2="6.5" y2="13" />
    </svg>
  ),
  Inspector: () => (
    <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.2">
      <rect x="2" y="3" width="12" height="10" rx="1.5" /><line x1="10.5" y1="3" x2="10.5" y2="13" />
    </svg>
  ),
  Play: () => (
    <svg width="11" height="11" viewBox="0 0 16 16" fill="currentColor"><path d="M4 3.2v9.6L13 8z" /></svg>
  ),
  Refresh: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
      <path d="M3 8a5 5 0 019-3l1.5 1.5M13 8a5 5 0 01-9 3L2.5 9.5" /><path d="M13.5 3v3.5H10M2.5 13V9.5H6" />
    </svg>
  ),
  Share: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
      <path d="M8 10V2M5 5l3-3 3 3" /><path d="M3.5 9v3.5A1.5 1.5 0 005 14h6a1.5 1.5 0 001.5-1.5V9" />
    </svg>
  ),
  Doc: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.2">
      <path d="M3.5 2h6L12.5 5v9h-9z" /><path d="M9.5 2v3h3" />
    </svg>
  ),
  Folder: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.2">
      <path d="M2 5.5A1.5 1.5 0 013.5 4h2.586a1.5 1.5 0 011.06.44l.708.706A1.5 1.5 0 008.914 5.5H12.5A1.5 1.5 0 0114 7v4.5A1.5 1.5 0 0112.5 13h-9A1.5 1.5 0 012 11.5z" />
    </svg>
  ),
  Family: ({ glyph, color }) => (
    <span style={{ fontFamily: "var(--font-mono)", fontWeight: 600, fontSize: 12, color: color || "currentColor" }}>{glyph}</span>
  ),
  ZoomIn: () => (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round">
      <circle cx="7" cy="7" r="4" /><line x1="10" y1="10" x2="14" y2="14" /><line x1="5" y1="7" x2="9" y2="7" /><line x1="7" y1="5" x2="7" y2="9" />
    </svg>
  ),
  ZoomOut: () => (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round">
      <circle cx="7" cy="7" r="4" /><line x1="10" y1="10" x2="14" y2="14" /><line x1="5" y1="7" x2="9" y2="7" />
    </svg>
  ),
  Fit: () => (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 6V3h3M13 6V3h-3M3 10v3h3M13 10v3h-3" />
    </svg>
  ),
  Copy: () => (
    <svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3">
      <rect x="3" y="3" width="8" height="8" rx="1" /><path d="M5.5 5.5h8v8h-8z" />
    </svg>
  ),
  Warning: () => (
    <svg width="10" height="10" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1.5l7 12h-14z" stroke="#1C1C1E" strokeWidth="0.5" /><path d="M8 7v3M8 11.5v0.5" stroke="#1C1C1E" strokeWidth="1.2" fill="none" strokeLinecap="round" /></svg>
  ),
  Info: () => (
    <svg width="10" height="10" viewBox="0 0 16 16" fill="currentColor"><circle cx="8" cy="8" r="7" stroke="#1C1C1E" strokeWidth="0.5" /><path d="M8 7v4M8 5v0.5" stroke="#1C1C1E" strokeWidth="1.2" strokeLinecap="round" fill="none" /></svg>
  ),
  Dot: () => (<svg width="6" height="6" viewBox="0 0 6 6"><circle cx="3" cy="3" r="2.5" fill="currentColor" /></svg>),
  Settings: () => (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.2">
      <circle cx="8" cy="8" r="2.2" /><path d="M8 1.5v1.8M8 12.7v1.8M14.5 8h-1.8M3.3 8H1.5M12.6 3.4l-1.3 1.3M4.7 11.3l-1.3 1.3M12.6 12.6l-1.3-1.3M4.7 4.7L3.4 3.4" />
    </svg>
  ),
  Code: () => (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5.5 11L2 8l3.5-3M10.5 11L14 8l-3.5-3" />
    </svg>
  ),
  Visual: () => (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4">
      <circle cx="5" cy="5" r="2" /><circle cx="11" cy="11" r="2" /><line x1="6.5" y1="6.5" x2="9.5" y2="9.5" strokeLinecap="round" />
    </svg>
  ),
  Split: () => (
    <svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3">
      <rect x="2" y="3" width="12" height="10" rx="1.5" /><line x1="8" y1="3" x2="8" y2="13" />
    </svg>
  ),
  Pointer: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor"><path d="M3 2l9 5-4 1.2-1.2 4z" /></svg>
  ),
  Hand: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3">
      <path d="M6 6v3M8 5v4M10 6v3M5.5 8c0 4 2 5.5 3 5.5s3.5-1.5 3.5-5.5V5.5a.8.8 0 00-1.6 0v2M4.5 9.5C4.5 7 5.5 7 5.5 8" />
    </svg>
  ),
  Marquee: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3" strokeDasharray="2 2">
      <rect x="2.5" y="2.5" width="11" height="11" rx="1" />
    </svg>
  ),
  Connector: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round">
      <circle cx="4" cy="4" r="1.5" /><circle cx="12" cy="12" r="1.5" /><path d="M5 5l6 6" />
    </svg>
  ),
  Undo: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round">
      <path d="M3 7h6.5a3.5 3.5 0 010 7H8M3 7l3-3M3 7l3 3" />
    </svg>
  ),
  Redo: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round">
      <path d="M13 7H6.5a3.5 3.5 0 100 7H8M13 7l-3-3M13 7l-3 3" />
    </svg>
  ),
  ArrowLeft: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
      <path d="M10 4l-4 4 4 4" />
    </svg>
  ),
  ArrowRight: () => (
    <svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round">
      <path d="M6 4l4 4-4 4" />
    </svg>
  ),
  Close: () => (
    <svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
      <path d="M4 4l8 8M12 4l-8 8" />
    </svg>
  ),
  Chevron: () => (
    <svg width="10" height="10" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
      <path d="M5 5l3 3-3 3" />
    </svg>
  ),
};

// ====================== Brand mark ======================
function DKMark() {
  return (
    <span className="dk-mark">
      <svg width="13" height="13" viewBox="0 0 16 16" fill="none">
        <rect x="2" y="2" width="5" height="5" rx="1" fill="#fff" />
        <rect x="9" y="2" width="5" height="5" rx="1" fill="#fff" opacity="0.7" />
        <rect x="2" y="9" width="5" height="5" rx="1" fill="#fff" opacity="0.55" />
        <rect x="9" y="9" width="5" height="5" rx="1" fill="#fff" opacity="0.85" />
        <line x1="7" y1="4.5" x2="9" y2="4.5" stroke="#fff" strokeWidth="1" />
        <line x1="4.5" y1="7" x2="4.5" y2="9" stroke="#fff" strokeWidth="1" />
        <line x1="11.5" y1="7" x2="11.5" y2="9" stroke="#fff" strokeWidth="1" />
        <line x1="7" y1="11.5" x2="9" y2="11.5" stroke="#fff" strokeWidth="1" />
      </svg>
    </span>
  );
}

// "Placeholder" wrapper for any number sourced from BASELINES.md.
// Reviewers see a dotted underline + tooltip flagging the value for verification.
function Ph({ children, note }) {
  return (
    <span className="ph" title={note || "Verify against BASELINES.md"}>{children}</span>
  );
}

// Citation pin overlay — when t.showCitations is on, each pin marks where
// in Sources/* a panel's behaviour comes from.
function CitePin({ top, left, right, side = "left", label, num }) {
  const style = { top, left, right };
  return (
    <div className={"cite-pin " + (side === "right" ? "right" : "")} style={style} title={label}>
      {num != null && <span className="num">{num}</span>}{label}
    </div>
  );
}

// ====================== Toggle ======================
function Toggle({ on, onClick }) {
  return (
    <span onClick={onClick} style={{
      width: 30, height: 18, borderRadius: 9999,
      background: on ? "var(--accent)" : "rgba(255,255,255,0.10)",
      border: "0.5px solid " + (on ? "transparent" : "var(--border-subtle)"),
      position: "relative", display: "inline-block", transition: "background 0.2s", cursor: "pointer", flex: "0 0 auto",
    }}>
      <span style={{
        position: "absolute", top: 1.5, left: on ? 13 : 1.5,
        width: 14, height: 14, borderRadius: "50%", background: "#fff",
        boxShadow: "0 1px 2px rgba(0,0,0,0.3)", transition: "left 0.2s"
      }} />
    </span>
  );
}

// ====================== Workspace-mode segmented control ======================
// Replaces v1's SVG/Image/ASCII segment — that's a render backend, not a workspace mode.
function WorkspaceModeSeg({ mode, onMode }) {
  const modes = [
    { id: "code",   l: "Code",   Ic: Icon.Code },
    { id: "visual", l: "Visual", Ic: Icon.Visual },
    { id: "split",  l: "Split",  Ic: Icon.Split },
  ];
  return (
    <div className="mode-seg" role="tablist" aria-label="Workspace mode">
      {modes.map((m) => (
        <button key={m.id} className={mode === m.id ? "on" : ""} onClick={() => onMode && onMode(m.id)}>
          <span className="gx"><m.Ic /></span>{m.l}
        </button>
      ))}
    </div>
  );
}

// ====================== Titlebar ======================
function Titlebar({ mode, onMode, sample, onToggleSidebar, onToggleInspector }) {
  return (
    <div className="titlebar">
      <div className="titlebar-left">
        <span className="traffic">
          <span className="tl r" /><span className="tl y" /><span className="tl g" />
        </span>
        <button className="tb-btn icon-only" onClick={onToggleSidebar} title="Toggle sidebar"><Icon.Sidebar /></button>
        <div className="titlebar-doc">
          <Icon.Folder />
          <span className="crumb-dim">DiagramKit</span>
          <span className="crumb-sep">›</span>
          <span>{sample.fileName}</span>
          <span className="dirty" title="unsaved changes" />
        </div>
      </div>

      <div className="titlebar-center">
        <WorkspaceModeSeg mode={mode} onMode={onMode} />
      </div>

      <div className="titlebar-right">
        <button className="tb-btn"><Icon.Refresh /> Re-render <span className="kbd">⌘R</span></button>
        <button className="tb-btn"><Icon.Share /> Share</button>
        <button className="tb-btn primary"><Icon.Play /> Export <span className="kbd">⌘E</span></button>
        <button className="tb-btn icon-only" onClick={onToggleInspector} title="Toggle inspector"><Icon.Inspector /></button>
      </div>
    </div>
  );
}

// ====================== Statusbar ======================
function Statusbar({ backend, paint, sampleId }) {
  return (
    <div className="statusbar">
      <div className="seg"><span className="dot" /><span className="strong">DiagramEngine</span><span>· ready</span></div>
      <div className="seg"><span>worker thread · 8 MB stack</span></div>
      <div className="seg"><span>Swift</span> <span className="strong">6.3</span></div>
      <div className="seg"><span>fonts registered</span> <span className="strong">Noto Sans · Mono</span></div>
      <div className="grow" />
      <div className="seg"><span>backend</span> <span className="accent">{backend}</span></div>
      <div className="seg"><span>last render</span> <span className="strong">{paint}</span></div>
      <div className="seg"><Ph note="From BASELINES.md — verify on green ci"><span className="strong">1044</span> snapshots</Ph> <span style={{ color: "var(--status-success)" }}>● pass</span></div>
      <div className="seg"><Ph note="From BASELINES.md"><span className="strong">422</span> corpus</Ph></div>
      <div className="seg" style={{ paddingRight: 4 }}><span style={{ fontFamily: "var(--font-mono)" }}>{sampleId}</span></div>
    </div>
  );
}

// ====================== Sidebar ======================
function Sidebar({ activeId, onSelect, format }) {
  const formats = [
    { id: "mermaid",     label: "Mermaid" },
    { id: "d2",          label: "D2" },
    { id: "graphviz",    label: "DOT" },
    { id: "structurizr", label: "Structurizr" },
    { id: "plantuml",    label: "PlantUML" },
  ];
  return (
    <aside className="pane sidebar">
      <div className="pane-head">
        <DKMark />
        <div style={{ display: "flex", flexDirection: "column", lineHeight: 1.15 }}>
          <span style={{ fontSize: 13, fontWeight: 700, letterSpacing: "-0.005em", color: "var(--fg1)" }}>DiagramKit</span>
          <span style={{ fontSize: 10, color: "var(--fg2)", fontFamily: "var(--font-mono)" }}>v0.10.1 · <Ph note="From BASELINES.md">28 families</Ph></span>
        </div>
        <div className="grow" />
        <button className="icon-btn" title="New diagram"><Icon.Plus /></button>
      </div>

      <div className="lib-search">
        <Icon.Search />
        <input placeholder="Search · format · family · diagnostic state" defaultValue="" />
        <span className="kbd-hint">⌘K</span>
      </div>

      <div className="format-chips" role="tablist" aria-label="Source format">
        {formats.map((f) => (
          <span key={f.id} className={"chip" + (format === f.id ? " on" : "")}>
            <span className="dot" /> {f.label}
          </span>
        ))}
      </div>

      <div className="pane-scroll">
        <div className="lib-sec">Pinned</div>
        <div className="lib-nav">
          <div className="lib-row active"><span className="ic"><Icon.Folder /></span>Open documents <span className="count">3</span></div>
          <div className="lib-row"><span className="ic"><Icon.Doc /></span>Recent <span className="count">12</span></div>
          <div className="lib-row"><span className="ic"><Icon.Settings /></span>Corpus browser <span className="count"><Ph note="From BASELINES.md">422</Ph></span></div>
        </div>

        {SAMPLE_TREE.map((sec) => (
          <React.Fragment key={sec.sec}>
            <div className="lib-sec">{sec.sec}<span className="count">{sec.items.length}</span></div>
            <div className="lib-nav" style={{ paddingBottom: 4 }}>
              {sec.items.map((it) => {
                const live = SAMPLES.find((s) => s.id === it.id);
                const active = activeId === it.id;
                return (
                  <div key={it.id} className={"sample-row" + (active ? " active" : "")} onClick={() => live && onSelect && onSelect(it.id)}>
                    <span className="gylph"><Icon.Family glyph={FAMILY_ICON_MAP[it.family] || "▢"} /></span>
                    <div className="tk">
                      <span className="t">{it.title}</span>
                      <span className="a">{it.family}</span>
                    </div>
                    <span className="badge">{it.badge}</span>
                  </div>
                );
              })}
            </div>
          </React.Fragment>
        ))}
        {/* Snippets surface — restored in v2.1. Counts: 28 patterns, see v2-1.jsx SNIPPETS array. */}
        <div className="lib-sec">Library<span className="count">2</span></div>
        <div className="lib-nav" style={{ paddingBottom: 8 }}>
          <div className="lib-row"><span className="ic"><Icon.Doc /></span>Snippets <span className="count">28</span></div>
          <div className="lib-row"><span className="ic"><Icon.Settings /></span>Themes <span className="count">15</span></div>
        </div>
        <div style={{ height: 12 }} />
      </div>
    </aside>
  );
}

// ====================== Inspector ======================
function Inspector({ sample, backend, setBackend, theme, setTheme, accent, setAccent, showCitations, onShowCitations, extras }) {
  return (
    <aside className="pane inspector">
      <div className="pane-head">
        <span className="title">Inspector</span>
        <div className="grow" />
        <span className="pill-mini">{sample.format}</span>
      </div>

      <div className="pane-scroll">
        {/* Document */}
        <div className="insp-section">
          <h6><span>Document</span><span className="grow" /><span className="cite-key" title="Sources/DiagramKit/DiagramDocument.swift">DiagramDocument</span></h6>
          <div className="kv-grid">
            <span className="k">File</span><span className="v">{sample.fileName}</span>
            <span className="k">Family</span><span className="v">{sample.family}</span>
            <span className="k">Format</span><span className="v">{sample.format}</span>
            <span className="k">Nodes</span><span className="v">{sample.stats.nodes}</span>
            <span className="k">Edges</span><span className="v">{sample.stats.edges}</span>
            <span className="k">Layout</span><span className="v">{sample.stats.layout}</span>
            <span className="k">Paint</span><span className="v">{sample.stats.paint}</span>
            <span className="k">Bundled fonts</span><span className="v">Noto Sans · Mono</span>
          </div>
        </div>

        {/* Render backend (SVG/Image/ASCII — moved out of titlebar) */}
        <div className="insp-section">
          <h6><span>Render backend</span><span className="grow" /><span className="cite-key" title="Sources/DiagramKit/DiagramPipeline.swift">DiagramPipeline</span></h6>
          <div className="backend-seg" style={{ width: "100%" }}>
            {[
              { id: "svg",   l: "SVG",   g: "&lt;/&gt;" },
              { id: "image", l: "Image", g: "@2x" },
              { id: "ascii", l: "ASCII", g: "▦" },
            ].map((b) => (
              <button key={b.id} className={backend === b.id ? "on" : ""} style={{ flex: 1, justifyContent: "center" }} onClick={() => setBackend && setBackend(b.id)}>
                {b.l} <span className="glyph" dangerouslySetInnerHTML={{ __html: b.g }} />
              </button>
            ))}
          </div>
          <div className="kv-grid" style={{ marginTop: 10 }}>
            {backend === "svg" && (<>
              <span className="k">viewBox</span><span className="v">0 0 880 460</span>
              <span className="k">size</span><span className="v">{sample.stats.svg}</span>
              <span className="k">renderer</span><span className="v">renderSVG(_:)</span>
            </>)}
            {backend === "image" && (<>
              <span className="k">dimensions</span><span className="v">1760 × 920 px</span>
              <span className="k">scale</span><span className="v">2.0×</span>
              <span className="k">renderer</span><span className="v">DiagramImageRenderer</span>
            </>)}
            {backend === "ascii" && (<>
              <span className="k">cols</span><span className="v">80</span>
              <span className="k">renderer</span><span className="v">AsciiRenderOutput</span>
              <span className="k">coverage</span><span className="v">28 / 28 families</span>
            </>)}
          </div>
          <div className="toggle-row" style={{ marginTop: 12 }}>
            <span>Render on every keystroke</span><span className="grow" /><Toggle on />
          </div>
          <div className="toggle-row" style={{ marginTop: 8 }}>
            <span>Worker thread · 8 MB stack</span><span className="grow" /><Toggle on />
          </div>
        </div>

        {/* Theme */}
        <div className="insp-section">
          <h6><span>Theme</span><span className="grow" /><span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--fg3)" }}>%%{`{init:{theme}}%%`}</span></h6>
          <div className="theme-grid">
            {[
              { id: "dark",       lbl: "Dark",       cols: ["#1C1C1E", "#0A84FF", "#30D158"] },
              { id: "light",      lbl: "Light",      cols: ["#FFFFFF", "#007AFF", "#34C759"] },
              { id: "forest",     lbl: "Forest",     cols: ["#11221A", "#30D158", "#64D2FF"] },
              { id: "neutral",    lbl: "Neutral",    cols: ["#2C2C2E", "#A1A1A6", "#FFFFFF"] },
            ].map((t) => (
              <div key={t.id} className={"theme-sw" + (theme === t.id ? " on" : "")}
                   style={{ background: t.cols[0] }}
                   onClick={() => setTheme && setTheme(t.id)}>
                <span className="lbl">{t.lbl}</span>
                <span className="swatch">{t.cols.map((c, i) => <span key={i} style={{ background: c }} />)}</span>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 12, fontSize: 11, color: "var(--fg2)" }}>Accent</div>
          <div className="accent-row" style={{ marginTop: 6 }}>
            {["#0A84FF", "#5E5CE6", "#BF5AF2", "#64D2FF", "#30D158", "#FF9F0A", "#FF375F"].map((v) => (
              <span key={v} className={"acc" + (accent === v ? " on" : "")} style={{ background: v }} onClick={() => setAccent && setAccent(v)} />
            ))}
          </div>
        </div>

        {/* v2.1 extras — ThemeBuilder, Platform, Mutations cards */}
        {extras}

        {/* Diagnostics */}
        <div className="insp-section">
          <h6>
            <span>Diagnostics</span>
            <span className="grow" />
            <span className="cite-key" title="Sources/DiagramKitCommon/DiagramDiagnostic.swift">[DiagramDiagnostic]</span>
          </h6>
          {(sample.diagnostics || []).length === 0 && (
            <div style={{ fontSize: 11.5, color: "var(--fg3)" }}>No diagnostics. Source parses clean.</div>
          )}
          <div className="diag-list">
            {(sample.diagnostics || []).map((d, i) => (
              <div key={i} className={"diag-item " + d.severity}>
                <span className="ic">{d.severity === "warn" ? <Icon.Warning /> : <Icon.Info />}</span>
                <div>
                  <div className="msg">{d.msg}</div>
                  <div className="pos">{d.code} · Ln {d.line} · {d.cat || ".lossyTransform"}</div>
                </div>
                <span className="where">go →</span>
              </div>
            ))}
          </div>
        </div>

        {/* History */}
        <div className="insp-section">
          <h6><span>History</span><span className="grow" /><span className="cite-key" title="Sources/DiagramKitInteractive/DiagramEditor+Undo.swift">UndoManager</span></h6>
          <div style={{ position: "relative" }}>
            <div className="hist-trail" />
            {sample.history.map((h, i) => (
              <div key={i} className="hist-row">
                <span className={"dot" + (h.current ? " cur" : "")} />
                <span className="msg">{h.msg}</span>
                <span className="ts">{h.ts}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Source citations toggle */}
        <div className="insp-section">
          <h6><span>Source citations</span></h6>
          <div className="toggle-row">
            <span style={{ fontSize: 11.5 }}>Pin Sources/* refs on every panel</span>
            <span className="grow" />
            <Toggle on={showCitations} onClick={() => onShowCitations && onShowCitations(!showCitations)} />
          </div>
          <div style={{ fontSize: 10.5, color: "var(--fg3)", marginTop: 6, lineHeight: 1.4 }}>
            Reveals which file under <span style={{ fontFamily: "var(--font-mono)" }}>Sources/DiagramKit*/</span> each panel maps to — useful for engineering review.
          </div>
        </div>

        <div style={{ height: 12 }} />
      </div>
    </aside>
  );
}

// ====================== KPill (used widely) ======================
function KPill({ tone, children, dot, glyph }) {
  return (
    <span className={"kpill" + (tone ? " " + tone : "")}>
      {dot && <span className="d" />}{glyph}{children}
    </span>
  );
}

// ====================== Reusable Editor pane ======================
function EditorPane({ sample, openTabs, activeId, biSelLine, minimap, onSelect, onClose, onLineHover }) {
  const langDot = (s) => {
    if (s.format === "mermaid")     return "#FF9F0A";
    if (s.format === "d2")          return "#5E5CE6";
    if (s.format === "graphviz")    return "#BF5AF2";
    if (s.format === "structurizr") return "#64D2FF";
    if (s.format === "plantuml")    return "#FF375F";
    return "var(--fg2)";
  };
  const diags = sample.diagnostics || [];
  const totalLines = sample.source.length;
  return (
    <section className="pane editor">
      <div className="editor-stack">
        <div className="tabbar" role="tablist">
          {openTabs.map((s) => {
            const on = s.id === activeId;
            return (
              <div key={s.id} className={"tab" + (on ? " on" : "")} onClick={() => onSelect && onSelect(s.id)}>
                <span className="lang-dot" style={{ background: langDot(s) }} />
                <span>{s.fileName}</span>
                <span className="x" onClick={(e) => { e.stopPropagation(); onClose && onClose(s.id); }}>×</span>
              </div>
            );
          })}
          <div style={{ flex: 1 }} />
          <div style={{ display: "inline-flex", gap: 6, paddingRight: 6, alignItems: "center" }}>
            <KPill tone="ok" dot>parses</KPill>
            {diags.length > 0 && (
              <KPill tone="warn" dot>{diags.length} issue{diags.length === 1 ? "" : "s"}</KPill>
            )}
          </div>
        </div>

        <div className={"code-wrap" + (minimap ? " code-mode" : "")}>
          <div className="code-gutter">
            {sample.source.map((_, i) => {
              const ln = i + 1;
              const d = diags.find((d) => d.line === ln);
              const cls = "ln" + (d ? (d.severity === "warn" ? " warn" : d.severity === "info" ? " warn" : "") : "") + (ln === 2 ? " cur" : "");
              return <div className={cls} key={i}>{ln}</div>;
            })}
            <div style={{ height: 18 }} />
          </div>
          <pre className="code" style={{ position: "relative" }}>
            {sample.source.map((row, i) => {
              const ln = i + 1;
              const isCur = i === 1;
              const isBi = biSelLine === ln;
              const cls = "ln-row" + (isCur ? " cur" : "") + (isBi ? " bi-sel" : "");
              return (
                <span key={i} className={cls} onMouseEnter={() => onLineHover && onLineHover(ln)}>
                  {row.length === 0 ? "\u200b" : row.map(([cl, txt], j) => (
                    <span key={j} className={cl}>{txt}</span>
                  ))}
                  {"\n"}
                </span>
              );
            })}
            {/* Diagnostic strip */}
            <div className="diag-strip">
              {diags.map((d, i) => (
                <span key={i} className={"mk " + d.severity} style={{ top: (d.line - 0.5) * 19.7 }} />
              ))}
            </div>
          </pre>
          {minimap && (
            <div className="minimap">
              <div className="mm-lines">
                {sample.source.map((row, i) => {
                  let cls = "";
                  if (row[0]) {
                    if (row[0][0] === "tk-cmnt") cls = "cmnt";
                    else if (row[0][0] === "tk-kw" || (row[1] && row[1][0] === "tk-kw")) cls = "kw";
                  }
                  const isWarn = diags.find((d) => d.line === i + 1);
                  if (isWarn) cls = "warn";
                  // sniff text width — empty lines collapse
                  const w = Math.max(8, Math.min(100, row.reduce((acc, t) => acc + (t[1] ? t[1].length : 0), 0) * 1.5));
                  return <div key={i} className={"mm-row " + cls} style={{ width: w + "%" }} />;
                })}
              </div>
              <div className="mm-viewport" style={{
                top: 8,
                height: Math.min(200, (totalLines * 8) || 60),
              }} />
            </div>
          )}
        </div>

        <div className="editor-foot">
          <span>Ln 2, Col 14</span>
          <span className="sep">·</span>
          <span>{sample.source.length} lines</span>
          <span className="sep">·</span>
          <span>UTF-8</span>
          <span className="sep">·</span>
          <span>LF</span>
          <span className="sep">·</span>
          <span>{sample.format}</span>
          <span style={{ flex: 1 }} />
          {diags.length === 0
            ? <span className="ok">● parsed clean</span>
            : <span className="warn">▲ {diags.length} issue · {diags[0].code}</span>}
        </div>
      </div>
    </section>
  );
}

// ====================== Preview pane (for split/code modes) ======================
function PreviewPane({ sample, backend, theme, biSelNode, onNodeHover, renderHealth }) {
  const DiagramComp = sample.family === "flowchart" ? FlowchartDiagram
                    : sample.family === "timeline"  ? TimelineDiagram
                    : GanttDiagram;
  return (
    <section className="pane preview">
      <div className="preview-stack">
        <div className="preview-toolbar">
          <KPill tone="accent" glyph={<Icon.Family glyph={FAMILY_ICON_MAP[sample.family] || "▢"} />}>&nbsp;{sample.family}</KPill>
          <KPill glyph={<span className="d" style={{ background: "var(--fg3)" }} />}>&nbsp;{sample.stats.nodes}n · {sample.stats.edges}e</KPill>
          <div style={{ flex: 1, minWidth: 0 }} />
          {typeof RenderHealthPill !== "undefined"
            ? <RenderHealthPill renderHealth={renderHealth || "ok"} layoutMs={sample.stats.layout} paintMs={sample.stats.paint} />
            : <div className="pill-status"><span className="dot" /> {sample.stats.layout}</div>}
          <div className="zoom-group">
            <button title="Zoom out"><Icon.ZoomOut /></button>
            <span className="zlabel">100%</span>
            <button title="Zoom in"><Icon.ZoomIn /></button>
            <button title="Fit"><Icon.Fit /></button>
          </div>
        </div>

        <div className="preview-canvas">
          {backend === "svg" && (
            <div className="preview-frame">
              <DiagramComp biSelNode={biSelNode} onNodeHover={onNodeHover} />
            </div>
          )}
          {backend === "image" && (
            <div className="preview-frame" style={{ padding: 0, background: "transparent", boxShadow: "none", border: 0 }}>
              <PngBackend DiagramComp={DiagramComp} />
            </div>
          )}
          {backend === "ascii" && (
            <pre className="ascii-view">{ASCII_OUT[sample.family]}</pre>
          )}
        </div>

        <div className="preview-foot">
          <span>backend</span>
          <span className="stat-num">{backend === "image" ? "DiagramImageRenderer · @2x" : backend === "svg" ? "renderSVG" : "renderASCII"}</span>
          <span style={{ color: "var(--fg3)" }}>·</span>
          <span>theme</span>
          <span className="stat-num">{theme}</span>
          <span style={{ color: "var(--fg3)" }}>·</span>
          <span>fonts</span>
          <span className="stat-num">Noto Sans · Mono</span>
          <span style={{ flex: 1 }} />
          <span>parse <span className="stat-num">0.6 ms</span></span>
          <span style={{ color: "var(--fg3)" }}>·</span>
          <span>layout <span className="stat-num">{sample.stats.layout}</span></span>
          <span style={{ color: "var(--fg3)" }}>·</span>
          <span>paint <span className="stat-num">{sample.stats.paint}</span></span>
        </div>
      </div>
    </section>
  );
}

// Export to window so other Babel scripts pick them up
Object.assign(window, {
  Icon, DKMark, Ph, CitePin,
  Toggle, KPill,
  WorkspaceModeSeg, Titlebar, Statusbar, Sidebar, Inspector,
  EditorPane, PreviewPane,
});
