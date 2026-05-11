# Prototype v2 Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconcile the conceptual language across all eight screens of `Design/prototype-v2/` per the [UX redesign spec](../specs/2026-05-11-prototype-v2-redesign-design.md) — consolidate Playground + Visual editor into a Diagram editor destination, narrow AI studio, standardize page-header anatomy, lock in right-rail identities, unify terminology, formalize a status-pill taxonomy, and replace Render with Publish.

**Architecture:** Six staged commits, each landable as its own PR and independently testable via the Node harness at `tests/prototype-enhancements.test.mjs`. Stages 1–3 are CSS + find/replace + chrome refactor on the existing nine HTML files. Stage 4 creates `editor.html` (consolidating playground.html + visual.html) and deletes the originals. Stages 5–6 polish per-screen and wire the new JS controllers (Mode, Selection, Publish, ShareModal, RefineAI).

**Tech Stack:** Vanilla HTML + CSS (with custom properties) + ES module JS, served by a zero-dep Node static server (`server.mjs`). Tests are a single Node script that string-matches the rendered HTML/CSS/JS.

---

## File Structure

```
Design/prototype-v2/
├── index.html              — Home (reframed in Stage 5)
├── editor.html             — Diagram editor — CREATED in Stage 4
├── ai.html                 — AI studio (scope narrowed in Stage 6)
├── library.html            — Library (location/filter split in Stage 5)
├── present.html            — Presentations (consolidations in Stage 5)
├── activity.html           — Activity (consolidations in Stage 5)
├── settings.html           — Settings (consolidations in Stage 5)
├── share.html              — Share modal (modal-ified in Stage 5)
├── playground.html         — DELETED in Stage 4
├── visual.html             — DELETED in Stage 4
├── assets/
│   ├── shared.css          — Token + anatomy additions (Stage 1); class swaps across stages
│   └── prototype.js        — New controllers added in Stages 4 + 6
├── tests/
│   └── prototype-enhancements.test.mjs   — Expanded across every stage
├── server.mjs              — Unchanged
└── package.json            — Unchanged
```

**Reference paths in this plan are absolute** (from repo root): `Design/prototype-v2/<file>`.

**Run tests with:** `cd Design/prototype-v2 && npm test`
**Run dev server with:** `cd Design/prototype-v2 && npm start` (opens browser; `NO_OPEN=1 npm start` to skip)

---

## Stage 1 — Tokens & shared chrome

**Goal:** Add the new design tokens and structural classes to `shared.css` so subsequent stages have a vocabulary to write against. No HTML edits in this stage.

**Files:**
- Modify: `Design/prototype-v2/assets/shared.css`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

### Task 1.1: Add pill-family tokens to shared.css

**Files:**
- Modify: `Design/prototype-v2/assets/shared.css` (in the `:root` block, alongside existing tokens)
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add failing test for the new tokens**

Edit `tests/prototype-enhancements.test.mjs`. Find the `requiredCss` array (~line 26) and append these entries:

```js
const requiredCss = [
  ".prototype-toast-region",
  ".command-palette",
  ".new-diagram-modal",
  ".presenter-overlay",
  ".card-grid.is-list",
  ".empty-state",
  // New in Stage 1 — pill family tokens (asserted via custom-property names)
  "--pill-state-bg",
  "--pill-state-bd",
  "--pill-sync-live-bg",
  "--pill-sync-stale-bg",
  "--pill-sync-snapshot-bd",
  "--pill-sharing-bg",
  "--pill-ai-bg",
  "--pill-ai-bd",
];
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

Expected: `assets/shared.css missing --pill-state-bg` (and similar for the other new tokens).

- [ ] **Step 3: Add the tokens in `:root`**

Edit `assets/shared.css`. Find the `/* Status */` block (around line 35) and add a new block immediately after it:

```css
    /* Pill families (Stage 1 redesign) */
    /* Document state — neutral pill, leading dot; warning dot becomes amber */
    --pill-state-bg: #f3f3f5;
    --pill-state-bd: #e1e1e4;
    --pill-state-fg: #424245;
    --pill-state-warn-dot: #d97706;

    /* Sync state — Live/Co-editing animated dot; Stale amber; Snapshot outline */
    --pill-sync-live-bg: #f3f3f5;
    --pill-sync-live-dot: #30a46c;
    --pill-sync-stale-bg: rgba(217, 119, 6, 0.10);
    --pill-sync-stale-bd: rgba(217, 119, 6, 0.28);
    --pill-sync-stale-fg: #b45309;
    --pill-sync-snapshot-bg: transparent;
    --pill-sync-snapshot-bd: #d1d1d6;
    --pill-sync-snapshot-fg: #86868b;

    /* Sharing state — neutral with glyph */
    --pill-sharing-bg: #f3f3f5;
    --pill-sharing-bd: #e1e1e4;
    --pill-sharing-fg: #424245;
    --pill-sharing-external-bg: rgba(217, 119, 6, 0.10);
    --pill-sharing-external-fg: #b45309;

    /* AI state — lavender (accent family) with sparkle */
    --pill-ai-bg: rgba(94, 92, 230, 0.10);
    --pill-ai-bd: rgba(94, 92, 230, 0.28);
    --pill-ai-fg: #5e5ce6;
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd Design/prototype-v2 && npm test
```

Expected: `Prototype wiring checks passed (...)`.

- [ ] **Step 5: Commit**

```bash
git add Design/prototype-v2/assets/shared.css Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: add pill-family tokens for status-pill taxonomy

Adds custom properties for the five pill families (Document state, Sync,
Sharing, Content type [uses existing --type-*], AI) plus warning treatments.
Sets the vocabulary for subsequent stages."
```

### Task 1.2: Add page-header anatomy classes

**Files:**
- Modify: `Design/prototype-v2/assets/shared.css`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add failing test for the header anatomy classes**

Edit `tests/prototype-enhancements.test.mjs`. Extend `requiredCss`:

```js
  // New in Stage 1 — page header anatomy
  ".pageheader",
  ".pageheader__row1",
  ".pageheader__row2",
  ".pageheader__breadcrumb",
  ".pageheader__modes",
  ".pageheader__status",
  ".pageheader__cta",
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

Expected: failures for each new selector.

- [ ] **Step 3: Add the page-header anatomy classes**

Edit `assets/shared.css`. Add at the end of the file (after the last existing block):

```css
/* =========================================================================
   Page header anatomy (Stage 1 redesign)
   ========================================================================= */
.pageheader {
  display: flex;
  flex-direction: column;
  background: var(--titlebar);
  border-bottom: 1px solid var(--border);
}
.pageheader__row1,
.pageheader__row2 {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 0 20px;
  min-height: 36px;
}
.pageheader__row1 {
  border-bottom: 1px solid var(--border-3);
}
.pageheader__breadcrumb {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: var(--text-meta);
  color: var(--ink-2);
  font-family: var(--display);
  flex: 1 1 auto;
  min-width: 0;
}
.pageheader__breadcrumb .sep {
  color: var(--ink-4);
  margin: 0 2px;
}
.pageheader__breadcrumb .leaf {
  color: var(--ink);
  font-weight: 600;
}
.pageheader__modes {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 2px;
}
.pageheader__modes a,
.pageheader__modes button {
  font: 500 12px/1 var(--display);
  color: var(--ink-3);
  padding: 6px 10px;
  border-radius: 6px;
  text-decoration: none;
  background: transparent;
  border: 0;
  cursor: pointer;
}
.pageheader__modes a.is-on,
.pageheader__modes button.is-on {
  background: var(--surface);
  color: var(--ink);
  box-shadow: 0 1px 0 rgba(0,0,0,0.04);
}
.pageheader__status {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: var(--text-meta);
  color: var(--ink-3);
  flex: 1 1 auto;
}
.pageheader__cta {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 5: Commit**

```bash
git add Design/prototype-v2/assets/shared.css Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: add two-row page-header anatomy

Adds .pageheader / .pageheader__row1 / .pageheader__row2 plus breadcrumb,
modes, status, and cta slots. Subsequent stages convert each page to use
this anatomy."
```

### Task 1.3: Add rail anatomy classes

**Files:**
- Modify: `Design/prototype-v2/assets/shared.css`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add failing test for the rail classes**

Extend `requiredCss` in the test file:

```js
  // New in Stage 1 — rail anatomy
  ".rail",
  ".rail__header",
  ".rail__tabs",
  ".rail__tabpanel",
  ".rail--inspector",
  ".rail--diagram",
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Add the rail anatomy**

Append to `assets/shared.css`:

```css
/* =========================================================================
   Right-rail anatomy (Stage 1 redesign)
   .rail--inspector / .rail--diagram swap on the same container; width
   does not change.
   ========================================================================= */
.rail {
  display: flex;
  flex-direction: column;
  background: var(--surface);
  border-left: 1px solid var(--border);
  min-width: var(--inspector);
  max-width: var(--inspector);
}
.rail__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 12px 14px 8px;
  font: 600 12px/1 var(--display);
  color: var(--ink);
  letter-spacing: -0.005em;
}
.rail__header .rail__title::before {
  content: attr(data-title);
}
.rail--inspector .rail__title::before { content: "Inspector"; }
.rail--diagram   .rail__title::before { content: "Diagram"; }
.rail__tabs {
  display: flex;
  gap: 2px;
  padding: 0 10px 8px;
  border-bottom: 1px solid var(--border-3);
  overflow-x: auto;
}
.rail__tabs button {
  font: 500 12px/1 var(--display);
  color: var(--ink-3);
  padding: 6px 8px;
  background: transparent;
  border: 0;
  border-radius: 6px;
  cursor: pointer;
  white-space: nowrap;
}
.rail__tabs button.is-on {
  color: var(--accent);
  background: var(--accent-bg-2);
}
.rail__tabpanel {
  padding: 12px 14px;
  overflow-y: auto;
  flex: 1 1 auto;
}
.rail__tabpanel:not(.is-on) { display: none; }
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 5: Commit**

```bash
git add Design/prototype-v2/assets/shared.css Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: add tabbed right-rail anatomy

Adds .rail / .rail__header / .rail__tabs / .rail__tabpanel plus the
Inspector ↔ Diagram identity swap (.rail--inspector / .rail--diagram).
The container width is preserved across identity swap."
```

### Task 1.4: Add pending-edit banner and card-chip container classes

**Files:**
- Modify: `Design/prototype-v2/assets/shared.css`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add failing test**

Extend `requiredCss`:

```js
  // New in Stage 1 — banner + chip container
  ".editbanner",
  ".editbanner--active",
  ".cardchips",
  ".pill--state",
  ".pill--sync",
  ".pill--sharing",
  ".pill--type",
  ".pill--ai",
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Add the banner and chip family classes**

Append to `assets/shared.css`:

```css
/* =========================================================================
   Pending-edits banner (Visual mode in Diagram editor)
   ========================================================================= */
.editbanner {
  display: none;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 16px;
  background: var(--accent-bg);
  border-top: 1px solid var(--accent-bd);
  font-size: var(--text-meta);
  color: var(--ink-2);
}
.editbanner--active { display: flex; }
.editbanner__actions { display: inline-flex; gap: 8px; }

/* =========================================================================
   Card chips (status-pill taxonomy)
   Order enforced by DOM: [Type] [Sync] [Sharing] [AI]
   ========================================================================= */
.cardchips {
  display: inline-flex;
  flex-wrap: wrap;
  gap: 4px;
  align-items: center;
}
.pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font: 500 11px/1 var(--display);
  letter-spacing: 0.01em;
  padding: 3px 7px;
  border-radius: 999px;
  border: 1px solid transparent;
  white-space: nowrap;
}
.pill__dot {
  width: 6px; height: 6px; border-radius: 50%;
  display: inline-block;
}
.pill--state {
  background: var(--pill-state-bg);
  border-color: var(--pill-state-bd);
  color: var(--pill-state-fg);
}
.pill--state.is-warn .pill__dot { background: var(--pill-state-warn-dot); }

.pill--sync.is-live { background: var(--pill-sync-live-bg); }
.pill--sync.is-live .pill__dot { background: var(--pill-sync-live-dot); animation: pulse 1.6s ease-in-out infinite; }
.pill--sync.is-stale {
  background: var(--pill-sync-stale-bg);
  border-color: var(--pill-sync-stale-bd);
  color: var(--pill-sync-stale-fg);
}
.pill--sync.is-snapshot {
  background: var(--pill-sync-snapshot-bg);
  border-color: var(--pill-sync-snapshot-bd);
  color: var(--pill-sync-snapshot-fg);
}

.pill--sharing {
  background: var(--pill-sharing-bg);
  border-color: var(--pill-sharing-bd);
  color: var(--pill-sharing-fg);
}
.pill--sharing.is-external {
  background: var(--pill-sharing-external-bg);
  color: var(--pill-sharing-external-fg);
}

.pill--type {
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 3px 6px;
  font-size: 10px;
  color: #fff;
}
.pill--type.is-flow    { background: var(--type-flow); }
.pill--type.is-seq     { background: var(--type-seq); }
.pill--type.is-state   { background: var(--type-state); }
.pill--type.is-er      { background: var(--type-er); }
.pill--type.is-class   { background: var(--type-class); }
.pill--type.is-gantt   { background: var(--type-gantt); }
.pill--type.is-mind    { background: var(--type-mind); }
.pill--type.is-journey { background: var(--type-journey); }

.pill--ai {
  background: var(--pill-ai-bg);
  border-color: var(--pill-ai-bd);
  color: var(--pill-ai-fg);
}

@keyframes pulse {
  0%,100% { opacity: 1; }
  50%     { opacity: 0.4; }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 5: Visual smoke check in the dev server**

```bash
cd Design/prototype-v2 && NO_OPEN=1 npm start &
sleep 2
curl -sS http://127.0.0.1:4321/ | head -1
# Expect: <!DOCTYPE html>
kill %1
```

Then open any page manually and confirm nothing broke. (No HTML uses the new classes yet — pages should look identical to v0.3.0.)

- [ ] **Step 6: Commit**

```bash
git add Design/prototype-v2/assets/shared.css Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: add edit-banner and card-chip families

Adds .editbanner / .editbanner--active for pending source-mod state in
Visual mode, and .pill--{state,sync,sharing,type,ai} classes plus the
.cardchips DOM-order container. Closes the Stage-1 vocabulary set."
```

---

## Stage 2 — Terminology pass

**Goal:** Adopt the global rename pass from the spec's terminology table in one stage so no commit leaves the app in a half-state. Add denylist tests first (they fail), then update each HTML file to drive them to passing.

**Files (every HTML page touched):**
- Modify: all 9 HTML files in `Design/prototype-v2/`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

### Task 2.1: Add cross-cutting terminology denylist tests

**Files:**
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add the denylist checks (these will fail until Tasks 2.2–2.10 land)**

Edit `tests/prototype-enhancements.test.mjs`. Add this block immediately after the per-page wiring loop ends (after the closing `}` of `for (const page of pages) {`):

```js
// --- Terminology denylist (Stage 2 redesign) ---------------------------------
//
// These regexes look for the OLD vocabulary in label-bearing contexts (tab
// labels, button labels, nav-pill labels, h1/h2 headings, breadcrumbs).
// Bare appearances inside prose comments or alt-text are tolerated; the test
// targets the user-visible labels that the rename pass is meant to fix.
const labelContext = (term) =>
  new RegExp(
    `(?:<button[^>]*>\\s*${term}\\s*<|` +
    `<a[^>]*class="[^"]*nav-pill[^"]*"[^>]*>\\s*${term}\\s*<|` +
    `<h1[^>]*>\\s*${term}\\s*<|` +
    `<h2[^>]*>\\s*${term}\\s*<|` +
    `data-tab="${term}"|` +
    `data-mode="${term}")`,
    "i"
  );

const denied = [
  { term: "Code",          where: "tab/button/heading" },
  { term: "Code editor",   where: "label" },
  { term: "Studio",        where: "bare label (allowed only as 'Studio plan', 'AI studio', or 'Assistant')" },
  { term: "Studio AI",     where: "activity actor" },
  { term: "Studio assistant", where: "right panel" },
  { term: "Playground",    where: "any label" },
  { term: "Visual editor", where: "destination label" },
  { term: "Review diff",   where: "button label (should be 'Review source diff')" },
];

for (const page of pages) {
  const html = read(page);
  for (const rule of denied) {
    if (labelContext(rule.term).test(html)) {
      fail(`${page}: forbidden term "${rule.term}" appears as a ${rule.where}`);
    }
  }
  // Bare "Studio" check, narrower regex to avoid false-positives on "Studio plan" / "AI studio" / "Assistant"
  if (/<button[^>]*>\s*Studio\s*<|data-tab="Studio"/.test(html)) {
    fail(`${page}: bare "Studio" appears as a tab/button label (use Assistant or AI studio or 'Studio plan')`);
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

Expected: multiple failures across most HTML files. This is correct — the rename hasn't happened yet.

- [ ] **Step 3: Commit the failing tests**

```bash
git add Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: add terminology denylist tests (failing)

These tests will fail until the per-page rename tasks land. Committing
them first locks in the target vocabulary as a verifiable contract."
```

### Task 2.2: Rename in index.html

**Files:**
- Modify: `Design/prototype-v2/index.html`

- [ ] **Step 1: Audit current usage of the old vocabulary**

```bash
cd Design/prototype-v2
grep -nE 'Playground|Visual editor|Code editor|>Code<|>Studio<|Studio AI|Review diff' index.html
```

Record each match. Most likely sites: the workstation cards section, the Recent rows, any inline tab labels.

- [ ] **Step 2: Apply the renames**

Open `index.html` and apply these edits per the spec's terminology table:
- Replace any nav-pill or card label `Playground` with `Diagram editor`.
- Replace any nav-pill or card label `Visual editor` with `Diagram editor` (since Visual is now a mode inside the Diagram editor, not its own destination — the Home Quick-actions row should reference `New diagram` instead, per spec).
- If a button/tab anywhere says bare `Code`, rename to `Source`.
- If any element says bare `Studio` as a nav or tab label, rename to `Assistant` (panels) or `AI studio` (destination) or `Studio plan` (tier) — choose based on context.
- Replace `Review diff` with `Review source diff` (button labels only).
- Replace any `Studio AI` actor strings with `AI assistant`.

For multiple occurrences of the same term in the same role, prefer the Edit tool with `replace_all: true` per term:

```
Edit index.html: old="Playground" new="Diagram editor" replace_all=true
```
(Only if the term appears exclusively as a label. If "Playground" also appears in prose comments that should stay, use targeted replacements.)

- [ ] **Step 3: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

Expected: the failures for `index.html` from Task 2.1 are now gone. Failures for the other pages remain.

- [ ] **Step 4: Browser smoke check**

```bash
cd Design/prototype-v2 && NO_OPEN=1 npm start &
sleep 1
open http://127.0.0.1:4321/index.html
```

Confirm: no stray Playground / Code / bare Studio labels visible. Layout unchanged.

- [ ] **Step 5: Commit**

```bash
git add Design/prototype-v2/index.html
git commit -m "prototype-v2: rename Home labels to redesign vocabulary

Playground/Visual editor → Diagram editor; Code → Source; bare Studio →
Assistant/AI studio/Studio plan per context; Review diff → Review source
diff; Studio AI → AI assistant."
```

### Task 2.3: Rename in playground.html (interim — file still exists)

**Files:**
- Modify: `Design/prototype-v2/playground.html`

- [ ] **Step 1: Audit and apply the same renames**

```bash
cd Design/prototype-v2
grep -nE '>Code<|>Studio<|Studio AI|Review diff|Studio assistant' playground.html
```

Apply the rename rules from Task 2.2 to `playground.html`. Notes specific to this file:
- The right "Studio" panel header becomes `Assistant`.
- The `Code · Config · Inspector` tab strip — `Code` becomes `Source` for now (the tab structure gets reorganized in Stage 3 when the page adopts the new header anatomy, and the file is deleted entirely in Stage 4).
- The page's nav-pill in the left rail stays pointing at itself (`playground.html`) for now — it still exists.

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

Expected: failures for `playground.html` are gone.

- [ ] **Step 3: Commit**

```bash
git add Design/prototype-v2/playground.html
git commit -m "prototype-v2: rename Playground labels (interim — file kept until Stage 4)

Code → Source, Studio panel → Assistant, Review diff → Review source diff.
File is deleted in Stage 4 once editor.html consolidates it."
```

### Task 2.4: Rename in visual.html

**Files:**
- Modify: `Design/prototype-v2/visual.html`

- [ ] **Step 1: Audit and apply renames**

```bash
cd Design/prototype-v2
grep -nE '>Code<|>Studio<|Visual editor|Review diff' visual.html
```

Apply:
- `Code` tab labels → `Source`.
- Any heading that says `Visual editor` as a workspace title → keep `Visual editor` *only* in chrome (titlebar) for now; the page becomes deleted in Stage 4 anyway. But change every `Open in Visual editor` button to `Open in Visual mode`.
- `Review diff` → `Review source diff`.
- The right panel "Studio" → `Assistant`.

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Commit**

```bash
git add Design/prototype-v2/visual.html
git commit -m "prototype-v2: rename Visual editor labels (interim — file kept until Stage 4)"
```

### Task 2.5: Rename in ai.html

**Files:**
- Modify: `Design/prototype-v2/ai.html`

- [ ] **Step 1: Audit and apply renames**

```bash
cd Design/prototype-v2
grep -nE '>Code<|>Studio<|Studio AI|Studio assistant|Review diff|Playground' ai.html
```

Apply:
- Any `Studio assistant` / `Studio AI` → `AI assistant` (as actor) or `Assistant` (as panel title).
- `Code` → `Source`.
- `Playground` → `Diagram editor` (links).
- `Review diff` → `Review source diff`.
- Confirm the nav-pill in the left rail correctly points at `ai.html` and is labeled `AI studio` (per spec).

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Commit**

```bash
git add Design/prototype-v2/ai.html
git commit -m "prototype-v2: rename AI studio labels to redesign vocabulary"
```

### Task 2.6: Rename in library.html

**Files:**
- Modify: `Design/prototype-v2/library.html`

- [ ] **Step 1: Audit and apply renames**

```bash
cd Design/prototype-v2
grep -nE 'Open in Visual|Open in Code|AI refine|Add to deck|>Studio<|>Playground<|Review diff' library.html
```

Apply:
- `Open in Visual` → `Open in Visual mode`.
- `Open in Code` → `Open in Source mode`.
- `AI refine` → `Refine with AI`.
- `Add to deck` → `Add to presentation`.
- `Playground` → `Diagram editor` (cross-links).
- Role labels in the right panel: verify they match Owner / Editor / Commenter / Viewer / Pending exactly (these will be used by Settings + Share in Stage 5).

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Commit**

```bash
git add Design/prototype-v2/library.html
git commit -m "prototype-v2: rename Library 'Open in' actions

Open in Visual/Code/AI refine/Add to deck → Open in Visual mode / Source
mode / Refine with AI / Add to presentation. Aligns Library with the
editor and presentation destinations."
```

### Task 2.7: Rename in present.html

**Files:**
- Modify: `Design/prototype-v2/present.html`

- [ ] **Step 1: Audit and apply renames**

```bash
cd Design/prototype-v2
grep -nE 'Outline\|Edit\|Source|Studio assistant|>Code<|Review diff|>Studio<' present.html
```

Apply:
- The top tab strip `Outline · Edit · Source` → `Slides · Outline · Source`. (The structural reorg lands in Stage 3 — this task only renames the labels.)
- The left panel title `Outline` (if present) → `Slide navigator`.
- `Studio assistant` / `Studio` panel sections → `Assistant`.
- `Code` tab anywhere → `Source`.
- Verify `Add to deck` cross-references say `Add to presentation`.

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Commit**

```bash
git add Design/prototype-v2/present.html
git commit -m "prototype-v2: rename Presentations labels

Outline·Edit·Source → Slides·Outline·Source; Studio assistant → Assistant;
Outline panel → Slide navigator."
```

### Task 2.8: Rename in activity.html

**Files:**
- Modify: `Design/prototype-v2/activity.html`

- [ ] **Step 1: Audit and apply renames**

```bash
cd Design/prototype-v2
grep -nE 'Studio AI|Source mode|>Studio<|Playground|Visual editor' activity.html
```

Apply:
- Every `Studio AI` actor label → `AI assistant`.
- The detail field label `Source mode` → `Edited in`.
- Field values: `Visual editor` (as a surface name) → `Visual mode`; `Playground` (as a surface name) → `Source mode`.
- Any other bare `Studio` references → `AI assistant` (if referring to the actor) or `AI studio` (if referring to the destination).

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Commit**

```bash
git add Design/prototype-v2/activity.html
git commit -m "prototype-v2: rename Activity actor + field labels

Studio AI → AI assistant; Source mode field → Edited in; values use
Visual mode / Source mode instead of Visual editor / Playground."
```

### Task 2.9: Rename in settings.html

**Files:**
- Modify: `Design/prototype-v2/settings.html`

- [ ] **Step 1: Audit and apply renames**

```bash
cd Design/prototype-v2
grep -nE 'Sharing policy|Studio plan|>Studio<|>Code<|Playground|Visual editor' settings.html
```

Apply:
- The settings nav label `Sharing policy` → `Sharing & permissions` (page title and nav label must match).
- `Studio` as a plan reference → `Studio plan` (always with "plan" suffix).
- `Code` tab/button labels → `Source`.
- Cross-links: `Playground` → `Diagram editor`, `Visual editor` (destination) → `Diagram editor`.
- The `Studio plan feature` upsell pill stays — that's a correct usage of the term.

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Commit**

```bash
git add Design/prototype-v2/settings.html
git commit -m "prototype-v2: rename Settings labels

Sharing policy → Sharing & permissions (nav matches page title); bare
Studio → Studio plan; Code → Source; destination cross-links → Diagram
editor."
```

### Task 2.10: Rename in share.html

**Files:**
- Modify: `Design/prototype-v2/share.html`

- [ ] **Step 1: Audit and apply renames**

```bash
cd Design/prototype-v2
grep -nE '>Studio<|>Code<|Playground|Visual editor|Review diff' share.html
```

Apply:
- Any bare `Studio` references → `Studio plan` (if plan tier) or `AI studio` (if destination) or `Assistant` (if panel).
- Cross-link destination names → `Diagram editor`.
- `Code` tab/button labels → `Source` (the SVG-vs-Code distinction in link cards becomes SVG-vs-Source).

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

Expected: ALL terminology denylist tests now pass.

- [ ] **Step 3: Commit**

```bash
git add Design/prototype-v2/share.html
git commit -m "prototype-v2: rename Share labels to redesign vocabulary

Closes the Stage-2 terminology pass — denylist tests now green across
all nine HTML files."
```

---

## Stage 3 — Header + rail anatomy on existing pages

**Goal:** Convert every page's header and right rail to the new two-row + tabbed-rail anatomy *in place*. `playground.html` and `visual.html` adopt the new chrome too (interim — they'll be deleted in Stage 4).

**Files:** all 9 HTML files + the test harness.

### Task 3.1: Add cross-cutting header invariant tests

**Files:**
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add structural invariant tests**

Append to `tests/prototype-enhancements.test.mjs`, after the terminology denylist block:

```js
// --- Cross-cutting header + rail invariants (Stage 3 redesign) ---------------
const headerlessPages = new Set(["share.html"]); // Share uses its own modal chrome

for (const page of pages) {
  if (headerlessPages.has(page)) continue;
  const html = read(page);

  // Exactly one .pageheader with row1 + row2.
  const headerCount = (html.match(/class="[^"]*pageheader[^"]*"/g) || []).length;
  if (headerCount < 1) fail(`${page}: missing .pageheader element`);

  const hasRow1 = /class="[^"]*pageheader__row1[^"]*"/.test(html);
  const hasRow2 = /class="[^"]*pageheader__row2[^"]*"/.test(html);
  if (!hasRow1) fail(`${page}: pageheader missing __row1`);
  if (!hasRow2) fail(`${page}: pageheader missing __row2`);

  // Row 1 breadcrumb must start with the workspace name "Engineering".
  const breadcrumb = html.match(/class="pageheader__breadcrumb"[^>]*>([\s\S]*?)<\/[a-z]+>/);
  if (breadcrumb && !/Engineering/.test(breadcrumb[1])) {
    fail(`${page}: breadcrumb does not start with workspace "Engineering"`);
  }

  // Save-state strings ("Saved", "Auto-saved") must not appear inside .rail
  // or in any right-panel container — they belong in pageheader__row2 only.
  const railBlocks = [...html.matchAll(/class="[^"]*rail[^"]*"[\s\S]*?<\/aside>/g)].map(m => m[0]);
  for (const block of railBlocks) {
    if (/\bSaved\b|\bAuto-saved\b/.test(block)) {
      fail(`${page}: save-state appears inside a .rail block (must be in pageheader only)`);
    }
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

Expected: every page (except share.html) reports missing `.pageheader` / `__row1` / `__row2`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: add page-header structural invariant tests (failing)

Asserts every object screen has the two-row .pageheader with the
workspace-prefixed breadcrumb, and that save-state never appears in
a right rail. Will pass after Stage 3's per-page conversions."
```

### Task 3.2–3.10: Convert each page's header + rail to the new anatomy

Apply the same pattern to each of: `index.html` (3.2), `playground.html` (3.3), `visual.html` (3.4), `ai.html` (3.5), `library.html` (3.6), `present.html` (3.7), `activity.html` (3.8), `settings.html` (3.9). For `share.html` (3.10) see the modal note at the end.

For each page, the shared HTML pattern to install is:

```html
<header class="pageheader">
  <div class="pageheader__row1">
    <nav class="pageheader__breadcrumb" aria-label="Breadcrumb">
      <a href="index.html">Engineering</a>
      <span class="sep">›</span>
      <!-- Section -->
      <a href="<section-href>"><Section></a>
      <!-- Optional middle level -->
      <span class="sep">›</span>
      <a href="<sub-href>"><Sub></a>
      <!-- Object -->
      <span class="sep">›</span>
      <span class="leaf"><Object></span>
    </nav>
    <div class="pageheader__actions">
      <!-- collaborator avatars, Share, Export, ⋯ -->
    </div>
  </div>
  <div class="pageheader__row2">
    <!-- Left slot: mode tabs OR scope/filter toggles -->
    <div class="pageheader__modes">
      <button class="is-on" data-mode="..."><Mode-1></button>
      <button data-mode="..."><Mode-2></button>
      <button data-mode="..."><Mode-3></button>
    </div>
    <!-- Middle: status pills -->
    <div class="pageheader__status">
      <span class="pill pill--state">Saved</span>
      <span class="pill pill--state">Auto · 312ms</span>
    </div>
    <!-- Right: primary CTA (or empty) -->
    <div class="pageheader__cta">
      <button class="btn btn--ghost">✨ Refine with AI →</button>
      <button class="btn btn--primary">Publish version ⌘⇧P</button>
    </div>
  </div>
</header>
```

And the rail pattern:

```html
<aside class="rail rail--diagram" data-rail-state="diagram">
  <div class="rail__header">
    <h2 class="rail__title" data-title></h2>
  </div>
  <div class="rail__tabs" role="tablist">
    <button class="is-on" role="tab" aria-selected="true" data-tab="details">Details</button>
    <button role="tab" aria-selected="false" data-tab="comments">Comments</button>
    <button role="tab" aria-selected="false" data-tab="history">History</button>
    <button role="tab" aria-selected="false" data-tab="export">Export</button>
    <button role="tab" aria-selected="false" data-tab="assistant">Assistant</button>
  </div>
  <div class="rail__tabpanel is-on" data-tabpanel="details"><!-- ... --></div>
  <div class="rail__tabpanel" data-tabpanel="comments"><!-- ... --></div>
  <!-- etc -->
</aside>
```

**Per-page specifics for breadcrumb / modes / status / CTA / rail:**

| Page | Breadcrumb | Modes (Row 2 left) | Status (Row 2 middle) | CTA (Row 2 right) | Rail |
|---|---|---|---|---|---|
| `index.html` | `Engineering › Home` | (no modes — leave the slot empty or omit `.pageheader__modes`) | `(empty)` | `(empty)` | Keep `This week` rail content; wrap in new `.rail` shell with no tabs |
| `playground.html` | `Engineering › Diagram editor › <file>.mmd` | `Source ｜ Visual ｜ Split` (Source `is-on`; for now Visual/Split links point to `visual.html` — fixed in Stage 4) | `Saved · Auto · 312ms` | `[Refine with AI →] [Publish version ⌘⇧P]` | Diagram rail with `Details · Comments · History · Export · Assistant` tabs. Move the existing Studio panel content under the Assistant tab |
| `visual.html` | `Engineering › Diagram editor › <file>.mmd` | `Source ｜ Visual ｜ Split` (Visual `is-on`) | `Saved · Auto · 312ms` | `[Refine with AI →] [Publish version ⌘⇧P]` | Diagram rail by default; the existing node-inspector becomes the `Inspector` identity (`.rail--inspector`) when selection active |
| `ai.html` | `Engineering › AI studio › New diagram` (or `· <file>.mmd` when refining) | (Optional: `Generate ｜ Refine`) | `AI · 12 credits used` (generating) or `Source diff · N changes` (refining) | `[Reset] [Generate ⌘⏎]` or `[Discard] [Apply diff]` | Rail content largely unchanged; wrap in `.rail` shell |
| `library.html` | `Engineering › Library` | scope chip (current Folder/View name) — no tabs slot, place chip directly | `47 diagrams · 9 shown` (plain text, NOT pills) | `[Sort ▾] [+ New diagram ▾]` | `.rail--diagram` with `Details · Sharing · Used in decks · Comments · History` tabs |
| `present.html` | `Engineering › Presentations › SDK Auth · Q2 review` | `Slides ｜ Outline ｜ Source` (Slides `is-on`) | `Saved · 12 slides · 1 stale diagram` | `[Refine with AI →] [Present ⌘⇧P]` | Slide rail with `Notes · Diagrams · Assistant · Theme` tabs |
| `activity.html` | `Engineering › Activity` | scope toggle: `This diagram ｜ All workspace ｜ Involving me` | `3 unread` | `[Mark all read]` | Event rail with `Details · Related · Audit` tabs |
| `settings.html` | `Engineering › Settings › Sharing & permissions` (matches the active subpage) | (no modes — leave empty) | `Saved · 2s ago` | `(empty)` | Scope rail with sections `Scope` / `Plan & usage` / `Help` (single column, no tabs) |

For each per-page task (3.2 through 3.9), the steps are identical in shape:

- [ ] **Step 1: Locate the current header DOM**

```bash
cd Design/prototype-v2
grep -n -A 2 -B 2 'class="titlebar\|class="header\|class="topbar' <page>.html | head -40
```

(The current shell uses different class names; identify which block plays the role of "page header" and which plays the role of "right rail.")

- [ ] **Step 2: Replace the header DOM with the two-row anatomy**

Use the template above, filling in the per-page values from the table.

- [ ] **Step 3: Replace the right-rail DOM with the `.rail` anatomy**

Use the rail template above. Keep the existing panel CONTENT but reorganize into the rail's tabpanels. For pages that previously had stacked sections (Presentations, Settings), each section becomes a tab; for Settings specifically, keep them as stacked sections inside a single tabless rail (per the table).

- [ ] **Step 4: Remove save-state strings from any non-header element**

```bash
grep -n 'Saved\|Auto-saved' <page>.html
```

Any match outside of `.pageheader__row2` → delete or migrate up to the header.

- [ ] **Step 5: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

Expected: the per-page failures from Task 3.1 for this page are gone.

- [ ] **Step 6: Browser smoke check**

```bash
NO_OPEN=1 npm start &
sleep 1
open http://127.0.0.1:4321/<page>.html
```

Confirm visually: header now shows the two-row anatomy with workspace-prefixed breadcrumb, mode/scope slot left of status pills, primary CTA (or empty) on the right.

- [ ] **Step 7: Commit**

```bash
git add Design/prototype-v2/<page>.html
git commit -m "prototype-v2: convert <page> to two-row header + tabbed rail"
```

Repeat for each page in the table (Tasks 3.2 → 3.9).

### Task 3.10: Convert share.html header to modal-friendly chrome

**Files:**
- Modify: `Design/prototype-v2/share.html`

Share is the one page that does **not** use `.pageheader`. It uses its own modal chrome. But we still standardize its header strip.

- [ ] **Step 1: Replace the current top strip with modal header**

```html
<header class="modalheader">
  <div class="modalheader__title">
    <span class="modalheader__file">auth-flow.mmd</span>
    <span class="modalheader__sep">·</span>
    <span class="modalheader__action">Share</span>
  </div>
  <div class="modalheader__subtitle">
    Engineering · workspace policy: external sharing allowed for 2 domains
  </div>
  <button class="modalheader__close" aria-label="Close">✕</button>
</header>
```

- [ ] **Step 2: Add corresponding CSS to `assets/shared.css`**

Append:

```css
.modalheader {
  display: grid;
  grid-template-columns: 1fr auto;
  grid-template-rows: auto auto;
  align-items: center;
  gap: 4px 12px;
  padding: 14px 18px 12px;
  border-bottom: 1px solid var(--border);
}
.modalheader__title {
  font: 600 14px/1.2 var(--display);
  color: var(--ink);
}
.modalheader__file { color: var(--ink); }
.modalheader__sep { color: var(--ink-4); margin: 0 4px; }
.modalheader__action { color: var(--ink-2); }
.modalheader__subtitle {
  grid-column: 1 / 2;
  font: 400 12px/1.4 var(--body);
  color: var(--ink-3);
}
.modalheader__close {
  grid-column: 2 / 3;
  grid-row: 1 / 3;
  width: 28px; height: 28px;
  background: transparent;
  border: 0;
  border-radius: 6px;
  color: var(--ink-3);
  cursor: pointer;
}
.modalheader__close:hover { background: var(--surface-2); color: var(--ink); }
```

- [ ] **Step 3: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 4: Commit**

```bash
git add Design/prototype-v2/share.html Design/prototype-v2/assets/shared.css
git commit -m "prototype-v2: convert Share header to modal chrome

Share uses its own modal header with file·action title, policy subtitle,
and a ✕ close. The page is still standalone-renderable for preview; the
modal mount behavior is added in Stage 5."
```

---

## Stage 4 — Diagram editor consolidation

**Goal:** Create `editor.html` (the unified Diagram editor), wire the Mode + Selection + Publish controllers, update every internal link, delete `playground.html` and `visual.html`.

**Files:**
- Create: `Design/prototype-v2/editor.html`
- Modify: `Design/prototype-v2/assets/prototype.js`
- Delete: `Design/prototype-v2/playground.html`, `Design/prototype-v2/visual.html`
- Modify: all remaining HTML files (link updates)
- Modify: `Design/prototype-v2/server.mjs` — replace `playground.html` and `visual.html` entries in the implicit page list (none exists; only tests reference these pages)
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

### Task 4.1: Update the test harness page list and add editor.html tests

**Files:**
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Replace the `pages` array**

Edit `tests/prototype-enhancements.test.mjs` (around line 8):

```js
const pages = [
  "index.html",
  "editor.html",
  "ai.html",
  "present.html",
  "library.html",
  "activity.html",
  "settings.html",
  "share.html",
];
```

(Remove `"playground.html"` and `"visual.html"`; add `"editor.html"`.)

- [ ] **Step 2: Add editor.html mode-routing test**

Append to the test file, after the cross-cutting header block:

```js
// --- editor.html mode routing (Stage 4 redesign) -----------------------------
{
  const html = read("editor.html");
  for (const mode of ["source", "visual", "split"]) {
    if (!html.includes(`data-mode="${mode}"`)) {
      fail(`editor.html: missing data-mode="${mode}" tab`);
    }
    if (!html.includes(`data-pane="${mode}"`)) {
      fail(`editor.html: missing data-pane="${mode}" content`);
    }
  }
  if (!/<button[^>]*data-mode="source"[^>]*is-on/.test(html)) {
    fail(`editor.html: default mode should be Source (is-on)`);
  }
}
```

- [ ] **Step 3: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

Expected: failures for missing `editor.html` and the page-list pages that no longer exist (these resolve in subsequent tasks).

- [ ] **Step 4: Commit**

```bash
git add Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: update test page list for Stage 4 consolidation

Drops playground.html / visual.html, adds editor.html. Adds mode-routing
invariants (data-mode + data-pane for each of source/visual/split, default
source). Tests fail until Tasks 4.2-4.6 land."
```

### Task 4.2: Create the editor.html shell

**Files:**
- Create: `Design/prototype-v2/editor.html`

- [ ] **Step 1: Create the file**

Create `Design/prototype-v2/editor.html` with the following structure. Start from `playground.html` (still on disk) for the shell and prune.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Mermaid — Diagram editor</title>
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link
  href="https://fonts.googleapis.com/css2?family=Inter:wght@400;450;500;600;700&family=Inter+Display:wght@500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap"
  rel="stylesheet"
/>
<link rel="stylesheet" href="assets/shared.css" />
<style>
  /* Editor-specific layout — adapted from playground.html + visual.html */
  .editor { display: grid; grid-template-columns: var(--rail-md) 1fr var(--inspector); height: 100%; min-height: 0; }
  .editor__center { display: grid; grid-template-rows: 1fr auto; min-height: 0; }
  .editor__pane { display: none; flex: 1 1 auto; min-height: 0; overflow: hidden; }
  .editor__pane.is-on { display: flex; }
  /* Source-mode pane: editor left, preview right */
  .editor__pane[data-pane="source"]  { grid-template-columns: 1fr 1fr; }
  .editor__pane[data-pane="visual"]  { grid-template-columns: 1fr; }
  .editor__pane[data-pane="split"]   { grid-template-columns: 1fr 1fr; }
</style>
</head>
<body>
<div class="app">
  <!-- Left global nav — copy from playground.html, mark Diagram editor active -->
  <aside class="globalnav">
    <!-- ... existing nav-pill markup ... -->
  </aside>

  <main class="workspace">
    <!-- Page header (Stage 3 anatomy applied) -->
    <header class="pageheader">
      <div class="pageheader__row1">
        <nav class="pageheader__breadcrumb" aria-label="Breadcrumb">
          <a href="index.html">Engineering</a>
          <span class="sep">›</span>
          <a href="library.html">Library</a>
          <span class="sep">›</span>
          <a href="library.html?folder=architecture">Architecture</a>
          <span class="sep">›</span>
          <span class="leaf">pr-lifecycle.mmd</span>
        </nav>
        <div class="pageheader__actions">
          <span class="avatars" aria-label="Collaborators">👤👤👤+1</span>
          <a class="btn btn--ghost" href="share.html?open=1&from=editor">Share</a>
          <button class="btn btn--ghost">Export</button>
          <button class="btn btn--icon" aria-label="More">⋯</button>
        </div>
      </div>
      <div class="pageheader__row2">
        <div class="pageheader__modes" data-mode-tabs>
          <button class="is-on" data-mode="source" aria-pressed="true">Source</button>
          <button data-mode="visual" aria-pressed="false">Visual</button>
          <button data-mode="split" aria-pressed="false">Split</button>
        </div>
        <div class="pageheader__status">
          <span class="pill pill--state">Saved</span>
          <span class="pill pill--state">Auto · 312ms</span>
        </div>
        <div class="pageheader__cta">
          <button class="btn btn--ghost" data-refine-ai>✨ Refine with AI →</button>
          <button class="btn btn--primary" data-publish>Publish version ⌘⇧P</button>
        </div>
      </div>
    </header>

    <!-- Editor body: catalog rail | center (three panes) | right rail -->
    <div class="editor">
      <aside class="catalog">
        <!-- ... existing catalog content from playground.html ... -->
      </aside>

      <section class="editor__center">
        <!-- Source mode pane: editor + preview -->
        <div class="editor__pane is-on" data-pane="source">
          <!-- ... source editor + live preview, adapted from playground.html ... -->
        </div>

        <!-- Visual mode pane: full-width canvas -->
        <div class="editor__pane" data-pane="visual">
          <!-- ... canvas + shapes/connect/layout palette, adapted from visual.html ... -->
          <!-- Unsupported-type empty state: hidden by default, shown by JS when
               the active diagram type is not supported in Visual mode -->
          <div class="visual-unsupported" data-visual-unsupported hidden>
            <p>Visual mode isn't available for <strong data-unsupported-type>sequence</strong> diagrams yet.</p>
            <p>Edit in Source mode, or see the supported types →</p>
            <button class="btn btn--primary" data-switch-to-source>Open in Source mode</button>
          </div>
        </div>

        <!-- Split mode pane: editor left, canvas right -->
        <div class="editor__pane" data-pane="split">
          <!-- ... composite of source + visual halves ... -->
        </div>

        <!-- Pending-edit banner (visible only in Visual mode with pending edits) -->
        <div class="editbanner" data-editbanner>
          <span>Visual edits will update Mermaid source.</span>
          <span class="editbanner__actions">
            <button class="btn btn--ghost">Review source diff</button>
            <button class="btn btn--primary">Apply changes</button>
          </span>
        </div>

        <footer class="statusbar">
          <!-- L 14 · C 12 · UTF-8 · LF · 714 B · 19 lines -->
        </footer>
      </section>

      <aside class="rail rail--diagram" data-rail-state="diagram">
        <div class="rail__header"><h2 class="rail__title" data-title></h2></div>
        <div class="rail__tabs" role="tablist">
          <button class="is-on" role="tab" aria-selected="true" data-tab="details">Details</button>
          <button role="tab" aria-selected="false" data-tab="comments">Comments</button>
          <button role="tab" aria-selected="false" data-tab="history">History</button>
          <button role="tab" aria-selected="false" data-tab="export">Export</button>
          <button role="tab" aria-selected="false" data-tab="assistant">Assistant</button>
        </div>
        <div class="rail__tabpanel is-on" data-tabpanel="details">
          <!-- File properties, sharing summary, etc. -->
        </div>
        <div class="rail__tabpanel" data-tabpanel="comments"><!-- ... --></div>
        <div class="rail__tabpanel" data-tabpanel="history"><!-- ... --></div>
        <div class="rail__tabpanel" data-tabpanel="export"><!-- ... --></div>
        <div class="rail__tabpanel" data-tabpanel="assistant">
          <!-- AI assistant chat — adapted from the old playground Studio panel -->
          <button class="btn btn--ghost" data-promote-to-ai-studio>⤢ Open in AI studio</button>
        </div>
      </aside>
    </div>
  </main>
</div>
<script src="assets/prototype.js"></script>
</body>
</html>
```

Use the existing `playground.html` as a content source for the Source pane and catalog; use `visual.html` as the source for the Visual pane content (canvas, shapes rail). Inline the relevant blocks rather than linking — `editor.html` must be self-contained.

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

Expected: editor.html tests (data-mode, data-pane, default is-on Source) pass. Cross-cutting header invariants for editor.html pass. Page-list missing entries fixed.

- [ ] **Step 3: Browser smoke check**

```bash
NO_OPEN=1 npm start &
sleep 1
open http://127.0.0.1:4321/editor.html
```

Confirm: page renders, Source pane is visible by default, Visual and Split panes are hidden. The mode tabs are visible but clicking them does not yet swap panes (controller wiring in Task 4.4).

- [ ] **Step 4: Commit**

```bash
git add Design/prototype-v2/editor.html
git commit -m "prototype-v2: add editor.html consolidated Diagram editor shell

Creates the editor.html file with three panes (Source/Visual/Split),
the two-row header, and the Diagram rail with five tabs. Mode-switching
is static for now — the controller lands in Task 4.4."
```

### Task 4.3: Wire the Mode controller in prototype.js

**Files:**
- Modify: `Design/prototype-v2/assets/prototype.js`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add a test for the Mode controller hook**

Edit `tests/prototype-enhancements.test.mjs`. Extend `requiredJsHooks`:

```js
const requiredJsHooks = [
  // ... existing ...
  "initEditorMode",
  "initEditorSelection",
  "initPublishVersion",
];
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Design/prototype-v2 && npm test
```

Expected: `assets/prototype.js missing function initEditorMode` (and the two others).

- [ ] **Step 3: Add the Mode controller to prototype.js**

Edit `assets/prototype.js`. Find a good insertion point near the existing `initVisualEditor` (around line 363). Add this new function:

```js
function initEditorMode() {
  const tabs = document.querySelectorAll('[data-mode-tabs] button[data-mode]');
  const panes = document.querySelectorAll('[data-pane]');
  if (tabs.length === 0 || panes.length === 0) return;

  const params = new URLSearchParams(location.search);
  const requested = params.get("mode");
  const defaultMode = "source";
  const startMode = ["source", "visual", "split"].includes(requested) ? requested : defaultMode;

  function apply(mode) {
    tabs.forEach((btn) => {
      const on = btn.dataset.mode === mode;
      btn.classList.toggle("is-on", on);
      btn.setAttribute("aria-pressed", on ? "true" : "false");
    });
    panes.forEach((pane) => {
      pane.classList.toggle("is-on", pane.dataset.pane === mode);
    });
    // Reflect in URL without page reload
    const next = new URL(location.href);
    next.searchParams.set("mode", mode);
    history.replaceState(null, "", next);
    // Remember last-used mode for this diagram in sessionStorage
    const diagramId = document.body.dataset.diagramId || "default";
    sessionStorage.setItem(`editor:lastMode:${diagramId}`, mode);
  }

  tabs.forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      apply(btn.dataset.mode);
    });
  });

  apply(startMode);
}
```

Then in the existing DOMContentLoaded boot block (search for `initCommandPalette()` for an example), add:

```js
  initEditorMode();
```

- [ ] **Step 4: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

Expected: `initEditorMode` test passes.

- [ ] **Step 5: Browser test**

Open `http://127.0.0.1:4321/editor.html`. Click `Visual` tab. Confirm:
- The pane swaps (Visual content visible, Source hidden).
- The URL shows `?mode=visual`.
- Reloading the page keeps Visual selected.
- Clicking `Split` then refreshing keeps Split.

- [ ] **Step 6: Commit**

```bash
git add Design/prototype-v2/assets/prototype.js Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: wire editor mode controller

initEditorMode() reads ?mode=source|visual|split, swaps panes in place,
mirrors mode to the URL with history.replaceState, and persists last-used
mode per diagram to sessionStorage."
```

### Task 4.4: Wire the Selection controller (Inspector ↔ Diagram swap)

**Files:**
- Modify: `Design/prototype-v2/assets/prototype.js`
- Modify: `Design/prototype-v2/editor.html` (add selection sample nodes)

- [ ] **Step 1: Add a sample selectable node to the Visual pane**

In `editor.html` inside `[data-pane="visual"]`, add at least one canvas node element that JS can attach a `click` handler to:

```html
<svg class="canvas" viewBox="0 0 600 400">
  <rect class="node" data-node-id="n1" x="80" y="80" width="120" height="48" rx="8" />
  <text x="140" y="108" text-anchor="middle">Start</text>
</svg>
```

Style it lightly in the page's `<style>` block so it shows up:

```css
.canvas .node { fill: #fff; stroke: var(--border); stroke-width: 1; cursor: pointer; }
.canvas .node.is-selected { stroke: var(--accent); stroke-width: 2; }
```

- [ ] **Step 2: Add the Selection controller**

In `assets/prototype.js`, add after `initEditorMode`:

```js
function initEditorSelection() {
  const rail = document.querySelector('[data-rail-state]');
  if (!rail) return;
  const nodes = document.querySelectorAll('.canvas .node');
  if (nodes.length === 0) return;

  function setState(state, payload = null) {
    rail.classList.toggle("rail--inspector", state === "inspector");
    rail.classList.toggle("rail--diagram", state === "diagram");
    rail.dataset.railState = state;
    // Optional: render payload into an Inspector tabpanel
    const panel = rail.querySelector('[data-tabpanel="details"]');
    if (state === "inspector" && payload && panel) {
      panel.innerHTML = `<p>Node <code>${payload.id}</code> selected.</p>`;
    }
  }

  nodes.forEach((node) => {
    node.addEventListener("click", () => {
      nodes.forEach((n) => n.classList.remove("is-selected"));
      node.classList.add("is-selected");
      setState("inspector", { id: node.dataset.nodeId });
    });
  });
  // Clicking on canvas background (the SVG itself) deselects
  document.querySelectorAll('.canvas').forEach((svg) => {
    svg.addEventListener("click", (e) => {
      if (e.target.classList.contains("canvas")) {
        nodes.forEach((n) => n.classList.remove("is-selected"));
        setState("diagram");
      }
    });
  });

  setState("diagram");
}
```

Boot it alongside `initEditorMode()`:

```js
  initEditorMode();
  initEditorSelection();
```

- [ ] **Step 3: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 4: Browser test**

Open editor.html, switch to Visual mode, click the sample node. Confirm:
- Rail header label changes from "Diagram" to "Inspector".
- The Details tabpanel shows the node id placeholder.
- Clicking on empty canvas reverts the rail to "Diagram".

- [ ] **Step 5: Commit**

```bash
git add Design/prototype-v2/assets/prototype.js Design/prototype-v2/editor.html
git commit -m "prototype-v2: wire editor Inspector↔Diagram selection swap

initEditorSelection() listens for canvas node clicks; toggles the rail
between .rail--inspector and .rail--diagram on the same container, so
the width is preserved. Background click deselects."
```

### Task 4.5: Add Publish controller stub (popover + flash)

**Files:**
- Modify: `Design/prototype-v2/assets/prototype.js`
- Modify: `Design/prototype-v2/editor.html` (no DOM changes beyond `data-publish`)

- [ ] **Step 1: Add the Publish controller**

In `assets/prototype.js`, add after `initEditorSelection`:

```js
function initPublishVersion() {
  const trigger = document.querySelector('[data-publish]');
  if (!trigger) return;

  let versionCount = 3; // mock starting count; live editor would read from history

  trigger.addEventListener("click", (e) => {
    e.preventDefault();
    const popover = makeScrim(`
      <div class="publish-popover">
        <h3>Publish version of pr-lifecycle.mmd</h3>
        <label>Version label<input type="text" value="v0.${++versionCount}" data-publish-label /></label>
        <label>Notes (optional)<textarea data-publish-notes></textarea></label>
        <div class="publish-popover__actions">
          <button class="btn btn--ghost" data-publish-cancel>Cancel</button>
          <button class="btn btn--primary" data-publish-confirm>Publish ⌘⇧P</button>
        </div>
      </div>
    `, "publish-scrim");

    popover.querySelector("[data-publish-cancel]").onclick = () => closeScrim(popover);
    popover.querySelector("[data-publish-confirm]").onclick = () => {
      const label = popover.querySelector("[data-publish-label]").value || `v0.${versionCount}`;
      closeScrim(popover);
      flashPublished(label);
    };
  });

  function flashPublished(label) {
    const status = document.querySelector('.pageheader__status .pill--state');
    if (!status) return;
    const original = status.textContent;
    status.textContent = `Published · ${label}`;
    status.classList.add("is-flash");
    setTimeout(() => {
      status.textContent = original;
      status.classList.remove("is-flash");
    }, 1200);
  }
}
```

Boot it:

```js
  initEditorMode();
  initEditorSelection();
  initPublishVersion();
```

- [ ] **Step 2: Add light styling to shared.css**

Append:

```css
.publish-popover {
  background: var(--surface);
  border-radius: 10px;
  box-shadow: var(--shadow-pop);
  padding: 16px 18px;
  width: 360px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.publish-popover h3 { font: 600 14px/1.2 var(--display); margin: 0 0 4px; }
.publish-popover label {
  display: flex; flex-direction: column; gap: 4px;
  font: 500 12px/1 var(--display); color: var(--ink-2);
}
.publish-popover input, .publish-popover textarea {
  font: 400 13px/1.4 var(--body);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 6px 8px;
}
.publish-popover__actions { display: flex; justify-content: flex-end; gap: 8px; }

.pill--state.is-flash {
  background: var(--accent-bg);
  color: var(--accent);
  transition: background 200ms, color 200ms;
}
```

- [ ] **Step 3: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 4: Browser test**

Click `Publish version` button → confirm popover opens, Cancel closes it, Publish triggers the `Published · v0.4` flash for ~1.2s, then settles back to `Saved`.

- [ ] **Step 5: Commit**

```bash
git add Design/prototype-v2/assets/prototype.js Design/prototype-v2/assets/shared.css
git commit -m "prototype-v2: add Publish version popover + status flash

initPublishVersion() opens a popover with label + notes; on confirm,
animates the Saved pill to Published · v0.{N} for ~1.2s then settles
back. Replaces the unclear 'Render' CTA."
```

### Task 4.6: Update internal links across all pages to point at editor.html

**Files:**
- Modify: `Design/prototype-v2/index.html`
- Modify: `Design/prototype-v2/ai.html`
- Modify: `Design/prototype-v2/library.html`
- Modify: `Design/prototype-v2/present.html`
- Modify: `Design/prototype-v2/activity.html`
- Modify: `Design/prototype-v2/settings.html`
- Modify: `Design/prototype-v2/share.html`

- [ ] **Step 1: Find all links to playground.html and visual.html**

```bash
cd Design/prototype-v2
grep -rn 'href="playground.html\|href="visual.html' *.html
```

- [ ] **Step 2: Rewrite each link**

Per the spec's "Open in" semantics (Library):
- `href="playground.html"` → `href="editor.html?mode=source"`
- `href="visual.html"` → `href="editor.html?mode=visual"`
- Generic Diagram-editor nav-pill links (left nav) → `href="editor.html"` (which defaults to Source mode)

Use targeted `Edit` calls with `replace_all=true` on each file as appropriate. The left nav-pill in each file should additionally:
- Add `class="... is-on"` on `editor.html` link when the current page is `editor.html`.
- Remove any prior nav-pills that pointed at `playground.html` or `visual.html`.

- [ ] **Step 3: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

Expected: no broken-link failures, no missing nav-pill failures.

- [ ] **Step 4: Browser smoke**

Click through each page's left nav. Confirm `Diagram editor` always lands on `editor.html` with Source mode active by default.

- [ ] **Step 5: Commit**

```bash
git add Design/prototype-v2/*.html
git commit -m "prototype-v2: redirect internal links to editor.html

All references to playground.html or visual.html now point at
editor.html with the appropriate ?mode= parameter. Left-nav pills
collapse to a single Diagram editor entry."
```

### Task 4.7: Delete playground.html and visual.html

**Files:**
- Delete: `Design/prototype-v2/playground.html`
- Delete: `Design/prototype-v2/visual.html`

- [ ] **Step 1: Delete the files**

```bash
cd Design/prototype-v2
git rm playground.html visual.html
```

- [ ] **Step 2: Run tests**

```bash
npm test
```

Expected: all tests pass. (If any failure references the deleted files, an internal link was missed in Task 4.6 — fix it then re-run.)

- [ ] **Step 3: Browser smoke**

```bash
NO_OPEN=1 npm start &
sleep 1
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4321/playground.html
# Expect: 404
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4321/visual.html
# Expect: 404
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4321/editor.html
# Expect: 200
```

- [ ] **Step 4: Commit**

```bash
git commit -m "prototype-v2: delete playground.html and visual.html

Both files are now subsumed by editor.html with mode tabs. The IA
consolidation is complete."
```

---

### Task 4.8: Add remaining cross-cutting structural invariants

**Files:**
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

With `playground.html` and `visual.html` gone, the stricter "appears nowhere in HTML" invariants can be asserted. Add the chip-order, family-class, and counts-not-pill invariants too.

- [ ] **Step 1: Append the invariants block**

Append to `tests/prototype-enhancements.test.mjs`, after the editor.html block:

```js
// --- Remaining cross-cutting invariants (Stage 4 post-deletion) -------------
const PILL_FAMILIES = ["state", "sync", "sharing", "type", "ai"];
const CHIP_ORDER = ["type", "sync", "sharing", "ai"];

for (const page of pages) {
  const html = read(page);

  // "Playground" / "Visual editor" (as destinations) appear nowhere — stricter
  // than the label-only check in Stage 2. Allowed exceptions: HTML comments,
  // alt text on bridge prototypes (none currently). The check looks at any
  // visible text — anything between `>` and `<` outside of <script> blocks.
  const visibleText = html.replace(/<script[\s\S]*?<\/script>/g, "")
                          .replace(/<!--[\s\S]*?-->/g, "");
  if (/\bPlayground\b/.test(visibleText)) {
    fail(`${page}: 'Playground' appears in visible text (deleted concept)`);
  }
  // "Visual editor" as a destination — allow "Visual mode" but flag "Visual editor"
  if (/\bVisual editor\b/.test(visibleText)) {
    fail(`${page}: 'Visual editor' appears as a destination label (use 'Visual mode' or 'Diagram editor')`);
  }

  // Each .pill must carry exactly one family modifier class.
  const pills = [...html.matchAll(/<[a-z]+[^>]*class="([^"]*\bpill\b[^"]*)"/g)].map(m => m[1]);
  for (const cls of pills) {
    const families = PILL_FAMILIES.filter(f => new RegExp(`\\bpill--${f}\\b`).test(cls));
    if (families.length === 0) {
      fail(`${page}: .pill without a family class ("${cls}")`);
    } else if (families.length > 1) {
      fail(`${page}: .pill with multiple family classes ("${cls}")`);
    }
  }

  // Card chip order — every .cardchips must list pills in [type, sync, sharing, ai].
  const chipBlocks = [...html.matchAll(/<[a-z]+[^>]*class="[^"]*\bcardchips\b[^"]*"[^>]*>([\s\S]*?)<\/[a-z]+>/g)];
  for (const [block, inner] of chipBlocks) {
    const pillFamilies = [...inner.matchAll(/class="[^"]*\bpill--(state|sync|sharing|type|ai)\b/g)].map(m => m[1]);
    const filtered = pillFamilies.filter(f => f !== "state"); // state is not a card chip
    let lastIdx = -1;
    for (const f of filtered) {
      const idx = CHIP_ORDER.indexOf(f);
      if (idx < lastIdx) {
        fail(`${page}: .cardchips DOM order violates [type][sync][sharing][ai] (saw ${filtered.join(",")})`);
        break;
      }
      lastIdx = idx;
    }
  }

  // Counts (e.g. "47 diagrams", "9 shown", "3 unread", "12 events") render as
  // plain text, never inside a .pill class.
  const countPatterns = [
    /<[a-z]+[^>]*class="[^"]*\bpill\b[^"]*"[^>]*>\s*\d+\s+(diagrams|shown|unread|events)\b/i,
  ];
  for (const re of countPatterns) {
    if (re.test(html)) {
      fail(`${page}: a count appears inside a .pill (counts must be plain text)`);
    }
  }

  // Notifications block lives only in the global notif button — never inside
  // a .rail__tabpanel.
  const tabpanels = [...html.matchAll(/<div class="[^"]*rail__tabpanel[^"]*"[^>]*>([\s\S]*?)<\/div>/g)].map(m => m[1]);
  for (const panel of tabpanels) {
    if (/\bNotifications?\b/.test(panel) && !/aria-label="Notifications"/.test(panel)) {
      fail(`${page}: 'Notifications' appears inside a rail tabpanel (move to global notif button)`);
    }
  }

  // Mode tabs (where present) sit in pageheader__row2, not row1.
  const row1Match = html.match(/class="pageheader__row1"[\s\S]*?<\/div>/);
  if (row1Match && /\bpageheader__modes\b/.test(row1Match[0])) {
    fail(`${page}: mode tabs appear in row1 (must be in row2)`);
  }
}
```

- [ ] **Step 2: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

Any failure here points to either (a) a still-present `Playground`/`Visual editor` reference (search and fix), (b) a card chip in the wrong order, or (c) a `Notifications` reference left in a rail tabpanel.

- [ ] **Step 3: Commit**

```bash
git add Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: add post-deletion cross-cutting invariants

Asserts Playground/Visual editor are gone from visible text; .pill carries
exactly one family class; .cardchips DOM order is [type][sync][sharing][ai];
counts never appear inside a .pill; Notifications never appears in a rail
tabpanel; mode tabs live in row2, not row1."
```

---

## Stage 5 — Per-screen consolidations

**Goal:** Apply the per-screen detail polish — Home reframe, Library location/filter split, Activity decision support, Presentations slide-nav dedup, Settings save-state dedup, Share modal-ification.

**Files:** every remaining HTML except `editor.html` and `ai.html`, plus the test harness and assets.

### Task 5.1: Home — resume-first reframe

**Files:**
- Modify: `Design/prototype-v2/index.html`

- [ ] **Step 1: Write the structural test**

Add to `tests/prototype-enhancements.test.mjs`:

```js
// --- index.html resume-first reframe (Stage 5) -------------------------------
{
  const html = read("index.html");
  // Greeting copy matches spec
  if (!/Pick up where you left off, or start something new/.test(html)) {
    fail("index.html: greeting subtitle missing");
  }
  // Recent list is present and uses .cardchips for chip order enforcement
  if (!/class="[^"]*recent-list[^"]*"/.test(html)) {
    fail("index.html: recent-list section missing");
  }
  // Workstation mode-grid cards are removed
  if (/class="[^"]*mode[^"]*"[^>]*data-workstation/.test(html)) {
    fail("index.html: workstation .mode cards should be removed");
  }
  // Create row replaces them
  if (!/data-create-row/.test(html)) {
    fail("index.html: create row (data-create-row) missing");
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Edit index.html**

- Replace the greeting block's subtitle with:
  `Pick up where you left off, or start something new.`
- Delete the `.modes` grid (the four workstation cards).
- Replace it with the Create row:
  ```html
  <section class="home-create" data-create-row>
    <h2 class="home-create__title">Start something new</h2>
    <div class="home-create__actions">
      <button class="btn btn--primary">+ New diagram</button>
      <button class="btn btn--ghost">✨ Generate with AI</button>
      <button class="btn btn--ghost">📄 From template</button>
      <button class="btn btn--ghost">↑ Import Mermaid</button>
      <button class="btn btn--ghost">▦ New presentation</button>
    </div>
  </section>
  ```
- Ensure each Recent row uses `.cardchips` with the chip order `[Type] [Sync] [Sharing] [AI]`:
  ```html
  <a class="recent-row" href="editor.html?mode=source&id=pr-lifecycle">
    <span class="recent-row__name">pr-lifecycle.mmd</span>
    <span class="cardchips">
      <span class="pill pill--type is-flow">Flow</span>
      <span class="pill pill--sync is-live"><span class="pill__dot"></span>Live</span>
      <span class="pill pill--sharing">Shared</span>
    </span>
    <span class="recent-row__time">2m ago</span>
  </a>
  ```
  (Repeat the pattern for the other Recent rows. AI chip drops out when not applicable.)
- Add the minimal `.home-create` styles inline in the `<style>` block.

- [ ] **Step 4: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 5: Browser smoke check**

Open `http://127.0.0.1:4321/index.html`. Confirm: greeting + recent + create row + This week column.

- [ ] **Step 6: Commit**

```bash
git add Design/prototype-v2/index.html Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: reframe Home as resume-first

Removes the workstation mode cards (they duplicated the left nav).
Adds a unified Create row. Recent rows adopt the [Type][Sync][Sharing][AI]
chip order."
```

### Task 5.2: Library — location-vs-filter split

**Files:**
- Modify: `Design/prototype-v2/library.html`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Write the structural test**

```js
// --- library.html location vs filter split (Stage 5) -------------------------
{
  const html = read("library.html");
  // Type + Status filter chips are above the grid (data-filter-chips)
  if (!/data-filter-chips="type"/.test(html)) {
    fail("library.html: Type filter chip strip missing");
  }
  if (!/data-filter-chips="status"/.test(html)) {
    fail("library.html: Status filter chip strip missing");
  }
  // Views and Folders are in the left rail (data-left-rail-section)
  if (!/data-left-rail-section="views"/.test(html)) {
    fail("library.html: Views left-rail section missing");
  }
  if (!/data-left-rail-section="folders"/.test(html)) {
    fail("library.html: Folders left-rail section missing");
  }
  // 'Used in decks' tab is its own tab (not buried)
  if (!/data-tabpanel="used-in-decks"/.test(html)) {
    fail("library.html: Used-in-decks tab missing");
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Restructure library.html**

- In the left rail, organize into two sections with `data-left-rail-section`:
  ```html
  <section data-left-rail-section="views">
    <h3>Views</h3>
    <ul><!-- All / My diagrams / Shared with me / Recently edited --></ul>
  </section>
  <section data-left-rail-section="folders">
    <h3>Folders</h3>
    <ul><!-- Architecture / Auth / Pipelines / Templates --></ul>
  </section>
  ```
- Above the grid (below `.pageheader`), add the filter chip strips:
  ```html
  <div class="filter-chips" data-filter-chips="type">
    <span>Type:</span>
    <button>Flow</button><button>Seq</button><!-- ... --><button>Journey</button>
  </div>
  <div class="filter-chips" data-filter-chips="status">
    <span>Status:</span>
    <button>Live</button><button>Stale</button><button>AI</button><button>Comments</button><button>In deck</button>
  </div>
  ```
- In the right rail, add a `Used in decks` tab to the tab strip:
  ```html
  <button role="tab" data-tab="used-in-decks">Used in decks</button>
  ```
  And the corresponding `<div class="rail__tabpanel" data-tabpanel="used-in-decks">…</div>`. The content lists decks this diagram is embedded in, with counts.
- Move counts (`47 diagrams · 9 shown`) into plain text (NOT `.pill`) inside `pageheader__row2`'s status slot. **Important:** the v0.3.0 prototype had a duplicate "9 shown 9 shown" rendering bug — confirm the count appears exactly once after the move.
- Audit every card in the grid: each `.cardchips` block must list pills in DOM order `[Type] [Sync] [Sharing] [AI]` (Stage 4's invariant test will catch violations). Specifically, ensure the Type chip uses the correct `--type-*` token tied to the diagram type (Flow→is-flow, Sequence→is-seq, etc.). Decorative color overrides that weren't tied to type — for example a "pink Flow" card — must be removed so color encodes type and only type.

- [ ] **Step 4: Add minimal styles**

In library.html `<style>`:

```css
.filter-chips {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 20px;
  flex-wrap: wrap;
  border-bottom: 1px solid var(--border-3);
}
.filter-chips > span { font: 500 12px/1 var(--display); color: var(--ink-3); }
.filter-chips button {
  font: 500 11px/1 var(--display);
  padding: 4px 8px;
  border-radius: 999px;
  border: 1px solid var(--border);
  background: var(--surface-2);
  color: var(--ink-2);
  cursor: pointer;
}
.filter-chips button.is-on {
  background: var(--accent-bg);
  border-color: var(--accent-bd);
  color: var(--accent);
}
```

- [ ] **Step 5: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 6: Browser smoke check**

Open library.html. Confirm: left rail shows Views + Folders sections; filter chips visible above the grid; right panel has the Used-in-decks tab.

- [ ] **Step 7: Commit**

```bash
git add Design/prototype-v2/library.html Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: Library location-vs-filter split

Views + Folders move to the left rail (the location selector). Type +
Status become chip strips above the grid (the filter composers).
Used-in-decks is promoted to its own right-rail tab."
```

### Task 5.3: Activity — clickable Decision support + single Mark-all-read

**Files:**
- Modify: `Design/prototype-v2/activity.html`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add the structural test**

```js
// --- activity.html clickable decision support (Stage 5) ---------------------
{
  const html = read("activity.html");
  // Decision support rows are buttons (role=button) with aria-pressed
  const dsBlock = html.match(/data-decision-support[\s\S]*?<\/section>/);
  if (!dsBlock) fail("activity.html: data-decision-support section missing");
  else if (!/role="button"/.test(dsBlock[0])) {
    fail("activity.html: decision support rows must have role=button");
  }
  // Primary CTA is 'Mark all read' (not 'Notifications')
  if (!/data-mark-all-read/.test(html)) {
    fail("activity.html: Mark all read CTA missing");
  }
  // 'Mark as read' (singular, right-panel) should be removed
  if (/data-mark-as-read/.test(html)) {
    fail("activity.html: duplicate per-event 'Mark as read' should be removed");
  }
  // Audit log moved out of Scope group
  if (!/data-rail-section="audit-log"/.test(html)) {
    fail("activity.html: audit-log should be in its own rail section");
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Edit activity.html**

- Find the Decision support panel; wrap each row in:
  ```html
  <button class="ds-row" role="button" data-decision-filter="unresolved" aria-pressed="false">
    <span class="ds-row__count">3</span> unresolved
  </button>
  ```
  Repeat for `restorable` (`2 restorable AI edits`) and `stale-deck-link` (`1 stale deck link`).
- Above the Decision support section, add `data-decision-support`:
  ```html
  <section data-decision-support>...</section>
  ```
- Replace any existing `Notifications` primary CTA in `pageheader__cta` with:
  ```html
  <button class="btn btn--primary" data-mark-all-read>Mark all read</button>
  ```
- Remove the per-event `Mark as read` from the right rail (search for `Mark as read` and delete the button).
- Move the Audit log out of the Scope cluster into its own rail section:
  ```html
  <section data-rail-section="audit-log">
    <h3>Audit log <span class="tag tag--admin">admin</span></h3>
    <a href="#">Open audit log →</a>
  </section>
  ```
- Update time display per the spec: every feed card shows relative time (`2m`, `1h`, `14m`); the right-panel `Event` Details tabpanel shows local + UTC parenthetical (`14:20 local · 18:20 UTC`). Find any UTC-only timestamps in the feed and replace with relative; find any relative-only timestamps in the detail panel and replace with the local+UTC pair.

- [ ] **Step 4: Wire JS hook for decision-support filter (lightweight stub)**

In `assets/prototype.js`, find `initActivityFilters` (around line 308) and extend it:

```js
function initActivityFilters() {
  // ... existing implementation ...
  const dsButtons = document.querySelectorAll('[data-decision-filter]');
  dsButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      const active = btn.getAttribute("aria-pressed") === "true";
      dsButtons.forEach((b) => b.setAttribute("aria-pressed", "false"));
      btn.setAttribute("aria-pressed", String(!active));
      // Apply filter to feed — feed implementation can be a no-op stub
      // that the future controller wires up.
      document.body.dataset.decisionFilter = !active ? btn.dataset.decisionFilter : "";
    });
  });
}
```

- [ ] **Step 5: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 6: Browser smoke check**

Open activity.html. Click a Decision support count — confirm `aria-pressed="true"` flips, the body data attribute changes. Confirm primary CTA reads `Mark all read`. Confirm right panel no longer has its own `Mark as read`.

- [ ] **Step 7: Commit**

```bash
git add Design/prototype-v2/activity.html Design/prototype-v2/assets/prototype.js Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: Activity clickable decision support + single Mark CTA

Decision support counts become aria-pressed buttons that filter the feed.
Primary CTA changes from 'Notifications' (circular) to 'Mark all read'.
Per-event 'Mark as read' is removed. Audit log gets its own rail section
with an admin tag."
```

### Task 5.4: Presentations — slide-nav dedup + tabbed rail + stale review consolidation

**Files:**
- Modify: `Design/prototype-v2/present.html`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add the structural test**

```js
// --- present.html slide-nav dedup + tabbed rail (Stage 5) -------------------
{
  const html = read("present.html");
  // The bottom thumbnail strip is deleted (not hidden)
  if (/class="[^"]*slide-thumb-strip[^"]*"/.test(html)) {
    fail("present.html: bottom slide thumbnail strip should be deleted");
  }
  // The right rail uses tabs (Notes / Diagrams / Assistant / Theme)
  for (const tab of ["notes", "diagrams", "assistant", "theme"]) {
    if (!new RegExp(`data-tab="${tab}"`).test(html)) {
      fail(`present.html: rail tab "${tab}" missing`);
    }
  }
  // 'Slide N of M' appears at most once
  const matches = html.match(/Slide \d+ of \d+/g) || [];
  if (matches.length > 1) {
    fail(`present.html: 'Slide N of M' appears ${matches.length} times (must be 1)`);
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Edit present.html**

- Delete the bottom thumbnail strip element entirely (`grep -n slide-thumb-strip present.html` to find it).
- Replace the right-rail's stacked sections with the tabbed rail:
  ```html
  <aside class="rail rail--slide" data-rail-state="slide">
    <div class="rail__header"><h2 class="rail__title">Slide</h2></div>
    <div class="rail__tabs" role="tablist">
      <button class="is-on" role="tab" data-tab="notes">Notes</button>
      <button role="tab" data-tab="diagrams">Diagrams <span class="badge">1</span></button>
      <button role="tab" data-tab="assistant">Assistant</button>
      <button role="tab" data-tab="theme">Theme</button>
    </div>
    <div class="rail__tabpanel is-on" data-tabpanel="notes"><!-- existing notes content --></div>
    <div class="rail__tabpanel" data-tabpanel="diagrams">
      <!-- Linked diagrams list + stale-review banner -->
      <div class="stale-review">
        <p>1 linked diagram needs review</p>
        <div class="stale-review__actions">
          <button>Compare changes</button>
          <button>Accept update</button>
          <button>Keep snapshot</button>
          <button>Update all</button>
        </div>
      </div>
    </div>
    <div class="rail__tabpanel" data-tabpanel="assistant"><!-- existing assistant content --></div>
    <div class="rail__tabpanel" data-tabpanel="theme"><!-- existing theme content --></div>
  </aside>
  ```
- Remove the duplicate `Slide N of M` from the bottom pagination line; keep it only in the canvas's slide-status corner.
- In `pageheader__row2`'s status slot, add the stale-diagram pill that clicks through to the Diagrams tab:
  ```html
  <span class="pill pill--sync is-stale">1 stale diagram</span>
  ```
  (No additional JS click handler required for the prototype — the rail's existing tab controller handles it once the user is in the rail. Optional: add a JS hook later that scrolls/focuses the Diagrams tab.)
- Each embedded diagram card inside a slide previously had a header like `Service boundary · Live`, which competed with the slide's own title (UX-1's complaint). Remove the card-level header; the diagram card now shows only the Sync pill (`Live` / `Stale` / `Snapshot`). Find any `<header class="diagram-card__title">` (or equivalent) inside slide content and replace with just the chip:
  ```html
  <div class="diagram-card__chip">
    <span class="pill pill--sync is-live"><span class="pill__dot"></span>Live</span>
  </div>
  ```

- [ ] **Step 4: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 5: Browser smoke check**

- Confirm the bottom thumbnail strip is gone.
- Confirm right rail has the four tabs.
- Confirm `Slide N of M` appears only in the canvas corner.

- [ ] **Step 6: Commit**

```bash
git add Design/prototype-v2/present.html Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: Presentations dedup + tabbed rail

Removes the bottom thumbnail strip (left outline is the canonical
navigator). Right rail becomes Notes/Diagrams/Assistant/Theme tabs.
'Slide N of M' appears once. Stale-diagram review consolidates into
the Diagrams tab; top pill links there."
```

### Task 5.5: Settings — save-state dedup + plan-as-chip + label alignment + nav tags

**Files:**
- Modify: `Design/prototype-v2/settings.html`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add the structural test**

```js
// --- settings.html consolidations (Stage 5) ----------------------------------
{
  const html = read("settings.html");
  // Nav label and page title both read 'Sharing & permissions'
  const navMatch = html.match(/data-settings-nav-item="sharing"[^>]*>([\s\S]*?)<\/a>/);
  if (navMatch && !/Sharing & permissions/.test(navMatch[1])) {
    fail("settings.html: nav label for Sharing should be 'Sharing & permissions'");
  }
  if (!/<h1[^>]*>Sharing & permissions<\/h1>/.test(html) && /sharing/i.test(html)) {
    // soft check — only fail if a sharing subpage h1 exists but doesn't match
  }
  // Plan chip + Advanced glyph + nav tags
  if (!/data-nav-tag="new"/.test(html))     fail("settings.html: Personal nav tag 'new' missing");
  if (!/data-nav-tag="team"/.test(html))    fail("settings.html: Workspace nav tag 'team' missing");
  if (!/data-nav-tag="billing"/.test(html)) fail("settings.html: Plan nav tag 'billing' missing");
  if (!/data-nav-tag="admin"/.test(html))   fail("settings.html: Advanced nav tag 'admin' missing");
  if (/data-nav-tag="careful"/.test(html))  fail("settings.html: 'careful' tag should be removed");
  if (!/<span class="chip chip--plan">Studio plan<\/span>/.test(html)) {
    fail("settings.html: Studio plan chip missing");
  }
  // Save-state appears only in pageheader, not in right rail
  const railSection = html.match(/class="[^"]*rail[^"]*"[\s\S]*?<\/aside>/);
  if (railSection && /Auto-saved|Saved · \d/.test(railSection[0])) {
    fail("settings.html: save-state appears in the right rail (must be in pageheader only)");
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Edit settings.html**

- In the left settings nav, ensure each nav item has its `data-settings-nav-item` and `data-nav-tag` attributes:
  ```html
  <a data-settings-nav-item="personal"  data-nav-tag="new">Personal</a>
  <a data-settings-nav-item="defaults">Diagram defaults</a>
  <a data-settings-nav-item="workspace" data-nav-tag="team">Workspace</a>
  <a data-settings-nav-item="sharing">Sharing & permissions</a>
  <a data-settings-nav-item="plan"      data-nav-tag="billing">Plan <span class="chip chip--plan">Studio plan</span></a>
  <a data-settings-nav-item="advanced"  data-nav-tag="admin">Advanced <span class="glyph">⚠</span></a>
  ```
- Style nav tags with a small uppercase pill (`.tag`, `.chip--plan`); add CSS as needed in the inline `<style>`.
- Remove the right-rail `Status · Auto-saved · 2s` block (delete the whole subsection). The Save-state appears once in `pageheader__row2`.
- Make sure the Plan & usage block in the right rail stays visible on every settings subpage (no `display: none` per-page).
- For the Sharing subpage, ensure `<h1>` says `Sharing & permissions`.

- [ ] **Step 4: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 5: Browser smoke check**

Click through each settings nav item. Confirm the page title `<h1>` for Sharing & permissions is correct. Confirm only one save-state indicator exists (in the page header).

- [ ] **Step 6: Commit**

```bash
git add Design/prototype-v2/settings.html Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: Settings consolidations

Aligns nav label and page title for Sharing & permissions. Standardizes
nav tags (new/team/billing/admin; drops 'careful'). Adds Studio plan chip
on the Plan nav item; ⚠ glyph on Advanced (destructive warnings inline
at action sites). Deletes the duplicate right-rail Status block; Plan &
usage stays in the right rail across every subpage."
```

### Task 5.6: Share — modal-ification + single CTA + footer summary

**Files:**
- Modify: `Design/prototype-v2/share.html`
- Modify: `Design/prototype-v2/assets/prototype.js`
- Modify: `Design/prototype-v2/assets/shared.css`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add the structural test**

```js
// --- share.html modal mode + single CTA (Stage 5) ---------------------------
{
  const html = read("share.html");
  // Modal markup is present
  if (!/data-share-modal/.test(html)) {
    fail("share.html: data-share-modal wrapper missing");
  }
  // Single primary CTA in the footer
  const cta = html.match(/data-share-send-save[^>]*>([\s\S]*?)<\/button>/);
  if (!cta) fail("share.html: 'Send & save' primary CTA missing (data-share-send-save)");
  // Old multi-action buttons removed
  if (/data-share-confirm-external/.test(html)) {
    fail("share.html: 'Confirm external share' should be folded into Send & save");
  }
  if (/data-share-manage-links/.test(html)) {
    fail("share.html: 'Manage links' should be folded into Send & save");
  }
  if (/data-share-save-changes/.test(html)) {
    fail("share.html: 'Save changes' should be folded into Send & save");
  }
  // Workspace policy subhead is in the header (not buried at the bottom)
  if (!/class="modalheader__subtitle"[^>]*>[\s\S]*workspace policy/.test(html)) {
    fail("share.html: workspace policy subhead missing from modal header");
  }
  // Footer summary string is present
  if (!/data-share-summary/.test(html)) {
    fail("share.html: footer summary (data-share-summary) missing");
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Wrap share.html content in a modal scaffold**

Restructure as:

```html
<body>
<div class="app share-app" data-share-modal>
  <div class="share-modal__backdrop" data-share-backdrop></div>
  <section class="share-modal" role="dialog" aria-modal="true" aria-labelledby="share-title">
    <!-- modalheader from Task 3.10 -->
    <header class="modalheader">...</header>

    <div class="share-modal__body">
      <section class="share-people">
        <!-- Invite + People with access (existing content; ensure roles match Library/Settings) -->
      </section>
      <section class="share-links">
        <!-- Diagram link card + SVG link card; each with ▾ Advanced disclosure -->
      </section>
      <details class="share-policy">
        <summary>Workspace policy details</summary>
        <!-- Existing policy details content -->
      </details>
    </div>

    <footer class="share-modal__footer">
      <span data-share-summary>2 invites · 1 external (Allowed by policy)</span>
      <span class="share-modal__cta-group">
        <button class="btn btn--ghost" data-share-cancel>Cancel</button>
        <button class="btn btn--primary" data-share-send-save>Send & save</button>
      </span>
    </footer>
  </section>
</div>
<script src="assets/prototype.js"></script>
</body>
```

Delete any pre-existing standalone `Confirm external share`, `Manage links`, `Save changes` buttons. The Suppression rule for `+ Studio plan` upsell: keep it only if `data-user-plan != "studio"`. For prototype purposes, hardcode `<body data-user-plan="studio">` and conditionally render the upsell via inline `<template>` + JS.

- [ ] **Step 4: Add modal styling**

Append to `assets/shared.css`:

```css
.share-app { display: contents; }
.share-modal__backdrop {
  position: fixed; inset: 0;
  background: rgba(0,0,0,0.32);
  backdrop-filter: blur(2px);
  z-index: 100;
}
.share-modal {
  position: fixed;
  top: 50%; left: 50%;
  transform: translate(-50%, -50%);
  width: min(720px, calc(100vw - 64px));
  max-height: calc(100vh - 64px);
  display: grid;
  grid-template-rows: auto 1fr auto;
  background: var(--surface);
  border-radius: var(--win-radius);
  box-shadow: var(--shadow-win);
  z-index: 101;
  overflow: hidden;
}
.share-modal__body { padding: 16px 18px; overflow-y: auto; }
.share-modal__footer {
  display: flex; justify-content: space-between; align-items: center;
  padding: 12px 18px; gap: 12px;
  border-top: 1px solid var(--border);
  background: var(--surface-2);
  font: 500 12px/1 var(--display);
  color: var(--ink-2);
}
.share-modal__cta-group { display: inline-flex; gap: 8px; }
```

- [ ] **Step 5: Add JS for modal close + CTA behavior**

In `assets/prototype.js`, replace the existing `initShareDialog` body (around line 688) with logic that handles the new single-CTA model:

```js
function initShareDialog() {
  const modal = document.querySelector('[data-share-modal]');
  if (!modal) return;

  const backdrop = modal.querySelector('[data-share-backdrop]');
  const cancel = modal.querySelector('[data-share-cancel]');
  const close = modal.querySelector('.modalheader__close');
  const send = modal.querySelector('[data-share-send-save]');
  const summary = modal.querySelector('[data-share-summary]');

  // Standalone preview vs modal mount:
  // When loaded with ?open=1 (from another page), it stays as a modal overlay
  // on this URL. When loaded directly (no param), it renders full-screen for
  // standalone preview, but the close affordances still navigate back.
  const params = new URLSearchParams(location.search);
  const from = params.get("from") || "library.html";
  const open = params.get("open") === "1";

  if (!open) {
    // Standalone preview: dim the backdrop a little less, keep modal visible
    backdrop.style.opacity = "0.2";
  }

  function dismiss() {
    if (open && history.length > 1) history.back();
    else location.href = from;
  }
  backdrop.addEventListener("click", dismiss);
  cancel.addEventListener("click", dismiss);
  close.addEventListener("click", dismiss);
  document.addEventListener("keydown", (e) => { if (e.key === "Escape") dismiss(); });

  send.addEventListener("click", () => {
    // Stub: commit invites + role changes + link toggles + external confirmations
    showToast("Sent", summary.textContent, "success");
    dismiss();
  });
}
```

- [ ] **Step 6: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 7: Browser smoke check**

- Open `http://127.0.0.1:4321/share.html` (standalone): renders as overlay with mild backdrop.
- Open `http://127.0.0.1:4321/library.html`, click any Share button: navigates to share.html with `?open=1&from=library.html`, fully modal.
- Press Esc: returns.
- Click `Send & save`: toast fires, returns.

- [ ] **Step 8: Commit**

```bash
git add Design/prototype-v2/share.html Design/prototype-v2/assets/prototype.js Design/prototype-v2/assets/shared.css Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: Share modal-ify + single Send & save CTA

share.html becomes a real modal overlay (with ?open=1 from a parent) or
a standalone preview (no param). Folds Confirm-external / Manage-links /
Save-changes into a single 'Send & save' primary CTA. Workspace policy
is promoted to the modal subhead. Footer summarizes what Send & save
will commit. The +Studio plan upsell is suppressed when user is on
Studio plan."
```

---

## Stage 6 — Refine-with-AI handoff + Publish polish

**Goal:** Wire the Assistant tab as the in-place AI surface; wire `⤢ Open in AI studio` promotion with preserved state; AI studio empty-state + refine-from-recent landing.

**Files:**
- Modify: `Design/prototype-v2/editor.html`
- Modify: `Design/prototype-v2/ai.html`
- Modify: `Design/prototype-v2/assets/prototype.js`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

### Task 6.1: Wire the RefineAI controller (editor → Assistant tab)

**Files:**
- Modify: `Design/prototype-v2/assets/prototype.js`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add a test for the hook**

Extend `requiredJsHooks`:

```js
  "initRefineAI",
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Add the controller to prototype.js**

```js
function initRefineAI() {
  const trigger = document.querySelector('[data-refine-ai]');
  const rail = document.querySelector('[data-rail-state]');
  if (!trigger || !rail) return;

  trigger.addEventListener("click", (e) => {
    e.preventDefault();
    // Force rail into Diagram identity (deselect if Inspector was active)
    rail.classList.remove("rail--inspector");
    rail.classList.add("rail--diagram");
    rail.dataset.railState = "diagram";
    // Activate Assistant tab
    rail.querySelectorAll('.rail__tabs button').forEach((b) => {
      b.classList.toggle("is-on", b.dataset.tab === "assistant");
      b.setAttribute("aria-selected", String(b.dataset.tab === "assistant"));
    });
    rail.querySelectorAll('.rail__tabpanel').forEach((p) => {
      p.classList.toggle("is-on", p.dataset.tabpanel === "assistant");
    });
    // Focus the chat input in the panel
    const input = rail.querySelector('[data-tabpanel="assistant"] input, [data-tabpanel="assistant"] textarea');
    if (input) input.focus();
  });

  // Promote to AI studio
  const promote = rail.querySelector('[data-promote-to-ai-studio]');
  if (promote) {
    promote.addEventListener("click", () => {
      const diagramId = document.body.dataset.diagramId || "default";
      const draft = rail.querySelector('[data-tabpanel="assistant"] textarea')?.value || "";
      sessionStorage.setItem(`ai-studio:chat-draft:${diagramId}`, draft);
      location.href = `ai.html?source=${encodeURIComponent(diagramId)}&from=editor`;
    });
  }
}
```

Boot it:

```js
  initEditorMode();
  initEditorSelection();
  initPublishVersion();
  initRefineAI();
```

- [ ] **Step 4: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 5: Browser smoke check**

Open editor.html. Click `✨ Refine with AI →`. Confirm:
- Rail header becomes Diagram (or stays Diagram).
- Assistant tab activates.
- Focus moves to the chat input (if present).

Then click `⤢ Open in AI studio` inside the Assistant panel. Confirm navigation to `ai.html?source=...&from=editor`.

- [ ] **Step 6: Commit**

```bash
git add Design/prototype-v2/assets/prototype.js Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: wire Refine-with-AI handoff

initRefineAI() opens the editor's Assistant tab in place; the panel's
'Open in AI studio' affordance promotes to ai.html with the diagram and
chat draft preserved via sessionStorage."
```

### Task 6.2: AI studio empty-state + refine-from-recent landing

**Files:**
- Modify: `Design/prototype-v2/ai.html`
- Modify: `Design/prototype-v2/tests/prototype-enhancements.test.mjs`

- [ ] **Step 1: Add a test for the landing surfaces**

```js
// --- ai.html scoped landing (Stage 6) ---------------------------------------
{
  const html = read("ai.html");
  // Empty-state primary actions present
  if (!/data-ai-action="generate-new"/.test(html)) {
    fail("ai.html: empty-state 'Generate a new diagram' action missing");
  }
  if (!/data-ai-action="refine-existing"/.test(html)) {
    fail("ai.html: empty-state 'Refine an existing diagram' action missing");
  }
  // Source diff component class exists for refining mode
  if (!/class="[^"]*source-diff[^"]*"/.test(html)) {
    fail("ai.html: source-diff component markup missing");
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 3: Edit ai.html**

- Add the empty-state landing (visible when no `?source=` param is present):
  ```html
  <section class="ai-empty-state" data-ai-empty>
    <h1>What would you like to do?</h1>
    <div class="ai-empty-state__actions">
      <button class="btn btn--primary" data-ai-action="generate-new">✨ Generate a new diagram</button>
      <button class="btn btn--ghost" data-ai-action="refine-existing">Refine an existing diagram →</button>
    </div>
  </section>
  ```
- Add the source-diff component (visible when `?source=` is present):
  ```html
  <section class="source-diff" data-source-diff hidden>
    <div class="source-diff__pane source-diff__pane--current">
      <h3>Current</h3>
      <pre>flowchart TD<br>  A --> B</pre>
    </div>
    <div class="source-diff__pane source-diff__pane--proposed">
      <h3>Proposed</h3>
      <pre>flowchart TD<br>  A --> B<br>  B --> C[Retry]</pre>
    </div>
  </section>
  ```
- Add a `refine-recent` picker stub for the `Refine an existing diagram →` action:
  ```html
  <section class="ai-refine-picker" data-ai-picker hidden>
    <h2>Refine a recent diagram</h2>
    <ul>
      <li><a href="ai.html?source=pr-lifecycle">pr-lifecycle.mmd</a></li>
      <li><a href="ai.html?source=auth-flow">auth-flow.mmd</a></li>
    </ul>
  </section>
  ```
- Add light styling.

- [ ] **Step 4: Update ai.html JS routing**

In `assets/prototype.js`, find `initAiStudio` and adapt:

```js
function initAiStudio() {
  const empty = document.querySelector('[data-ai-empty]');
  const diff = document.querySelector('[data-source-diff]');
  const picker = document.querySelector('[data-ai-picker]');
  if (!empty) return;

  const params = new URLSearchParams(location.search);
  const source = params.get("source");
  const fromEditor = params.get("from") === "editor";

  if (source) {
    empty.hidden = true;
    if (diff) diff.hidden = false;
    // Restore chat draft if returning from editor
    if (fromEditor) {
      const draft = sessionStorage.getItem(`ai-studio:chat-draft:${source}`);
      const composer = document.querySelector('[data-ai-composer] textarea, [data-ai-composer] input');
      if (composer && draft) composer.value = draft;
    }
  } else {
    empty.hidden = false;
    document.querySelector('[data-ai-action="refine-existing"]')?.addEventListener("click", () => {
      empty.hidden = true;
      if (picker) picker.hidden = false;
    });
  }
}
```

- [ ] **Step 5: Run tests**

```bash
cd Design/prototype-v2 && npm test
```

- [ ] **Step 6: Browser smoke check**

- Open `http://127.0.0.1:4321/ai.html` — confirm empty-state landing.
- Click `Refine an existing diagram →` — confirm the picker shows.
- Open `http://127.0.0.1:4321/ai.html?source=pr-lifecycle&from=editor` — confirm source-diff is visible and chat draft restoration is wired (if there was a saved draft).

- [ ] **Step 7: Commit**

```bash
git add Design/prototype-v2/ai.html Design/prototype-v2/assets/prototype.js Design/prototype-v2/tests/prototype-enhancements.test.mjs
git commit -m "prototype-v2: AI studio empty-state + refine-from-recent

Adds the two-primary landing (Generate / Refine existing), a recent-diagram
picker, and a source-diff component used when refining. Restores chat
draft from sessionStorage when arriving from the editor."
```

### Task 6.3: Full regression — run the harness one last time + browser walkthrough

**Files:**
- (verification only)

- [ ] **Step 1: Run the full test harness**

```bash
cd Design/prototype-v2 && npm test
```

Expected: all tests pass.

- [ ] **Step 2: Walk the eight screens manually**

Start the dev server, then walk:
1. Home → confirm resume-first layout, Create row, chip orders.
2. Library → confirm Views/Folders rail, filter chips above grid, Used-in-decks tab.
3. Diagram editor (Source) → confirm two-row header, status pills, Publish/Refine CTAs.
4. Diagram editor (Visual) → confirm Inspector ↔ Diagram swap on node click, pending-edit banner only when active.
5. Diagram editor (Split) → confirm both panes render.
6. AI studio (empty) → confirm landing.
7. AI studio (refining, `?source=pr-lifecycle&from=editor`) → confirm diff view.
8. Presentations → confirm single navigator (no bottom strip), tabbed rail, single Slide-N-of-M, stale-diagram pill in header.
9. Activity → confirm clickable Decision support, Mark all read CTA, AI assistant actor names, "Edited in" field label.
10. Settings → confirm aligned nav label + page title, plan chip + admin glyph, only one save-state indicator.
11. Share (modal from Library) → confirm modal overlay, policy subhead, Send & save commits everything.

- [ ] **Step 3: Spot-check the cross-cutting denylist + invariants**

```bash
cd Design/prototype-v2
grep -rn 'Studio AI\|Source mode:' *.html
# Expected: zero matches outside of explanatory prose

grep -rn 'href="playground\|href="visual' *.html
# Expected: zero matches

grep -c 'class="pageheader"' index.html editor.html ai.html library.html present.html activity.html settings.html
# Expected: each page has exactly 1 match (share.html intentionally has 0)
```

- [ ] **Step 4: Final commit (no code changes — sanity tag)**

If everything passes:

```bash
cd /Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift
git log --oneline -25
# Confirm Stage-by-stage commit story is clean
```

(No additional commit needed; the redesign is complete at the end of the previous tasks. If a discrepancy is found, fix it inline as a regression-fix commit.)

---

## Verification checklist

Before declaring the redesign done:

- [ ] `npm test` passes in `Design/prototype-v2/`.
- [ ] `playground.html` and `visual.html` no longer exist.
- [ ] `editor.html` responds to `?mode=source|visual|split` without page reload.
- [ ] Every page header is two rows; breadcrumb begins with `Engineering`.
- [ ] Every right rail matches the spec's identity table.
- [ ] No bare `Studio`, no bare `Code`, no `Playground` or `Visual editor` as destination labels.
- [ ] Counts (`47 diagrams`, `9 shown`, `3 unread`, `12 events`) are plain text, never inside `.pill`.
- [ ] Share opens as a modal with `?open=1` and standalone otherwise.
- [ ] A full walkthrough reads as one product, not eight.
