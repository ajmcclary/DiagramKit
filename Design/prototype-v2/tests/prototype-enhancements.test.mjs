import { readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (rel) => readFileSync(resolve(ROOT, rel), "utf8");

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

// share.html is a sub-view of Library and intentionally highlights the
// Library nav-pill rather than a dedicated one.
const activeNavOverride = {
  "share.html": "library.html",
};

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
  // New in Stage 1 — page header anatomy
  ".pageheader",
  ".pageheader__row1",
  ".pageheader__row2",
  ".pageheader__breadcrumb",
  ".pageheader__modes",
  ".pageheader__status",
  ".pageheader__cta",
  // New in Stage 1 — rail anatomy
  ".rail",
  ".rail__header",
  ".rail__tabs",
  ".rail__tabpanel",
  ".rail--inspector",
  ".rail--diagram",
  // New in Stage 1 — banner + chip container
  ".editbanner",
  ".editbanner--active",
  ".cardchips",
  ".pill--state",
  ".pill--sync",
  ".pill--sharing",
  ".pill--type",
  ".pill--ai",
];

const requiredJsHooks = [
  "initCommandPalette",
  "initNewDiagramFlow",
  "initLibraryFilters",
  "initActivityFilters",
  "initVisualEditor",
  "initAiStudio",
  "initAiComposer",
  "initShareDialog",
  "initPresentationMode",
  "showToast",
];

// Page-specific requirements: each entry asserts substrings present.
const pageRequirements = {
  "ai.html": [
    'data-ai-composer',           // composer form is present
    'data-ai-send',                // send button is wired
    'class="turn user"',           // sender turn class
    'class="stack"',               // stack wrapper used by new alignment
  ],
};

const failures = [];
const fail = (msg) => failures.push(msg);

// --- Per-page wiring ---------------------------------------------------------
for (const page of pages) {
  const html = read(page);

  if (!html.includes('src="assets/prototype.js"')) {
    fail(`${page}: missing <script src="assets/prototype.js">`);
  }
  if (!html.includes('href="assets/shared.css"')) {
    fail(`${page}: missing <link href="assets/shared.css">`);
  }
  for (const snippet of pageRequirements[page] || []) {
    if (!html.includes(snippet)) {
      fail(`${page}: missing required snippet "${snippet}"`);
    }
  }

  // Active nav-pill must point at this page (or the documented override).
  const expectedActive = activeNavOverride[page] || page;
  const activeRe = /<a[^>]+href="([^"]+\.html)"[^>]*class="[^"]*nav-pill[^"]*is-on/g;
  const actives = [...html.matchAll(activeRe)].map((m) => m[1]);
  if (actives.length === 0) {
    fail(`${page}: no nav-pill marked is-on`);
  } else if (actives.length > 1) {
    fail(`${page}: multiple nav-pills marked is-on (${actives.join(", ")})`);
  } else if (actives[0] !== expectedActive) {
    fail(`${page}: active nav-pill is "${actives[0]}", expected "${expectedActive}"`);
  }

  // Every internal *.html href must resolve to a file in this directory.
  const linkRe = /href="([^"#?]+\.html)(?:[?#][^"]*)?"/g;
  const links = new Set([...html.matchAll(linkRe)].map((m) => m[1]));
  for (const link of links) {
    // Skip absolute URLs / paths that escape this dir.
    if (/^https?:/.test(link) || link.startsWith("/")) continue;
    if (!existsSync(resolve(ROOT, link))) {
      fail(`${page}: broken link href="${link}"`);
    }
  }
}

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
  // Bare "Studio" check, narrower regex to avoid false-positives on
  // "Studio plan" / "AI studio" / "Assistant".
  if (/<button[^>]*>\s*Studio\s*<|data-tab="Studio"/.test(html)) {
    fail(`${page}: bare "Studio" appears as a tab/button label (use Assistant or AI studio or 'Studio plan')`);
  }
}

// --- editor.html mode routing (Stage 4 redesign) -----------------------------
{
  const html = existsSync(resolve(ROOT, "editor.html")) ? read("editor.html") : "";
  if (html) {
    for (const mode of ["source", "visual", "split"]) {
      if (!html.includes(`data-mode="${mode}"`)) {
        fail(`editor.html: missing data-mode="${mode}" tab`);
      }
      if (!html.includes(`data-pane="${mode}"`)) {
        fail(`editor.html: missing data-pane="${mode}" content`);
      }
    }
    if (!/<button[^>]*data-mode="source"[^>]*\bis-on\b/.test(html)) {
      fail(`editor.html: default mode should be Source (is-on)`);
    }
  }
}

// --- Cross-cutting header + rail invariants (Stage 3 redesign) ---------------
const headerlessPages = new Set(["share.html"]); // Share uses its own modal chrome

for (const page of pages) {
  if (headerlessPages.has(page)) continue;
  const html = read(page);

  // Exactly one .pageheader with row1 + row2.
  const headerCount = (html.match(/class="[^"]*\bpageheader\b[^"]*"/g) || []).length;
  if (headerCount < 1) fail(`${page}: missing .pageheader element`);

  const hasRow1 = /class="[^"]*\bpageheader__row1\b[^"]*"/.test(html);
  const hasRow2 = /class="[^"]*\bpageheader__row2\b[^"]*"/.test(html);
  if (!hasRow1) fail(`${page}: pageheader missing __row1`);
  if (!hasRow2) fail(`${page}: pageheader missing __row2`);

  // Row 1 breadcrumb must start with the workspace name "Engineering".
  const breadcrumb = html.match(/class="[^"]*pageheader__breadcrumb[^"]*"[^>]*>([\s\S]*?)<\/nav>/);
  if (breadcrumb && !/Engineering/.test(breadcrumb[1])) {
    fail(`${page}: breadcrumb does not start with workspace "Engineering"`);
  }
}

// --- Shared CSS surface ------------------------------------------------------
const css = read("assets/shared.css");
for (const selector of requiredCss) {
  if (!css.includes(selector)) {
    fail(`assets/shared.css missing ${selector}`);
  }
}

// --- Prototype.js surface ----------------------------------------------------
const js = read("assets/prototype.js");
for (const hook of requiredJsHooks) {
  if (!js.includes(`function ${hook}`)) {
    fail(`assets/prototype.js missing function ${hook}`);
  }
}

// `window.prototypeDemo` is the public surface used from inline onclick
// handlers in index.html; if it disappears those buttons silently break.
if (!/window\.prototypeDemo\s*=/.test(js)) {
  fail("assets/prototype.js missing window.prototypeDemo export");
}

// --- Report ------------------------------------------------------------------
if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(`Prototype wiring checks passed (${pages.length} pages, ${requiredCss.length} CSS hooks, ${requiredJsHooks.length} JS hooks).`);
