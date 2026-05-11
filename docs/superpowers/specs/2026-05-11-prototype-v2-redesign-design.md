# Prototype v2 — UX redesign from UX-1 + UX-2 feedback

**Date:** 2026-05-11
**Source:** `Design/prototype-v2/` (current state, v0.3.0)
**Target:** `Design/prototype-v2/` (in place — same directory, refactored)
**Input docs:** [`Design/UX-1.md`](../../../Design/UX-1.md), [`Design/UX-2.md`](../../../Design/UX-2.md)
**Predecessor spec:** [`2026-05-10-prototype-v2-design.md`](2026-05-10-prototype-v2-design.md) (v0.3.0 visual pass)

## Goal

The v0.3.0 prototype landed a professional macOS-light visual language. Two independent UX reviews then identified that the *visual* layer is solid but the *conceptual* layer is inconsistent: the same concepts surface as workstations, editor modes, pane tabs, right-rail sections, cards, and "Open in…" actions on different screens, often under different names. This redesign keeps the visual language untouched and reconciles the conceptual language across all eight screens.

This is a full-sweep refactor (option C from brainstorming): it consolidates information architecture, standardizes the page header anatomy, unifies the right-rail identities, locks in a status-pill taxonomy, renames overloaded terms (Code, Studio, Playground, Visual editor), and clarifies the primary-CTA semantics. The Diagram editor + AI studio handoff is reorganized so both surfaces have a single, defensible job.

## Non-goals

- Visual language changes — color tokens, type stack, spacing scale, shadow recipes all stay as v0.3.0 set them.
- New product capabilities — no new diagram types, no new canvas features, no new export formats.
- Accessibility audit — worth doing, not bundled here.
- Mobile / responsive — prototype targets desktop widths only.
- Production Swift code (`Sources/`) — this is a clickable HTML prototype.
- Dark mode — tokens stay structured for it, but it ships separately.

## Inputs in summary

**UX-1's priorities (in its own order):** unify mode-switching tabs across editors; resolve "Studio" naming conflict; standardize page-title formula; clarify Render button; dedup save-state messaging; resolve modal-vs-page for Share; standardize right-panel identity.

**UX-2's priorities:** unify diagram-editor modes; pick Source over Code; rename or scope-narrow Playground; standardize right rails; normalize creation and open-in labels; reduce duplicate navigation in Presentations; simplify Share action model.

The two reviews converge on every cross-cutting issue and diverge only on degree: UX-2 recommends the stronger move of consolidating Playground + Visual editor + AI studio into one destination. This spec adopts a **hybrid consolidation** — Playground + Visual editor merge into a single "Diagram editor" destination with `Source · Visual · Split` modes; AI studio remains a separate destination scoped to generation-from-scratch and heavyweight multi-turn refinement; the editor reaches AI via an in-place Assistant panel with an "Open in AI studio" promotion.

## Decisions in one place

| Area | Decision |
|---|---|
| IA — destinations | Home · Library · **Diagram editor** · AI studio · Presentations · Activity · Settings |
| IA — editor modes | `Source · Visual · Split` as URL state (`editor.html?mode=…`) |
| IA — AI handoff | In-place **Assistant** rail tab + `⤢ Open in AI studio` promotion |
| Header — structure | Two-row header on every object screen |
| Header — title formula | `Workspace › Section › Object` |
| Header — primary CTA | Paired with the mode it acts on; Diagram editor → **Publish version**; Presentations → **Present** |
| Terminology | Source replaces Code; Assistant replaces "Studio" (panel); Studio plan retained for the tier; Playground deleted; Visual editor deleted as a destination |
| Right rails | Inspector ↔ Diagram swap on editor; Slide rail on Presentations; Diagram rail on Library; Event rail on Activity; Scope rail on Settings; none on Share |
| Status pills | Five families: Document state · Sync · Sharing · Content type · AI. Counts are not pills. Card chip order: `[Type] [Sync] [Sharing] [AI]` |
| Share dialog | Modal at 720px; single `Send & save` primary CTA |
| Notifications | Global notif button only — never in a right rail |
| Save state | Page header Row 2 only — never duplicated in a right rail |
| Render button | Replaced by **Publish version** — writes a named, immutable snapshot |
| File structure | One `editor.html` with mode as URL state; `playground.html` and `visual.html` deleted |

## Information architecture

Final mental model:
- **Library** is where diagrams live.
- **Diagram editor** is where diagrams are edited (modes: Source, Visual, Split).
- **AI studio** is where new diagrams are generated, and where heavyweight multi-turn refinement happens.
- **Presentations** is deck authoring; embeds diagrams from Library.
- **Activity** is the change feed, decision support, and audit log.
- **Settings** controls workspace policy and plan.
- **Share** is a modal opened from any object screen.

Left nav (in order):
```
Home
Library
Diagram editor   ⌘1
AI studio        ⌘2
Presentations    ⌘3
Activity
Settings
```

The previous four "workstation" cards (Home + Playground + Visual editor + AI studio) are reduced to three primary work destinations. The `⌘4` shortcut is retired.

## Page header anatomy (cross-cutting)

Every object-level screen — Library, Diagram editor, AI studio, Presentations, Activity, Settings — uses the same two-row header. Share uses its own modal chrome and is described separately.

```
┌─ Row 1 ─ Workspace › Section › Object ──────────────────── [collab][Share][Export][⋯] ┐
├─ Row 2 ─ [Mode tabs or scope toggles] ····  [Status pills]    [Primary CTA when applicable] │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**Row 1 — *where I am and what I can do to this thing***

- Breadcrumb is left-aligned. Always starts with the workspace name (`Engineering`). Max three levels for readability; deeper paths collapse the middle with `…`.
- Right cluster carries object-level actions: collaborator avatars (when present), `Share`, `Export`, overflow menu.

**Row 2 — *which view I'm in and what state it's in***

- Left slot:
  - When the screen has modes (Diagram editor, Presentations, AI studio refining): `Source · Visual · Split` style tab strip.
  - When the screen has no modes (Library, Activity, Settings): scope/filter/location toggles (Library: location chip + filter chips; Activity: scope toggle; Settings: scope chip with the `ADMIN · affects all of Engineering` callout pattern from v0.3.0).
- Middle: status pills, following the chip-family order locked in below.
- Right slot: primary CTA, paired with the mode it acts on. Screens without a primary CTA (Library, Activity, Settings) leave this slot empty.

**Title formula — `Workspace › Section › Object`**

Examples:
```
Engineering › Library › Architecture › pr-lifecycle.mmd
Engineering › Diagram editor › pr-lifecycle.mmd
Engineering › Presentations › SDK Auth · Q2 review
Engineering › AI studio › New diagram
Engineering › AI studio › pr-lifecycle.mmd        (refining)
Engineering › Activity
Engineering › Settings › Sharing & permissions
```

The previous formulas (`{filename} — {workstation}`, `{workstation} — {workspace}`, bare `Settings`) are retired. The workspace prefix exists on every page, so Settings (which previously had no second term) gets the same anchoring as any other screen.

## Terminology

A single rename pass. Adopted in one commit so the app never lives in a half-state.

| Surface | Before | After |
|---|---|---|
| Mode label | `Code` | **Source** |
| Editor target | `Code editor` | **Source editor** (the Source mode of Diagram editor) |
| Diff CTA | `Review diff` | **Review source diff** |
| Workstation card / nav | `Playground` | (deleted — folded into Diagram editor) |
| Workstation card / nav | `Visual editor` | (deleted — Visual is a *mode* inside Diagram editor) |
| Right panel (old Playground) | `Studio` | **Assistant** |
| Right panel (Presentations) | `Studio assistant` | **Assistant** |
| Activity actor | `Studio AI` | **AI assistant** |
| Activity field | `Source mode: Visual editor` | **Edited in: Visual mode** |
| Library row action | `Open in Visual` | **Open in Visual mode** |
| Library row action | `Open in Code` | **Open in Source mode** |
| Library row action | `AI refine` | **Refine with AI** |
| Library row action | `Add to deck` | **Add to presentation** |
| Presentations top tabs | `Outline · Edit · Source` | **Slides · Outline · Source** |
| Presentations left panel | `Outline` | **Slide navigator** |
| Plan name | `Studio` (bare) | **Studio plan** (always with "plan"; visually a plan chip) |
| Plan upsell pill | `+ Studio plan` | Suppressed when user is already on Studio plan |
| Settings nav label | `Sharing policy` | **Sharing & permissions** (matches the page title) |
| Settings nav tag | `careful` (Advanced) | (removed — destructive warnings inline at the action site) |

**Final dictionary** — exactly one meaning per word after the pass:

| Word | Meaning |
|---|---|
| Source | The textual representation of an artifact (Mermaid for diagrams, markdown for decks) |
| Visual | A canvas mode for editing a diagram interactively |
| Split | A pane mode showing Source and Visual side-by-side |
| Diagram editor | The destination where diagrams are edited (any mode) |
| AI studio | The global destination for generating diagrams from scratch and heavyweight multi-turn refinement |
| Assistant | A contextual AI panel inside another surface (Diagram editor rail, Presentations rail). Same component, same name, both places |
| AI assistant | The AI actor name in Activity events |
| Studio plan | The subscription tier — always with "plan" |
| Publish | Commit a named, immutable version of an artifact |
| Present | Enter presentation playback mode for a deck |

## Right-rail identities

| Screen | Rail | Tabs (when applicable) | Notes |
|---|---|---|---|
| Diagram editor — selection active | **Inspector** | — | Auto-swaps in when user clicks a canvas node |
| Diagram editor — no selection | **Diagram** | Details · Comments · History · Export · Assistant | Default state |
| Presentations | **Slide** | Notes · Diagrams · Assistant · Theme | Default tab: Notes. Diagrams tab carries the stale-diagram review banner when applicable |
| Library — file selected | **Diagram** | Details · Sharing · Used in decks · Comments · History | Same rail anatomy and identity as the editor's Diagram rail; tab set is screen-specific (Sharing and Used-in-decks belong here; Assistant and Export belong in the editor) |
| Activity — event selected | **Event** | Details · Related · Audit | Notifications block is *not* here |
| Settings | **Scope** | — (Scope · Plan & usage · Help as sections) | Plan & usage stays visible on every settings subpage |
| Share | (no rail) | — | The modal itself is the surface |
| Home | **This week** | — | AI credits · Activity · Updates |

**Cross-cutting rules:**
- Notifications appear only in the global notif button (titlebar). Never in any rail.
- Save state appears only in the page header Row 2. Never duplicated in any rail.
- The Inspector ↔ Diagram swap inside the editor uses the same DOM container — only the rail header label and tab set change, the width does not.

## Status pill taxonomy

Five families, each with its own visual treatment. Counts are explicitly not pills.

| Family | Examples | Treatment |
|---|---|---|
| Document state | Saved · Auto-saved · Unsaved · Rendered · Warning | Neutral pill, leading dot; warning gets amber dot |
| Sync state | Live · Co-editing · Stale · Snapshot | Neutral pill; animated dot for Live / Co-editing; amber for Stale; outline-only for Snapshot |
| Sharing state | Private · Shared · External · Pending invite | Neutral pill with glyph (lock / share / external) |
| Content type | Flow · Sequence · State · ER · Gantt · Class · Mindmap · Journey | Colored chip using existing `--type-*` tokens. Type-coding becomes load-bearing across every screen |
| AI state | AI-generated · AI-refined · Restorable | Lavender pill (the `--accent` family) with sparkle glyph |
| Counts | `47 diagrams` · `9 shown` · `3 unread` · `12 events` | Plain inline text — never a pill |

**Card chip order rule:** `[Type] [Sync] [Sharing] [AI]`. The order is enforced by DOM placement, not CSS ordering, so an out-of-order chip is visible in code review. Missing chips simply drop out.

The order fixes UX-1's "Flow is blue here, pink there" complaint by anchoring color to type, not to layout; and it fixes UX-2's "chip order is inconsistent" note by codifying a single sequence.

## Diagram editor

```
┌─ Row 1 ─ Engineering › Diagram editor › Architecture › pr-lifecycle.mmd ──────────────┐
│                                                       [👤👤👤+1][Share][Export][⋯]   │
├─ Row 2 ─ Source | Visual | Split ················  Saved · Auto · 312ms              │
│                                                    [✨ Refine with AI →]  [Publish ⌘⇧P]│
├─ Catalog rail ──────┬─ Center pane (depends on mode) ──┬─ Right rail ────────────────┤
│  Recent             │                                   │ Diagram  (or Inspector)    │
│  Catalog            │  Source → editor + preview        │   Tabs: Details · Comments │
│  ─ Architecture     │  Visual → canvas + shapes rail    │          · History         │
│  ─ Auth             │  Split  → editor | canvas         │          · Export · Assistant│
│  ─ Pipelines        │                                   │                            │
│  ─ Templates        │                                   │ Inspector activates when a │
│                     │                                   │  node is selected — same   │
│                     │                                   │  width, label swaps.       │
└─ Status bar ────────┴─────── L 14 · C 12 · UTF-8 · LF · 714 B · 19 lines ────────────┘
```

**Mode behavior:**

- **Source mode** — Mermaid source on the left of the center pane, live preview on the right. The stat strip (`Rendered · 312ms | 24 nodes | 31 edges | 3 subgraphs | flowchart TD`) sits above the editor. Warning chip slides to the right edge with a popover for full text (fixes UX-1's truncation complaint).
- **Visual mode** — full-width canvas; the catalog rail is replaced by the shapes / connect / layout palette from the current `visual.html`. Floating toolbar above selection (`Shape · Fill · Stroke · Label · Dupe · Delete`) is retained for quick actions. Right rail becomes Inspector while a node is selected, Diagram otherwise.
- **Split mode** — Source left, canvas right, 50/50 with a draggable splitter. Both sides remain interactive.

**Mode changes are URL state, not navigation.** `editor.html?mode=source|visual|split` (default `source`). The center pane swaps in place; rails, header, breadcrumb, and status bar stay mounted. Tabs animate underline + content fade. `sessionStorage` remembers the last-used mode per diagram so Library's `Open` button uses it.

**Visual mode pending-edit banner** — single banner, visible only when there are pending visual edits not yet written to source:
```
Visual edits will update Mermaid source.    [Review source diff]  [Apply changes]
```
Idle state shows nothing. The current always-on NOTE banner is removed.

**Visual mode unsupported-type empty state** — just-in-time, replaces the always-visible "Limitations" card:
```
Visual mode isn't available for sequence diagrams yet.
Edit in Source mode, or see the supported types →
                                                  [Open in Source mode]
```

## Refine with AI handoff

The flow is the same regardless of where the user starts.

- **From the Diagram editor header** — clicking `✨ Refine with AI →` opens the right rail and selects the **Assistant** tab inside the Diagram rail. Chat happens in-place. No page transition.
- **Promoting to AI studio** — the Assistant panel has an `⤢ Open in AI studio` affordance. Clicking navigates with `?source=<id>&from=editor`, preserves chat state, opens AI studio with the diagram source pre-loaded and the side-by-side diff view active. The back-arrow returns to the editor.
- **From AI studio directly** — empty-state landing offers `Generate a new diagram` and `Refine an existing diagram →` (which opens a small picker scoped to recent diagrams).
- **Diff view** — both surfaces share a `Source diff` component (left = current, right = proposed). `Apply` writes back to source. `Apply & return` does the same and bounces back to the editor.

**AI studio's job after this:** generation from scratch, and heavyweight multi-turn refinement. It is *not* the only place to talk to the AI about a diagram. The Assistant panel is.

**Activity attribution:** every AI-authored event lists `AI assistant` as the actor, regardless of whether it came from the Assistant panel or AI studio. The `Edited in` field carries the surface (`Visual mode`, `Source mode`, `AI studio`).

## Publish version (replaces Render)

The Diagram editor's primary CTA opens a popover:
```
Publish version of pr-lifecycle.mmd
─────────────────────────────────────
Version label    v0.4
Notes (optional) Added retry edges for transient failures
                                            [Cancel]  [Publish ⌘⇧P]
```

**On publish:**
- A named, immutable snapshot is created. It appears in the Diagram rail's History tab.
- The `Saved` status pill flashes to `Published · v0.4` for ~1.2s, then settles back to `Saved`.
- All consumers that target "the latest" refresh to the new version:
  - Presentations' stale-diagram review queue
  - Library's `Used in decks` references
  - Share's Diagram-link cards (when set to "latest")
- Auto-render continues to update the live preview between publishes. Publish is decoupled from render.

## Page-by-page changes

### `index.html` — Home (resume-first reframe)

- Greeting: `Good afternoon, Alex. Pick up where you left off, or start something new.`
- **Recent** list at the top — five rows, each with `[Type] [Sync] [Sharing] [AI]` chips in that order, file name, relative time. `See all in Library →` link to the right.
- **Start something new** row below: `+ New diagram · ✨ Generate with AI · 📄 From template · ↑ Import Mermaid · ▦ New presentation`. This is the canonical creation row; Library reuses it in its `+ New diagram ▾` dropdown.
- Right column: `This week` — `AI credits 32/50` with progress bar (Studio plan), Activity summary, Updates.
- Workstation cards are deleted entirely (they duplicated the left nav).

### `editor.html` — Diagram editor (new file)

Consolidates the current `playground.html` + `visual.html`. See the Diagram editor section above for layout.

### `ai.html` — AI studio (scope narrowed)

- Empty state lands with two primary actions: `✨ Generate a new diagram` and `Refine an existing diagram →`.
- Refining surface uses the same `Source diff` component as the editor's Assistant panel.
- Header right slot:
  - Generating: `AI · 12 credits used` status · `[Reset]` · `[Generate ⌘⏎]`
  - Refining: `Source diff · 4 changes` status · `[Discard]` · `[Apply diff]`
- AI studio is no longer the right destination for one-off refinements — those happen in the editor's Assistant panel.

### `library.html` — Library (location-vs-filter split)

- **Row 1**: `Engineering › Library` · right cluster `[Sort ▾] [+ New diagram ▾]`.
- **Row 2**: location chip on the left (the active Folder or View name) · count text on the right (`47 diagrams · 9 shown`). Below this row, two chip strips: `Type:` and `Status:`, each filter chip with an ✕, plus `Clear all filters` when ≥1 chip is active.
- **Left rail**: Views section (saved queries) above a Folders section. Mutually exclusive — picking a Folder clears the Views selection and vice versa.
- **Card grid**: chip order `[Type] [Sync] [Sharing] [AI]` everywhere.
- **Right rail**: `Diagram` rail with tabs `Details · Sharing · Used in decks · Comments · History`. The `Used in decks` tab is promoted from the bottom of a long panel to its own tab — answering "if I edit this, what breaks?" is one click.
- **"Open this diagram" cluster** in the right rail: `[Open]` (last-used mode) + secondary `[▾ Open in Source mode]` `[▾ Open in Visual mode]` `[▾ Open in Split mode]` `[✨ Refine with AI]` `[+ Add to presentation]`.
- Role labels (Owner / Editor / Commenter / Viewer / Pending) match Share and Settings exactly.

### `present.html` — Presentations (single navigator, tabbed rail)

- **Row 1**: `Engineering › Presentations › <deck name>` · right cluster `[Share][Export][⋯]`.
- **Row 2**: tabs `Slides · Outline · Source` · status `Saved · 12 slides · 1 stale diagram` (Stale uses the amber Sync pill) · right slot `[✨ Refine with AI →] [Present ⌘⇧P]`.
- **Left rail**: **Slide navigator** (the single, canonical slide list). The bottom thumbnail strip is deleted, not hidden.
- **Slide canvas**: shows `Slide 4 of 12` only in the canvas's slide-status corner. The bottom pagination line is removed.
- **Right rail**: `Slide` rail with tabs `Notes · Diagrams · Assistant · Theme`. Notes is the default tab.
- **Stale-diagram review**: when any diagram in the deck is stale, the `Diagrams` tab carries a count badge and the review banner (`Compare changes · Accept update · Keep snapshot · Update all`). The Row 2 `1 stale diagram` pill clicks through to that tab — two entry points, one canonical view.
- **Slide title vs diagram caption**: the diagram card shows only the Sync pill (`Live` / `Stale` / `Snapshot`). The slide's own header remains the single header per slide.
- `Source` mode collapses the left rail (deck markdown takes the full center width).

### `activity.html` — Activity (clickable decision support, single Mark-read)

- **Row 1**: `Engineering › Activity` · right cluster `[⋯]`.
- **Row 2**: scope toggle (`This diagram · All workspace · Involving me`) · status `3 unread` · right slot `[Mark all read]`.
- **Left rail**: `Filters` section above a `Decision support` section above a `Scope` section above an `Audit log (admin)` section. Audit log is demoted out of Scope into its own slot with an `(admin)` glyph.
- **Decision support counts are filters** — clicking `3 unresolved` scopes the feed to unresolved items. Same for restorable AI edits and stale links.
- **Feed**: each event card uses the locked-in vocabulary (`AI assistant` actor, `Edited in: Visual mode` field, relative time).
- **Right rail**: `Event` rail with tabs `Details · Related · Audit`. Notifications block is **not** here — it lives in the global notif button.
- **Single Mark-read affordance**: `Mark all read` is the only one. Selecting and resolving an event marks it read implicitly; the duplicate right-panel `Mark as read` is removed.
- **Time display**: relative in the feed (`2m`, `1h`); local + UTC parenthetical in the right rail (`14:20 local · 18:20 UTC`).

### `settings.html` — Settings (aligned labels, dedup'd save, plan-as-chip)

- **Row 1**: `Engineering › Settings › Sharing & permissions` · right cluster shows the existing `ADMIN · affects all of Engineering` callout pattern.
- **Row 2**: no mode tabs · status `Saved · 2s ago` · no primary CTA.
- **Settings nav**: `Personal · Diagram defaults · Workspace · Plan · Advanced`. Each nav item carries a small tag where useful: `Personal: new` (when new features land in personal settings), `Workspace: team`, `Plan: billing` + a `Studio plan` chip, `Advanced: admin` + a `⚠` glyph. The `careful` tag is removed; destructive actions inside Advanced get inline red confirmation at the action site instead.
- **Workspace → Sharing & permissions**: nav label and page title both read `Sharing & permissions`.
- **Right rail**: `Scope` rail with three sections — `Scope`, `Plan & usage` (AI credits · Diagrams · Workspaces · Co-editors · External shares), `Help`. Plan & usage stays visible on every settings subpage so quota gating is always answerable.
- Save-state appears only in Row 2. The duplicate right-rail Status block is removed.
- Role descriptions (Owner / Editor / Commenter / Viewer / Pending) are the single source of truth that Library and Share read from — same descriptions everywhere.

### `share.html` — Share (modal, single CTA, policy promoted)

- Modal, 720px max width. Esc / backdrop / ✕ close. Originating page stays visible underneath. The file can still be opened standalone for preview (renders as a full page when no `?open=1` parameter is present).
- **Header**: `<file>.mmd · Share` · ✕.
- **Subhead**: `Engineering · workspace policy: external sharing allowed for 2 domains` — policy state surfaced at the top, not buried at the bottom.
- **People section**: invite input · external invite chips inline with `External · Allowed by policy` confirmation · `People with access` list with role chips that match Library/Settings vocabulary.
- **Links section**: two link cards (Diagram link, SVG link) with primary fields visible (`On/off · Permission · Sign-in · Expiration · Copy`). Advanced settings (source visibility, CDN mode, theme, live-update behavior) live behind a `▾ Advanced` disclosure per card.
- **Workspace policy details**: a collapsible callout below the link section. Collapsed by default unless the current state is blocking.
- **Footer**: summary string `2 invites · 1 external (Allowed by policy)` · `[Cancel] [Send & save]`. `Send & save` commits all pending changes (invites + role changes + link toggles + external confirmations) atomically.
- The `+ Studio plan` upsell pill is suppressed when the user is already on Studio plan.

## File map

```
Design/prototype-v2/
├── index.html              — Home (reframed)
├── editor.html             — Diagram editor (NEW; Source / Visual / Split via ?mode=)
├── ai.html                 — AI studio (scope narrowed)
├── library.html            — Library
├── present.html            — Presentations
├── activity.html           — Activity
├── settings.html           — Settings
├── share.html              — Share modal
├── playground.html         — DELETED
├── visual.html             — DELETED
├── assets/
│   ├── shared.css          — Updated tokens + anatomies + chip families
│   └── prototype.js        — Updated controllers (Mode, Selection, Publish, ShareModal, RefineAI)
├── tests/
│   └── prototype-enhancements.test.mjs   — Expanded invariant checks
├── server.mjs              — Unchanged
└── package.json            — Unchanged
```

### `assets/shared.css` changes

- New chip-family tokens: `--pill-state-*`, `--pill-sync-*` (with amber for Stale), `--pill-sharing-*`, `--pill-ai-*` (lavender). The existing `--type-*` tokens become the load-bearing Content type chips.
- New page-header anatomy: `.pageheader`, `.pageheader__row1`, `.pageheader__row2`, `.pageheader__breadcrumb`, `.pageheader__modes`, `.pageheader__status`, `.pageheader__cta`. Identical DOM shape on every page.
- New rail anatomy: `.rail`, `.rail__header`, `.rail__tabs`, `.rail__tabpanel`. Inspector ↔ Diagram swap is a class toggle (`.rail--inspector` / `.rail--diagram`) on the same container — width preserved.
- New pending-edits banner: `.editbanner` (visible only when JS adds `.editbanner--active`).
- Card chip order enforced via DOM order in `.cardchips`. No CSS ordering — chips in the wrong order surface as visibly wrong rather than reordered into place.

### `assets/prototype.js` changes (new controllers)

- **Mode** — for `editor.html`. Reads `?mode=`, swaps `.editor__pane--{source,visual,split}` visibility, updates `.pageheader__modes` underline, persists last-used mode to `sessionStorage` keyed by diagram id.
- **Selection** — for `editor.html` Visual mode. On canvas-node select, swaps the right rail's class to `.rail--inspector` and renders inspector contents; on deselect, swaps back to `.rail--diagram`.
- **Publish** — opens the version-naming popover; on confirm, animates the `Saved` chip → `Published · v0.4` → `Saved`. Adds a new History tab entry (mock data).
- **ShareModal** — on any page that opens Share. Dims the originating page, mounts the modal, owns Esc/backdrop close, owns the `Send & save` footer summary string. When `share.html` is loaded standalone (no `?open=1`), it renders as a full page for preview.
- **RefineAI** — opens the editor's right rail to the `Assistant` tab; `Open in AI studio ⤢` navigates with `?source=<id>&from=editor` so AI studio's back-arrow returns to the editor.

## Testing — `tests/prototype-enhancements.test.mjs`

The existing Node test harness is expanded with structural invariants. The intent is that any future edit that breaks a cross-cutting promise fails the test, not the eye.

**Cross-cutting invariants:**
- Every page has exactly one `.pageheader` with `row1` + `row2`.
- Every page's `row1` breadcrumb starts with the workspace name (`Engineering`).
- Mode tabs (where present) sit in `row2`'s left slot, not `row1`.
- Save-state appears in `row2` only (zero `Save`/`Auto-saved` matches inside `.rail` or `.activity__rightpanel`).
- Notifications block appears only in the global notif button (zero matches inside `.rail__tabpanel`).
- Card chip order is `[Type] [Sync] [Sharing] [AI]` in every `.cardchips` (assert DOM order, not CSS order).
- "Code" never appears as a tab label, rail label, or button label (find/replace audit — only "Source").
- "Studio" appears only as part of "Studio plan", "AI studio", or "Assistant" (regex denylist for bare "Studio" in tab/label/button contexts).
- "Playground" appears nowhere in HTML.
- "Visual editor" appears nowhere as a destination label (only "Visual mode" inside Diagram editor contexts).
- Counts (`47 diagrams`, `9 shown`, `3 unread`, `12 events`) render as plain text — never inside a `.pill` class.
- Each `.pill` carries exactly one family class from the set `{state, sync, sharing, type, ai}`.

**Per-screen invariants:**
- `editor.html` responds to `?mode=source|visual|split` (default `source`).
- `editor.html` has a `.editbanner` that is `.editbanner--active` only when there are pending visual edits (test fixture provides both states).
- `present.html` has zero bottom-strip slide thumbnails (the strip element is deleted, not hidden).
- `library.html` has `Type` + `Status` chip strips above the grid, and `Views` + `Folders` in the left rail.
- `activity.html` `.decisionsupport` rows have `role="button"` and `aria-pressed` (clickable filter behavior, not informational).
- `share.html` mounts as a modal when opened with `?open=1` from a parent page; renders standalone otherwise.
- `settings.html` nav label and `h1` both read `Sharing & permissions`.

## Implementation choreography

Six stages, each independently testable, each landable as its own PR.

1. **Tokens & shared chrome** — add the new pill-family tokens, page-header anatomy classes, rail anatomy classes, and banner pattern to `shared.css`. No HTML edits yet. Tests for tokens and class shape. Lowest-risk diff.
2. **Terminology pass** — global find-replace across every existing HTML file (Code→Source, Studio→Assistant/AI studio/Studio plan per the dictionary, Visual editor→Visual mode in Library, etc.). Add the negative tests (no bare "Studio", no "Code"). No structural changes.
3. **Header + rail anatomy on existing pages** — convert every page's header and right rail to the new two-row + rail-tabs shape *in place*. Library, Activity, Settings, Presentations, AI, Share use the new chrome. `playground.html` and `visual.html` adopt the new chrome too (interim state — they'll be deleted in stage 4). Cross-cutting invariant tests pass for all screens at the end of this stage.
4. **Diagram editor consolidation** — create `editor.html` with `?mode=source|visual|split`. Wire Mode, Selection, and Publish controllers. Delete `playground.html` and `visual.html`. Update every internal link to point at `editor.html?mode=…`. The IA collapse.
5. **Per-screen consolidations** — Home reframe (resume-first). Library location/filter split + Used-in-decks tab. Activity clickable decision support + Mark-all-read CTA. Presentations slide-nav dedup + tabbed rail. Settings save-state dedup + plan-as-chip + label alignment. Share modal-ification + single CTA.
6. **Refine-with-AI handoff + Publish polish** — wire the Assistant tab as the in-place AI surface, wire `⤢ Open in AI studio` promotion with preserved state, wire the Publish-version popover and the `Published · v0.4` flash. Update AI studio's empty-state and refine-from-recent landing.

Stages 1–3 are mostly mechanical (CSS + find/replace + chrome refactor). Stages 4–6 are where the new JS lives.

## Risks and how we mitigate them

- **Half-state risk during the rename pass.** The terminology pass is intentionally a single stage that touches every HTML file together. No two-PR window where some screens say "Code" and others say "Source".
- **Visual regressions in v0.3.0's polish.** The visual language is untouched (same color tokens, same spacing scale, same shadow recipes). Snapshot-style screenshot checks against v0.3.0 are not part of the test harness; reviewers eyeball each stage in the browser before approving.
- **The editor mode-swap feeling janky.** Mode change is URL state, not navigation — center pane swaps in place, rails stay mounted, tabs animate underline + content fade. If the swap stutters, fall back to crossfade rather than instant cut.
- **AI studio feeling redundant after the scope narrowing.** This is the deliberate trade — the redundancy was the problem. AI studio's job is now narrow but defensible (generation + heavy refine). The Assistant panel handles the cases AI studio used to absorb.
- **Card color-coding gone wrong.** The `--type-*` tokens already exist in `shared.css`; the work is removing decorative overrides where they happen. Tests assert that every `.cardchips` carries the Type chip first, so a missing type chip surfaces as a test failure.

## Done definition

The redesign is done when:
- All six stages have shipped, each with its own PR and passing tests.
- `playground.html` and `visual.html` no longer exist.
- `editor.html` responds to `?mode=source|visual|split` and renders the three modes without page reload.
- Every cross-cutting invariant in `prototype-enhancements.test.mjs` passes.
- Every page's header matches the two-row anatomy and breadcrumb formula.
- Every right rail matches its locked-in identity from the table above.
- A walkthrough of all eight screens reads as one product, not eight.
