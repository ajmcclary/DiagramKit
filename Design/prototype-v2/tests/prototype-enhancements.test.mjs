import { readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (rel) => readFileSync(resolve(ROOT, rel), "utf8");

const pages = [
  "index.html",
  "playground.html",
  "visual.html",
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
