#!/usr/bin/env node
// Zero-dependency static dev server for the Design/prototype-v2 prototype.
// Adds SSE-driven live reload so editing HTML/CSS/JS refreshes the browser.

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { watch } from "node:fs";
import { extname, join, normalize, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { exec } from "node:child_process";

const ROOT = resolve(fileURLToPath(new URL("./", import.meta.url)));
const PORT = Number(process.env.PORT) || 4321;
const HOST = process.env.HOST || "127.0.0.1";

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css":  "text/css; charset=utf-8",
  ".js":   "application/javascript; charset=utf-8",
  ".mjs":  "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg":  "image/svg+xml",
  ".png":  "image/png",
  ".jpg":  "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif":  "image/gif",
  ".webp": "image/webp",
  ".ico":  "image/x-icon",
  ".woff": "font/woff",
  ".woff2":"font/woff2",
  ".ttf":  "font/ttf",
  ".map":  "application/json; charset=utf-8",
};

const RELOAD_SNIPPET = `
<script>
(() => {
  if (window.__protoReloadWired) return;
  window.__protoReloadWired = true;
  const connect = () => {
    const es = new EventSource("/__reload");
    es.addEventListener("reload", () => location.reload());
    es.addEventListener("css", (e) => {
      document.querySelectorAll('link[rel="stylesheet"]').forEach((link) => {
        const url = new URL(link.href, location.href);
        if (e.data && !url.pathname.endsWith(e.data)) return;
        url.searchParams.set("v", Date.now().toString());
        link.href = url.toString();
      });
    });
    es.onerror = () => {
      es.close();
      setTimeout(connect, 800);
    };
  };
  connect();
})();
</script>
`;

const clients = new Set();

function broadcast(event, data = "") {
  const payload = `event: ${event}\ndata: ${data}\n\n`;
  for (const res of clients) {
    try { res.write(payload); } catch { clients.delete(res); }
  }
}

function safeJoin(root, urlPath) {
  const clean = decodeURIComponent(urlPath.split("?")[0].split("#")[0]);
  const joined = normalize(join(root, clean));
  if (joined !== root && !joined.startsWith(root + sep)) return null;
  return joined;
}

async function serveStatic(req, res) {
  const urlPath = req.url === "/" ? "/index.html" : req.url;
  let filePath = safeJoin(ROOT, urlPath);
  if (!filePath) {
    res.writeHead(403).end("Forbidden");
    return;
  }
  try {
    const info = await stat(filePath);
    if (info.isDirectory()) filePath = join(filePath, "index.html");
  } catch {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" })
       .end(`Not found: ${urlPath}`);
    return;
  }

  const ext = extname(filePath).toLowerCase();
  const type = MIME[ext] || "application/octet-stream";

  try {
    const body = await readFile(filePath);
    if (ext === ".html") {
      const html = body.toString("utf8");
      const injected = html.includes("</body>")
        ? html.replace("</body>", `${RELOAD_SNIPPET}</body>`)
        : html + RELOAD_SNIPPET;
      res.writeHead(200, {
        "content-type": type,
        "cache-control": "no-store",
      }).end(injected);
    } else {
      res.writeHead(200, {
        "content-type": type,
        "cache-control": "no-store",
      }).end(body);
    }
  } catch (err) {
    res.writeHead(500, { "content-type": "text/plain; charset=utf-8" })
       .end(`Server error: ${err.message}`);
  }
}

const server = createServer(async (req, res) => {
  if (req.url === "/__reload") {
    res.writeHead(200, {
      "content-type": "text/event-stream",
      "cache-control": "no-cache, no-transform",
      "connection": "keep-alive",
      "x-accel-buffering": "no",
    });
    res.write(`event: hello\ndata: connected\n\n`);
    clients.add(res);
    req.on("close", () => clients.delete(res));
    return;
  }
  if (req.url === "/__health") {
    res.writeHead(200, { "content-type": "application/json" })
       .end(JSON.stringify({ ok: true, clients: clients.size }));
    return;
  }
  await serveStatic(req, res);
});

let pending = null;
const queue = new Set();
function schedule(file, kind) {
  queue.add(`${kind}:${file}`);
  if (pending) return;
  pending = setTimeout(() => {
    const items = Array.from(queue);
    queue.clear();
    pending = null;
    const cssOnly = items.every((s) => s.startsWith("css:"));
    if (cssOnly) {
      for (const item of items) broadcast("css", item.slice(4));
    } else {
      broadcast("reload");
    }
  }, 80);
}

function startWatch() {
  const watchTargets = [
    { dir: ROOT, recursive: false },
    { dir: join(ROOT, "assets"), recursive: false },
  ];
  for (const { dir, recursive } of watchTargets) {
    try {
      watch(dir, { recursive }, (_event, filename) => {
        if (!filename) return;
        const ext = extname(filename).toLowerCase();
        if (ext === ".css") schedule(filename, "css");
        else if (ext === ".html" || ext === ".js" || ext === ".mjs") schedule(filename, "any");
      });
    } catch (err) {
      console.warn(`[watch] could not watch ${dir}: ${err.message}`);
    }
  }
}

function openBrowser(url) {
  if (process.env.NO_OPEN) return;
  const cmd =
    process.platform === "darwin" ? `open "${url}"` :
    process.platform === "win32"  ? `start "" "${url}"` :
                                    `xdg-open "${url}"`;
  exec(cmd, () => { /* ignore */ });
}

server.listen(PORT, HOST, () => {
  const url = `http://${HOST}:${PORT}/`;
  console.log(`prototype-v2  ->  ${url}`);
  console.log(`live-reload   ->  watching *.html, assets/*.{css,js}`);
  startWatch();
  openBrowser(url);
});

for (const sig of ["SIGINT", "SIGTERM"]) {
  process.on(sig, () => { server.close(); process.exit(0); });
}
