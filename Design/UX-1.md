# Mermaid UX Review

Before diving in screen by screen, a quick map of the cross-cutting patterns I see, because most of what's worth fixing here is system-level rather than screen-local.

## The big cross-cutting issues

**The title bar formula keeps swapping arguments.** You're using `{X} — {Y}` everywhere, but X and Y mean different things:

- Document views: `{filename} — {workstation}` ("pr-lifecycle.mmd — Playground")
- Workspace views: `{workstation} — {workspace}` ("Library — Engineering")
- Modal/action: `{filename} — {action}` ("auth-flow.mmd — Share")
- Settings: just `Settings`, no second term

Three different grammars for what looks like one pattern. Pick one rule and apply it. My recommendation: always `{context} — {scope/mode}`, where context is the thing you're operating on (file, workspace, or "Workspace" if global), and scope is where you are in the app. So Settings becomes "Engineering — Settings", which also fixes the disorientation of a totally context-free Settings page.

**The "switch the representation" tabs live in three different places.** This is the biggest navigation inconsistency, and you flagged it:

- Playground: `Code | Config | Inspector` — inside the center column header
- Visual editor: `Visual | Split | Code` — in the breadcrumb row
- Presentations: `Outline | Edit | Source` — in the top toolbar

These are all doing the same job: toggle between views of the same artifact. They should sit in the same slot in the same affordance across all three editors. The breadcrumb row is the strongest candidate because it's where the user looks when establishing "where am I" — but wherever you put it, put it in the same spot every time. Also, the labels are inconsistent in meaning: "Code" in Playground means Mermaid source, "Code" in Visual editor means the same Mermaid source, but "Source" in Presentations means deck markdown. Consider standardizing on `Source` everywhere for raw text and reserving `Code` for things that are actually code.

**"Studio" is overloaded.** You have a plan called Studio, a workstation called "AI studio", a panel called "Studio" (right side of Playground), an assistant called "Studio assistant" (Presentations), and an actor called "Studio AI" (Activity). Settings calls out "Studio plan feature" pills. A user can't tell whether Studio refers to their plan, their AI, or a workspace concept. Rename at least one of these — easiest fix is to call the plan something else (Pro, Team) and let "Studio" mean the AI surface consistently.

**The "Render" / primary CTA semantics are unclear.** Playground and Visual editor both have a Render button top-right, but the diagram is already rendered in the preview with `Auto · 312ms`. If Render = re-render, you don't need it (auto handles it). If it means "publish" or "commit version", call it that. The fact that the button is the most prominent UI element on each screen and I can't tell what it does is a problem.

**Status pills mix state with counts.** Top-center pills like "Synced", "Co-editing · live", "1 stale diagram", "47 diagrams", "12 events · 3 unread", "Auto-saved · 2s" all share the same visual treatment, but some are states (good/bad), some are counts (neutral), and some are warnings. Either visually differentiate them (state pills get a dot, count pills don't) or consolidate to one meaning. The "1 stale diagram" pill in Presentations is correctly orange — that pattern should extend to all warning-state pills.

Now the per-screen feedback.

---

## Screen 1 — Home

The greeting + "pick a workstation" framing is good. It tells the user this app has multiple modes and helps them feel oriented. The four workstation cards with ⌘1–⌘4 keyboard hints are excellent — that's a learnability win.

A few things to reconsider. The action row (`+ New blank diagram | + From AI | Visual editor | From sample | Import…`) duplicates the workstation cards underneath. "Visual editor" is both a button at the top and a card below. "From AI" maps roughly to "AI studio" but isn't called the same thing. Either remove the action row, or make it clearly different (e.g., "Quick actions: New blank, From AI, From sample, Import" without the redundant "Visual editor" entry).

The "Recent" list and "This week" + "Updates" stack on the right are doing a lot of work for a Home screen. They're useful but visually they compete with the workstation cards — which are supposed to be the primary CTA. Consider whether the workstation cards should be more prominent (larger, more visual) and the Recent/Updates collapsed into a single stream or tucked below the fold. Right now my eye doesn't know whether to pick a workstation or open a recent file.

The status pills on Recent items (Live / Shared / Stale / Snapshot) are great signal — but make sure these terms are used consistently elsewhere. In Library the filter chips are `Live | Stale | AI | Comments | In deck` — so "Shared" and "Snapshot" don't appear there. Unify the vocabulary.

One thing I really like: the "AI credits 32/50" with the progress bar in the "This week" card. That's concrete and useful. Don't lose it.

---

## Screen 2 — Playground

The information density here is high but workable. The three-pane layout (Catalog | Editor + Preview | Studio) is clear. Some observations:

The **stat strip above the code** (`Rendered · 312ms | 24 nodes | 31 edges | 3 subgraphs | flowchart TD | 1 warning — L7: unlabeled feedback edge`) is excellent — it gives the user signal without taking much space. The warning chip at the right is the right pattern. Only nitpick: the warning text wraps awkwardly inside its column. Either truncate with hover, or move warnings to a popover triggered by the warning badge.

The Catalog rail on the left has both "Recent" and "Catalog" sections with the same item types. The visual distinction is weak — same row treatment, same chevrons. Consider stronger differentiation: Recent could be horizontally scrolling thumbnails at the top, leaving the vertical rail for the full Catalog tree. Or use a visual indicator (a dot, a clock icon) for recents within a unified list.

The **tabs `Code | Config | Inspector`** inside the editor column conflict with the Visual editor's tab placement (see cross-cutting note above). They should move to the breadcrumb row or to a consistent slot.

The right "Studio" panel header (`theme · export · history`) reads like sub-navigation but it's actually three stacked sections in the same panel. That's confusing because in other screens those words would be tabs. If they're sections, treat them as section headers within the panel; if they're filters/jumps, make that interaction clear.

The bottom status bar (`L 14 · C 12 | UTF-8 · LF · 714 B · 19 lines`) is a nice VSCode-esque touch and well-aligned with the developer audience. Worth keeping.

---

## Screen 3 — Visual editor

The floating toolbar above the selection (`Shape | Fill | Stroke | Label | Dupe | Delete`) is a strong pattern. Good context-sensitivity.

The bottom of this screen is the busiest part of the review. You have **two stacked banners**:
1. "NOTE: Visual edits may reformat your Mermaid source. Preview source changes before applying."
2. "Source will be modified — Visual edits restructure Mermaid source. Semantic meaning preserved · whitespace normalized. [Review diff] [Apply]"

These say essentially the same thing twice. Merge them. The lower one with action buttons is the one that matters; promote it and remove the dismissible-looking NOTE above.

The right-panel "Limitations" card ("Sequence, Class, ER, and 24 other types are code-edit + preview only. See plan →") is a great honesty pattern, but it's buried at the bottom of a long panel. If the user is currently editing a flowchart they don't need to see it. Consider only showing it when they try to visually edit an unsupported type — turn it from passive disclosure into a just-in-time message.

The `Visual | Split | Code` tab strip and the breadcrumb share a row. That's fine, but the visual hierarchy gives them equal weight when the tabs are far more important (they're a mode switch; the breadcrumb is just location). Make the tabs more prominent or move the breadcrumb above them.

The shapes/connect/layout/tools rail on the left is well-organized but the "Connect" section's four empty boxes are mysterious — those look like placeholders or broken icons. If they're connector styles, the iconography needs to be clearer.

The "14 / 28 edits" pill in the top right — what's the 28? Total possible edits? Edit limit? If it's a quota, surface that. If it's session edits / total session, the labels need to clarify.

---

## Screen 4 — Presentations

The deck outline on the left with slide thumbnails is the right pattern — matches Keynote/Slides mental models.

The **stale diagram review queue** at the top of the canvas is genuinely impressive UX. Surfacing the divergence inline, with `Compare old/new | Accept update | Keep snapshot | Update all deck refs` is exactly the right set of choices. The fact that there's also a top-bar "1 stale diagram — Review changes →" link means the user can find this from two places. Good.

A few issues:

The tab strip `Outline | Edit | Source` in the top toolbar is in a different position from the same concept in Playground and Visual editor. As noted, unify.

The right panel is doing a lot: Speaker notes, Linked diagrams, Studio assistant, Deck theme. Each is useful but the panel is roughly 350+ px of vertical-scrolling sections. Consider whether Deck theme belongs there or in a deck-level settings drawer (you'd only set it once). The Studio assistant action chips (`Generate speaker notes | Convert diagram → bullets | Summarize for title slide`) are excellent and discoverable — those should stay prominent.

The slide content area shows both prose (`The SDK terminates traffic at the edge gateway...`) and a live linked diagram side by side. Good. But the "Service boundary · Live" header on the diagram card vs. the slide title "Where authentication lives" creates two competing headers for one slide. Consider whether the diagram needs its own caption when the slide already has a title.

"SLIDE 4 OF 12" appears in the slide canvas, and the same info repeats in the bottom pagination. Pick one.

---

## Screen 5 — Library

This is your strongest screen. The grid of diagram cards with type pills (FLOW / SEQ / STATE / GANTT / ER / MIND / CLASS / JOURNEY) and status badges (LIVE / STALE / + AI) gives you immediate scannability. The right-panel "Open in" grid (Visual / Code / AI refine / Add to deck) makes the next action obvious without forcing a click-through.

A few things to refine:

The **filter rail** has three sections: Views (saved queries), Folders (location), Type (filter), Status (filter). They're visually similar but they behave differently — Views/Folders are mutually exclusive (you pick one location to browse), while Type and Status compose. Consider visually separating "where to look" from "what to filter" — for example, put Views and Folders in a top stack that acts as a tree picker, and put Type and Status as filter chips above the grid (not in the rail). Right now you have 12 diagrams in Architecture but the type/status chips suggest you can filter further, and it's unclear whether they apply globally or to the current folder.

Card color coding: Flow is blue on `Pull-Request Lifecycle` but pink on `Incident escalation flow`. If color encodes type, it should be consistent. If it encodes something else (status? team?), make that legible. Right now it looks decorative-but-meaningful, which is the worst of both worlds.

The "9 shown 9 shown" duplicated stat (top right of grid) is a typo or rendering issue.

The right panel's "Sharing & collaborators" section is rich (owner, editor, commenter, viewer, pending) with great avatar-state combinations. Keep this. It's the best collaborator UI in the whole app.

"Used in decks" at the very bottom is valuable for understanding diagram impact ("if I edit this, what breaks?"). Promote it higher in the panel — it's currently below sharing which is below properties which is below open-in.

---

## Screen 6 — Activity

The feed pattern works. Each event card has a clear actor + verb + object structure, with relevant inline preview (the comment text, the diff block, the share invite). Good.

The "+ alt MFA required (optional)" / "−Token → Auth: tokens" diff block is a particularly nice touch — showing the AI's actual change inline rather than a generic "AI refined" message. Lots of products would lose courage and hide this.

Issues:

The right panel is again very heavy. Notifications, Decision support, Details, Actions, Related diff, Audit log — six sections. The Notifications block at the top (3 unread items) looks like it should be a global inbox, not a per-event panel. Consider moving Notifications out — into the top-right "Notifications" button you already have — and let the right panel focus on the selected event.

The "Mark all read" button in the top toolbar competes with the right-panel "Mark as read" button. Pick one and let the other be derivative.

The Scope rail (`This diagram | All workspace | Involving me | Audit log`) is good but "Audit log" feels like a different beast — it's admin-only ("admin" tag) and probably routes to a different page treatment. Either move it out of Scope, or visually demote it.

The "2 new events arrived while you were scrolled away — jump to top" banner is a great real-time pattern. Keep it.

Why is the primary CTA "Notifications"? That's odd. Notifications is a place, not an action. If the user is already on the Activity page, having a Notifications button as the primary action is circular. Consider what the real primary action is — perhaps it's "Mark all read", or perhaps Activity simply doesn't need a primary CTA.

---

## Screen 7 — Settings

The structure is sound: Personal → Diagram defaults → Workspace → Plan → Advanced, with clear admin/billing/etc. tags on each. The "ADMIN · affects all of Engineering" callout at the top of the page is exactly the kind of safety messaging that should appear before destructive scope changes.

Problems:

The page title is just "Settings" with no scope. Per the cross-cutting note: "Engineering — Settings" would orient the user immediately.

The right panel has Scope, Save state, Plan & usage, Help. Plan & usage in particular is information-dense (AI 32/50, Diagrams 47/100, Workspaces 2/5, Co-editors 4/10, External shares 2 · enabled) and arguably more important than the actual settings content for users who are trying to figure out why something is gated. Consider whether Plan & usage should be its own primary settings section (left rail) rather than a contextual right panel.

The "Save state · Auto-saved · 2s ago" with a Revert changes button conflicts with the top-bar "Auto-saved · 2s" and "Reset" — three places telling me about save state. Consolidate.

The Sharing & permissions content itself is clean. The toggle + explanatory paragraph pattern is good. The "External sharing" segmented control (Off | Allow-listed | Any domain) with the approved-domains chip list below is well-thought-out and matches how enterprise admins actually think.

One nit: "Allow diagram-specific permission overrides" is a really important setting (it determines whether owners can override workspace defaults). Consider giving it more emphasis or grouping it with related per-diagram concerns.

---

## Screen 8 — Share dialog

This is presented as a modal but the top bar shows "auth-flow.mmd — Share" and a "Back to library" button, which makes it feel like a dedicated page. Decide which it is. If it's a modal:

- The page title shouldn't change
- "Back to library" should be an X or "Done" button
- The dimmed background is appropriate

If it's a page:

- Drop the modal framing
- Use a full-width layout
- "Back to library" is fine

Right now it's both, which is disorienting — the user can't predict where they'll land when they close it.

Content-wise this is very good. The split between "Invite collaborators" and "Share with a link" is the right primary axis. The link cards (Diagram link / SVG link) with permission-aware settings (Permission · Viewer, Destination · Editor, requires Sign-in, expires 7 days) are some of the best link-sharing UI I've seen — most products just give you a URL with no granularity.

The "External sharing in progress" warning at the bottom-left ("rajiv@partner-co.io is outside Engineering. Workspace policy: partner-co.io matches the allowlist. [Confirm external share]") is excellent safety UX. You're showing the user exactly which person triggers the external-sharing rule and confirming the policy decision. Don't lose this.

A few issues:

The "Studio feature enabled" callout overlaps with the "+ Studio plan · full editing + external sharing" upsell pill at the bottom. The first says I have Studio; the second pitches me Studio. If I'm already on Studio, the second shouldn't appear. (Or it should say "Upgrade to Team for SSO" or whatever the next tier is.)

"Engineering · workspace policy — SSO required · external sharing allowed for 2 [domains]" — the truncated text + Review button is a nice compact pattern, but it appears at the bottom of a long modal and is easy to miss. Consider surfacing the policy state earlier — perhaps as a small chip near the top of the modal so the user knows the rules before they start inviting.

The "People with access" section shows "Click a collaborator to see what they can access" but only one collaborator (Alex Chen — You) is visible in the screenshot. If there are 4 collaborators and 1 pending, that should all be scannable without scrolling.

---

## Priority recommendations

If I were going to fix this in order of impact:

1. **Unify the mode-switching tabs** (Code/Visual/Source) across Playground, Visual editor, and Presentations. One position, one vocabulary.
2. **Resolve the "Studio" naming conflict**. Pick whether Studio means the plan, the AI, or a panel — and rename the others.
3. **Standardize the page title formula**. Apply one grammar everywhere, including Settings.
4. **Clarify the Render button** semantics, or remove it if Auto-render already does the job.
5. **De-duplicate save-state messaging** (top bar + right panel + auto-save indicator all saying the same thing).
6. **Modal vs. page disambiguation** for the Share dialog and any other overlay flows.
7. **Right-panel consistency**. "Selected · {type}" → "{name}" is a good pattern; apply it to Playground (currently "Studio") and Presentations (currently "Notes").

Happy to dig deeper into any of these or sketch out alternative layouts for the most problematic screens.
