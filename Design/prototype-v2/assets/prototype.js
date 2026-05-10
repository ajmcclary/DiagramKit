(() => {
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const page = location.pathname.split("/").pop() || "index.html";

  function showToast(title, body = "", tone = "success") {
    let region = $(".prototype-toast-region");
    if (!region) {
      region = document.createElement("div");
      region.className = "prototype-toast-region";
      region.setAttribute("aria-live", "polite");
      document.body.appendChild(region);
    }

    const toast = document.createElement("div");
    toast.className = `prototype-toast ${tone}`;
    toast.innerHTML = `<strong>${title}</strong>${body ? `<span>${body}</span>` : ""}`;
    region.appendChild(toast);
    window.setTimeout(() => {
      toast.style.opacity = "0";
      toast.style.transform = "translateY(8px)";
      window.setTimeout(() => toast.remove(), 180);
    }, 2800);
  }

  function makeScrim(content, className = "") {
    const scrim = document.createElement("div");
    scrim.className = `prototype-scrim ${className}`.trim();
    scrim.appendChild(content);
    scrim.addEventListener("click", (event) => {
      if (event.target === scrim) closeScrim(scrim);
    });
    document.body.appendChild(scrim);
    const close = $(".prototype-close", content);
    if (close) close.addEventListener("click", () => closeScrim(scrim));
    return scrim;
  }

  function closeScrim(scrim = $(".prototype-scrim")) {
    if (scrim) scrim.remove();
  }

  function focusFirst(root) {
    const focusable = $("input, textarea, button, a[href]", root);
    if (focusable) focusable.focus({ preventScroll: true });
  }

  function initCommandPalette() {
    const commands = [
      ["New diagram", "Choose type and starting mode", "N", "modal", "plus"],
      ["Open Visual editor", "Flowchart visual editing with source sync", "2", "visual.html", "visual"],
      ["Open AI studio", "Prompt, validate, repair, and hand off", "3", "ai.html", "spark"],
      ["Open Library", "Search, filter, share, and organize diagrams", "L", "library.html", "grid"],
      ["Open Activity", "Review comments, AI changes, and share events", "A", "activity.html", "activity"],
      ["Open Settings", "Workspace policy, AI, export, and editor defaults", ",", "settings.html", "settings"],
      ["Open Share dialog", "Invite people and manage Editor/SVG links", "S", "share.html", "share"],
      ["Open Presentations", "Markdown deck editor with live diagrams", "P", "present.html", "present"],
    ];

    const icon = {
      plus: "+",
      visual: "□",
      spark: "✦",
      grid: "▦",
      activity: "↯",
      settings: "⚙",
      share: "↗",
      present: "▭",
    };

    const open = () => {
      const palette = document.createElement("div");
      palette.className = "command-palette";
      palette.setAttribute("role", "dialog");
      palette.setAttribute("aria-label", "Command palette");
      palette.innerHTML = `
        <div class="cp-search">
          <span style="color: var(--ink-3);">⌕</span>
          <input type="text" placeholder="Search commands, pages, and flows..." />
          <span class="kbd">Esc</span>
        </div>
        <div class="command-list"></div>
      `;
      const list = $(".command-list", palette);
      const render = (query = "") => {
        const q = query.trim().toLowerCase();
        list.innerHTML = "";
        commands
          .filter(([name, desc]) => `${name} ${desc}`.toLowerCase().includes(q))
          .forEach(([name, desc, key, target, ic], index) => {
            const item = document.createElement("button");
            item.className = `command-item ${index === 0 ? "is-on" : ""}`;
            item.type = "button";
            item.innerHTML = `
              <span class="ci">${icon[ic]}</span>
              <span><span class="name">${name}</span><span class="desc">${desc}</span></span>
              <span class="scope">${key}</span>
            `;
            item.addEventListener("click", () => {
              closeScrim();
              if (target === "modal") {
                openNewDiagramModal();
              } else if (target !== page) {
                location.href = target;
              } else {
                showToast("Already here", name, "warn");
              }
            });
            list.appendChild(item);
          });

        if (!list.children.length) {
          list.innerHTML = `<div class="empty-state">No commands match "${query}".</div>`;
        }
      };

      render();
      const scrim = makeScrim(palette);
      const input = $("input", palette);
      input.addEventListener("input", () => render(input.value));
      input.addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
          const active = $(".command-item.is-on", palette) || $(".command-item", palette);
          if (active) active.click();
        }
      });
      focusFirst(scrim);
    };

    document.addEventListener("keydown", (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        open();
      }
      if (event.key === "Escape") closeScrim();
    });

    $$('button[title="Search"], .search-input .kbd').forEach((trigger) => {
      trigger.addEventListener("click", (event) => {
        event.preventDefault();
        open();
      });
    });
  }

  function initNewDiagramFlow() {
    $$("button, a").forEach((control) => {
      const label = control.textContent.replace(/\s+/g, " ").trim().toLowerCase();
      if (label === "+ new diagram" || label === "new diagram" || label === "+ new blank diagram") {
        control.addEventListener("click", (event) => {
          event.preventDefault();
          openNewDiagramModal();
        });
      }
    });
  }

  function openNewDiagramModal() {
    const modal = document.createElement("div");
    modal.className = "new-diagram-modal";
    modal.setAttribute("role", "dialog");
    modal.setAttribute("aria-labelledby", "new-diagram-title");
    modal.innerHTML = `
      <div class="prototype-modal-head">
        <div>
          <h2 id="new-diagram-title">Create a diagram</h2>
          <p>Start from a Mermaid type, then choose whether to write source, refine visually, or prompt Studio AI.</p>
        </div>
        <button class="prototype-close" aria-label="Close">×</button>
      </div>
      <div class="new-flow-grid">
        <div class="new-flow-section">
          <h3>Diagram type</h3>
          <div class="new-type-grid">
            <button class="new-type is-on" data-type="Flowchart"><span class="name">Flowchart</span><span class="desc">Visual editing supported</span></button>
            <button class="new-type" data-type="Sequence"><span class="name">Sequence</span><span class="desc">Code + AI + preview</span></button>
            <button class="new-type" data-type="ER"><span class="name">ER diagram</span><span class="desc">Schema and relationships</span></button>
            <button class="new-type" data-type="State"><span class="name">State</span><span class="desc">Lifecycle and transitions</span></button>
            <button class="new-type" data-type="Gantt"><span class="name">Gantt</span><span class="desc">Roadmaps and phases</span></button>
            <button class="new-type" data-type="Mind map"><span class="name">Mind map</span><span class="desc">Idea hierarchy</span></button>
          </div>
        </div>
        <div class="new-flow-section">
          <h3>Start in</h3>
          <div class="entry-grid">
            <button class="entry-card is-on" data-entry="ai.html"><span class="name">Studio AI</span><span class="desc">Prompt to Mermaid with validation</span></button>
            <button class="entry-card" data-entry="visual.html"><span class="name">Visual editor</span><span class="desc">Flowchart direct manipulation</span></button>
            <button class="entry-card" data-entry="playground.html"><span class="name">Code editor</span><span class="desc">Source-first Mermaid editing</span></button>
            <button class="entry-card" data-entry="present.html"><span class="name">Presentation</span><span class="desc">Insert into a Markdown deck</span></button>
          </div>
        </div>
      </div>
      <div class="new-flow-footer">
        <span class="summary">Flowchart · Studio AI</span>
        <div style="display: flex; gap: 8px;">
          <button class="btn" data-close>Cancel</button>
          <button class="btn primary" data-create>Create <span class="kbd">Enter</span></button>
        </div>
      </div>
    `;

    const scrim = makeScrim(modal);
    const summary = $(".summary", modal);
    const updateSummary = () => {
      const type = $(".new-type.is-on", modal).dataset.type;
      const entry = $(".entry-card.is-on .name", modal).textContent;
      summary.textContent = `${type} · ${entry}`;
    };

    $$(".new-type", modal).forEach((button) => {
      button.addEventListener("click", () => {
        $$(".new-type", modal).forEach((item) => item.classList.remove("is-on"));
        button.classList.add("is-on");
        const visual = $('.entry-card[data-entry="visual.html"]', modal);
        if (button.dataset.type !== "Flowchart" && visual.classList.contains("is-on")) {
          visual.classList.remove("is-on");
          $('.entry-card[data-entry="playground.html"]', modal).classList.add("is-on");
          showToast("Visual fallback", "Only flowcharts are visually editable in this prototype.", "warn");
        }
        updateSummary();
      });
    });

    $$(".entry-card", modal).forEach((button) => {
      button.addEventListener("click", () => {
        const type = $(".new-type.is-on", modal).dataset.type;
        if (button.dataset.entry === "visual.html" && type !== "Flowchart") {
          showToast("Flowcharts only", "Unsupported types open in code + preview without losing source.", "warn");
          return;
        }
        $$(".entry-card", modal).forEach((item) => item.classList.remove("is-on"));
        button.classList.add("is-on");
        updateSummary();
      });
    });

    $("[data-close]", modal).addEventListener("click", () => closeScrim(scrim));
    $("[data-create]", modal).addEventListener("click", () => {
      const entry = $(".entry-card.is-on", modal).dataset.entry;
      showToast("Draft created", summary.textContent, "success");
      window.setTimeout(() => {
        location.href = entry;
      }, 450);
    });
    modal.addEventListener("keydown", (event) => {
      if (event.key === "Enter") $("[data-create]", modal).click();
    });
    focusFirst(scrim);
  }

  function initLibraryFilters() {
    const root = $(".lib-grid");
    if (!root) return;

    const cards = $$(".lib-card", root);
    const grid = $(".card-grid", root);
    const search = $(".lib-toolbar input", root);
    const toolbar = $(".lib-toolbar", root);
    const count = document.createElement("span");
    count.className = "filter-count";
    toolbar.appendChild(count);

    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "No diagrams match the current search and filters.";
    empty.hidden = true;
    grid.appendChild(empty);

    const apply = () => {
      const q = (search?.value || "").trim().toLowerCase();
      const groups = $$(".type-chips", root);
      const type = $(".chip.is-on", groups[0])?.textContent.trim().toLowerCase() || "all";
      const status = $(".chip.is-on", groups[1])?.textContent.trim().toLowerCase() || "";
      let visible = 0;

      cards.forEach((card) => {
        const text = card.textContent.toLowerCase();
        const matchesSearch = !q || text.includes(q);
        const matchesType = type === "all" || text.includes(type);
        const matchesStatus = !status || text.includes(status.toLowerCase());
        const show = matchesSearch && matchesType && matchesStatus;
        card.classList.toggle("is-filtered-out", !show);
        if (show) visible += 1;
      });

      count.textContent = `${visible} shown`;
      empty.hidden = visible > 0;
    };

    if (search) search.addEventListener("input", apply);
    $$(".type-chips .chip", root).forEach((button) => button.addEventListener("click", apply));
    $$(".view-toggle button", root).forEach((button, index) => {
      button.addEventListener("click", () => {
        grid.classList.toggle("is-list", index === 1);
        showToast(index === 1 ? "List view" : "Grid view", "Library layout preference updated.");
      });
    });
    $$(".lib-card", root).forEach((card) => {
      card.addEventListener("click", () => {
        cards.forEach((item) => item.classList.remove("is-on"));
        card.classList.add("is-on");
      });
    });

    apply();
  }

  function initActivityFilters() {
    const root = $(".ac-grid");
    if (!root) return;

    const events = $$(".event", root);
    const search = $(".ac-toolbar input", root);
    const toolbar = $(".ac-toolbar", root);
    const timeline = $(".timeline", root);
    const count = document.createElement("span");
    count.className = "filter-count";
    toolbar.appendChild(count);

    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "No activity matches the selected filters.";
    empty.hidden = true;
    timeline.appendChild(empty);

    const apply = () => {
      const q = (search?.value || "").trim().toLowerCase();
      const activeScope = $(".scope-row.is-on", root)?.textContent.toLowerCase() || "";
      const activeActors = $$(".actor-row.is-on .name", root).map((x) => x.textContent.toLowerCase());
      let visible = 0;

      events.forEach((event) => {
        const text = event.textContent.toLowerCase();
        const actorMatch = activeActors.length === 0 || activeActors.some((actor) => text.includes(actor));
        const scopeMatch =
          !activeScope.includes("involving me") ||
          text.includes("you") ||
          text.includes("@you") ||
          text.includes("alex");
        const show = (!q || text.includes(q)) && actorMatch && scopeMatch;
        event.classList.toggle("is-filtered-out", !show);
        if (show) visible += 1;
      });

      count.textContent = `${visible} events`;
      empty.hidden = visible > 0;
    };

    if (search) search.addEventListener("input", apply);
    $$(".scope-row, .actor-row, .date-chips .chip", root).forEach((item) => {
      item.addEventListener("click", () => window.setTimeout(apply));
    });
    $$(".event .actions button", root).forEach((button) => {
      button.addEventListener("click", (event) => {
        event.stopPropagation();
        showToast(button.textContent.trim(), "Activity item action queued in the prototype.");
      });
    });

    apply();
  }

  function initVisualEditor() {
    const root = $(".ve-grid");
    if (!root) return;

    const saveState = $(".title-actions .save-state");
    const source = $(".src-pv", root);
    const fillRow = $(".insp-block .row .v", root);
    const markDirty = (label) => {
      if (saveState) saveState.innerHTML = '<span class="dot"></span>Unsaved visual edit';
      if (source) {
        source.innerHTML = `<span class="dim">// will rewrite as:</span><span class="change">B["${label}"]:::cycle</span><span class="add">B --> Test</span><span class="add">B -.-> Review</span><span class="dim">// semantic structure preserved · whitespace normalized</span>`;
      }
    };

    $$(".swatches .sw", root).forEach((swatch) => {
      swatch.addEventListener("click", () => {
        const color = swatch.style.background || "#0891B2";
        if (fillRow) fillRow.innerHTML = `<span style="width:12px; height:12px; border-radius:3px; background:${color};"></span>${color.includes("gradient") ? "theme gradient" : color}`;
        markDirty("Build & cache deps");
      });
    });

    $$(".shape-grid .sh, .stroke-row .opt, .dir-btn, .tool", root).forEach((button) => {
      button.addEventListener("click", () => markDirty("Build & cache deps"));
    });

    $$(".canvas-toolbar button", root).forEach((button) => {
      button.addEventListener("click", () => {
        const value = $(".canvas-toolbar .v", root);
        if (!value) return;
        const current = Number.parseInt(value.textContent, 10) || 100;
        if (button.title === "Zoom in") value.textContent = `${Math.min(180, current + 12)}%`;
        if (button.title === "Zoom out") value.textContent = `${Math.max(40, current - 12)}%`;
        if (button.title === "Fit") value.textContent = "100%";
      });
    });

    $$(".ctx-btn", root).forEach((button) => {
      button.addEventListener("click", () => {
        const label = button.textContent.trim();
        if (label.includes("Label")) {
          const next = window.prompt("Edit node label", "Build & cache deps");
          if (next) {
            $$(".vn-text", root)
              .filter((node) => node.textContent.includes("Build"))
              .forEach((node) => (node.textContent = next));
            markDirty(next);
          }
        } else if (label.includes("Delete")) {
          showToast("Node removed", "Undo is available from the title bar.", "danger");
          markDirty("Deleted Build node");
        } else {
          showToast(label, "Contextual node control applied.");
          markDirty("Build & cache deps");
        }
      });
    });

    $$("a", root).forEach((link) => {
      if (link.textContent.includes("Preview source changes")) {
        link.addEventListener("click", (event) => {
          event.preventDefault();
          openSourceReview();
        });
      }
    });

    // Wire safety bar buttons (class-based, no inline handlers)
    $(".safety-diff-btn", root)?.addEventListener("click", () => {
      openSourceReview();
    });
    $(".safety-apply-btn", root)?.addEventListener("click", () => {
      showToast("Source applied", "Visual and source are back in sync.");
    });
    $(".safety-diff-link", root)?.addEventListener("click", (event) => {
      event.preventDefault();
      openSourceReview();
    });
  }

  function openSourceReview() {
    const modal = document.createElement("div");
    modal.className = "source-review-modal";
    modal.innerHTML = `
      <div class="prototype-modal-head">
        <div>
          <h2>Review source normalization</h2>
          <p>Visual edits keep the diagram meaning, but Mermaid source may be prettified before it is applied.</p>
        </div>
        <button class="prototype-close" aria-label="Close">×</button>
      </div>
      <div class="source-review-body">
        <pre><span class="note">Before</span>
subgraph Pipeline[CI Pipeline]
  B[Build & cache deps]
  T[Test]
  L[Lint & Type-check]
end
B --> T</pre>
        <pre><span class="note">After</span>
subgraph Pipeline["CI Pipeline"]
  B["Build & cache deps"]:::cycle
  B --> T["Test"]
  B -.-> Review{"Reviewer approves?"}
end
<span class="add">+ classDef cycle fill:#ECFEFF,stroke:#0891B2</span></pre>
      </div>
      <div class="new-flow-footer">
        <span class="summary">No unsupported source will be discarded.</span>
        <button class="btn primary" data-apply>Apply normalized source</button>
      </div>
    `;
    const scrim = makeScrim(modal);
    $("[data-apply]", modal).addEventListener("click", () => {
      closeScrim(scrim);
      showToast("Source applied", "Visual and Mermaid source are back in sync.");
    });
    focusFirst(scrim);
  }

  function initAiStudio() {
    const root = $(".ai-grid");
    if (!root) return;

    const input = $(".refine-input input", root);
    const send = $(".refine-input .send", root);
    const chat = $(".chat", root);
    const credit = $(".title-actions .save-state");
    const headline = $(".ai-headline .byline", root);

    const submit = () => {
      const prompt = input?.value.trim();
      if (!prompt) {
        showToast("Prompt required", "Describe the refinement before sending.", "warn");
        return;
      }
      send.classList.add("is-loading");
      send.textContent = "Generating...";
      const turn = document.createElement("div");
      turn.className = "turn";
      turn.innerHTML = `
        <span class="av ai"></span>
        <div>
          <div class="who">Studio<span class="ts">now · 1.8s</span></div>
          <div class="msg">Added a token-expiry retry path and kept MFA optional. Validation passed; one label was shortened for readability.</div>
          <div class="meta-pills">
            <span class="meta-pill ai">✦ refined</span>
            <span class="meta-pill live">✓ valid</span>
            <span class="meta-pill warn">1 source normalization</span>
          </div>
        </div>
      `;
      window.setTimeout(() => {
        chat.appendChild(turn);
        chat.scrollTop = chat.scrollHeight;
        send.classList.remove("is-loading");
        send.innerHTML = 'Send <span class="kbd">⌘↩</span>';
        if (credit) credit.innerHTML = '<span class="dot"></span>31 / 50 credits';
        if (headline) headline.insertAdjacentHTML("beforeend", '<span>Saved as <span class="v">draft · v4</span></span>');
        showToast("AI refinement drafted", "Review the updated source before saving.");
      }, 700);
    };

    if (send) send.addEventListener("click", submit);
    if (input) {
      input.addEventListener("keydown", (event) => {
        if ((event.metaKey || event.ctrlKey) && event.key === "Enter") submit();
      });
    }

    $$(".refine-chips .chip, .starter-list button", root).forEach((chip) => {
      chip.addEventListener("click", () => {
        if (input) input.value = chip.textContent.replace(/^[+−↻⇄⌘⊕✦]\s*/, "");
        if (input) input.focus();
      });
    });
  }

  function initAiComposer() {
    const composer = $("[data-ai-composer]");
    if (!composer) return;
    if (composer.dataset.aiComposerInit === "1") return;
    composer.dataset.aiComposerInit = "1";
    const textarea = $("textarea", composer);
    const sendBtn = $("[data-ai-send]", composer);
    const chat = $(".chat");
    const counterEl = $(".ai-pane .pane-head .meta");
    if (!textarea || !sendBtn || !chat) return;

    const formatNow = () => {
      const d = new Date();
      const hh = String(d.getHours()).padStart(2, "0");
      const mm = String(d.getMinutes()).padStart(2, "0");
      return `${hh}:${mm}`;
    };

    const autosize = () => {
      textarea.style.height = "auto";
      const max = parseFloat(getComputedStyle(textarea).maxHeight) || 168;
      textarea.style.height = `${Math.min(textarea.scrollHeight, max)}px`;
    };

    const refreshSendState = () => {
      sendBtn.disabled = textarea.value.trim().length === 0;
    };

    const scrollToEnd = () => {
      chat.scrollTop = chat.scrollHeight;
    };

    const bumpTurnCounter = () => {
      if (!counterEl) return;
      const match = counterEl.textContent.match(/(\d+)/);
      if (!match) return;
      const next = Number(match[1]) + 1;
      counterEl.textContent = `${next} turns`;
    };

    const appendUserTurn = (text) => {
      const turn = document.createElement("div");
      turn.className = "turn user";
      turn.innerHTML = `
        <span class="av">A</span>
        <div class="stack">
          <div class="who"><span class="ts">${formatNow()}</span>You</div>
          <div class="msg"></div>
        </div>
      `;
      $(".msg", turn).textContent = text;
      chat.appendChild(turn);
      return turn;
    };

    const appendPendingStudio = () => {
      const turn = document.createElement("div");
      turn.className = "turn";
      turn.innerHTML = `
        <span class="av ai"></span>
        <div class="stack">
          <div class="who">Studio<span class="ts">thinking…</span></div>
          <div class="msg is-pending">
            <span class="dotz" aria-hidden="true"><span></span><span></span><span></span></span>
          </div>
        </div>
      `;
      chat.appendChild(turn);
      return turn;
    };

    const resolveStudioTurn = (turn, prompt) => {
      const lower = prompt.toLowerCase();
      let summary = "Refined the diagram. Validation passed; preview updated.";
      const pills = ['<span class="meta-pill ai">✦ refined</span>', '<span class="meta-pill live">✓ valid</span>'];
      if (/(flow ?chart|swimlane)/.test(lower)) {
        summary = "Converted to flowchart with swimlanes for each actor. Source kept in sync.";
        pills.push('<span class="meta-pill warn">↺ structure</span>');
      } else if (/error|retry|expir/.test(lower)) {
        summary = "Added the error/retry path. Re-ran validate and repair — one label shortened.";
        pills.push('<span class="meta-pill warn">↺ 1 fix</span>');
      } else if (/simplif|concise|collapse/.test(lower)) {
        summary = "Collapsed redundant steps; reduced from 7 to 5 messages. Layout re-fit.";
      }

      const elapsed = `${(0.8 + Math.random() * 1.6).toFixed(1)}s`;
      turn.innerHTML = `
        <span class="av ai"></span>
        <div class="stack">
          <div class="who">Studio<span class="ts">${formatNow()} · ${elapsed}</span></div>
          <div class="msg">${summary}</div>
          <div class="meta-pills">${pills.join("")}</div>
        </div>
      `;
      bumpTurnCounter();
      bumpTurnCounter();
    };

    const submit = () => {
      const value = textarea.value.trim();
      if (!value) {
        textarea.focus();
        return;
      }
      appendUserTurn(value);
      const pending = appendPendingStudio();
      scrollToEnd();
      textarea.value = "";
      autosize();
      refreshSendState();
      textarea.focus();
      window.setTimeout(() => {
        resolveStudioTurn(pending, value);
        scrollToEnd();
        showToast("Studio replied", "Preview will update once you accept the revision.");
      }, 950);
    };

    textarea.addEventListener("input", () => {
      autosize();
      refreshSendState();
    });
    textarea.addEventListener("keydown", (event) => {
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        submit();
      }
    });
    sendBtn.addEventListener("click", (event) => {
      event.preventDefault();
      submit();
    });

    $$(".ai-chip", composer).forEach((chip) => {
      chip.addEventListener("click", () => {
        const suggestion = chip.dataset.suggest || chip.textContent.trim();
        textarea.value = suggestion;
        autosize();
        refreshSendState();
        textarea.focus();
      });
    });

    refreshSendState();
    autosize();
  }

  function initShareDialog() {
    const root = $(".share-card");
    if (!root) return;

    const inviteInput = $(".invite-input input", root);
    const send = $(".invite-send", root);
    const people = $(".collab-list", root);
    const footerAlert = $(".share-foot .alert", root);

    $$(".role-menu .opt", root).forEach((option) => {
      option.addEventListener("click", () => {
        $$(".role-menu .opt", root).forEach((item) => item.classList.remove("is-on"));
        option.classList.add("is-on");
        const role = $(".name", option).textContent;
        $(".role-selector span:nth-child(2)", root).textContent = role;
      });
    });

    $$(".copy", root).forEach((button) => {
      button.addEventListener("click", async () => {
        const url = button.closest(".url-row")?.querySelector(".url")?.textContent.trim();
        try {
          if (navigator.clipboard && url) await navigator.clipboard.writeText(url);
          showToast("Link copied", url || "Share URL copied.");
        } catch {
          showToast("Copy unavailable", "Clipboard permissions are blocked in this preview.", "warn");
        }
      });
    });

    $$(".switch", root).forEach((toggle) => {
      toggle.addEventListener("change", () => {
        showToast(toggle.checked ? "Link enabled" : "Link disabled", "Permissions will be saved with the dialog.");
      });
    });

    if (send) {
      send.addEventListener("click", () => {
        const email = inviteInput?.value.trim();
        if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
          showFieldError(inviteInput, "Enter a valid email address.");
          return;
        }
        const pending = document.createElement("div");
        pending.className = "collab-row pending";
        pending.innerHTML = `
          <span class="av dashed">N</span>
          <div class="who">
            <span class="name">${email || "new.collaborator@engineering.dev"} <span class="tag pending">Pending</span></span>
            <span class="meta">invited just now — awaiting accept</span>
          </div>
          <button class="role cyan">Commenter ▾</button>
          <button class="more">•••</button>
        `;
        people.appendChild(pending);
        if (inviteInput) inviteInput.value = "";
        showToast("Invite queued", "Pending invitation added to People with access.");
      });
    }

    $$("button", root).forEach((button) => {
      if (button.textContent.includes("Confirm external share")) {
        button.addEventListener("click", () => {
          if (footerAlert) {
            footerAlert.classList.remove("gold");
            footerAlert.innerHTML = '<span class="ic" style="width: 16px; height: 16px; font-size: 9px;">✓</span><div class="body"><span class="ttl" style="font-size: 11.5px;">External share confirmed</span><span class="desc" style="font-size: 10.5px;">partner-co.io matched the workspace allowlist and sign-in remains required.</span></div>';
          }
          showToast("External share confirmed", "Workspace policy requirements are visible in the audit log.");
        });
      }
      if (button.textContent.includes("Save changes")) {
        button.addEventListener("click", () => showToast("Sharing saved", "Collaborators and link settings updated."));
      }
    });
  }

  function showFieldError(input, message) {
    if (!input) return;
    input.setAttribute("aria-invalid", "true");
    let error = input.closest(".invite-input")?.nextElementSibling;
    if (!error || !error.classList.contains("field-error")) {
      error = document.createElement("div");
      error.className = "field-error";
      input.closest(".invite-input").after(error);
    }
    error.textContent = message;
  }

  function initPresentationMode() {
    const root = $(".pr-grid");
    if (!root) return;

    const slides = $$(".slide-card", root).filter((slide) => !slide.closest(".nested"));
    const thumbs = $$(".ribbon .thumb", root);
    let index = Math.max(0, slides.findIndex((slide) => slide.classList.contains("is-on")));

    const syncSelection = () => {
      slides.forEach((slide, i) => slide.classList.toggle("is-on", i === index));
      thumbs.forEach((thumb, i) => thumb.classList.toggle("is-on", i === index));
      const cur = $(".slide-header .cur", root);
      if (cur) cur.textContent = `${index + 1}`;
      const ribbonPos = $(".ribbon .pos");
      if (ribbonPos) ribbonPos.textContent = `${index + 1} / ${slides.length}`;
    };

    slides.forEach((slide, i) => slide.addEventListener("click", () => {
      index = i;
      syncSelection();
    }));
    thumbs.forEach((thumb, i) => thumb.addEventListener("click", () => {
      index = i;
      syncSelection();
    }));

    const open = () => {
      let overlay = $(".presenter-overlay");
      if (!overlay) {
        overlay = document.createElement("div");
        overlay.className = "presenter-overlay";
        overlay.innerHTML = `
          <div class="presenter-top">
            <span>SDK Auth · Q2 review</span>
            <button class="presenter-close">Close</button>
          </div>
          <div class="presenter-slide"></div>
          <div class="presenter-bottom">
            <span class="presenter-pos"></span>
            <div class="presenter-controls">
              <button data-prev>Prev</button>
              <button data-next>Next</button>
            </div>
          </div>
        `;
        document.body.appendChild(overlay);
        $(".presenter-close", overlay).addEventListener("click", () => overlay.classList.add("is-hidden"));
        $("[data-prev]", overlay).addEventListener("click", () => {
          index = Math.max(0, index - 1);
          renderPresenter();
        });
        $("[data-next]", overlay).addEventListener("click", () => {
          index = Math.min(slides.length - 1, index + 1);
          renderPresenter();
        });
      }
      overlay.classList.remove("is-hidden");
      renderPresenter();
    };

    const renderPresenter = () => {
      syncSelection();
      const overlay = $(".presenter-overlay");
      const title = $(".name", slides[index])?.textContent || "Service boundary";
      const meta = $(".meta", slides[index])?.textContent || "Live linked diagram";
      $(".presenter-slide", overlay).innerHTML = `
        <div class="presenter-card">
          <div>
            <h1>${title}</h1>
            <p>${meta}. This presenter view hides editing chrome and keeps diagram context visible for a technical walkthrough.</p>
            <ul>
              <li>Linked diagram status remains visible.</li>
              <li>Keyboard navigation uses arrow keys.</li>
              <li>Slide ${index + 1} stays synchronized with the outline.</li>
            </ul>
          </div>
          <div class="presenter-diagram">${$(".slide-thumb", slides[index])?.innerHTML || ""}</div>
        </div>
      `;
      $(".presenter-pos", overlay).textContent = `Slide ${index + 1} of ${slides.length}`;
    };

    $$("button, a").forEach((control) => {
      if (control.textContent.trim() === "Present") {
        control.addEventListener("click", (event) => {
          event.preventDefault();
          open();
        });
      }
    });
    document.addEventListener("keydown", (event) => {
      const overlay = $(".presenter-overlay:not(.is-hidden)");
      if (!overlay) return;
      if (event.key === "ArrowRight") {
        index = Math.min(slides.length - 1, index + 1);
        renderPresenter();
      }
      if (event.key === "ArrowLeft") {
        index = Math.max(0, index - 1);
        renderPresenter();
      }
      if (event.key === "Escape") overlay.classList.add("is-hidden");
    });

    $$(".prompter button", root).forEach((button) => {
      button.addEventListener("click", () => showToast("Prompter drafted", "Generated content remains editable Markdown."));
    });
  }

  function initSettingsFeedback() {
    const root = $(".se-grid");
    if (!root) return;

    const saveState = $(".title-actions .save-state");
    const search = $(".nav-rail input", root);
    const rows = $$(".nav-row", root);

    if (search) {
      search.addEventListener("input", () => {
        const q = search.value.trim().toLowerCase();
        rows.forEach((row) => row.classList.toggle("is-filtered-out", q && !row.textContent.toLowerCase().includes(q)));
      });
    }

    $$(".toggle, .seg button, .mode-card, .theme-row", root).forEach((control) => {
      control.addEventListener("click", () => {
        if (saveState) saveState.innerHTML = '<span class="dot"></span>Unsaved · autosaving';
        window.setTimeout(() => {
          if (saveState) saveState.innerHTML = '<span class="dot"></span>Auto-saved · just now';
        }, 800);
      });
    });
  }

  function initAccessibilityLabels() {
    $$("input, textarea, select").forEach((field, index) => {
      const fallback = field.placeholder || field.getAttribute("aria-label") || `Prototype field ${index + 1}`;
      const name = fallback
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "") || `prototype-field-${index + 1}`;
      if (!field.id) field.id = name;
      if (!field.name) field.name = name;
      if (!field.getAttribute("aria-label")) field.setAttribute("aria-label", fallback.replace(/…/g, ""));
    });
    $$("button:not([aria-label])").forEach((button) => {
      const label = button.textContent.replace(/\s+/g, " ").trim() || button.title;
      if (label) button.setAttribute("aria-label", label);
    });
  }

  function initGenericActionFeedback() {
    $$("button").forEach((button) => {
      const label = button.textContent.replace(/\s+/g, " ").trim();
      if (/^(Render|Re-render|Export|Import|Reset|Reflow|Restore|Resolve comment|Mark as read|Mark all read|Notifications)$/.test(label)) {
        button.addEventListener("click", () => showToast(label, "Prototype action feedback."));
      }
    });
  }

  document.addEventListener("DOMContentLoaded", () => {
    initAccessibilityLabels();
    initCommandPalette();
    initNewDiagramFlow();
    initLibraryFilters();
    initActivityFilters();
    initVisualEditor();
    initAiStudio();
    initShareDialog();
    initPresentationMode();
    initSettingsFeedback();
    initGenericActionFeedback();
  });

  // =======================================================================
  // GOLDEN PATH — Cross-page workflow state
  // =======================================================================

  const GOLDEN_PATH = {
    steps: [
      { id: "library", label: "Library", page: "library.html" },
      { id: "new", label: "New diagram", page: "modal" },
      { id: "ai", label: "AI draft", page: "ai.html" },
      { id: "visual", label: "Visual refine", page: "visual.html" },
      { id: "share", label: "Share", page: "share.html" },
      { id: "activity", label: "Activity", page: "activity.html" },
      { id: "deck", label: "Insert into deck", page: "present.html" },
      { id: "present", label: "Present", page: "presenter" },
    ],

    getState() {
      try {
        return JSON.parse(sessionStorage.getItem("dk_golden_path") || "{}");
      } catch {
        return {};
      }
    },

    setState(state) {
      sessionStorage.setItem("dk_golden_path", JSON.stringify(state));
    },

    markDone(stepId) {
      const state = this.getState();
      state[stepId] = "done";
      if (!state.started) {
        state.started = Date.now();
        // Auto-complete earlier steps
        const idx = this.steps.findIndex((s) => s.id === stepId);
        for (let i = 0; i < idx; i++) {
          if (!state[this.steps[i].id]) state[this.steps[i].id] = "done";
        }
      }
      this.setState(state);
      this.updateIndicator();
    },

    isActive() {
      return !!this.getState().started;
    },

    currentStepIdx() {
      const state = this.getState();
      for (let i = this.steps.length - 1; i >= 0; i--) {
        if (state[this.steps[i].id] === "done") return i + 1;
      }
      return 0;
    },

    initIndicator() {
      // Show page state banner if golden path is active
      const banner = $("[data-golden-banner]");
      if (banner) {
        banner.style.display = this.isActive() ? "flex" : "none";
      }

      if (!this.isActive()) return;

      let indicator = $(".golden-path-indicator");
      if (!indicator) {
        indicator = document.createElement("div");
        indicator.className = "golden-path-indicator";
        indicator.innerHTML = `
          <span class="step-dots"></span>
          <span class="step-label"></span>
          <button style="appearance:none;background:none;border:none;color:var(--ink-3);cursor:pointer;padding:0 2px;font-size:12px;" title="Reset tour">×</button>
        `;
        document.body.appendChild(indicator);
        $("button", indicator).addEventListener("click", () => {
          sessionStorage.removeItem("dk_golden_path");
          indicator.remove();
          showToast("Golden path reset", "Cross-page workflow state cleared.");
        });
      }
      this.updateIndicator();
    },

    updateIndicator() {
      const indicator = $(".golden-path-indicator");
      if (!indicator) return;
      const state = this.getState();
      const dots = $(".step-dots", indicator);
      const label = $(".step-label", indicator);
      dots.innerHTML = this.steps
        .map((s) => {
          let cls = "";
          if (state[s.id] === "done") cls = "done";
          return `<span class="step-dot ${cls}"></span>`;
        })
        .join("");
      const done = Object.values(state).filter((v) => v === "done").length;
      label.textContent = `${done}/${this.steps.length}`;
    },

    // Auto-detect and mark steps based on current page
    autoDetect() {
      const pageToStep = {
        "library.html": "library",
        "ai.html": "ai",
        "visual.html": "visual",
        "share.html": "share",
        "activity.html": "activity",
        "present.html": "deck",
        "index.html": null,
        "playground.html": null,
        "settings.html": null,
      };
      const stepId = pageToStep[page];
      if (stepId) this.markDone(stepId);

      // Detect "Present" step when presenter overlay appears
      const observer = new MutationObserver(() => {
        if ($(".presenter-overlay:not(.is-hidden)")) {
          this.markDone("present");
        }
      });
      observer.observe(document.body, { childList: true, subtree: true });
    },
  };

  // =======================================================================
  // GUIDED TOUR — Step-by-step walkthrough
  // =======================================================================

  const GUIDED_TOUR = {
    steps: [
      {
        page: "index.html",
        selector: ".greeting .btn.primary, button:contains('New diagram')",
        title: "Start a diagram",
        body: "Every diagram begins here. Click New diagram to choose a type and editing mode. The golden path tracks your journey across screens.",
      },
      {
        page: "library.html",
        selector: ".card-grid .lib-card:first-child",
        title: "Find a diagram",
        body: "The Library is your workspace command center. Each card shows type, status, sharing, and recency. Open one to begin editing.",
      },
      {
        page: "ai.html",
        selector: ".refine-input input",
        title: "Describe your diagram",
        body: "Studio AI converts natural language into validated Mermaid source. Try 'Sketch an auth flow with MFA and token refresh.' The output remains fully editable.",
      },
      {
        page: "visual.html",
        selector: ".canvas-stage-svg",
        title: "Refine visually",
        body: "Drag nodes, draw connectors, edit labels inline. The Inspector shows node identity, shape, and styling. Source stays in sync — but be aware: visual edits may normalize formatting.",
      },
      {
        page: "share.html",
        selector: ".invite-composer",
        title: "Share with your team",
        body: "Invite collaborators by email or workspace handle. Each role has clear permissions. The permission preview shows exactly what each person will see.",
      },
      {
        page: "activity.html",
        selector: ".timeline .event:first-child",
        title: "Track changes",
        body: "Activity groups edits into sessions, highlights unresolved items, and surfaces actions: restore AI edits, reply to comments, review stale deck links.",
      },
      {
        page: "present.html",
        selector: ".stage-banner",
        title: "Review before presenting",
        body: "The review queue flags stale linked diagrams. Compare old and new, accept updates, or keep snapshots. Your deck stays honest.",
      },
      {
        page: "present.html",
        selector: 'button:contains("Present"), .tb-btn.primary:contains("Present")',
        title: "Present with confidence",
        body: "Launch full-screen presentation mode. Linked diagrams stay live — no stale screenshots. Keyboard navigation, speaker notes, and slide timing are ready.",
      },
    ],

    currentIdx: 0,
    dismissed: false,

    start() {
      if (this.dismissed) return;
      this.currentIdx = 0;
      this.showCurrent();
    },

    showCurrent() {
      this.dismiss();
      const step = this.steps[this.currentIdx];
      if (!step) return;

      // Find target element
      let target;
      try {
        target = document.evaluate(
          step.selector,
          document,
          null,
          XPathResult.FIRST_ORDERED_NODE_TYPE,
          null
        ).singleNodeValue;
      } catch {
        target = $(step.selector.split(",")[0].trim());
      }
      if (!target) {
        this.currentIdx++;
        this.showCurrent();
        return;
      }

      const rect = target.getBoundingClientRect();

      // Spotlight
      const spotlight = document.createElement("div");
      spotlight.className = "tour-spotlight";
      const cutout = document.createElement("div");
      cutout.className = "cutout";
      cutout.style.cssText = `
        left: ${rect.left - 8}px;
        top: ${rect.top - 8}px;
        width: ${rect.width + 16}px;
        height: ${rect.height + 16}px;
      `;
      spotlight.appendChild(cutout);
      document.body.appendChild(spotlight);

      // Tooltip
      const tooltip = document.createElement("div");
      tooltip.className = "tour-tooltip";
      const isLast = this.currentIdx >= this.steps.length - 1;
      tooltip.innerHTML = `
        <h3>${step.title}</h3>
        <p>${step.body}</p>
        <div class="tour-actions">
          <div class="tour-progress">
            ${this.steps
              .map((_, i) => {
                let cls = "";
                if (i < this.currentIdx) cls = "done";
                if (i === this.currentIdx) cls = "active";
                return `<span class="dot ${cls}"></span>`;
              })
              .join("")}
          </div>
          <button data-tour-skip>Skip all</button>
          ${this.currentIdx > 0 ? '<button data-tour-prev>Back</button>' : ""}
          <button class="primary" data-tour-next>${isLast ? "Finish" : "Next"}</button>
        </div>
      `;
      document.body.appendChild(tooltip);

      // Position tooltip
      const tipH = tooltip.offsetHeight;
      const below = rect.bottom + tipH + 40 < window.innerHeight;
      tooltip.style.left = `${Math.max(16, rect.left)}px`;
      tooltip.style.top = below
        ? `${rect.bottom + 16}px`
        : `${rect.top - tipH - 16}px`;

      // Event handlers
      const cleanup = () => {
        spotlight.remove();
        tooltip.remove();
      };

      $("[data-tour-skip]", tooltip).addEventListener("click", () => {
        cleanup();
        this.dismissed = true;
        showToast("Tour dismissed", "You can restart from the golden path indicator.");
      });

      $("[data-tour-prev]", tooltip)?.addEventListener("click", () => {
        cleanup();
        this.currentIdx = Math.max(0, this.currentIdx - 1);
        this.showCurrent();
      });

      $("[data-tour-next]", tooltip).addEventListener("click", () => {
        cleanup();
        this.currentIdx++;
        if (this.currentIdx >= this.steps.length) {
          this.dismissed = true;
          showToast("Tour complete", "You've seen the full golden path.");
        } else {
          this.showCurrent();
        }
      });

      $(".cutout", spotlight).addEventListener("click", () => {
        cleanup();
        this.currentIdx++;
        if (this.currentIdx >= this.steps.length) {
          this.dismissed = true;
          showToast("Tour complete", "You've seen the full golden path.");
        } else {
          this.showCurrent();
        }
      });
    },

    dismiss() {
      $$(".tour-spotlight, .tour-tooltip").forEach((el) => el.remove());
    },
  };

  // =======================================================================
  // CAPABILITY MATRIX — Shared data model
  // =======================================================================

  const DIAGRAM_CAPABILITIES = {
    Flowchart: {
      visualEdit: true,
      codeEdit: true,
      aiGenerate: true,
      export: true,
      presentEmbed: true,
      comments: true,
      icon: "flow",
    },
    Sequence: {
      visualEdit: false,
      codeEdit: true,
      aiGenerate: true,
      export: true,
      presentEmbed: true,
      comments: true,
      icon: "seq",
    },
    "ER diagram": {
      visualEdit: false,
      codeEdit: true,
      aiGenerate: true,
      export: true,
      presentEmbed: true,
      comments: true,
      icon: "er",
    },
    State: {
      visualEdit: false,
      codeEdit: true,
      aiGenerate: true,
      export: true,
      presentEmbed: true,
      comments: true,
      icon: "state",
    },
    Gantt: {
      visualEdit: false,
      codeEdit: true,
      aiGenerate: true,
      export: true,
      presentEmbed: true,
      comments: false,
      icon: "gantt",
    },
    "Mind map": {
      visualEdit: false,
      codeEdit: true,
      aiGenerate: true,
      export: true,
      presentEmbed: false,
      comments: false,
      icon: "mind",
    },
    Class: {
      visualEdit: false,
      codeEdit: true,
      aiGenerate: true,
      export: true,
      presentEmbed: true,
      comments: false,
      icon: "class",
    },
    Journey: {
      visualEdit: false,
      codeEdit: true,
      aiGenerate: true,
      export: false,
      presentEmbed: false,
      comments: false,
      icon: "journey",
    },
  };

  function renderCapabilityMatrix(container, highlightType) {
    if (!container) return;
    const types = Object.keys(DIAGRAM_CAPABILITIES);
    const dims = ["visualEdit", "codeEdit", "aiGenerate", "export", "presentEmbed", "comments"];
    const dimLabels = ["Visual edit", "Code edit", "AI generate", "Export", "Deck embed", "Comments"];

    let html = '<table class="capability-matrix"><thead><tr><th>Type</th>';
    dimLabels.forEach((d) => (html += `<th>${d}</th>`));
    html += "</tr></thead><tbody>";

    types.forEach((type) => {
      const caps = DIAGRAM_CAPABILITIES[type];
      const isHighlighted = type === highlightType;
      html += `<tr${isHighlighted ? ' style="background:var(--accent-bg-2);"' : ""}>`;
      html += `<td class="icon-row"><span class="type-dot ${caps.icon}"></span>${type}</td>`;
      dims.forEach((dim) => {
        const val = caps[dim];
        const cls = val === true ? "cap-yes" : val === false ? "cap-no" : "cap-partial";
        const label = val === true ? "✓" : val === false ? "—" : "~";
        html += `<td class="${cls}">${label}</td>`;
      });
      html += "</tr>";
    });

    html += "</tbody></table>";
    container.innerHTML = html;
  }

  // =======================================================================
  // ENHANCED NEW DIAGRAM MODAL with capability matrix
  // =======================================================================

  const origOpenNewDiagram = openNewDiagramModal;

  openNewDiagramModal = function () {
    origOpenNewDiagram();

    // Add capability matrix below the type grid
    window.setTimeout(() => {
      const modal = $(".new-diagram-modal");
      if (!modal) return;

      const typeSection = $(".new-flow-section:first-child", modal);
      if (!typeSection) return;

      // Add capability note
      let capNote = document.createElement("div");
      capNote.className = "alert-info";
      capNote.style.cssText = "margin-top: 8px;";
      capNote.innerHTML =
        '<span class="icon">i</span><span><b>Capability matrix</b> — Only <b>Flowchart</b> supports full visual editing. All types support code editing and AI generation. <a style="cursor:pointer;" data-show-cap>See full matrix →</a></span>';
      typeSection.appendChild(capNote);

      // Wire up capability toggle
      $("[data-show-cap]", capNote).addEventListener("click", (e) => {
        e.preventDefault();
        const matrixContainer = $(".cap-matrix-container", modal);
        if (matrixContainer) {
          const visible = matrixContainer.style.display !== "none";
          matrixContainer.style.display = visible ? "none" : "block";
        }
      });

      // Add capability matrix container
      let matrixContainer = document.createElement("div");
      matrixContainer.className = "cap-matrix-container";
      matrixContainer.style.cssText = "margin-top: 8px; display: none; overflow-x: auto;";
      typeSection.appendChild(matrixContainer);

      const updateMatrix = () => {
        const activeType = $(".new-type.is-on", modal)?.dataset?.type;
        renderCapabilityMatrix(matrixContainer, activeType);
      };

      // Re-render on type change
      $$(".new-type", modal).forEach((btn) => {
        btn.addEventListener("click", () => window.setTimeout(updateMatrix));
      });

      updateMatrix();
    }, 100);

    // Hook golden path
    GOLDEN_PATH.markDone("new");
  };

  // =======================================================================
  // ENHANCED SOURCE SAFETY — Diff/Review/Restore
  // =======================================================================

  function openSourceDiffModal(beforeSource, afterSource, unsupportedLines) {
    const modal = document.createElement("div");
    modal.className = "source-review-modal";
    modal.setAttribute("role", "dialog");
    modal.setAttribute("aria-label", "Source diff review");

    const beforeLines = (beforeSource || "// no previous source").split("\n");
    const afterLines = (afterSource || "// no generated source").split("\n");

    modal.innerHTML = `
      <div class="prototype-modal-head">
        <div>
          <h2>Review source changes</h2>
          <p>Visual edits keep the diagram meaning but may restructure Mermaid source. Review before applying.</p>
        </div>
        <button class="prototype-close" aria-label="Close">×</button>
      </div>
      <div class="source-diff" style="padding: 16px 18px;">
        <div class="diff-pane">
          <div class="pane-label before">Before (last valid)</div>
          <div class="diff-body">${beforeLines
            .map((l) => `<span class="line-ctx">${escapeHtml(l)}</span>`)
            .join("\n")}</div>
        </div>
        <div class="diff-pane">
          <div class="pane-label after">After (will apply)</div>
          <div class="diff-body">${afterLines
            .map((l, i) => {
              if (unsupportedLines && unsupportedLines.includes(i + 1)) {
                return `<span class="line-unsupported">⚠ ${escapeHtml(l)}</span>`;
              }
              if (l.startsWith("+")) {
                return `<span class="line-add">${escapeHtml(l)}</span>`;
              }
              if (l.startsWith("-")) {
                return `<span class="line-del">${escapeHtml(l)}</span>`;
              }
              return `<span class="line-ctx">${escapeHtml(l)}</span>`;
            })
            .join("\n")}</div>
        </div>
      </div>
      ${
        unsupportedLines && unsupportedLines.length
          ? `<div class="alert-required" style="margin: 0 18px 12px;">
              <span class="icon">!</span>
              <div class="body">
                <span class="ttl">Unsupported syntax detected</span>
                <span class="desc"><b>${unsupportedLines.length} line(s)</b> contain syntax the visual editor cannot represent. These will be preserved in source but hidden from the canvas. <em>No data will be lost.</em></span>
              </div>
            </div>`
          : ""
      }
      <div class="new-flow-footer">
        <span class="summary">Source diff · unsupported syntax preserved</span>
        <div style="display: flex; gap: 8px;">
          <button class="btn" data-revert>Revert to last valid</button>
          <button class="btn primary" data-apply>Apply changes</button>
        </div>
      </div>
    `;

    const scrim = makeScrim(modal);
    focusFirst(scrim);

    $("[data-apply]", modal).addEventListener("click", () => {
      closeScrim(scrim);
      showToast("Source applied", "Visual and source are back in sync. Changes saved to history.");
      GOLDEN_PATH.markDone("visual");
    });

    $("[data-revert]", modal).addEventListener("click", () => {
      closeScrim(scrim);
      showToast("Source reverted", "Restored to the last valid source. Visual canvas unchanged.", "warn");
    });
  }

  function escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  // =======================================================================
  // PERMISSION PREVIEW — What will this person see?
  // =======================================================================

  function showPermissionPreview(email, role, isExternal) {
    const modal = document.createElement("div");
    modal.className = "new-diagram-modal";
    modal.setAttribute("role", "dialog");
    modal.innerHTML = `
      <div class="prototype-modal-head">
        <div>
          <h2>Permission preview</h2>
          <p>What <b>${email || "this collaborator"}</b> will see with <b>${role}</b> access.</p>
        </div>
        <button class="prototype-close" aria-label="Close">×</button>
      </div>
      <div style="padding: 16px 18px 18px;">
        <div class="perm-preview">
          <div class="head">
            <span class="av ${isExternal ? 'rose' : 'violet'}">${(email || "?")[0].toUpperCase()}</span>
            <span class="ttl">${email || "new.collaborator@engineering.dev"}</span>
            <span class="role">${role}</span>
          </div>
          <div class="checks">
            <div class="check">
              <span class="ic ${role === 'Editor' ? 'allowed' : role === 'Commenter' ? 'limited' : 'denied'}">${role === 'Editor' ? '✓' : role === 'Commenter' ? '~' : '×'}</span>
              <span><b>Edit source</b> — ${role === 'Editor' ? 'Can modify Mermaid source and save changes.' : role === 'Commenter' ? 'View-only. Cannot modify.' : 'No access.'}</span>
            </div>
            <div class="check">
              <span class="ic ${role !== 'Viewer' ? 'allowed' : 'denied'}">${role !== 'Viewer' ? '✓' : '×'}</span>
              <span><b>Add comments</b> — ${role !== 'Viewer' ? 'Can comment and @mention.' : 'Cannot comment.'}</span>
            </div>
            <div class="check">
              <span class="ic allowed">✓</span>
              <span><b>View rendered diagram</b> — Rendered output is always visible.</span>
            </div>
            <div class="check">
              <span class="ic ${role === 'Editor' ? 'allowed' : 'denied'}">${role === 'Editor' ? '✓' : '×'}</span>
              <span><b>View Mermaid source</b> — ${role === 'Editor' ? 'Full source access.' : 'Source is hidden in SVG mode, visible in Editor mode if link type allows.'}</span>
            </div>
            <div class="check">
              <span class="ic ${role === 'Editor' ? 'allowed' : 'denied'}">${role === 'Editor' ? '✓' : '×'}</span>
              <span><b>Export diagrams</b> — ${role === 'Editor' ? 'Can export PNG, SVG, MMD.' : 'Export blocked.'}</span>
            </div>
            <div class="check">
              <span class="ic ${!isExternal ? 'allowed' : 'limited'}">${!isExternal ? '✓' : '~'}</span>
              <span><b>${isExternal ? 'External access' : 'Internal workspace'}</b> — ${isExternal ? 'Requires sign-in. Link expires per workspace policy.' : 'Full workspace member access.'}</span>
            </div>
            <div class="check">
              <span class="ic ${isExternal ? 'denied' : 'allowed'}">${isExternal ? '×' : '✓'}</span>
              <span><b>See other collaborators</b> — ${isExternal ? 'Hidden for external viewers.' : 'Visible to workspace members.'}</span>
            </div>
          </div>
        </div>
      </div>
      <div class="new-flow-footer">
        <span class="summary">Permissions are enforced across all modes: Code, Visual, AI, Present.</span>
        <button class="btn primary" data-close>Got it</button>
      </div>
    `;
    const scrim = makeScrim(modal);
    $("[data-close]", modal).addEventListener("click", () => closeScrim(scrim));
    focusFirst(scrim);
  }

  // =======================================================================
  // VISUAL EDITOR — Enhanced state model
  // =======================================================================

  function initVisualEditorStateModel() {
    const root = $(".ve-grid");
    if (!root) return;

    const inspector = $(".insp", root);
    if (!inspector) return;

    const states = ["canvas", "node", "edge", "multi", "unsupported"];

    // Add state classes to inspector
    inspector.classList.add("insp-state-node"); // Default: node selected

    // Add state-switching event listeners
    // Click on empty canvas area
    $(".canvas-wrap", root)?.addEventListener("click", (e) => {
      if (e.target.closest(".vn-rect, .vn-edge, .ctx-toolbar, .ctx-menu, .label-edit")) return;
      setInspectorState("canvas");
    });

    // Click on nodes
    $$(".vn-rect", root).forEach((node) => {
      node.addEventListener("click", (e) => {
        e.stopPropagation();
        setInspectorState("node");
        updateInspectorForNode(node);
      });
    });

    // Add edge selection simulation
    $$(".vn-edge", root).forEach((edge) => {
      edge.addEventListener("click", (e) => {
        e.stopPropagation();
        setInspectorState("edge");
      });
    });
  }

  function setInspectorState(state) {
    const inspector = $(".ve-grid .insp");
    if (!inspector) return;
    ["canvas", "node", "edge", "multi", "unsupported"].forEach((s) => {
      inspector.classList.remove(`insp-state-${s}`);
    });
    inspector.classList.add(`insp-state-${state}`);

    // Update inspector header
    const tag = $(".insp-head .tag", inspector);
    const h2 = $(".insp-head h2", inspector);
    const meta = $(".insp-head .meta", inspector);

    switch (state) {
      case "canvas":
        if (tag) tag.textContent = "Selected · canvas";
        if (h2) h2.textContent = "Diagram";
        if (meta) meta.innerHTML = 'flowchart TD · <span class="v">24 nodes · 31 edges</span>';
        break;
      case "node":
        if (tag) tag.textContent = "Selected · node";
        if (h2) h2.textContent = "Build & cache deps";
        if (meta) meta.innerHTML = '<span class="v">Build</span> · flowchart node · subgraph: CI Pipeline';
        break;
      case "edge":
        if (tag) tag.textContent = "Selected · edge";
        if (h2) h2.textContent = "Build → Test";
        if (meta) meta.innerHTML = 'arrow · solid · <span class="v">labeled</span>';
        break;
      case "multi":
        if (tag) tag.textContent = "Selected · 3 nodes";
        if (h2) h2.textContent = "Multiple selection";
        if (meta) meta.innerHTML = '<span class="v">Build, Test, Lint</span> · bulk actions available';
        break;
      case "unsupported":
        if (tag) tag.textContent = "⚠ Unsupported syntax";
        if (h2) h2.textContent = "Code-only region";
        if (meta) meta.innerHTML = '<span class="v">3 lines</span> · preserved in source · hidden on canvas';
        break;
    }
  }

  function updateInspectorForNode(node) {
    // Read label from the node's SVG text
    const textEl = node.closest("g")?.querySelector(".vn-text");
    if (textEl) {
      const label = textEl.textContent.trim();
      const h2 = $(".ve-grid .insp-head h2");
      if (h2) h2.textContent = label;
    }
  }

  // =======================================================================
  // INIT HOOKS — Wire up golden path on every page
  // =======================================================================

  function initGoldenPathHooks() {
    GOLDEN_PATH.autoDetect();
    GOLDEN_PATH.initIndicator();

    // Listen for Present button
    document.addEventListener("click", (e) => {
      if (e.target.closest('button:contains("Present"), .tb-btn.primary:contains("Present")')) {
        window.setTimeout(() => {
          if ($(".presenter-overlay:not(.is-hidden)")) {
            GOLDEN_PATH.markDone("present");
          }
        }, 500);
      }
    });
  }

  function initGuidedTourTrigger() {
    // Start tour on first visit or from golden path indicator
    if (!GOLDEN_PATH.isActive() && page === "index.html") {
      window.setTimeout(() => {
        if (!sessionStorage.getItem("dk_tour_seen")) {
          sessionStorage.setItem("dk_tour_seen", "1");
          GUIDED_TOUR.start();
        }
      }, 800);
    }
  }

  // Wire permission preview into share dialog
  function initPermissionPreviewHooks() {
    const root = $(".share-card");
    if (!root) return;

    $$(".collab-row", root).forEach((row) => {
      row.addEventListener("click", (e) => {
        if (e.target.closest("button, .more")) return;
        const name = $(".who .name", row)?.textContent?.trim() || "Collaborator";
        const roleEl = $(".role", row);
        const role = roleEl?.textContent?.replace("▾", "").trim() || "Viewer";
        const isExternal = row.classList.contains("pending") || name.includes("external") || name.includes("partner");
        showPermissionPreview(name, role, isExternal);
      });
    });

    // Wire existing permission preview to collab rows
    $$(".collab-row .av, .collab-row .who", root).forEach((el) => {
      el.style.cursor = "pointer";
      el.title = "Click to see permission preview";
    });
  }

  // =======================================================================
  // DOM READY — Master init
  // =======================================================================

  document.addEventListener("DOMContentLoaded", () => {
    initAccessibilityLabels();
    initCommandPalette();
    initNewDiagramFlow();
    initLibraryFilters();
    initActivityFilters();
    initVisualEditor();
    initAiStudio();
    initAiComposer();
    initShareDialog();
    initPresentationMode();
    initSettingsFeedback();
    initGenericActionFeedback();

    // v3 enhancements
    initGoldenPathHooks();
    initGuidedTourTrigger();
    initVisualEditorStateModel();
    initPermissionPreviewHooks();
  });

  window.prototypeDemo = {
    showToast,
    openNewDiagramModal,
    goldenPath: GOLDEN_PATH,
    guidedTour: GUIDED_TOUR,
    showPermissionPreview,
    openSourceDiffModal,
    renderCapabilityMatrix,
  };
})();
