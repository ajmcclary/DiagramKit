Overall assessment

The visual system is strong: spacing, rounded panels, subtle borders, soft status colors, and the lavender accent all feel cohesive. The product already reads like a polished desktop-grade SaaS app.

The biggest UX issue is not visual polish. It is navigation semantics: the same concepts appear as workstations, editor modes, pane tabs, right-rail sections, cards, and “Open in…” actions depending on the screen. Users will learn the product faster if each navigation layer has a single job.

The core consistency problem I see:

Playground, Visual editor, AI studio, Code, Source, Preview, Inspector, Studio, Presentations, Decks, and Add to deck are all related, but they behave like different navigation systems.

I would define one clear model:

Recommended navigation model

Global left nav: where am I in the product?
Home, Library, Activity, Presentations, Settings.

Diagram editor modes: how am I editing this diagram?
Source, Visual, Split, AI refine.

Presentation editor modes: how am I editing this deck?
Slides, Outline, Source, Present.

Pane layout: what am I looking at inside the current workspace?
Left = navigator/catalog, center = work area, right = inspector/assistant/details.

Right rail: what can I do with the selected thing?
Properties, Comments, History, Export, Assistant, Notes.

Right now, those layers overlap. For example, Visual editor is both a global workstation and an “Open in” action. Code appears as a mode in one place, while Source appears elsewhere. Studio means an AI/workflow panel in one place, a plan name in another, and an AI actor in Activity.

My strongest recommendation: consider consolidating Playground + Visual editor + AI studio into one “Diagram editor” destination, with mode tabs inside it: Source, Visual, Split, AI refine. That would immediately reduce much of the navigation inconsistency.

⸻

Global consistency recommendations

1. Standardize the page header

Every object-level screen should have the same header structure:

Breadcrumb / object title / status / collaborators / actions

Example pattern:

Library › Architecture › Pull-request lifecycle.mmd
Source | Visual | Split | AI refine
Right side: Saved · Auto render · 4 collaborators · Share · Export · Render/Present

Currently:

* Playground has Code / Config / Inspector tabs above the editor pane.
* Visual editor has Visual / Split / Code near the breadcrumb.
* Presentations has Outline / Edit / Source in the top bar.
* Library uses “Open in” cards in the right rail.
* Share is a modal with no comparable mode model.

A consistent rule would help:

* Top mode tabs switch the whole workspace.
* Pane tabs switch only the current pane.
* Right rail tabs switch contextual tools.

2. Pick one term: Code or Source

You currently use both:

* Playground: Code
* Visual editor: Code
* Presentations: Source
* Bottom bar: SOURCE › deck.md
* Visual editor: “Source will be modified”
* Right rail: “Source preview”

I would use Source everywhere for Mermaid text and Markdown-backed deck content. “Code” is understandable, but “Source” better matches the authoring model and avoids implying general programming code.

Recommended labels:

* Source editor, not Code editor
* Source, not Code
* Source preview, keep as-is
* Review source diff, not Review diff when source is affected

3. Rename or reposition “Playground”

The Playground screen looks like a serious production editor with library navigation, sharing, export, saved state, and history. “Playground” sounds experimental or temporary.

Possible alternatives:

* Source editor
* Diagram editor
* Mermaid editor
* Editor

If you keep “Playground,” reserve it for experiments, samples, and scratch diagrams. Production files should open in a more permanent-sounding editor.

4. Clarify “Studio”

“Studio” appears in several meanings:

* AI studio in left nav
* Studio panel in Playground
* Studio assistant in Presentations
* Studio plan in Settings and Share
* Studio AI actor in Activity

That is a lot of conceptual load.

I would use:

* AI studio for the global AI destination.
* Assistant for contextual AI panels.
* Plan: Studio when referring to the subscription tier.
* AI assistant or AI studio as the activity actor, but not “Studio AI.”

5. Separate status types visually and semantically

The UI uses many chips: Live, Shared, Stale, Snapshot, AI, External, Pending, Rendered, Auto, Saved, Co-editing, etc. These are useful, but they mix different categories.

I would define separate chip families:

Document state: Saved, Unsaved, Auto-saved, Rendered, Warning
Sync state: Live, Stale, Snapshot
Sharing state: Private, Shared, External, Pending
Content type: Flow, Sequence, ER, Gantt, State
AI state: AI-generated, AI-refined, Restorable

This would make the chips easier to scan and prevent “Live” from meaning slightly different things in Library, Presentations, embedded diagrams, and share links.

6. Standardize the right rail

The right rail is one of your strongest patterns, but it changes identity per screen:

* Playground: Studio
* Visual editor: Selected node inspector
* Presentations: Notes
* Library: Selected diagram
* Activity: Selected event
* Settings: Scope / Save state / Plan / Help
* Share: Links / policy / plan information

This is okay, but the structure should feel the same. I would standardize the rail header and tabs:

Inspector for selected canvas/object properties.
Details for selected diagram/event metadata.
Assistant for AI help.
History for versions and changes.
Export for output controls.
Notes for presentation-specific speaker notes.

The rail can have different content by workspace, but the component anatomy should be consistent.

⸻

Screen-by-screen review

⸻

1. Home

What works well

This is a strong landing screen. It gives users a clear sense that the app has multiple work areas, recent files, activity, usage, and updates. The visual hierarchy is approachable, and the workstation cards are easy to scan.

The “Recent” list is particularly useful because it gives status, file name, diagram type, and recency without needing to open the Library.

Main UX issues

The biggest issue is that Home treats workstations as the main way to enter the app, while other screens treat files, diagrams, decks, and workspace objects as the main entities. The title “pick a workstation” frames the product around internal modes instead of the user’s goals.

The CTA row also mixes creation actions and navigation actions:

* New blank diagram
* From AI
* Visual editor
* From sample
* Import…

“Visual editor” is not the same kind of action as the others. It is a destination/mode, not a creation source.

The left nav already lists the same workstations, so the four large cards duplicate the primary nav. That is acceptable for onboarding, but it may feel repetitive once users are familiar with the app.

Recommendations

Change the page from “pick a workstation” to “start or resume work.”

A possible title:

Good afternoon — what would you like to create?

Or:

Good afternoon — start a diagram or open recent work.

Standardize the CTA row:

* New diagram
* Generate with AI
* Import Mermaid
* From template
* Open recent

Then the workstation cards can become secondary: “Ways to work” or “Editors.”

I would also rename or clarify Playground. On the Home screen, “Playground” sounds less professional than the rest of the app. If it is the code/source editor, call it Source editor.

Recent items are good, but the statuses need clearer grouping. For example, Live, Shared, Stale, and Snapshot are not equivalent states. I would separate them into columns or chip positions: one chip for sync state, one for sharing state.

⸻

2. Playground / Source editing screen

What works well

The core layout is strong: catalog on the left, source editor in the middle, preview on the right, and tools/history in the far-right rail. This is a natural layout for Mermaid authoring.

The render status is useful. Showing Rendered · 312ms, node count, edge count, subgraph count, and warning count gives technical users helpful confidence.

The right rail with theme, export, and history is useful and relevant.

Main UX issues

The largest inconsistency is the tab placement and meaning.

You have Code / Config / Inspector as tabs above the source editor, but Preview is a separate pane title and Studio is a separate right rail. In the Visual editor, however, Visual / Split / Code are global mode tabs. In Presentations, Outline / Edit / Source are top-level modes.

This means tabs sometimes switch the whole workspace, sometimes switch only a pane, and sometimes represent tools.

The word Inspector is also inconsistent here. In the Visual editor, the inspector is the right-side properties panel for a selected node. In Playground, Inspector appears as a tab near the source editor.

The preview also feels underutilized: the rendered diagram is tiny within a large grid area. That may be technically correct because of bounds, but the default user experience should probably be “fit to visible area.”

Recommendations

Rename this screen from Playground to Source editor if it is used for production files.

Move the primary editor mode switch to the same place as the Visual editor:

Source | Visual | Split | AI refine

Then use pane-level tabs only for local concerns:

* Source pane: Mermaid, Config
* Right rail: Inspector, Theme, Export, History, Assistant

I would avoid Code / Config / Inspector as equal tabs. Code and Config are source-authoring concepts; Inspector is contextual object metadata. They should not sit at the same level.

The Preview pane should use the same canvas toolbar as the Visual editor: zoom, fit, grid, pan, and perhaps “open full preview.” Default to Fit rather than a small centered rendering.

Also, CG & SVG · 1x is hard to parse. Consider a more explicit control:

Renderer: SVG · Scale: 1x

or place those settings in the Export/Preview toolbar with tooltips.

⸻

3. Visual editor

What works well

This is one of the strongest screens. The layout is clear, the selected node state is obvious, the left tool palette is understandable, and the right inspector provides useful detail. The canvas interactions feel credible.

The source preview in the right rail is excellent because it reassures users that visual edits are still Mermaid-backed.

The selected-node floating toolbar is also useful. It gives fast access to common actions without forcing users to move to the right rail every time.

Main UX issues

The Visual / Split / Code mode switch is good, but it is inconsistent with the Playground screen’s Code / Config / Inspector and Presentations’ Outline / Edit / Source.

I would also change Code to Source.

There is too much warning UI at the bottom. The canvas has an orange note saying visual edits may reformat Mermaid source, and then a second bottom bar says “Source will be modified” with Review diff and Apply. These communicate related things but occupy separate layers.

The bottom warning/action bar also competes with the canvas. It is important, but it feels like a persistent modal footer rather than an editor state.

The right rail title says Selected · node, which is good. However, the floating toolbar has Shape, Fill, Stroke, Label, Dupe, Delete, while the right rail also has Shape and Style controls. This is not wrong, but the division of responsibility should be explicit: floating toolbar = quick actions; inspector = full properties.

Recommendations

Use the same mode switch pattern everywhere:

Source | Visual | Split | AI refine

Put it in the object header or directly below the breadcrumb, always in the same position.

Replace the two bottom notices with one consistent source change review bar:

Visual edits will update Mermaid source
Review source diff Apply changes

Use a lower-intensity info banner for general limitations, and reserve the bottom bar for actual pending changes.

The Limitations card in the right rail is helpful, but it may be too late for users who open unsupported diagram types. If some diagram types are code-only, surface that at the top of the workspace before users enter Visual mode.

The left toolbar is strong, but some labels are cryptic: TD, LR, RL, BT. Those are Mermaid-native, so they make sense for expert users, but add tooltips like “Top down,” “Left to right,” etc.

The canvas toolbar should match the Playground preview toolbar. Same icons, same placement, same order.

⸻

4. Presentations editor

What works well

This screen communicates a lot effectively: slide outline, current slide, linked diagrams, notes, stale diagram review, deck source, and presentation actions. The embedded diagram concept is clear, and the stale linked diagram banner is useful.

The right rail is especially valuable here. Speaker notes, linked diagrams, and AI assistance are all contextually relevant.

Main UX issues

There are too many navigation systems active at once:

* Top mode tabs: Outline / Edit / Source
* Left slide outline
* Bottom slide thumbnail strip
* Right linked diagram list
* Bottom source drawer
* Stale diagram review queue
* Breadcrumbs and top actions

The biggest naming issue is that Outline appears both as a top-level mode and as the left panel title. If the user is already seeing an outline in Edit mode, what does the Outline tab do differently?

Source also appears as a top mode and as a bottom collapsed drawer. That creates uncertainty: is Source a full mode or a drawer?

There is also some terminology drift: the left nav says Presentations, the breadcrumb says Decks, the page title says SDK Auth · Q2 review, and elsewhere you say Add to deck.

Recommendations

Define a cleaner Presentation Editor structure:

* Left: slide navigator / outline
* Center: slide canvas
* Right: notes / linked diagrams / assistant / theme
* Top mode switch: Slides | Outline | Source
* Primary action: Present

If Outline is a mode, the left panel should change significantly when selected. If the left panel is always an outline, then the top tab should not be called Outline. Consider:

Edit | Source | Preview

or:

Slides | Source | Present

I would remove either the left slide outline or the bottom thumbnail strip as a default. Having both is redundant. A good compromise: keep the left outline as the primary navigator and use the bottom strip only when the left panel is collapsed or when presenting/reordering.

The stale linked diagram banner is good, but make it part of a consistent system used across Library and Activity. The status could say:

1 linked diagram needs review

Actions:

Compare changes Accept update Keep snapshot

The right rail should probably use tabs:

Notes | Diagrams | Assistant | Theme

Right now those are stacked sections, which works, but it becomes long and requires scrolling.

⸻

5. Library

What works well

The Library screen is very strong. It has a clear collection layout, useful filters, good card previews, a right-side detail panel, and strong object-level actions.

The selected diagram panel gives the user exactly what they need: ownership, type, folder, modified date, sharing state, collaborators, and deck usage.

The grid cards are visually distinct and easy to scan. The type chips are useful.

Main UX issues

The main inconsistency is the Open in area:

* Visual
* Code
* AI refine
* Add to deck

These map to product areas, but they do not match the left navigation labels:

* Visual editor
* Playground
* AI studio
* Presentations

This is a major terminology mismatch.

The creation controls also duplicate Home but with slightly different wording:

* Home: New blank diagram, From AI, Visual editor, From sample, Import…
* Library: New diagram, Blank, From AI, Visual, From sample

This should be one reusable creation pattern.

Recommendations

Standardize Open in labels:

* Open in Source editor
* Open in Visual editor
* Refine with AI
* Add to presentation

Or, if you consolidate editing modes:

* Primary button: Open
* Secondary menu: Open in Source, Open in Visual, Refine with AI, Add to presentation

Make the New diagram menu identical everywhere:

* Blank diagram
* Generate with AI
* From template
* Import Mermaid
* Import from URL/Gist if supported

The right rail should use the same terminology as the Share dialog. For example, if Share uses Editor, Commenter, Viewer, Library should use those exact terms and capability descriptions.

The status chips on cards should be standardized. A card with FLOW and LIVE is clear, but a card with SEQ and +AI may need consistent chip order: type first, state second, AI third.

⸻

6. Activity

What works well

This screen has a strong information architecture. The left filters, center feed, and right selected-event details create a clear triage workflow.

The selected mention card is well designed. It gives context, the quoted comment, metadata, and actions without forcing the user to open the full diagram.

The “2 new events arrived” banner is also good. It communicates real-time updates without disrupting the user.

Main UX issues

The terminology around AI and source/mode needs cleanup.

You have:

* Category: AI activity
* Actor: Studio AI
* Event: Studio AI refined Auth flow · v3
* Details field: Source mode Visual editor

“Source mode” is confusing here because “source” elsewhere means Mermaid source/code. In this context, it appears to mean where the event originated.

There is also some duplication between actions in the feed and actions in the right rail. For example, the selected comment has Reply, Resolve, Open thread in the feed card, while the right rail has Reply to thread, Resolve comment, Open full thread, Mark as read.

This is not necessarily wrong, but it can create hesitation about where to act.

Recommendations

Rename Source mode in Details to something clearer:

* Edited in
* Origin
* Workspace
* Created from

Example:

Edited in: Visual editor

Unify AI naming:

* Use AI studio or AI assistant, not Studio AI
* Use AI activity consistently as the category

The right rail should be the authoritative place for acting on the selected event. The feed card can have quick actions, but they should be visually lighter or limited to the top one or two actions.

The Decision support panel is useful. Make those counts clickable filters:

* Unresolved items need attention
* Restorable AI edits available
* Stale deck links detected

This would connect Activity directly to remediation workflows.

Use local time or relative time consistently. The feed shows 2m, 14m, etc., while the detail panel shows 14:20:18 UTC. UTC is useful for audits, but users usually need local time first.

⸻

7. Settings

What works well

The Settings structure is clear and professional. The left settings nav, central form content, and right contextual rail work well.

The scope card is especially helpful. Users need to know whether they are editing personal, workspace, or admin-level settings.

The sharing policy controls are understandable, and the copy generally does a good job explaining consequences.

Main UX issues

The left nav item says Sharing policy, but the page title says Sharing & permissions. These should match.

There is duplicate save-state information:

* Top bar: Auto-saved · 2s
* Right rail: Status · Auto-saved · 2s plus Revert changes

This duplication is not severe, but it contributes to header/right-rail inconsistency.

The word Studio appears again as a plan name. Since AI studio is also a major product area, “Studio plan feature” may be slightly confusing.

The small category labels in the settings nav — new, team, billing, careful — add personality, but they may reduce clarity. “Careful” under Advanced is charming, but it is not a standard category marker.

Recommendations

Rename the nav item to match the page:

Sharing & permissions

Or rename the page to match the nav:

Sharing policy

I prefer Sharing & permissions because the page covers roles, visibility, overrides, and external sharing.

Use one save-state location. I would keep save status in the top header and use the right rail for:

* Scope
* Change summary
* Revert changes
* Plan limits
* Help

If there are no unsaved changes, the right rail does not need to repeat “Auto-saved.”

For plan references, write:

Studio plan feature

but visually treat Studio as a plan chip or label, so it is clear that it is the subscription tier, not the AI Studio workspace.

The settings page is one of the better examples of a consistent secondary navigation pattern. I would reuse this “left subnav + content + context rail” structure for Library and Activity where appropriate.

⸻

8. Share dialog

What works well

The Share dialog is powerful. It handles internal collaborators, external sharing, roles, link permissions, SVG links, policies, plan features, and pending invites. The permission-aware link cards are a strong idea.

The external sharing warning is also good. It makes the risky action visible and explains why it is allowed.

The modal has a clear two-column structure: people on the left, links/policy on the right.

Main UX issues

The dialog is too dense for the core task. Sharing usually has one primary job: invite people or copy a link. Here, the user also has to process plan state, workspace policy, SVG embeds, external warning, link expiration, sign-in requirement, live auto-update, hidden source, and save state.

The largest issue is the action model. I see:

* Send
* Confirm external share
* Manage links
* Save changes

It is not immediately clear which action actually commits the invite, which commits link changes, and which is required for the external collaborator.

The external email chip is in the invite field, but the external confirmation appears in the sticky footer area. That disconnect increases cognitive load.

The role selector is strong, but the capability descriptions under each role should match exactly across Share, Library, and Settings.

Recommendations

Separate the dialog into clearer task areas:

People
Invite collaborators, set role, review access.

Links
Diagram link, SVG link, expiration, sign-in, destination, permissions.

Policy
External sharing rules, SSO, workspace restrictions.

Policy can be collapsed unless there is a warning or blocker.

Clarify the commit model. A better footer might be:

Cancel Save & send invitations

With a pending-change summary:

2 invitations · 1 external collaborator · external domain allowed

The external warning should be closer to the external invite chip:

rajiv@partner-co.io · External · Allowed by workspace policy

Then the confirmation can be inline:

Confirm external invite

or the primary footer button can become:

Confirm and send

Avoid having both Confirm external share and Save changes as separate primary-ish actions.

For the link cards, simplify the visible fields. Show the most important settings first:

* Link on/off
* Permission
* Access requirement
* Expiration
* Copy

Move advanced settings like source visibility, CDN mode, theme, and live-update behavior into an expandable Advanced link settings area.

⸻

Biggest consistency fixes to prioritize

Priority 1: Unify editor modes

Adopt one consistent mode switch for diagram files:

Source | Visual | Split | AI refine

Use it in the same place on every diagram-editing screen.

Priority 2: Resolve Code vs Source

Pick one. I recommend Source.

Then update:

* Code → Source
* Code editor → Source editor
* Review diff → Review source diff
* Source preview remains as-is

Priority 3: Reconsider Playground as a top-level destination

If Playground is the production source editor, rename it. If it is truly experimental, separate it from production editing.

Priority 4: Standardize right rails

Use consistent rail identities:

* Inspector for selected object properties
* Details for selected diagram/event metadata
* Assistant for AI
* History for versions
* Export for output
* Notes for presentations

Priority 5: Normalize creation and open actions

Every place that creates a diagram should use the same menu:

Blank diagram
Generate with AI
From template
Import Mermaid

Every place that opens a diagram should use the same labels:

Open in Source editor
Open in Visual editor
Refine with AI
Add to presentation

Priority 6: Reduce duplicate navigation in Presentations

The Presentations screen is the most navigation-heavy. Remove or collapse one of the slide navigation systems, and clarify whether Outline and Source are modes, panes, or drawers.

Priority 7: Simplify the Share dialog action model

Make it obvious whether the user is sending invites, saving link changes, confirming external access, or all of the above.

⸻

Final take

The product already has a mature visual language. The main opportunity is to make the conceptual language just as mature.

The cleanest mental model would be:

Library is where diagrams live.
Diagram Editor is where diagrams are edited.
Source, Visual, Split, and AI refine are modes of editing.
Presentations are a separate authoring workspace for decks.
Activity is where changes and attention items are triaged.
Settings controls workspace policy.
Share controls access for a specific object.

Once that model is reflected consistently in labels, tabs, headers, and right rails, the whole app will feel significantly easier to learn without needing a major visual redesign.
