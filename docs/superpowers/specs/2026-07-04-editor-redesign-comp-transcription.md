# DiagramKit Editor Redesign — Implementation Spec

Source: `DiagramKit Editor Redesign.dc.html` (Claude Design canvas doc).
This is the single source of truth for the UI redesign. All hex values and pixel
numbers are transcribed verbatim from the comp; match them exactly.

The app is the **CodeEditorSample / DiagramKit editor** — a native macOS/iOS
diagram editor. The redesign introduces an **activity rail + switchable side
panel**, turns the **Inspector into a full editing surface**, and moves all
global configuration out of the inspector into a **Settings sheet (⌘,)** with a
7-item sidebar. The visual language is **"LCARS Dark" / "Zed Trek"**: near-black
navy panels, a warm orange (#FF9933) accent, amber/gold secondary (#FFCC66), and
parchment-cream text (#F2E7D8).

Turns appear in the document in reverse order (t3, t2, t1). Chronology is
t1 → t2 → t3.

---

## 0. Global Canvas Chrome (doc shell — not part of the app UI)

These styles wrap the mockups (the design-doc presentation layer). Included for
completeness; they are NOT app UI.

- **Doc body**: `background:#0a0b0e`; dotted grid `radial-gradient(rgba(255,255,255,.025) 1px,transparent 1px)` at `background-size:32px 32px`; font-family `"SF Pro Text",-apple-system,BlinkMacSystemFont,system-ui,sans-serif`; antialiased.
- **`.dv-turn`** (section): `padding:60px 64px`; `border-bottom:1px solid rgba(255,255,255,.06)`.
- **`.dv-thd`** (turn header): flex, `gap:12px`, `margin:0 0 30px`.
- **`.dv-tid`** (turn number badge): `font:700 12px ui-monospace,Menlo,monospace`; `padding:5px 10px`; `background:#FF9933`; `color:#1a1205`; `border-radius:6px`.
- **`.dv-tname`** (turn name): `font:600 16px sans-serif`; `color:#F2E7D8`.
- **`.dv-tsub`** (turn subtitle): `font:400 13px sans-serif`; `color:#8B93A1`.
- **`.dv-opts`**: flex-wrap, `gap:60px`, align-items flex-start.
- **`.dv-opt`**: flex column, `gap:16px`.
- **`.dv-olabel`** (option caption): `font:400 13.5px sans-serif`; `color:#B8BFC9`; `gap:11px`; `max-width:1380px`. `<b>` inside → `color:#F2E7D8;font-weight:600`.
- **`.dv-oid`** (option id badge): `font:700 12px ui-monospace,Menlo,monospace`; `padding:4px 9px`; `background:rgba(255,153,51,.15)`; `color:#FF9933`; `border-radius:6px`. Targeted state → `background:#FF9933;color:#1a1205`.
- **`.dv-next`** (narrative): `font:13.5px/1.7 sans-serif`; `color:#8B93A1`; links `color:#FF9933;font-weight:600`.

---

## 1. Design Tokens (recurring, extracted from every mockup)

### 1.1 Color palette (every distinct hex + semantic role)

**Accents**
| Hex | Role |
|-----|------|
| `#FF9933` | PRIMARY ACCENT (orange). Active nav/tab fill, active toggles, selected node border, active-marker bar, primary buttons, focus ring, orange status dot. |
| `rgba(255,153,51,.16)` | Accent tint — active nav-item / rail-item / tree-row background, icon-badge background. |
| `rgba(255,153,51,.14)` | Accent tint (lighter) — active toolbar icon bg, canvas selection breadcrumb bg. |
| `rgba(255,153,51,.15)` | Doc option-id badge bg (doc chrome). |
| `rgba(255,153,51,.4)` | Selection breadcrumb border. |
| `rgba(255,153,51,.08)` | Active source-code line highlight background. |
| `#FFCC66` | SECONDARY ACCENT (amber/gold). Active nav-item text, active tree-row text, code-snippet/monospace value emphasis, node-id mono, spacing value, selected source keywords/brackets. |
| `#FFD8B0` | Light peach — "edit label" pencil icons in Mutations. |
| `#1a1205` | Text/icon ON accent (dark brown-black) — labels drawn on #FF9933 fills. |

**Text**
| Hex | Role |
|-----|------|
| `#F2E7D8` | PRIMARY TEXT (parchment cream). Titles, active labels, node text. |
| `#B8BFC9` | Secondary text (light gray) — inactive nav labels, dropdown values, sample rows, doc olabel body. |
| `#8B93A1` | Muted text / inactive icon stroke — subtitles, section captions, inactive rail icons, chevrons. |
| `#687282` | Placeholder text / faint mono captions. |
| `#6F7888` | Source-editor line-number gutter. |
| `#4F5868` | Faintest — "unsupported" dash, mono node-id captions in tree/browse. |
| `#5A6472` | Canvas edge lines & chevron arrowheads. |
| `#B98A4A` | Selected node-id mono (dark amber). |

**Surfaces / backgrounds**
| Hex | Role |
|-----|------|
| `#05060A` | Darkest — editor window bg, activity-rail bg, panel window bg, settings-modal frame bg, knob border on sliders. |
| `#080A0F` | Near-black — search/input field bg, code-editor bg, canvas bg base. |
| `#0A0B0E` | (doc canvas bg only). |
| `#0B0F18` | Settings sidebar-nav bg; Fonts info-callout bg. |
| `#0C111B` | Side-panel content bg, Organize panel bg, Inspector bg. |
| `#0D1018` | Title bar bg, status bar bg, canvas zoom-control bg. |
| `#0E1421` | SETTINGS SHEET panel bg. |
| `#111827` | Card / group-row container bg; canvas node fill; theme-card footer bg; search-result card bg. |
| `#151A24` | Segmented-control track bg, chip bg, pill/button bg, reset-button bg. |

**Borders / dividers**
| Hex | Role |
|-----|------|
| `#2A2030` | Warm outer panel/window border (0.5px); input borders in panels. |
| `#252B36` | Standard inner divider/border (0.5px) — card borders, row dividers, nav border-right, segmented borders. |
| `#1c2432` | Lighter row divider inside tables/lists (Platform Parity, Mutations rows). |
| `#3a4250` | Color-swatch border (inspector Background/Border color). |
| `#3a2626` | Reset-button reddish border. |

**Status / semantic**
| Hex | Role |
|-----|------|
| `#30D158` | GREEN — "on" status, "Full" parity checkmarks, "Bundled" badges, synced dot, add-node/add-edge (+) icons. |
| `#FF9F0A` | AMBER/ORANGE — "Partial" parity dot, web-fallback warning text. |
| `#EF5A5A` | RED destructive text — "Reset All Settings", remove-node/edge (−) icons. |
| `#FF5D57` | Traffic-light red (settings-sheet single dot, 11px; also editor window red). |
| `#FEBC2E` | Traffic-light yellow (editor window, 12px). |
| `#28C840` | Traffic-light green (editor window, 12px). |

**Category / diagram accents (icons, swatches)**
| Hex | Role |
|-----|------|
| `#7EC8DE` | Cyan/teal — EDGE category, code-snippet mono in Mutations, info icon, edge-label icons, source `TB` keyword, inspector Image icon, color dot. |
| `#4EE6A6` | Mint — inspector color dot, "Rearrange"/relayout refresh icon, Sick Bay swatch. |
| `#CC99FF` | Purple — "Set shape & style" icon, inspector "Icon" star, inspector color dot. |
| `#EF5A5A` | (also inspector color dot / red). |

**Theme-swatch specimen colors** (Theme tab, 3d)
| Theme | bg | bar 1 | bar 2 | bar 3 |
|-------|----|-------|-------|-------|
| LCARS Dark (active) | `#05060A` | `#FF9933` | `#7EC8DE` | `#FFCC66` |
| LCARS Light | `#FBF7F1` | `#E07A1E` | `#B8945A` | `#C77D28` |
| Federation | `#0A1020` | `#FFCC66` | `#3B6FE0` | `#7EC8DE` |
| Red Alert | `#160404` | `#FF453A` | `#FF9F0A` | `#FFCC66` |
| Sick Bay | `#04120F` | `#4EE6A6` | `#7EC8DE` | `#30D158` |
| Borg Cube | `#04120A` | `#39FF57` | `#4EE6A6` | `#A8FF60` |

**Highlight**
- Search match highlight bg: `rgba(255,216,176,.35)` (peach); highlighted text color reverts to `#F2E7D8` where noted.
- Diagram-palette gradient swatch (Theme "Zinc Light"): `linear-gradient(135deg,#F2E7D8,#8B93A1)`.

**White**
- `#fff` — toggle knob (ON state).

### 1.2 Typography scale

- Base UI font stack: `"SF Pro Text",-apple-system,BlinkMacSystemFont,system-ui,sans-serif` (antialiased).
- Node text font: `'SF Pro Display',-apple-system,sans-serif`.
- Monospace stack: `ui-monospace,'SF Mono',Menlo,monospace` (source editor, ids, code snippets, status bar).
- Sizes observed: `10px` (section captions, uppercase 700 letter-spacing .6px), `10.5px` (mono ids), `11px` (row descriptions / status bar / legend / rail section titles), `11.5px` (chips, theme names, snippet mono, info callout, direction segments), `12px` (dropdown values, nav search, rail icons text, zoom), `12.5px` (nav items, settings row labels, tree rows, table rows, buttons), `13px` (inspector text input, inspector header title), `13.5px` (doc olabel/next), `14px` (settings-sheet "Settings" title), `16px` (settings content H1 / turn name), `34px` (canvas node label).
- Weights: `400` (body), `500` (title-bar tab inactive), `600` (titles, active items, node text), `700` (uppercase section captions, ids/badges).
- Uppercase section-caption pattern: `font-size:10px;font-weight:700;letter-spacing:.6px;color:#8B93A1` (or `11px` for rail panel titles; color `#F2E7D8` for panel titles, `#FFCC66`/`#7EC8DE` for Mutations category headers).

### 1.3 Corner radii
- `26px` — large window shells (editor 1b, settings-modal frame 1d).
- `20px` — settings sheet panel.
- `18px` — side-panel window (turn 2).
- `12px` — canvas tool-palette container.
- `10px` — cards/groups, theme cards, zoom control, search-result cards, info callout.
- `9px` — rail-item & Render-format segmented track & search-result cards & nav rail icon tiles.
- `9999px` — toggles (pill), filter chips.
- `8px` — search fields, segmented-control tracks (border/insert/title-bar), inspector buttons, breadcrumb, canvas tool tiles.
- `7px` — nav items, stepper, inline value pills, filter fields, align buttons, inspector text input, tree rows.
- `6px` — traffic-light-adjacent radii, small chips, title-bar icon tiles, inspector icon badge, segment inner buttons, swatch.
- `3px` / `2px` — theme preview bars, resize handles, highlight chips.

### 1.4 Control styles (reusable)

- **Toggle (switch)**: `width:40px;height:24px;border-radius:9999px`. ON: `background:#FF9933`, knob `position:absolute;top:2px;right:2px;width:20px;height:20px;border-radius:50%;background:#fff`. OFF: `background:#252B36`, knob `top:2px;left:2px;background:#8B93A1`.
- **Stepper**: `border:0.5px solid #252B36;border-radius:7px;overflow:hidden;font-size:12px`. `−` → `padding:5px 10px;color:#8B93A1`; value → `padding:5px 10px;color:#F2E7D8;font-family:mono;border-left:0.5px solid #252B36;border-right:0.5px solid #252B36`; `+` → `padding:5px 10px;color:#8B93A1`.
- **Dropdown value (menu row trailing)**: flex, `gap:6px;font-size:12px;color:#B8BFC9`; chevron svg `11px`, stroke `#8B93A1`, path `m6 9 6 6 6-6`.
- **Segmented control (settings-format style)**: track `background:#151A24;border:0.5px solid #252B36;border-radius:9px;padding:3px;gap:3px`. Active seg: `color:#1a1205;background:#FF9933;border-radius:6px;font-weight:600;padding:8px 0`. Inactive: `color:#8B93A1`.
- **Segmented control (inspector style)**: track `background:#151A24;border:0.5px solid #252B36;border-radius:8px;padding:2px;gap:2px`. Active seg `flex:1;padding:5px 0;font-weight:600;color:#1a1205;background:#FF9933;border-radius:6px`. Inactive `color:#8B93A1`.
- **Filter chip (pill)**: `padding:4px 10px;font-size:11.5px;border-radius:9999px`. Active: `color:#1a1205;background:#FF9933;font-weight:600`. Inactive: `color:#B8BFC9;background:#151A24;border:0.5px solid #252B36`.
- **Sidebar nav item**: `height:32px;padding:0 10px;border-radius:7px;gap:9px;font-size:12.5px`; icon `15px`. Inactive: `color:#B8BFC9`, icon stroke `#8B93A1`. Active: `background:rgba(255,153,51,.16);color:#FFCC66;font-weight:600`, icon stroke `#FF9933`.
- **Activity-rail item**: tile `38x38;border-radius:9px`; icon `18px`. Inactive: `color:#8B93A1`. Active: `background:rgba(255,153,51,.16);color:#FF9933`, plus active marker bar `position:absolute;left:-10px;top:9px;bottom:9px;width:2.5px;border-radius:2px;background:#FF9933`.
- **Search field**: `height:28–30px;padding:0 10px;background:#080A0F;border:0.5px solid #2A2030;border-radius:8px;color:#687282;font-size:12px;gap:7px`; magnifier svg `13px` (circle r7 + `m21 21-4.3-4.3`). Active/focused variant (2c): `border:0.5px solid #FF9933;color:#F2E7D8`, icon stroke `#FF9933`.
- **Traffic-light dot**: circle; settings sheet uses a single `11px` `#FF5D57` dot; editor window uses three `12px` dots `#FF5D57 / #FEBC2E / #28C840` with `gap:8px`.
- **Card/group container**: `background:#111827;border:0.5px solid #252B36;border-radius:10px;overflow:hidden`. Rows: `padding:12px 14px`, divider `border-bottom:0.5px solid #252B36` (last row omits). Row label `12.5px #F2E7D8`; secondary description line `11px #687282`.

---

## 2. Information Architecture / Screen Flow

Top-level screens:

1. **Editor window** (1b) — the primary workspace. Title bar (Code/Editor/Split
   view segmented + right-side view/export/panel icons) · **Activity rail** (far
   left, 52px) · **switchable side panel** (Organize/Browse/Search/Source) ·
   **Canvas** (dotted grid, floating tool palette + zoom + selection breadcrumb)
   · **Inspector** (right, 312px, node/diagram editing) · **Status bar**.
2. **Activity-rail panels** (turn 2) — each rail tab shown as a standalone
   372×716 panel: **Organize** (graph/subgraph tree), **Browse** (sample
   library), **Search** (find nodes/edges/labels), **Source** (live Mermaid
   with active-line tracking). Rail also has a 5th bottom "settings/sliders"
   tile.
3. **Settings sheet** (⌘,) (1d + all of turn 3) — modal sheet 748×520 with a
   196px sidebar of 7 tabs: **General · Editor · Render Backend · Theme ·
   Platform Parity · Mutations Catalog · Fonts**. Opens over a dimmed/blurred
   editor (1d shows the frame + backdrop). Render Backend, Theme, and Platform
   Parity were pulled OUT of the old Inspector into this sheet.

Flow narrative (from `.dv-next`):
- Turn 1 established direction: keep the **activity rail (1b)**; Settings opens
  as a **sheet (1d)**.
- Turn 2 breaks the rail into one panel per tab.
- Turn 3 mocks every Settings tab. Cross-links: t1 → "every tab mocked in turn
  3", "turn 2 shows each rail tab".

---

## 3. TURN 1 — "Editor layout redesign"

- **Turn id**: `t1` (badge "1").
- **Name**: Editor layout redesign.
- **Subtitle**: "— Inspector becomes an editing surface · Settings modal · graph organizer · LCARS Dark".
- **Options present**: `1b`, `1d` (no 1a/1c in the doc).
- **Narrative (.dv-next)**: "Kept direction: **1b** — activity rail. Settings opens as a sheet (**1d**); every tab is mocked in turn **3**. Turn **2** shows each rail tab."

### 3.1 Option 1b — "Activity rail." (full editor window)

- **Caption**: "**Activity rail.** A slim far-left rail switches the adjacent panel between Organize / Browse / Search. Scales as you add panels."
- **Window**: `width:1380px;height:868px;border-radius:26px;overflow:hidden;background:#05060A;border:0.5px solid #2A2030;box-shadow:0 40px 100px rgba(0,0,0,.65);color:#F2E7D8`; flex column.

**Title bar** — `height:38px;background:#0D1018;border-bottom:0.5px solid #252B36;padding:0 14px`, relative:
- Traffic lights (left, gap 8px): 3 dots `12px` — `#FF5D57`, `#FEBC2E`, `#28C840`.
- Center segmented (absolute-centered): `background:#151A24;border:0.5px solid #252B36;border-radius:8px;padding:2px;gap:2px`. Segments `padding:4px 14px;font-size:12px;border-radius:6px`: **Code** (weight 500, `#8B93A1`) · **Editor** (ACTIVE — weight 600, `#1a1205`, bg `#FF9933`) · **Split** (500, `#8B93A1`).
- Right icons (margin-left auto, gap 2px), each `28×26;border-radius:6px`: eye/preview (`#8B93A1`); share/upload (`#8B93A1`); panel-split (ACTIVE — `#FF9933`, bg `rgba(255,153,51,.14)`).

**Activity rail** — `width:52px;background:#05060A;border-right:0.5px solid #2A2030;padding:10px 0;gap:4px`, centered. 5 tiles (`38×38;border-radius:9px`, icon 18px):
1. **Organize** (ACTIVE) — list icon; `background:rgba(255,153,51,.16);color:#FF9933` + orange marker bar (left −10px, top/bottom 9px, 2.5px, `#FF9933`).
2. **Browse** — file icon, `#8B93A1`.
3. **Search** — magnifier, `#8B93A1`.
4. **Source** — code `</>` icon, `#8B93A1`.
5. **(bottom, margin-top auto)** — sliders/equalizer icon, `#8B93A1` (settings/adjust).

**Organize side panel** — `width:236px;background:#0C111B;border-right:0.5px solid #2A2030`, flex column:
- Header `padding:14px 15px 8px`, space-between: "**ORGANIZE**" (`11px;700;letter-spacing:.6px;#F2E7D8`) + plus icon (13px `#8B93A1`).
- Filter field `padding:0 12px 8px`: `height:28px;background:#080A0F;border:0.5px solid #2A2030;border-radius:7px;color:#687282;font-size:12px`, magnifier + "Filter nodes…".
- Tree (`padding:0 8px 12px`, overflow-y auto):
  - **Ingest** (subgraph, id `sg1`) — chevron 11px + brackets icon `#FFCC66` 14px + bold label; trailing mono `sg1` `#4F5868`.
  - **Start** (node, id `A`) [SELECTED] — `padding:0 6px 0 26px;background:rgba(255,153,51,.16);color:#FFCC66;border-left:2px solid #FF9933`; rect icon 13px + bold; trailing mono `A` `#B98A4A`.
  - **Process** (node `B`) — indented; rect icon `#8B93A1`; mono `B` `#4F5868`.
  - **Output** (subgraph `sg2`) — chevron + brackets `#FFCC66` + bold; mono `sg2`.
  - **End** (node `C`) — indented; mono `C`.
  - **Edges** (group, count `3`, margin-top 8px) — chevron + arrow icon `#7EC8DE` + bold; mono `3`.
  - Edge rows (mono `12px #8B93A1`, `padding-left:28px`, height 24px): "A → B", "B → C", "C → A".

**Canvas** — `flex:1;background:#080A0F` with dotted grid `radial-gradient(rgba(255,255,255,.05) 1px,transparent 1px)` `background-size:26px 26px`, relative, overflow hidden:
- **Tool palette** (absolute top16 left16): `background:rgba(13,16,24,.9);border:0.5px solid #252B36;border-radius:12px;padding:6px;gap:3px` column. 4 tiles `32×32;border-radius:8px`: cursor/select (ACTIVE — bg `rgba(255,153,51,.16)`, `#FF9933`, filled arrow) · hand/pan (`#8B93A1`) · dashed-rect marquee (`#8B93A1`) · connector/arrow (`#8B93A1`).
- **Selection breadcrumb** (absolute top18, centered): `background:rgba(255,153,51,.14);border:0.5px solid rgba(255,153,51,.4);color:#FFCC66;font:12px mono;padding:5px 11px;border-radius:8px`; rect icon 12px + text "**flowchart:node:A**".
- **Edges** (SVG, `stroke:#5A6472;stroke-width:1.7`): line1 (50%,212)→(50%,322); line2 (50%,452)→(50%,562). Chevron arrowheads (`#5A6472`, 18px) at top 314 and 554.
- **Node "Start"** (SELECTED) — absolute top88, centered, `width:236px;height:120px;background:#111827;border:1.5px solid #FF9933;border-radius:8px`; label "Start" (`SF Pro Display;34px;600;#F2E7D8`). 4 corner resize handles: `9×9;background:#FF9933;border:1px solid #05060A;border-radius:2px`, offset −5px each corner.
- **Node "Process"** — absolute top328, `width:236;height:120;background:#111827;border:1px solid #252B36;border-radius:8px`; "Process".
- **Node "End"** — absolute top568, same style; "End".
- **Zoom control** (absolute bottom16, centered): `background:#0D1018;border:0.5px solid #252B36;border-radius:10px;padding:4px;font:12px mono;color:#8B93A1;gap:2px`. Items: "**Fit**" (ACTIVE — `padding:4px 10px;border-radius:7px;background:rgba(255,153,51,.16);color:#FF9933;font-weight:600`) · "−" · "100%" · "+" · "1:1".

**Inspector** — `width:312px;background:#0C111B;border-left:0.5px solid #2A2030`, flex column, overflow-y auto:
- **Header** `padding:12px 16px 10px;border-bottom:0.5px solid #252B36;gap:8px`: icon badge `24×24;border-radius:6px;background:rgba(255,153,51,.16);color:#FF9933` (rect icon 13px) + title "**Start**" (`13px;600;#F2E7D8`) + subtitle "flowchart:node:A" (`10.5px mono #687282`).
- **Section "EDIT NODE"** (`padding:14px 16px 6px`; 10px/700/.6px/`#8B93A1`). Fields (`padding:0 16px 14px;gap:11px`):
  - Text input value "**Start**": `width:100%;height:32px;padding:0 11px;background:#080A0F;border:0.5px solid #2A2030;border-radius:7px;color:#F2E7D8;font-size:13px`.
  - **Shape** row: label `12.5px #8B93A1`; value pill `height:28px;padding:0 8px;background:#151A24;border:0.5px solid #252B36;border-radius:7px;font-size:12px;#F2E7D8` = rect icon + "Rectangle" + chevron.
  - **Border** segmented (inspector style): **Solid** (ACTIVE `#1a1205`/`#FF9933`) · Dashed (`#8B93A1`) · Thick (`#8B93A1`).
  - **Background** row: label + swatch `44×24;border-radius:6px;background:#111827;border:0.5px solid #3a4250`.
  - **Border color** row: label + swatch `44×24;background:#FF9933;border:0.5px solid #3a4250`.
  - **Color dots** (gap 9px): 6 × `26×26;border-radius:50%`: `#4EE6A6` · `#FF9933` (SELECTED — ring `box-shadow:0 0 0 2px #0C111B,0 0 0 3.5px #FF9933`) · `#EF5A5A` · `#7EC8DE` · `#CC99FF` · `#F2E7D8`.
- **Section "ARRANGE"** (border-top divider): 6 align buttons `34×30;background:#151A24;border:0.5px solid #252B36;border-radius:7px;color:#B8BFC9` — align-left, align-center-H, align-right, then a `0.5px #252B36` vertical divider, align-top, align-middle-V, align-bottom.
- **Section "DIAGRAM"**:
  - **Direction** segmented (mono, inspector style): **TB** (ACTIVE) · LR · BT · RL (each `font-size:11.5px`).
  - **Node spacing** = **48** (`#FFCC66` mono). Slider: track `height:4px;border-radius:2px;background:#252B36`; fill `width:52%;background:#FF9933`; knob `14×14;border-radius:50%;background:#FFCC66;border:2px solid #05060A` at 52%.
- **Section "INSERT"**: grid 2 cols, gap 8px. 4 buttons `height:36px;padding:0 11px;background:#151A24;border:0.5px solid #252B36;border-radius:8px;font-size:12.5px;#F2E7D8`: **Subgraph** (brackets `#FFCC66`) · **Icon** (star `#CC99FF`) · **Image** (image `#7EC8DE`) · **Rearrange** (refresh `#4EE6A6`).

**Status bar** — `height:28px;background:#0D1018;border-top:0.5px solid #252B36;gap:16px;padding:0 14px;font:11px mono;#8B93A1`:
- orange dot `#FF9933` + "flowchart · Mermaid".
- "3 nodes · 3 edges · 2 subgraphs".
- (margin-left auto) "SVG · worker **on**" ("on" `#30D158`).
- "Ln 42, Col 7 · Spaces: 4 · GPU".

### 3.2 Option 1d — "Settings modal (⌘,)"

- **Caption**: "**Settings modal (⌘,).** Everything pulled out of the Inspector lives here: Render Backend, Theme, Platform Parity — one calm sheet."
- **Modal frame**: `width:920px;height:632px;border-radius:26px;overflow:hidden;background:#05060A;position:relative;box-shadow:0 40px 100px rgba(0,0,0,.65);border:0.5px solid #2A2030`.
  - Dimmed editor hint: absolute inset0, `background:#080A0F` dotted `radial-gradient(rgba(255,255,255,.04) 1px,transparent 1px)` `26px`.
  - Scrim: absolute inset0, `background:rgba(5,6,10,.62);backdrop-filter:blur(3px)`.
- **Sheet** (centered via `translate(-50%,-50%)`): `width:748px;height:520px;background:#0E1421;border:0.5px solid #2A2030;border-radius:20px;box-shadow:0 24px 60px rgba(0,0,0,.5)`, flex column, overflow hidden, `color:#F2E7D8`.
  - **Header** (see §4 shared chrome): red dot `#FF5D57` 11px + "Settings" (14px/600) + search field "Search settings…".
  - **Nav** (196px, 7 items). ACTIVE tab = **Render Backend** (monitor icon `#FF9933`, `background:rgba(255,153,51,.16);color:#FFCC66;font-weight:600`).
  - **Content = Render Backend** (identical to 3c but shorter):
    - H1 "Render Backend"; sub "How diagrams are rasterized and rendered."
    - Format segmented: **SVG** (ACTIVE, file icon) · Image (image icon) · ASCII (mono).
    - Group card: "Renderer" → `renderSVG(_:)` (mono `#FFCC66`) · "ID policy" → "Stable" + chevron · "Render on every keystroke" / "auto vs manual" → toggle ON · "Worker thread" / "8 MB stack · fresh per call" (mono) → "**on**" with green dot `#30D158`.
    - Section "PLATFORM PARITY" (10px/700/.6px/`#8B93A1`) + card row: green dot `#30D158` + "Full parity" + trailing mono "src_text_metrics.swift" (`#687282`).

---

## 4. Shared Settings-Sheet Chrome (used by 1d and every option of turn 3)

Every turn-3 tab is the SAME 748×520 sheet; only the content pane changes.

- **Sheet shell**: `width:748px;height:520px;border-radius:20px;overflow:hidden;background:#0E1421;border:0.5px solid #2A2030;box-shadow:0 30px 70px rgba(0,0,0,.55)`; flex column; `color:#F2E7D8`.
- **Header**: `height:52px;padding:0 16px;border-bottom:0.5px solid #252B36;gap:12px`. Contents: red traffic dot `11×11;border-radius:50%;background:#FF5D57` · "Settings" (`font-size:14px;font-weight:600`) · (margin-left auto) search field `height:30px;padding:0 10px;background:#080A0F;border:0.5px solid #2A2030;border-radius:8px;color:#687282;font-size:12px;width:180px;gap:7px` with magnifier (13px) + text "**Search settings…**" (3f uses "**Filter mutations…**").
- **Sidebar nav**: `width:196px;background:#0B0F18;border-right:0.5px solid #252B36;padding:12px 10px;gap:2px`. 7 items (nav-item style §1.4), icon 15px:
  1. **General** — sun/gear icon (circle r3 + rays).
  2. **Editor** — code brackets (`</>` with slash).
  3. **Render Backend** — monitor (`rect x2 y6 14×12` + stand).
  4. **Theme** — palette (4 dots + blob path); active-tab variant fills dots `#FF9933`.
  5. **Platform Parity** — two vertical panels (`rect x3` + `rect x14`).
  6. **Mutations Catalog** — hash/pound (`M12 3v18 M3 7.5h18 M3 16.5h18`).
  7. **Fonts** — serif "T" (`polyline 4 7 4 4 20 4 20 7` + stems).
- **Content pane**: `flex:1;overflow-y:auto;padding:20px 22px` (3f uses `18px 20px`). Starts with H1 `font-size:16px;font-weight:600;margin-bottom:3px` and subtitle `font-size:12.5px;color:#8B93A1;margin-bottom:16px`.

Active tab per option: 3a→General, 3b→Editor, 3c→Render Backend, 3d→Theme, 3e→Platform Parity, 3f→Mutations Catalog, 3g→Fonts, 1d→Render Backend.

---

## 5. TURN 3 — "Settings — every tab"

- **Turn id**: `t3` (badge "3").
- **Name**: Settings — every tab.
- **Subtitle**: "— the sheet from **1d**, one card per nav item".
- **Options**: `3a`, `3b`, `3c`, `3d`, `3e`, `3f`, `3g`.
- **Narrative (.dv-next)**: `Try next: "wire the Theme grid into the top-bar palette button" · "add a Shortcuts tab" · "make Platform Parity link to the source files" · "General needs an import/export section"`.

### 5.1 Option 3a — General
- **Caption**: "**General** — workspace & document defaults."
- H1 "General"; sub "Workspace and document defaults."
- **Group card 1** (margin-bottom 18px):
  - "Default format" → value "Auto-detect" + chevron.
  - "On startup" → value "Restore last document" + chevron.
  - "Confirm before delete" / desc "Ask before removing nodes or edges" → **toggle ON** (`#FF9933`).
  - "Send anonymous diagnostics" / desc "Crash reports and usage counts" → **toggle OFF** (`#252B36`, knob `#8B93A1`).
- **Section "RESET"** (10px/700/.6px/`#8B93A1`; margin-bottom 9px).
- **Button "Reset All Settings"**: `height:34px;padding:0 14px;background:#151A24;border:0.5px solid #3a2626;border-radius:8px;color:#EF5A5A;font-size:12.5px` + reset-circle icon (14px).

### 5.2 Option 3b — Editor
- **Caption**: "**Editor** — canvas & interaction."
- H1 "Editor"; sub "Canvas and interaction."
- **Single group card**:
  - "Snap to grid" → **toggle ON**.
  - "Grid size" → **stepper "26 px"**.
  - "Show connection handles" → **toggle ON**.
  - "Default node shape" → value "Rectangle" + chevron.
  - "Default edge style" → value "Solid arrow" + chevron.
  - "Keyboard nudge" / desc "Arrow-key move distance" → **stepper "8 px"**.

### 5.3 Option 3c — Render Backend
- **Caption**: "**Render Backend** — moved here from the Inspector."
- H1 "Render Backend"; sub "How diagrams are rasterized and rendered."
- **Format segmented** (margin-bottom 16px): **SVG** (ACTIVE — `#1a1205`/`#FF9933`, file icon) · **Image** (`#8B93A1`, image icon) · **ASCII** (`#8B93A1`, mono text).
- **Group card**:
  - "Renderer" → `renderSVG(_:)` (mono, `#FFCC66`).
  - "ID policy" → "Stable" + chevron.
  - "Render on every keystroke" / desc "auto vs manual" → **toggle ON**.
  - "Worker thread" / desc "8 MB stack · fresh per call" (mono) → status "**on**" (`#30D158`) with green dot (7px).

### 5.4 Option 3d — Theme
- **Caption**: "**Theme** — Zed Trek palette picker."
- H1 "Theme"; sub "Zed Trek — 20 variants. LCARS Dark is active."
- **Theme swatch grid**: `display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:18px`. Each **ThemeSwatchCard**: `border-radius:10px;overflow:hidden`, border `0.5px solid #252B36` (active `1.5px solid #FF9933`). Preview `height:60px;padding:9px 10px;gap:5px` column with 3 bars (bar1 `height:5px;width:55%`, bar2 `4px/82%`, bar3 `4px/44%`, radius 2px). Footer `padding:7px 10px;background:#111827;border-top:0.5px solid #252B36`, name `11.5px`. 6 cards (colors in §1.1 table):
  1. **LCARS Dark** (ACTIVE) — name `#F2E7D8` + orange checkmark (`#FF9933`, path `M20 6 9 17l-5-5`).
  2. **LCARS Light** — name `#B8BFC9`.
  3. **Federation** — name `#B8BFC9`.
  4. **Red Alert** — name `#B8BFC9`.
  5. **Sick Bay** — name `#B8BFC9`.
  6. **Borg Cube** — name `#B8BFC9`.
- **Group card**:
  - "Appearance" → value "Match system" + chevron.
  - "Diagram palette" → gradient swatch (`12px;border-radius:3px;linear-gradient(135deg,#F2E7D8,#8B93A1)`) + "Zinc Light" + chevron.
  - "Edit theme…" → chevron-right (13px `#8B93A1`, path `m9 18 6-6-6-6`).

### 5.5 Option 3e — Platform Parity
- **Caption**: "**Platform Parity** — feature coverage across targets."
- H1 "Platform Parity"; sub "Feature coverage across build targets."
- **Table card** (margin-bottom 14px):
  - Header row `padding:9px 14px;border-bottom:0.5px solid #252B36;font:10px/700 .6px #8B93A1`: **FEATURE** (flex1) · **MACOS** · **IOS** · **LINUX** (each width 60px, centered).
  - Rows `padding:11px 14px;border-bottom:0.5px solid #1c2432;font-size:12.5px`; cells: green check `#30D158` (path `M20 6 9 17l-5-5`), amber dot `#FF9F0A` (circle, "partial"), or dash `—` `#4F5868` ("unsupported"):
    | Feature | macOS | iOS | Linux |
    |---------|-------|-----|-------|
    | Parse & layout | ✓ | ✓ | ✓ |
    | SVG render | ✓ | ✓ | ● partial |
    | Image render (mono "CG") | ✓ | ✓ | — |
    | ASCII render | ✓ | ✓ | ✓ |
    | Interactive edit | ✓ | ✓ | — |
    | Local LSP (last, no divider) | ✓ | — | — |
- **Legend** (`font:11px #687282;gap:16px;padding:0 2px`): ✓ **Full** · ● **Partial** (`#FF9F0A` dot) · — **Unsupported** (`#4F5868`) · (margin-left auto) mono "**src_text_metrics.swift**".

### 5.6 Option 3f — Mutations Catalog
- **Caption**: "**Mutations Catalog** — searchable, grouped reference."
- Header search field placeholder = "**Filter mutations…**"; content pane `padding:18px 20px`.
- **Category header** pattern: `font:10px/700 .6px`, icon 13px, `margin:0 0 8px`.
- **NODE** (`#FFCC66`, node-rect icon). Card rows (`padding:9px 14px;gap:10px`, icon 14px, label 12.5px, trailing mono `#7EC8DE` 11.5px, dividers `0.5px #1c2432`):
  - "Add node" (+ `#30D158`) → `.addNode(id:label:)`
  - "Remove node" (− `#EF5A5A`) → `.removeNode(id:)`
  - "Edit label" (pencil `#FFD8B0`) → `.setLabel(id:text:)`
  - "Set shape & style" (rect `#CC99FF`) → `.setStyle(id:_:)`
- **EDGE** (`#7EC8DE`, arrow icon). Card:
  - "Add edge" (+ `#30D158`) → `.addEdge(from:to:)`
  - "Remove edge" (− `#EF5A5A`) → `.removeEdge(id:)`
  - "Set arrow & link style" (arrow `#FFD8B0`) → `.setLinkStyle(id:_:)`
- **SUBGRAPH & LAYOUT** (`#FFCC66`, brackets icon). Card:
  - "Create / move subgraph" (brackets `#FFCC66`) → `.subgraph(_:)`
  - "Rearrange & spacing" (refresh `#4EE6A6`) → `.relayout(config:)`

### 5.7 Option 3g — Fonts
- **Caption**: "**Fonts** — bundled & system typefaces."
- H1 "Fonts"; sub "Bundled and system typefaces."
- **Group card**:
  - "UI font" → value "SF Pro Text" + chevron.
  - "Mono font" / desc "Web fallback: JetBrains Mono" (desc color `#FF9F0A`) → value "SF Mono" (mono) + chevron.
  - "Diagram font" → **"Bundled" badge** (`#30D158` + check icon 12px) + "Noto Sans".
  - "Diagram mono" → **"Bundled" badge** + "Noto Sans Mono" (mono).
  - "UI text size" → **stepper "13 pt"**.
- **Info callout**: `background:#0B0F18;border:0.5px solid #252B36;border-radius:10px;padding:12px 14px;gap:9px`; info icon 15px `#7EC8DE`; text `11.5px;line-height:1.5;#8B93A1`: "Bundled Noto fonts neutralize system-font drift — the same source renders the same glyph positions across macOS and iOS versions."

---

## 6. TURN 2 — "Activity rail — one panel per tab"

- **Turn id**: `t2` (badge "2").
- **Name**: Activity rail — one panel per tab.
- **Subtitle**: "— the far-left rail from **1b**, shown in each selected state".
- **Options**: `2a`, `2b`, `2c`, `2d`.
- **Narrative (.dv-next)**: `Try next: "build 2a and 2d into the full 1b window" · "add a Diagnostics tab" · "make Search show edge matches too" · "collapse the panel to just the rail"`.

**Shared panel shell (all of turn 2)**: `width:372px;height:716px;border-radius:18px;overflow:hidden;border:0.5px solid #2A2030;box-shadow:0 30px 70px rgba(0,0,0,.55);background:#05060A;color:#F2E7D8`, flex row.
- **Activity rail** (left, `width:52px;background:#05060A;border-right:0.5px solid #2A2030;padding:12px 0;gap:5px`): the 5-tile rail from 1b (Organize list · Browse file · Search magnifier · Source code · bottom sliders). Each option highlights ONE tile (rail-item active style §1.4).
- **Content column**: `flex:1;background:#0C111B`, flex column.

### 6.1 Option 2a — Organize
- **Caption**: "**Organize** — graph & subgraph tree."
- Rail ACTIVE = tile 1 (Organize, list icon).
- Content = the Organize panel from 1b verbatim: header "ORGANIZE" + plus icon; filter "Filter nodes…"; tree (Ingest sg1 · **Start A** [selected] · Process B · Output sg2 · End C · Edges 3 · A→B · B→C · C→A). Same colors/dims as §3.1 Organize panel.

### 6.2 Option 2b — Browse
- **Caption**: "**Browse** — sample library (the old left sidebar)."
- Rail ACTIVE = tile 2 (Browse, file icon).
- Title "BROWSE" (`padding:15px 15px 8px;11px/700/.6px/#F2E7D8`).
- **Nav list** (`padding:0 8px`): rows `height:28px;gap:9px;border-radius:6px;font-size:12.5px;#F2E7D8`, icon 14px `#8B93A1`:
  - "Coverage matrix" (grid icon) → trailing mono "28×5" `#4F5868`.
  - "Corpus" (book icon) → mono "430".
  - "Cross-format" (columns icon).
  - "Importer probe" (search icon).
  - "Snippets library" (file icon).
- **Search field** (`padding:10px 12px 8px`): `height:30px`, "Search samples…".
- **Sample tree** (`padding:0 8px 12px`, overflow-y auto):
  - Group "**Flowchart**" count "(46)" — chevron + `12px;600;#8B93A1`, count mono `#4F5868`.
  - "**Simple Flow**" [SELECTED] — `height:26px;padding:0 8px 0 24px;background:rgba(255,153,51,.16);color:#FFCC66;border-left:2px solid #FF9933`.
  - Rows `#B8BFC9;12.5px;padding-left:24px;height:26px`: "Batch 1 Shapes", "All Edge Styles", "Subgraphs", "Nested Subgraphs", "CI/CD Pipeline", "System Architecture", "Decision Tree", "Git Branching Workflow".

### 6.3 Option 2c — Search
- **Caption**: "**Search** — find nodes, edges & labels in the diagram."
- Rail ACTIVE = tile 3 (Search, magnifier).
- Title "SEARCH".
- **Search field (focused)** (`padding:0 12px 10px`): `height:30px;background:#080A0F;border:0.5px solid #FF9933;color:#F2E7D8;font-size:12.5px`; magnifier `#FF9933`; query text "**process**"; trailing count mono "3" `#687282`.
- **Filter chips** (`padding:0 12px 12px;gap:6px`): "**All 3**" (ACTIVE — `#1a1205`/`#FF9933`/600) · "Nodes 1" · "Edges 0" · "Labels 2" (inactive chips `#B8BFC9`/`#151A24`/border `0.5px #252B36`).
- **Results** (`padding:0 10px 12px`):
  - Section "**NODES**" (`10px/700/.6px/#8B93A1;padding:4px 6px 6px`).
  - Result card (`padding:9px 10px;gap:9px;background:#111827;border:0.5px solid #252B36;border-radius:9px;margin-bottom:10px`): node icon 15px `#FFCC66`; text "Pro<mark>cess</mark>" (highlight `rgba(255,216,176,.35)`); trailing mono "node:B" `#4F5868`.
  - Section "**LABELS**".
  - Result card (margin-bottom 6px): edge-label arrow icon 15px `#7EC8DE`; text `"Run <mark>process</mark>"` (`12px #B8BFC9`, highlighted word `#F2E7D8`); trailing mono "A→B".
  - Result card: brackets icon `#FFCC66`; text "<mark>Process</mark> queue"; trailing mono "sg1".

### 6.4 Option 2d — Source
- **Caption**: "**Source** — live Mermaid, active line tracks the selection."
- Rail ACTIVE = tile 4 (Source, code `</>`).
- Header (`padding:15px 15px 10px`, space-between): "**SOURCE · MERMAID**" (`11px/700/.6px/#F2E7D8`) + copy icon (14px `#8B93A1`).
- **Code area** (`flex:1;background:#080A0F;font-family:ui-monospace,'SF Mono',Menlo,monospace;font-size:12.5px;line-height:22px;padding:8px 0`). Each line: gutter `width:34px;text-align:right;padding-right:10px;color:#6F7888`:
  1. `flowchart TB` — "flowchart" `#FF9933`, "TB" `#7EC8DE`.
  2. `  subgraph Ingest` — "subgraph" `#FF9933`.
  3. `    A[Start] --> B[Process]` **[ACTIVE LINE]** — row bg `rgba(255,153,51,.08)`, gutter `#FFCC66`, `[Start]`/`[Process]` `#FFCC66`, `-->` `#8B93A1`.
  4. `  end` — "end" `#FF9933`.
  5. `  subgraph Output` — "subgraph" `#FF9933`.
  6. `    C[End]` — `[End]` `#FFCC66`.
  7. `  end`.
  8. `  B --> C` — `-->` `#8B93A1`.
  9. `  C --> A`.
- **Status footer**: `height:30px;border-top:0.5px solid #252B36;padding:0 15px;gap:8px;font:11px mono;#687282`: green dot `#30D158` (6px) + "synced · Ln 3".

---

## 7. Component Inventory (reusable UI components implied)

| Component | Spec summary |
|-----------|-------------|
| **EditorWindow** | 1380×868, radius 26, bg #05060A, border 0.5px #2A2030, shadow 0 40px 100px .65. Title bar (38) + body row + status bar (28). |
| **TitleBar** | 38h #0D1018; traffic lights (3×12px); center view-mode segmented (Code/Editor/Split); right icon cluster (28×26 tiles). |
| **ViewModeSegmented** | #151A24 track, radius 8, active seg #FF9933/#1a1205/600. |
| **TrafficLights** | 3 × 12px dots #FF5D57/#FEBC2E/#28C840 (editor); single 11px #FF5D57 (settings). |
| **ActivityRail** | 52w #05060A, border-right 0.5px #2A2030; 38×38 radius-9 tiles; active = tint+#FF9933+left marker bar (2.5px). 5 tiles: Organize/Browse/Search/Source + bottom sliders. |
| **SidePanel** | 236w (editor) / 372w window (turn2); bg #0C111B; header caption + optional +; content list. |
| **OrganizeTree** | subgraph rows (brackets #FFCC66, chevron, mono id), node rows (rect icon, indent 26px, mono id), selected row = tint+#FFCC66+left border 2px #FF9933; edge group + mono edge rows. |
| **BrowseList** | nav rows (icon 14 + label + mono count) then search + collapsible sample groups; selected sample = tint highlight. |
| **SearchPanel** | focused search field (orange border), filter chips (pill), grouped result cards with highlight marks + mono locus. |
| **SourceEditor** | line-gutter + syntax-highlighted Mermaid, active line bg rgba(255,153,51,.08); synced status footer with green dot. |
| **Canvas** | dotted grid (26px), floating ToolPalette, ZoomControl, SelectionBreadcrumb, nodes + edges. |
| **ToolPalette** | rgba(13,16,24,.9) rounded-12 column; 32×32 radius-8 tiles; active = accent tint. |
| **ZoomControl** | #0D1018 radius-10; Fit(active)/−/100%/+/1:1 mono. |
| **SelectionBreadcrumb** | accent-tint pill w/ node icon + `flowchart:node:A` mono. |
| **CanvasNode** | 236×120 #111827 radius-8; selected = 1.5px #FF9933 + 4 corner handles (9px squares); default = 1px #252B36. Label SF Pro Display 34/600. |
| **Inspector** | 312w #0C111B; header (icon badge + title + mono id); sections EDIT NODE / ARRANGE / DIAGRAM / INSERT. |
| **TextInputRow** | 100%×32 #080A0F border 0.5px #2A2030 radius-7 13px. |
| **ValuePill (menu row)** | 28h #151A24 border 0.5px #252B36 radius-7 + icon + label + chevron. |
| **InspectorSegmented** | #151A24 radius-8 pad-2; active seg #FF9933/#1a1205/600 (Border, Direction). |
| **ColorSwatchRow** | label + 44×24 swatch (border 0.5px #3a4250). |
| **ColorDotPicker** | 6 × 26px round dots; selected = double ring box-shadow #FF9933. |
| **AlignButtonRow** | 6 × 34×30 #151A24 radius-7 buttons + inner divider. |
| **SliderRow** | 4px track #252B36, fill #FF9933, 14px knob #FFCC66 border 2px #05060A; mono value #FFCC66. |
| **InsertGrid** | 2-col grid of 36h labeled action buttons (Subgraph/Icon/Image/Rearrange), category-colored icons. |
| **StatusBar** | 28h #0D1018 mono 11px; family dot + counts + backend + cursor pos. |
| **SettingsSheet** | 748×520 radius-20 #0E1421; header + 196 nav + content. |
| **SettingsModalFrame** | 920×632 frame; dimmed dotted editor + rgba(5,6,10,.62) blur(3) scrim; centered sheet. |
| **SidebarNavItem** | 32h radius-7 gap-9 icon-15; active = tint/#FFCC66/600/#FF9933-icon. |
| **SettingsSearchField** | 30h×180w #080A0F border 0.5px #2A2030 radius-8 + magnifier. |
| **SettingsGroupCard** | #111827 border 0.5px #252B36 radius-10; rows pad 12×14, dividers 0.5px #252B36. |
| **ToggleRow** | label(+desc) + 40×24 pill switch (ON #FF9933/#fff knob; OFF #252B36/#8B93A1 knob). |
| **StepperRow** | label(+desc) + stepper (−/value mono/+) border 0.5px #252B36 radius-7. |
| **MenuRow (dropdown)** | label + value + chevron (11px #8B93A1). |
| **StatusRow** | label + colored dot + status word (e.g. green "on"). |
| **SegmentedFormatControl** | SVG/Image/ASCII; #151A24 radius-9 pad-3; active #FF9933. |
| **ThemeSwatchCard** | radius-10; 60px 3-bar preview over theme bg + footer name; active = 1.5px #FF9933 border + check. |
| **ThemeGrid** | 3-col grid gap-12 of ThemeSwatchCard. |
| **ParityTable** | header row (FEATURE + 3 target cols) + rows w/ check(#30D158)/dot(#FF9F0A)/dash(#4F5868); legend row. |
| **MutationCategoryGroup** | colored uppercase header + card of mutation rows (icon + label + mono API). |
| **BundledBadge** | green check + "Bundled" (#30D158) inline label. |
| **InfoCallout** | #0B0F18 border 0.5px #252B36 radius-10; info icon #7EC8DE + muted text. |
| **DestructiveButton** | 34h #151A24 border 0.5px #3a2626 radius-8 text #EF5A5A + icon. |

---

## 8. Complete Turn / Option Index

- **t1 — Editor layout redesign**: `1b` (full 1380×868 editor window), `1d` (Settings modal ⌘, — Render Backend tab active).
- **t2 — Activity rail — one panel per tab**: `2a` Organize, `2b` Browse, `2c` Search, `2d` Source (each 372×716 rail+panel).
- **t3 — Settings — every tab**: `3a` General, `3b` Editor, `3c` Render Backend, `3d` Theme, `3e` Platform Parity, `3f` Mutations Catalog, `3g` Fonts (each the 748×520 settings sheet).

Total: **3 turns, 13 options.**
