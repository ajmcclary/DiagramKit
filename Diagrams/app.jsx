// app.jsx — DiagramKit Playground v2 (design-canvas presentation)
//
// Eleven artboards across five sections, all sharing one playground shell.
// Tweaks drive workspace mode, active sample, visual-editing state,
// diagnostics drawer state, corpus selection, and a source-citation
// overlay that pins each panel to its Sources/* file.
//
// Source citations (where each panel maps in ajmcclary/DiagramKit @ main):
//   Workspace modes      → artifact-only (no repo equivalent — design)
//   Render backend       → Sources/DiagramKit/DiagramPipeline.swift
//   DiagramEditor + sel  → Sources/DiagramKitInteractive/DiagramEditor.swift
//   Mutations            → Sources/DiagramKitInteractive/DiagramMutation.swift
//   RoundTripHarness     → Sources/DiagramKitTestSupport/RoundTripHarness.swift
//   RoundTripLoss        → Sources/DiagramKitTestSupport/RoundTripLoss.swift
//   DiagnosticCategory   → Sources/DiagramKitCommon/DiagnosticCategory.swift
//   ExporterRegistry     → Sources/DiagramKitExport/ExporterRegistry.swift

// ─────────────────────────────────────────────────────────────
// Citation pins for the "Source citations" overlay (per artboard)
// ─────────────────────────────────────────────────────────────
const CITATION_SETS = {
  code: [
    { num: "1", side: "left",  top: 56,  left: 250,  label: "DiagramImportResult.diagnostics" },
    { num: "2", side: "left",  top: 96,  left: 270,  label: "Sources/DiagramKitCommon/DiagramDiagnostic.swift" },
    { num: "3", side: "right", top: 28,  right: 12,  label: "Sources/DiagramKitCommon/DiagnosticCategory.swift" },
    { num: "4", side: "left",  top: 868, left: 250,  label: "DiagramEngine._runOnWorker · 8 MB stack" },
    { num: "5", side: "right", top: 868, right: 332, label: "DiagramFontRegistry · Noto Sans + Mono" },
  ],
  visual: [
    { num: "1", side: "left",  top: 56,  left: 250, label: "DiagramSelection · element ID" },
    { num: "2", side: "left",  top: 160, left: 480, label: "Sources/DiagramKitInteractive/DiagramEditor.swift" },
    { num: "3", side: "left",  top: 360, left: 600, label: "DiagramMutation.setLabel(of:to:)" },
    { num: "4", side: "left",  top: 760, left: 380, label: "undoManager · DiagramEditor.canUndo" },
    { num: "5", side: "right", top: 152, right: 12, label: "DiagramKitInteractive/DiagramEditor+Mutations.swift" },
  ],
  split: [
    { num: "1", side: "left",  top: 56,  left: 250, label: "Mermaid source · ranges resolved at parse" },
    { num: "2", side: "left",  top: 96,  left: 680, label: "PositionedGraph.diagnostics — bidirectional sel" },
    { num: "3", side: "right", top: 84,  right: 12, label: "Sources/DiagramKit/DiagramPipeline.swift" },
    { num: "4", side: "right", top: 868, right: 12, label: "[DiagramDiagnostic] + UndoManager" },
  ],
  sequenceVisual: [
    { num: "1", side: "left",  top: 56,  left: 250, label: "PlantUMLSequenceExport · participant lifelines" },
    { num: "2", side: "left",  top: 350, left: 480, label: "DiagramEditor — message ordering mutation" },
  ],
  ganttVisual: [
    { num: "1", side: "left",  top: 56,  left: 250, label: "DIAGRAMKIT_GANTT_TODAY env var · BASELINES.md §1.3" },
    { num: "2", side: "left",  top: 540, left: 380, label: "FrontmatterBinding+Gantt.swift" },
  ],
  convert: [
    { num: "1", side: "left",  top: 132, left: 200, label: "RoundTripHarness.runCrossFormatRoundTrip" },
    { num: "2", side: "left",  top: 720, left: 200, label: "RoundTripLoss · 11 typed cases" },
    { num: "3", side: "right", top: 132, right: 200, label: "DiagramExportResult · diagnostics" },
  ],
  coverage: [
    { num: "1", side: "left",  top: 56,  left: 250, label: ".featureDropped(.diagramFamilyUnsupported)" },
    { num: "2", side: "right", top: 56,  right: 12, label: "ExporterRegistry · 5 format slices" },
  ],
  diagnostics: [
    { num: "1", side: "left",  top: 480, left: 250, label: "Tier · DiagramImportResult.diagnostics" },
    { num: "2", side: "right", top: 480, right: 332, label: "Tier · PositionedGraph.diagnostics" },
    { num: "3", side: "left",  top: 720, left: 250, label: "diagnosticsCover(loss:in:) typed-category equality" },
  ],
  export: [
    { num: "1", side: "left",  top: 132, left: 200, label: "DiagramExporter + ExporterRegistry" },
    { num: "2", side: "right", top: 700, right: 200, label: "RoundTripHarness · per-target check" },
  ],
  corpus: [
    { num: "1", side: "left",  top: 56,  left: 250, label: "Examples/DiagramPlayground/Resources/test-diagrams.json" },
    { num: "2", side: "right", top: 56,  right: 12, label: "Tests/DiagramKitTests/__Snapshots__/" },
  ],
  crossFormat: [
    { num: "1", side: "left",  top: 56,  left: 250, label: "Sources/DiagramKitMermaid/Exporter/" },
    { num: "2", side: "left",  top: 360, left: 480, label: "Sources/DiagramKitD2/D2Exporter.swift" },
    { num: "3", side: "right", top: 360, right: 280, label: "Sources/DiagramKitGraphviz/DOTExporter.swift" },
    { num: "4", side: "right", top: 820, right: 240, label: "RoundTripHarness.runCrossFormatRoundTrip" },
  ],
  subgraph: [
    { num: "1", side: "left",  top: 56,  left: 250, label: "DiagramSelection · marquee → [node:I, node:S, node:A]" },
    { num: "2", side: "left",  top: 560, left: 380, label: "DiagramEditor.perform(.groupIntoSubgraph) · design fiction" },
    { num: "3", side: "right", top: 152, right: 12, label: "Sources/DiagramKitInteractive/DiagramMutation.swift" },
  ],
  importerProbe: [
    { num: "1", side: "left",  top: 56,  left: 250, label: "Sources/DiagramKitImport/DiagramLoader.swift" },
    { num: "2", side: "left",  top: 420, left: 540, label: "Sources/DiagramKitImport/ImporterRegistry.swift · first-match-wins" },
    { num: "3", side: "right", top: 820, right: 240, label: "DiagramImportResult · { document, diagnostics }" },
  ],
  snippets: [
    { num: "1", side: "left",  top: 56,  left: 250, label: "Examples/DiagramPlayground/Resources/snippets/" },
    { num: "2", side: "right", top: 56,  right: 12, label: "DiagramFormatID · paste-ready insertion" },
  ],
};

// ─────────────────────────────────────────────────────────────
// One Playground shell that every artboard composes
// ─────────────────────────────────────────────────────────────
function Playground({
  mode,           // 'code' | 'visual' | 'split'
  sample,
  backend,
  theme,
  accent,
  state,          // visual-mode state stepper (0..6)
  visualFamily,   // 'flowchart' | 'sequence' | 'gantt' | undefined
  drawer,         // 'diagnostics' | undefined
  overlay,        // { kind: 'convert'|'export'|'coverage'|'corpus' } | undefined
  fullScreen,     // 'coverage' | 'corpus' | 'crossFormat' | 'importerProbe' | 'snippets' | undefined
  renderHealth,   // 'ok' | 'slow' | 'failed'
  themeBuilderOpen,
  mutationsOpen,
  importerProbeSample,
  showCitations,
  citations,
  setBackend, setTheme, setAccent,
  setMode,
  setShowCitations,
  // visual-mode interactions
  setState,
  // theme builder + mutations
  setThemeBuilderOpen, setMutationsOpen,
  // importer probe
  setImporterProbeSample,
  // diagnostics drawer state
  diagSeverity, setDiagSeverity, diagCat, setDiagCat, onCloseDrawer,
  // export sheet state
  exportTarget, setExportTarget, rtCheck, setRtCheck, onCloseSheet,
  // convert sheet
  convertTarget, setConvertTarget,
  // corpus
  corpusActiveId, setCorpusActiveId,
  linuxFilter, setLinuxFilter,
}) {
  const openTabIds = ["pipeline-flow", "phases-timeline", "phases-gantt"];
  const openTabs = openTabIds.map((id) => SAMPLES.find((s) => s.id === id)).filter(Boolean);
  const activeId = sample.id;

  return (
    <div className="win" style={{
      "--lib-w": "240px",
      "--insp-w": "320px",
      "--editor-w": mode === "split" ? "420px" : (mode === "code" ? "1fr" : "0px"),
      "--accent": accent,
      "--accent-10": `color-mix(in oklch, ${accent} 10%, transparent)`,
      "--accent-15": `color-mix(in oklch, ${accent} 15%, transparent)`,
      "--accent-20": `color-mix(in oklch, ${accent} 20%, transparent)`,
      "--accent-25": `color-mix(in oklch, ${accent} 25%, transparent)`,
    }}>
      {/* Titlebar */}
      <Titlebar
        mode={mode}
        onMode={setMode}
        sample={sample}
        onToggleSidebar={() => {}}
        onToggleInspector={() => {}}
      />

      {/* Body */}
      <div className={"body mode-" + mode}>
        {!fullScreen && <Sidebar activeId={activeId} format={sample.format} />}

        {/* Code-mode: editor full-width with minimap, no preview */}
        {mode === "code" && !fullScreen && (
          <EditorPane sample={sample} openTabs={openTabs} activeId={activeId} minimap={true} />
        )}

        {/* Visual-mode: replace editor + preview with one canvas */}
        {mode === "visual" && !fullScreen && (
          <VisualPane sample={sample} state={state} visualFamily={visualFamily} renderHealth={renderHealth} />
        )}

        {/* Split-mode: editor + preview side-by-side, with bi-directional selection */}
        {mode === "split" && !fullScreen && (<>
          <EditorPane sample={sample} openTabs={openTabs} activeId={activeId} biSelLine={2} />
          <PreviewPane sample={sample} backend={backend} theme={theme} biSelNode="A" renderHealth={renderHealth} />
        </>)}

        {fullScreen === "coverage" && (
          <CoverageMatrixHost />
        )}
        {fullScreen === "corpus" && (
          <CorpusBrowserHost activeId={corpusActiveId} setActiveId={setCorpusActiveId} linuxFilter={linuxFilter} setLinuxFilter={setLinuxFilter} />
        )}
        {fullScreen === "crossFormat" && (
          <div style={{ gridColumn: "2 / span 3", minHeight: 0, display: "flex" }}><ThreeFormatView /></div>
        )}
        {fullScreen === "importerProbe" && (
          <div style={{ gridColumn: "2 / span 3", minHeight: 0, display: "flex" }}>
            <ImporterRegistryProbeView activeSample={importerProbeSample || "d2"} onChange={setImporterProbeSample} />
          </div>
        )}
        {fullScreen === "snippets" && (
          <div style={{ gridColumn: "2 / span 3", minHeight: 0, display: "flex" }}><SnippetsLibrary /></div>
        )}

        {!fullScreen && <Inspector
          sample={sample}
          backend={backend} setBackend={setBackend}
          theme={theme} setTheme={setTheme}
          accent={accent} setAccent={setAccent}
          showCitations={showCitations}
          onShowCitations={setShowCitations}
          extras={<>
            <ThemeBuilderCard open={!!themeBuilderOpen} onToggle={setThemeBuilderOpen} />
            <div className="insp-section">
              <h6><span>Platform</span><span className="grow" /><span className="cite-key" title="Sources/DiagramKitCommon/src_text_metrics.swift">text-metrics</span></h6>
              <PlatformRow family={sample.family} />
            </div>
            <MutationsCatalogCard open={!!mutationsOpen} onToggle={setMutationsOpen} onDemo={setState} currentState={state} />
          </>}
        />}
      </div>

      {/* Status bar */}
      <Statusbar backend={backend} paint={sample.stats.paint} sampleId={sample.id} />

      {/* Diagnostics drawer (overlay) */}
      <DiagnosticsDrawer
        open={drawer === "diagnostics"}
        severityFilter={diagSeverity}
        setSeverity={setDiagSeverity}
        catFilter={diagCat}
        setCat={setDiagCat}
        onClose={onCloseDrawer}
      />

      {/* Sheets */}
      {overlay && overlay.kind === "convert" && (
        <ConvertSheet sourceFmt={sample.format} targetFmt={convertTarget} />
      )}
      {overlay && overlay.kind === "export" && (
        <ExportSheet
          target={exportTarget}
          setTarget={setExportTarget}
          rtCheck={rtCheck}
          setRtCheck={setRtCheck}
          onClose={onCloseSheet}
        />
      )}

      {/* Source-citation pins overlay */}
      {showCitations && citations && (
        <div className="cite-overlay">
          {citations.map((c, i) => (
            <CitePin key={i} top={c.top} left={c.left} right={c.right} side={c.side} num={c.num} label={c.label} />
          ))}
        </div>
      )}
    </div>
  );
}

// Wrapper that hosts CoverageMatrix as a full-window screen
function CoverageMatrixHost() {
  const [hover, setHover] = useState(null);
  return (
    <div style={{ gridColumn: "2 / span 3", minHeight: 0, display: "flex" }}>
      <CoverageMatrix hover={hover} setHover={setHover} />
    </div>
  );
}

// Wrapper that hosts CorpusBrowser as a full-window screen
function CorpusBrowserHost({ activeId, setActiveId, linuxFilter, setLinuxFilter }) {
  const [familyFilter, setFamilyFilter] = useState(null);
  const [formatFilter, setFormatFilter] = useState(null);
  const [diagFilter, setDiagFilter] = useState(null);
  return (
    <div style={{ gridColumn: "2 / span 3", minHeight: 0, display: "flex" }}>
      <CorpusBrowser
        familyFilter={familyFilter} setFamilyFilter={setFamilyFilter}
        formatFilter={formatFilter} setFormatFilter={setFormatFilter}
        diagFilter={diagFilter} setDiagFilter={setDiagFilter}
        linuxFilter={linuxFilter} setLinuxFilter={setLinuxFilter}
        activeId={activeId} setActiveId={setActiveId}
      />
    </div>
  );
}

// Visual mode central pane — picks the right canvas per family and layers
// popovers + tools + undo timeline + quick-fix on top.
function VisualPane({ sample, state, visualFamily, renderHealth }) {
  const fam = visualFamily || sample.family;
  const [tool, setTool] = useState("select");
  const isFlow = fam === "flowchart";
  const isSeq = fam === "sequence";
  const isGantt = fam === "gantt";

  return (
    <section className="pane preview" style={{ gridColumn: "2 / span 2" }}>
      <div className="preview-stack">
        <div className="preview-toolbar">
          <KPill tone="accent" glyph={<Icon.Family glyph={FAMILY_ICON_MAP[fam] || "▢"} />}>&nbsp;{fam} · visual</KPill>
          {isFlow && <KPill dot>9n · 11e · scene graph</KPill>}
          {isSeq && <KPill dot>5 participants · 6 messages</KPill>}
          {isGantt && <KPill dot>13 tasks · 4 sections · today w82</KPill>}
          <div style={{ flex: 1 }} />
          <RenderHealthPill renderHealth={renderHealth || "ok"} />
          <div className="zoom-group">
            <button><Icon.ZoomOut /></button>
            <span className="zlabel">100%</span>
            <button><Icon.ZoomIn /></button>
            <button><Icon.Fit /></button>
          </div>
        </div>

        <div className="visual-canvas">
          <div className="visual-stage">
            {isFlow && <FlowchartEditCanvas state={state} />}
            {isSeq && <SequenceEditCanvas dragging={true} />}
            {isGantt && <GanttEditCanvas dragBar={true} />}
          </div>

          {/* Floating tools */}
          <VisualToolPalette tool={tool} onTool={setTool} />
          <SelectionHUD state={isFlow ? state : (isSeq ? 1 : 1)} />

          {/* Node popover (flowchart, states 1/2) */}
          {isFlow && (state === 1 || state === 2) && (
            <NodeEditPopover state={state} x={640} y={304} />
          )}
          {/* Edge popover (flowchart, state 3) */}
          {isFlow && state === 3 && (
            <EdgeEditPopover x={620} y={236} />
          )}
          {/* Quick-fix diagnostic card (flowchart, states 1, 4) */}
          {isFlow && (state === 1 || state === 4) && (
            <QuickFix x={350} y={172} applied={state === 4} />
          )}
          {/* When state=2, hint that the label has been committed */}
          {isFlow && state === 2 && (
            <div className="diff-hover" style={{ left: 90, top: 488 }}>
              <div className="diff-hd">
                <Icon.Visual /> Inline edit · committed to source
                <span style={{ flex: 1 }} />
                <span style={{ color: "var(--fg3)", fontFamily: "var(--font-mono)", fontSize: 10 }}>perform(.setLabel)</span>
              </div>
              <div><span className="diff-del">- A["positioned"]</span></div>
              <div><span className="diff-add">+ A["positioned · ASCII"]</span></div>
              <div className="diff-ctx" style={{ marginTop: 6, fontSize: 10, fontFamily: "var(--font-sans)" }}>
                Bound through MermaidExporter · re-exported on commit.
              </div>
            </div>
          )}
          {/* state 6 — subgraph committed: source diff + commit toast */}
          {isFlow && state === 6 && <SubgraphDiffHover />}
          {isFlow && state === 6 && <SubgraphCommitToast />}

          {/* Failed render error sheet (overlays the canvas) */}
          {renderHealth === "failed" && <RenderFailedSheet />}

          {/* Undo/redo timeline at bottom */}
          {isFlow && <UndoTimeline state={state} />}

          {/* State stepper */}
          {isFlow && <StateStepper value={state} onChange={() => {}} />}
          {isSeq && (
            <div className="state-stepper">
              <span className="lbl">State</span>
              <div className="steps">
                <span className="step"><span className="n">0</span>Idle</span>
                <span className="step on"><span className="n">1</span>Drag message ↕</span>
                <span className="step"><span className="n">2</span>Inserted</span>
              </div>
            </div>
          )}
          {isGantt && (
            <div className="state-stepper">
              <span className="lbl">State</span>
              <div className="steps">
                <span className="step"><span className="n">0</span>Idle</span>
                <span className="step on"><span className="n">1</span>Drag end-handle</span>
                <span className="step"><span className="n">2</span>Released · range edited</span>
              </div>
            </div>
          )}
        </div>

        <div className="preview-foot">
          <span>editor</span>
          <span className="stat-num">DiagramEditor · @MainActor @Observable</span>
          <span style={{ color: "var(--fg3)" }}>·</span>
          <span>selection</span>
          <span className="stat-num">{isFlow ? (state >= 1 ? "node:A" : "—") : (isSeq ? "message[2]" : "task[8]")}</span>
          <span style={{ color: "var(--fg3)" }}>·</span>
          <span>preferred export</span>
          <span className="stat-num">{sample.format}</span>
          <span style={{ flex: 1 }} />
          <span>canUndo</span>
          <span className="stat-num" style={{ color: "var(--status-success)" }}>true</span>
          <span style={{ color: "var(--fg3)" }}>·</span>
          <span>isExporting</span>
          <span className="stat-num" style={{ color: "var(--fg3)" }}>false</span>
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// Per-artboard wrappers (one component per <DCArtboard>)
// ─────────────────────────────────────────────────────────────
function makeProps(t, overrides = {}) {
  const sample = SAMPLES.find((s) => s.id === t.activeSampleId) || SAMPLES[0];
  return {
    sample,
    backend: t.backend,
    theme: t.theme,
    accent: t.accent,
    state: t.visualState,
    showCitations: t.showCitations,
    renderHealth: t.renderHealth,
    themeBuilderOpen: t.themeBuilderOpen,
    mutationsOpen: t.mutationsOpen,
    importerProbeSample: t.importerProbeSample,
    linuxFilter: t.linuxFilter,
    ...overrides,
  };
}

function CodeArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="01 Code mode">
      <Playground
        {...makeProps(t)}
        mode="code"
        citations={CITATION_SETS.code}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
        setThemeBuilderOpen={(v) => setTweak("themeBuilderOpen", v)}
        setMutationsOpen={(v) => setTweak("mutationsOpen", v)}
        setState={(s) => setTweak("visualState", s)}
      />
    </div>
  );
}

function VisualArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="02 Visual mode (flowchart)">
      <Playground
        {...makeProps(t, { sample: SAMPLES.find((s) => s.id === "pipeline-flow") || SAMPLES[0] })}
        mode="visual"
        visualFamily="flowchart"
        citations={CITATION_SETS.visual}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
        setState={(s) => setTweak("visualState", s)}
        setThemeBuilderOpen={(v) => setTweak("themeBuilderOpen", v)}
        setMutationsOpen={(v) => setTweak("mutationsOpen", v)}
      />
    </div>
  );
}

function SplitArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="03 Split mode">
      <Playground
        {...makeProps(t)}
        mode="split"
        citations={CITATION_SETS.split}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

function SequenceVisualArtboard({ t, setTweak }) {
  // Force a sequence sample
  const seqSample = {
    id: "seq-render", title: "renderImage path", family: "sequence",
    format: "mermaid", fileName: "RenderPath.mmd",
    diagnostics: [], stats: { nodes: 5, edges: 6, layout: "0.9 ms", paint: "4.1 ms", svg: "8.4 KB" },
    source: [], history: [],
  };
  return (
    <div className="dk-art" data-screen-label="04 Visual · Sequence message drag">
      <Playground
        {...makeProps(t)}
        sample={seqSample}
        mode="visual"
        visualFamily="sequence"
        citations={CITATION_SETS.sequenceVisual}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

function GanttVisualArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="05 Visual · Gantt date-bar drag">
      <Playground
        {...makeProps(t, { sample: SAMPLES.find((s) => s.id === "phases-gantt") || SAMPLES[0] })}
        mode="visual"
        visualFamily="gantt"
        citations={CITATION_SETS.ganttVisual}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

function ConvertArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="06 Convert sheet (Mermaid → D2)">
      <Playground
        {...makeProps(t)}
        mode="split"
        overlay={{ kind: "convert" }}
        convertTarget="d2"
        citations={CITATION_SETS.convert}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

function CoverageArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="07 Coverage matrix · 28 × 5">
      <Playground
        {...makeProps(t)}
        mode="split"
        fullScreen="coverage"
        citations={CITATION_SETS.coverage}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

function DiagnosticsArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="08 Diagnostics drawer">
      <Playground
        {...makeProps(t)}
        mode="split"
        drawer="diagnostics"
        diagSeverity={t.diagSeverity}
        diagCat={t.diagCat}
        setDiagSeverity={(v) => setTweak("diagSeverity", v)}
        setDiagCat={(v) => setTweak("diagCat", v)}
        citations={CITATION_SETS.diagnostics}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

function ExportArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="09 Export sheet">
      <Playground
        {...makeProps(t)}
        mode="visual"
        visualFamily="flowchart"
        overlay={{ kind: "export" }}
        exportTarget={t.exportTarget}
        rtCheck={t.rtCheck}
        setExportTarget={(v) => setTweak("exportTarget", v)}
        setRtCheck={(v) => setTweak("rtCheck", v)}
        citations={CITATION_SETS.export}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

function CorpusArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="10 Corpus browser">
      <Playground
        {...makeProps(t)}
        mode="split"
        fullScreen="corpus"
        corpusActiveId={t.corpusActiveId}
        setCorpusActiveId={(v) => setTweak("corpusActiveId", v)}
        setLinuxFilter={(v) => setTweak("linuxFilter", v)}
        citations={CITATION_SETS.corpus}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

// v2.1 — new artboards
function CrossFormatArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="11 Cross-format · three-format view">
      <Playground
        {...makeProps(t)}
        mode="split"
        fullScreen="crossFormat"
        citations={CITATION_SETS.crossFormat}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

function SubgraphArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="12 Visual · Subgraph grouping">
      <Playground
        {...makeProps(t, {
          sample: SAMPLES.find((s) => s.id === "pipeline-flow") || SAMPLES[0],
          state: t.visualState >= 5 ? t.visualState : 6, // pin to subgraph state when low
        })}
        mode="visual"
        visualFamily="flowchart"
        citations={CITATION_SETS.subgraph}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
        setState={(s) => setTweak("visualState", s)}
        setThemeBuilderOpen={(v) => setTweak("themeBuilderOpen", v)}
        setMutationsOpen={(v) => setTweak("mutationsOpen", v)}
      />
    </div>
  );
}

function ImporterProbeArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="13 Importer registry probe">
      <Playground
        {...makeProps(t)}
        mode="split"
        fullScreen="importerProbe"
        setImporterProbeSample={(v) => setTweak("importerProbeSample", v)}
        citations={CITATION_SETS.importerProbe}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

function SnippetsArtboard({ t, setTweak }) {
  return (
    <div className="dk-art" data-screen-label="14 Snippets library">
      <Playground
        {...makeProps(t)}
        mode="split"
        fullScreen="snippets"
        citations={CITATION_SETS.snippets}
        setMode={(m) => setTweak("workspaceMode", m)}
        setShowCitations={(v) => setTweak("showCitations", v)}
      />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// App — DesignCanvas + Tweaks
// ─────────────────────────────────────────────────────────────
function App() {
  const tweakDefaults = /*EDITMODE-BEGIN*/{
    "workspaceMode": "split",
    "activeSampleId": "pipeline-flow",
    "backend": "svg",
    "theme": "dark",
    "accent": "#0A84FF",
    "visualState": 1,
    "diagSeverity": "all",
    "diagCat": null,
    "exportTarget": "d2",
    "rtCheck": true,
    "corpusActiveId": "flow-1-simple",
    "showCitations": false,
    "renderHealth": "ok",
    "linuxFilter": null,
    "themeBuilderOpen": false,
    "mutationsOpen": false,
    "importerProbeSample": "d2"
  }/*EDITMODE-END*/;

  const [t, setTweak] = useTweaks(tweakDefaults);

  // Mount theme at root so the editor + preview chrome flips light/dark.
  useEffect(() => {
    document.documentElement.dataset.theme = t.theme === "light" ? "light" : "dark";
  }, [t.theme]);

  // Shared props pass down to every artboard
  const sharedProps = { t, setTweak };

  return (
    <>
      <DesignCanvas>
        <DCSection id="modes" title="Workspace modes" subtitle="Code · Visual · Split — the title-bar segmented control switches between them.">
          <DCArtboard id="code"   label="A · Code mode"   width={1440} height={900}><CodeArtboard {...sharedProps} /></DCArtboard>
          <DCArtboard id="visual" label="B · Visual mode" width={1440} height={900}><VisualArtboard {...sharedProps} /></DCArtboard>
          <DCArtboard id="split"  label="C · Split mode"  width={1440} height={900}><SplitArtboard {...sharedProps} /></DCArtboard>
        </DCSection>

        <DCSection id="visual-families" title="Visual editing · family-specific surfaces" subtitle="Sequence message-ordering, Gantt date-bar drag, and subgraph grouping — the visual canvas takes the diagram family into account.">
          <DCArtboard id="seq-visual"   label="D · Sequence · message drag"  width={1440} height={900}><SequenceVisualArtboard {...sharedProps} /></DCArtboard>
          <DCArtboard id="gantt-visual" label="E · Gantt · date-bar drag"    width={1440} height={900}><GanttVisualArtboard {...sharedProps} /></DCArtboard>
          <DCArtboard id="subgraph"     label="L · Visual · Subgraph grouping"  width={1440} height={900}><SubgraphArtboard {...sharedProps} /></DCArtboard>
        </DCSection>

        <DCSection id="multi-format" title="Multi-format · round-trip" subtitle="Convert flow with RoundTripHarness assertion + RoundTripLoss callouts. Exporter coverage matrix. Importer registry probe sequence.">
          <DCArtboard id="convert"  label="F · Convert sheet"           width={1440} height={900}><ConvertArtboard {...sharedProps} /></DCArtboard>
          <DCArtboard id="coverage" label="G · Coverage · 28 × 5"        width={1440} height={900}><CoverageArtboard {...sharedProps} /></DCArtboard>
          <DCArtboard id="probe"    label="N · Importer registry probe" width={1440} height={900}><ImporterProbeArtboard {...sharedProps} /></DCArtboard>
        </DCSection>

        <DCSection id="diagnostics-export" title="Diagnostics · Export" subtitle="Diagnostics drawer expanded (severity + category + tier facets). Export sheet with round-trip toggle per target.">
          <DCArtboard id="diagnostics" label="H · Diagnostics drawer" width={1440} height={900}><DiagnosticsArtboard {...sharedProps} /></DCArtboard>
          <DCArtboard id="export"      label="I · Export sheet"        width={1440} height={900}><ExportArtboard {...sharedProps} /></DCArtboard>
        </DCSection>

        <DCSection id="library" title="Library · Corpus · Snippets" subtitle="The 28-family corpus with per-card Linux dot (full/approximate). Snippets restored from v1 — 9 paste-ready patterns.">
          <DCArtboard id="corpus"   label="J · Corpus browser"   width={1440} height={900}><CorpusArtboard {...sharedProps} /></DCArtboard>
          <DCArtboard id="snippets" label="M · Snippets library" width={1440} height={900}><SnippetsArtboard {...sharedProps} /></DCArtboard>
        </DCSection>

        <DCSection id="cross-format" title="Cross-format" subtitle="3-up side-by-side: same flowchart in Mermaid, D2, and DOT — with per-exporter diagnostics.">
          <DCArtboard id="three-format" label="K · Three-format view" width={1440} height={900}><CrossFormatArtboard {...sharedProps} /></DCArtboard>
        </DCSection>
      </DesignCanvas>

      <TweaksPanel title="Tweaks">
        <TweakSection label="Workspace">
          <TweakRadio
            label="Mode"
            value={t.workspaceMode}
            onChange={(v) => setTweak("workspaceMode", v)}
            options={[{ value: "code", label: "Code" }, { value: "visual", label: "Visual" }, { value: "split", label: "Split" }]}
          />
          <TweakSelect
            label="Active sample"
            value={t.activeSampleId}
            onChange={(v) => setTweak("activeSampleId", v)}
            options={SAMPLES.map((s) => ({ value: s.id, label: `${s.family} · ${s.fileName}` }))}
          />
          <TweakToggle label="Source citations overlay" value={t.showCitations} onChange={(v) => setTweak("showCitations", v)} />
        </TweakSection>

        <TweakSection label="Visual mode">
          <TweakSelect
            label="Selection state (flowchart)"
            value={t.visualState}
            onChange={(v) => setTweak("visualState", Number(v))}
            options={[
              { value: 0, label: "0 · Idle" },
              { value: 1, label: "1 · Node selected" },
              { value: 2, label: "2 · Label edited" },
              { value: 3, label: "3 · Edge drag (waypoints)" },
              { value: 4, label: "4 · Undone" },
              { value: 5, label: "5 · Marquee select" },
              { value: 6, label: "6 · Group into subgraph" },
            ]}
          />
          <TweakRadio
            label="Render health"
            value={t.renderHealth}
            onChange={(v) => setTweak("renderHealth", v)}
            options={[
              { value: "ok",     label: "● OK" },
              { value: "slow",   label: "⚠ Slow" },
              { value: "failed", label: "✕ Failed" },
            ]}
          />
          <TweakToggle label="Inspector · Edit theme open" value={t.themeBuilderOpen} onChange={(v) => setTweak("themeBuilderOpen", v)} />
          <TweakToggle label="Inspector · Mutations open" value={t.mutationsOpen} onChange={(v) => setTweak("mutationsOpen", v)} />
        </TweakSection>

        <TweakSection label="Importer probe">
          <TweakSelect
            label="Sample source"
            value={t.importerProbeSample}
            onChange={(v) => setTweak("importerProbeSample", v)}
            options={[
              { value: "mermaid",     label: "Mermaid · fallback wins" },
              { value: "d2",          label: "D2 · narrow · wins #1" },
              { value: "dot",         label: "DOT · Graphviz · wins #2" },
              { value: "structurizr", label: "Structurizr · wins #3" },
              { value: "plantuml",    label: "PlantUML · wins #4" },
            ]}
          />
        </TweakSection>

        <TweakSection label="Diagnostics drawer">
          <TweakRadio
            label="Severity"
            value={t.diagSeverity}
            onChange={(v) => setTweak("diagSeverity", v)}
            options={[
              { value: "all",   label: "All" },
              { value: "warn",  label: "▲ Warn" },
              { value: "unsup", label: "✕ Unsup" },
              { value: "info",  label: "● Info" },
            ]}
          />
          <TweakSelect
            label="Category"
            value={t.diagCat || ""}
            onChange={(v) => setTweak("diagCat", v || null)}
            options={[
              { value: "", label: "All categories" },
              { value: "idSanitization",         label: ".idSanitization" },
              { value: "shapeDowngrade",         label: ".shapeDowngrade" },
              { value: "styleDrop",              label: ".styleDrop" },
              { value: "subgraphFlatten",        label: ".subgraphFlatten" },
              { value: "c4SlotDrop",             label: ".c4SlotDrop" },
              { value: "configDrop",             label: ".configDrop" },
              { value: "labelNewlineEscape",     label: ".labelNewlineEscape" },
              { value: "d2InlineCommentStripped",label: ".d2InlineCommentStripped" },
              { value: "diagramFamilyUnsupported", label: ".diagramFamilyUnsupported" },
              { value: "slotUnsupported",        label: ".slotUnsupported" },
              { value: "identifierEscape",       label: ".identifierEscape" },
              { value: "commentPreserved",       label: ".commentPreserved" },
            ]}
          />
        </TweakSection>

        <TweakSection label="Corpus">
          <TweakSelect
            label="Active corpus entry"
            value={t.corpusActiveId}
            onChange={(v) => setTweak("corpusActiveId", v)}
            options={[
              { value: "flow-1-simple",    label: "flow-1-simple" },
              { value: "seq-1-basic",      label: "seq-1-basic" },
              { value: "class-1-basic",    label: "class-1-basic" },
              { value: "er-1-basic",       label: "er-1-basic" },
              { value: "state-1-basic",    label: "state-1-basic" },
              { value: "gantt-1",          label: "gantt-1" },
              { value: "c4-1-context",     label: "c4-1-context" },
              { value: "block-5-edges",    label: "block-5-edges" },
              { value: "xychart-1-bar",    label: "xychart-1-bar" },
              { value: "ish-1-fish",       label: "ish-1-fishbone (Linux ⚠)" },
              { value: "tree-2-folders",   label: "tree-2-folders (Linux ⚠)" },
              { value: "event-1-checkout", label: "event-1-checkout (Linux ⚠)" },
            ]}
          />
          <TweakRadio
            label="Linux facet"
            value={t.linuxFilter || "any"}
            onChange={(v) => setTweak("linuxFilter", v === "any" ? null : v)}
            options={[
              { value: "any",    label: "any" },
              { value: "full",   label: "● full" },
              { value: "approx", label: "⚠ approx" },
            ]}
          />
        </TweakSection>

        <TweakSection label="Theme">
          <TweakColor
            label="Accent"
            value={t.accent}
            onChange={(v) => setTweak("accent", v)}
            options={["#0A84FF", "#5E5CE6", "#BF5AF2", "#64D2FF", "#30D158", "#FF9F0A", "#FF375F"]}
          />
        </TweakSection>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
