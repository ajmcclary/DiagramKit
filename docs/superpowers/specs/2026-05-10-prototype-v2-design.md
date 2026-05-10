# Prototype v2 — macOS-light fidelity pass

**Date:** 2026-05-10
**Source:** `Design/prototype/` (v1, LCARS-themed inside macOS chrome)
**Target:** `Design/prototype-v2/` (macOS Sonoma light, Linear/Raycast/Things 3 lineage)

## Goal

Move the Mermaid·Swift clickable prototype from a costumed "LCARS bridge" treatment to a professional-fidelity macOS-light surface. Keep every page and every navigation edge; replace the chrome and strip dev/decorative helpers that distract from the user experience.

## Out of scope

- Behavior changes — every page links to the same set of pages it does today.
- Visual editor / AI / playground feature changes — only the chrome and the visual treatment of existing controls change.
- Light + dark theming. v2 ships light only; tokens are structured so dark can follow.
- Production code paths in `Sources/`. This work is mockups.

## Aesthetic direction

**Linear / Raycast / Things 3** lineage. Cool neutral surfaces, single restrained accent (Apple systemIndigo), Inter Display + Inter for UI, JetBrains Mono inside code only. Sharp corners (6–8px radii), hairline borders, dense but not cramped (13px body, 28px nav rows).

## Tokens

```
--bg:        #FAFAFA   page background
--surface:   #FFFFFF   cards, panels
--sidebar:   #F2F2F4   sidebar (vibrancy proxy)
--titlebar:  #F6F6F8   titlebar
--border:    #E5E5E7   hairlines
--border-2:  #D1D1D6   stronger dividers
--ink:       #1D1D1F   primary text
--ink-2:     #424245   secondary
--ink-3:     #86868B   tertiary
--ink-4:     #C7C7CC   placeholder
--accent:    #5E5CE6   indigo (CTA, focus, active nav, links)
--accent-bg: rgba(94, 92, 230, 0.10)
--accent-bd: rgba(94, 92, 230, 0.28)
--success:   #30D158
--warn:      #FF9F0A
--danger:    #FF3B30
```

Type stack: `Inter Display` headlines, `Inter` body, `JetBrains Mono` code (kept from v1).

## Chrome rules

- macOS Sonoma window: `1480×900` cap, `10px` radius, hairline border, layered shadow.
- **Single titlebar** (`38px`): traffic lights left, doc title centered, toolbar buttons inline right. No second header strip below.
- **No bottom dev status bar.** Save/sync state collapses into a tiny dot+label in the titlebar's right cluster.
- Sidebar `220px`, `--sidebar` background, no decorative shapes.

## Cuts (confirmed)

Stardates, `BRG-00` / `PG-01` / `VE-02` codes, "Mission log", render-avg / cache-hit / Linux-PASS / 914-snapshots dev metrics, kicker bars (`STARDATE 41254.7 · ALL STATIONS NOMINAL`), LCARS elbow stripes, decorative blip indicators, numbered section headers (`§ 03`), full status bar dev info, "Bridge" framing (renamed Home).

## Page-by-page treatment

| Page | Treatment |
|---|---|
| `index.html` | Renamed Home. Greeting + 4-card mode grid (icon + title + 2-line description, no stripes). Stat strip trimmed to **AI credits** + **active deck**. Recent kept (cleaner). Mission log cut. |
| `playground.html` | Catalog rail + code editor + canvas. Sonoma tab bar at top. Drop module codes. |
| `visual.html` | Canvas + right inspector (Linear-style property list). Drop stripe headers, drop module code. |
| `ai.html` | Chat-left, preview-right. Credits in a single quiet line near the prompt. |
| `present.html` | Slide outline left, slide editor center, notes drawer. Keynote-ish. |
| `library.html` | Two-pane Finder-like (folder tree + grid). |
| `activity.html` | Single feed, tighter grouping, right-aligned timestamps. |
| `settings.html` | macOS System Settings clone — category sidebar + form panel. |
| `share.html` | Centered macOS sheet over a dimmed app. |

## File layout

```
Design/prototype-v2/
  assets/shared.css     macOS-light tokens, chrome, sidebar, common components
  index.html            Home (renamed from Bridge)
  playground.html
  visual.html
  ai.html
  present.html
  library.html
  activity.html
  settings.html
  share.html
```

v1 (`Design/prototype/`) is left intact for comparison.

## Definition of done

- All 9 pages render in a browser, every nav link resolves to a sibling page in v2.
- No LCARS color tokens, no Antonio font, no `STARDATE` / `BRG-` / module-code text, no `Mission log` section, no `Render avg / Cache hit / Linux check / Snapshots` UI surface.
- Active nav state, hover state, focus ring all use the indigo accent.
- Inter loads from Google Fonts; JetBrains Mono loads from Google Fonts.
