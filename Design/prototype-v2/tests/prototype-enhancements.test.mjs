import { readFileSync } from "node:fs";

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
  "initShareDialog",
  "initPresentationMode",
  "showToast",
];

const failures = [];

for (const page of pages) {
  const html = readFileSync(page, "utf8");
  if (!html.includes('src="assets/prototype.js"')) {
    failures.push(`${page} does not include assets/prototype.js`);
  }
}

const css = readFileSync("assets/shared.css", "utf8");
for (const selector of requiredCss) {
  if (!css.includes(selector)) {
    failures.push(`assets/shared.css is missing ${selector}`);
  }
}

const js = readFileSync("assets/prototype.js", "utf8");
for (const hook of requiredJsHooks) {
  if (!js.includes(`function ${hook}`)) {
    failures.push(`assets/prototype.js is missing ${hook}`);
  }
}

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log("Prototype enhancement smoke checks passed");
