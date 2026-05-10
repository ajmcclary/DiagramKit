# Mermaid Presentations Requirements

## 1. Core Presentation Authoring

| ID     | Requirement                                                                                                                  | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------------- | -------: |
| PR-001 | The product shall allow users to create slide decks from Mermaid diagrams.                                                   |       P1 |
| PR-002 | The product shall allow users to create presentation content using Markdown syntax.                                          |       P1 |
| PR-003 | The product shall support diagrams, images, and text within slides.                                                          |       P1 |
| PR-004 | The product shall allow users to present diagrams as part of a structured slideshow rather than as isolated static exports.  |       P1 |
| PR-005 | The product should support technical walkthroughs, architecture reviews, strategy decks, and documentation presentations.    |       P2 |
| PR-006 | The product should treat presentations as a companion mode to diagrams, not as a full PowerPoint-style freeform design tool. |       P2 |

## 2. Markdown-Based Slide Structure

| ID     | Requirement                                                                                            | Priority |
| ------ | ------------------------------------------------------------------------------------------------------ | -------: |
| PR-007 | Presentations shall use Markdown as the primary slide authoring format.                                |       P1 |
| PR-008 | Users shall be able to create horizontal slides.                                                       |       P1 |
| PR-009 | Horizontal slides shall be separated using `----`.                                                     |       P1 |
| PR-010 | Users shall be able to create vertical or nested slides.                                               |       P1 |
| PR-011 | Vertical slides shall be separated using `====`.                                                       |       P1 |
| PR-012 | The product shall distinguish between horizontal deck navigation and vertical nested-slide navigation. |       P1 |
| PR-013 | The editor should visually communicate slide boundaries in the Markdown source.                        |       P2 |
| PR-014 | The editor should provide commands for inserting a new slide separator.                                |       P2 |
| PR-015 | The editor should provide commands for inserting a new sub-slide separator.                            |       P2 |

## 3. Slide Content Formatting

| ID     | Requirement                                                               | Priority |
| ------ | ------------------------------------------------------------------------- | -------: |
| PR-016 | Presentations shall support Markdown headings.                            |       P1 |
| PR-017 | Presentations shall support heading levels one through six.               |       P1 |
| PR-018 | Presentations shall support paragraph text.                               |       P1 |
| PR-019 | Presentations shall support bulleted lists.                               |       P1 |
| PR-020 | Presentations shall support numbered lists.                               |       P1 |
| PR-021 | Presentations shall support bold text.                                    |       P1 |
| PR-022 | Presentations shall support italic text.                                  |       P1 |
| PR-023 | Presentations shall support inline links.                                 |       P1 |
| PR-024 | Presentations shall support images.                                       |       P1 |
| PR-025 | Presentations should support tables.                                      |       P2 |
| PR-026 | Presentations should support code blocks.                                 |       P2 |
| PR-027 | Presentations should support inline code.                                 |       P2 |
| PR-028 | Presentations should preserve Markdown readability when edited as source. |       P1 |

## 4. Diagram Embedding

| ID     | Requirement                                                                                                                    | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------------------ | -------: |
| PR-029 | Users shall be able to add Mermaid diagrams to slides.                                                                         |       P1 |
| PR-030 | Embedded diagrams shall render inside the presentation view.                                                                   |       P1 |
| PR-031 | Embedded diagrams should remain connected to the source diagram where the product supports linked diagrams.                    |       P2 |
| PR-032 | Linked diagrams should automatically update in the presentation when the source diagram changes.                               |       P2 |
| PR-033 | The product shall avoid forcing users to manually re-export and re-import diagrams after every diagram change.                 |       P1 |
| PR-034 | Users should be able to embed multiple diagrams in a single deck.                                                              |       P2 |
| PR-035 | Users should be able to combine diagrams with explanatory text on the same slide.                                              |       P2 |
| PR-036 | The product should support diagram-first storytelling, where each slide focuses on one diagram state, concept, or explanation. |       P2 |

## 5. Slide Creation Toolbar

| ID     | Requirement                                                                                 | Priority |
| ------ | ------------------------------------------------------------------------------------------- | -------: |
| PR-037 | The presentation editor shall provide toolbar actions for common Markdown slide operations. |       P1 |
| PR-038 | The toolbar shall allow users to add a new slide.                                           |       P1 |
| PR-039 | The toolbar shall allow users to add a sub-slide.                                           |       P1 |
| PR-040 | The toolbar shall allow users to insert bullet-list markup.                                 |       P1 |
| PR-041 | The toolbar shall allow users to insert numbered-list markup.                               |       P1 |
| PR-042 | The toolbar should allow users to insert table markup.                                      |       P2 |
| PR-043 | The toolbar should allow users to insert image markup.                                      |       P2 |
| PR-044 | Toolbar commands should insert valid Markdown at the current cursor position.               |       P1 |
| PR-045 | Toolbar commands should not destroy existing Markdown formatting.                           |       P1 |
| PR-046 | Toolbar controls should be discoverable for users who do not remember Markdown syntax.      |       P2 |

## 6. Presentation Preview

| ID     | Requirement                                                                                          | Priority |
| ------ | ---------------------------------------------------------------------------------------------------- | -------: |
| PR-047 | The product shall provide a rendered presentation preview.                                           |       P1 |
| PR-048 | The preview shall reflect the current Markdown source.                                               |       P1 |
| PR-049 | The preview shall render embedded diagrams, images, headings, lists, and links.                      |       P1 |
| PR-050 | The preview should update when the presentation source changes.                                      |       P2 |
| PR-051 | The preview should provide clear feedback when Markdown or diagram content cannot be rendered.       |       P1 |
| PR-052 | The preview should support a slide-by-slide view rather than only showing the raw Markdown document. |       P1 |
| PR-053 | The preview should make slide boundaries clear.                                                      |       P2 |
| PR-054 | The preview should support responsive scaling for different display sizes.                           |       P2 |

## 7. Presentation Mode

| ID     | Requirement                                                                                           | Priority |
| ------ | ----------------------------------------------------------------------------------------------------- | -------: |
| PR-055 | The product shall allow users to launch a presentation mode.                                          |       P1 |
| PR-056 | Presentation mode shall display slides in a focused, audience-ready layout.                           |       P1 |
| PR-057 | Presentation mode shall support forward and backward navigation.                                      |       P1 |
| PR-058 | Presentation mode shall support keyboard navigation.                                                  |       P1 |
| PR-059 | Presentation mode should support full-screen display.                                                 |       P2 |
| PR-060 | Presentation mode should hide editing chrome while presenting.                                        |       P1 |
| PR-061 | Presentation mode should preserve diagram readability at presentation scale.                          |       P1 |
| PR-062 | Presentation mode should support navigation across both horizontal slides and vertical nested slides. |       P2 |
| PR-063 | Presentation mode should provide a clear current-slide position indicator.                            |       P2 |

## 8. Slide Navigation Model

| ID     | Requirement                                                                                | Priority |
| ------ | ------------------------------------------------------------------------------------------ | -------: |
| PR-064 | The product shall model a deck as an ordered set of slides.                                |       P1 |
| PR-065 | The product shall support nested slide relationships.                                      |       P1 |
| PR-066 | The product should expose slide thumbnails or an outline view.                             |       P2 |
| PR-067 | The outline should show horizontal slides and nested vertical slides.                      |       P2 |
| PR-068 | Users should be able to jump directly to a slide from the outline.                         |       P2 |
| PR-069 | Users should be able to reorder slides where the product supports structural editing.      |       P3 |
| PR-070 | Users should be able to duplicate slides where the product supports structural editing.    |       P3 |
| PR-071 | Users should be able to delete slides without corrupting the Markdown separator structure. |       P2 |

## 9. Live Diagram Updates

| ID     | Requirement                                                                                  | Priority |
| ------ | -------------------------------------------------------------------------------------------- | -------: |
| PR-072 | Embedded diagrams should update automatically when linked source diagrams change.            |       P2 |
| PR-073 | The product should communicate whether a diagram is linked or embedded as a static snapshot. |       P2 |
| PR-074 | The product should allow users to refresh diagram content manually.                          |       P2 |
| PR-075 | The product should prevent stale diagram content from being mistaken for the latest version. |       P2 |
| PR-076 | The product should handle missing, deleted, or inaccessible linked diagrams gracefully.      |       P1 |
| PR-077 | The product should preserve the deck even if a linked diagram fails to load.                 |       P1 |
| PR-078 | The product should show a placeholder or error state for unavailable diagrams.               |       P1 |

## 10. Editing Experience

| ID     | Requirement                                                                              | Priority |
| ------ | ---------------------------------------------------------------------------------------- | -------: |
| PR-079 | Users shall be able to edit presentation Markdown directly.                              |       P1 |
| PR-080 | Users should be able to edit a slide from preview mode or a slide outline.               |       P2 |
| PR-081 | The editor should support undo and redo.                                                 |       P1 |
| PR-082 | The editor should preserve cursor position during live preview updates.                  |       P2 |
| PR-083 | The editor should support copy and paste of Markdown content.                            |       P1 |
| PR-084 | The editor should support drag-and-drop or picker-based image insertion where practical. |       P3 |
| PR-085 | The editor should support inserting existing diagrams from the user’s workspace.         |       P2 |
| PR-086 | The editor should support creating a new diagram from within the presentation workflow.  |       P3 |
| PR-087 | The editor should allow users to move from a deck slide to the source diagram editor.    |       P2 |

## 11. Images and Media

| ID     | Requirement                                                                                         | Priority |
| ------ | --------------------------------------------------------------------------------------------------- | -------: |
| PR-088 | Presentations shall support image insertion.                                                        |       P1 |
| PR-089 | Image insertion shall use Markdown-compatible syntax.                                               |       P1 |
| PR-090 | Images shall render in preview and presentation mode.                                               |       P1 |
| PR-091 | The product should support image alt text.                                                          |       P1 |
| PR-092 | The product should support externally hosted image URLs where allowed.                              |       P2 |
| PR-093 | The product should support uploaded image assets where the account/workspace supports file storage. |       P3 |
| PR-094 | The product should handle missing image resources gracefully.                                       |       P1 |
| PR-095 | The product should preserve deck readability when images are too large for the slide.               |       P2 |

## 12. Links and External References

| ID     | Requirement                                                                        | Priority |
| ------ | ---------------------------------------------------------------------------------- | -------: |
| PR-096 | Presentations shall support Markdown links.                                        |       P1 |
| PR-097 | Links shall be clickable in preview and presentation contexts where appropriate.   |       P1 |
| PR-098 | The product should support opening links in a new browser tab or external browser. |       P2 |
| PR-099 | The product should visually distinguish links from plain text.                     |       P1 |
| PR-100 | The product should validate malformed links where practical.                       |       P3 |
| PR-101 | The product should preserve link text and destination when exporting or sharing.   |       P2 |

## 13. Tables

| ID     | Requirement                                                              | Priority |
| ------ | ------------------------------------------------------------------------ | -------: |
| PR-102 | The product should support Markdown table syntax.                        |       P2 |
| PR-103 | The toolbar should provide a table insertion helper.                     |       P2 |
| PR-104 | Tables should render in preview and presentation mode.                   |       P2 |
| PR-105 | Tables should remain readable on presentation slides.                    |       P2 |
| PR-106 | The product should warn or adapt when a table is too wide for the slide. |       P3 |

## 14. Theme and Visual Design

| ID     | Requirement                                                                                  | Priority |
| ------ | -------------------------------------------------------------------------------------------- | -------: |
| PR-107 | Presentations should use a consistent visual theme across slides.                            |       P2 |
| PR-108 | Presentation styling should preserve Mermaid diagram readability.                            |       P1 |
| PR-109 | Presentation styling should handle both light and dark diagram themes.                       |       P2 |
| PR-110 | The product should avoid decorative slide styling that reduces diagram clarity.              |       P2 |
| PR-111 | Users should be able to choose a presentation theme where supported.                         |       P3 |
| PR-112 | The product should provide sensible defaults for technical presentations.                    |       P2 |
| PR-113 | Slide typography should support headings, body text, captions, and lists clearly.            |       P1 |
| PR-114 | The product should support responsive layout behavior for different window and screen sizes. |       P2 |

## 15. Sharing and Collaboration

| ID     | Requirement                                                                      | Priority |
| ------ | -------------------------------------------------------------------------------- | -------: |
| PR-115 | Users should be able to share presentations where cloud sharing is supported.    |       P2 |
| PR-116 | Shared presentations should respect workspace and diagram permissions.           |       P1 |
| PR-117 | Viewers should be able to open a shared presentation without edit access.        |       P2 |
| PR-118 | Editors should be able to modify the presentation if granted permission.         |       P2 |
| PR-119 | Commenters should be able to comment where collaboration features are supported. |       P3 |
| PR-120 | Shared presentations should preserve embedded diagram access rules.              |       P1 |
| PR-121 | A shared deck should not expose private diagrams to unauthorized viewers.        |       P1 |
| PR-122 | The product should distinguish presentation sharing from source diagram sharing. |       P2 |

## 16. Export

| ID     | Requirement                                                                                                      | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------- | -------: |
| PR-123 | Users should be able to export presentation content.                                                             |       P2 |
| PR-124 | Export should preserve slide order.                                                                              |       P2 |
| PR-125 | Export should preserve embedded diagram visuals.                                                                 |       P2 |
| PR-126 | Export should preserve readable text, headings, lists, links, and images.                                        |       P2 |
| PR-127 | Export should support Markdown source.                                                                           |       P2 |
| PR-128 | Export should support PDF where feasible.                                                                        |       P3 |
| PR-129 | Export should support image-based slide export where feasible.                                                   |       P3 |
| PR-130 | Export should clearly communicate any unsupported content or formatting loss.                                    |       P2 |
| PR-131 | Exported decks should not require live network access unless explicitly exported as a linked/cloud presentation. |       P2 |

## 17. Presentation Storage Model

| ID     | Requirement                                                                                             | Priority |
| ------ | ------------------------------------------------------------------------------------------------------- | -------: |
| PR-132 | The product shall store presentation source separately from individual diagram source.                  |       P1 |
| PR-133 | The product should support references from presentation slides to diagram objects.                      |       P2 |
| PR-134 | The product should support static embedded diagram snapshots where linked references are not available. |       P2 |
| PR-135 | The product should track deck title, description, owner, creation date, and modified date.              |       P2 |
| PR-136 | The product should track which diagrams are used in a deck.                                             |       P2 |
| PR-137 | The product should detect broken diagram references.                                                    |       P2 |
| PR-138 | The product should support autosave where cloud/workspace editing is enabled.                           |       P2 |
| PR-139 | The product should support local draft state before publishing or sharing.                              |       P2 |

## 18. Versioning and History

| ID     | Requirement                                                                                             | Priority |
| ------ | ------------------------------------------------------------------------------------------------------- | -------: |
| PR-140 | The product should preserve deck revision history.                                                      |       P2 |
| PR-141 | The product should allow users to restore earlier presentation versions.                                |       P3 |
| PR-142 | The product should track changes to presentation Markdown separately from changes to embedded diagrams. |       P2 |
| PR-143 | The product should warn users when source diagrams have changed since the deck was last presented.      |       P3 |
| PR-144 | The product should allow users to review updated diagram content before presenting.                     |       P3 |
| PR-145 | The product should distinguish autosaved edits from explicitly published versions.                      |       P2 |

## 19. AI Interoperability

| ID     | Requirement                                                                                  | Priority |
| ------ | -------------------------------------------------------------------------------------------- | -------: |
| PR-146 | The presentation workflow should allow AI-generated diagrams to be inserted into decks.      |       P2 |
| PR-147 | The product should allow users to generate a deck outline from a diagram or set of diagrams. |       P3 |
| PR-148 | The product should allow users to generate speaker notes from a diagram.                     |       P3 |
| PR-149 | The product should allow users to summarize a diagram for slide text.                        |       P3 |
| PR-150 | The product should allow users to convert a diagram explanation into slide bullets.          |       P3 |
| PR-151 | AI-generated presentation content should remain editable Markdown.                           |       P2 |
| PR-152 | AI-generated slides should preserve diagram links where possible.                            |       P3 |

## 20. Templates and Starting Points

| ID     | Requirement                                                  | Priority |
| ------ | ------------------------------------------------------------ | -------: |
| PR-153 | The product should provide presentation templates.           |       P3 |
| PR-154 | Templates should support architecture walkthroughs.          |       P3 |
| PR-155 | Templates should support product strategy decks.             |       P3 |
| PR-156 | Templates should support incident/postmortem walkthroughs.   |       P3 |
| PR-157 | Templates should support database/schema review decks.       |       P3 |
| PR-158 | Templates should support onboarding and documentation decks. |       P3 |
| PR-159 | Templates should be authored in readable Markdown.           |       P3 |
| PR-160 | Users should be able to save custom deck templates.          |       P3 |

## 21. Error Handling

| ID     | Requirement                                                                                                                                | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------ | -------: |
| PR-161 | The product shall show an error when presentation Markdown cannot be parsed.                                                               |       P1 |
| PR-162 | The product shall show an error when an embedded diagram cannot be rendered.                                                               |       P1 |
| PR-163 | The product shall show an error when an image cannot be loaded.                                                                            |       P1 |
| PR-164 | The product shall show an error when a linked diagram is unavailable.                                                                      |       P1 |
| PR-165 | The product shall show an error when the user lacks permission to view an embedded diagram.                                                |       P1 |
| PR-166 | The product should identify whether an error came from Markdown, diagram rendering, asset loading, sharing permissions, or network access. |       P2 |
| PR-167 | The product should preserve editable source when preview or presentation rendering fails.                                                  |       P1 |
| PR-168 | The product should allow users to continue editing even when preview fails.                                                                |       P1 |

## 22. Accessibility

| ID     | Requirement                                                                              | Priority |
| ------ | ---------------------------------------------------------------------------------------- | -------: |
| PR-169 | Presentation authoring controls shall be keyboard accessible.                            |       P1 |
| PR-170 | Presentation mode shall support keyboard navigation.                                     |       P1 |
| PR-171 | Slide content shall preserve semantic heading structure.                                 |       P1 |
| PR-172 | Images should support alt text.                                                          |       P1 |
| PR-173 | Embedded diagrams should support accessible titles or descriptions where available.      |       P2 |
| PR-174 | Links should have readable link text.                                                    |       P1 |
| PR-175 | Presentation mode should maintain sufficient color contrast.                             |       P1 |
| PR-176 | The product should support reduced-motion preferences if slide transitions are animated. |       P2 |
| PR-177 | Errors should be announced to assistive technologies.                                    |       P1 |

## 23. Plan Gating and Account Awareness

| ID     | Requirement                                                                                | Priority |
| ------ | ------------------------------------------------------------------------------------------ | -------: |
| PR-178 | Presentation creation should respect account and workspace entitlements.                   |       P2 |
| PR-179 | Sharing presentations should respect plan-level sharing permissions.                       |       P2 |
| PR-180 | Collaboration on presentations should respect plan-level collaboration permissions.        |       P2 |
| PR-181 | External sharing should be gated where the product plan gates external sharing.            |       P2 |
| PR-182 | The product should show clear upgrade messaging when a presentation feature is plan-gated. |       P2 |
| PR-183 | The product should distinguish local deck editing from cloud sharing or collaboration.     |       P2 |

## 24. Recommended MVP Scope

For an MVP Presentations feature, I would include:

| Area            | MVP Requirement                                                   |
| --------------- | ----------------------------------------------------------------- |
| Authoring model | Markdown-based deck source                                        |
| Slide structure | Horizontal slides with `----`; vertical slides with `====`        |
| Content         | Headings, paragraphs, bullets, numbered lists, links, images      |
| Diagrams        | Embed Mermaid diagrams in slides                                  |
| Preview         | Rendered slide preview                                            |
| Presenting      | Full-screen/focused presentation mode                             |
| Navigation      | Keyboard next/previous slide navigation                           |
| Editing         | Toolbar buttons for new slide, sub-slide, bullets, numbers, image |
| Safety          | Preserve source when rendering fails                              |
| Sharing         | Optional share link if cloud features exist                       |

## 25. Recommended Advanced Scope

After MVP, the strongest differentiators would be:

| Area            | Advanced Requirement                                                  |
| --------------- | --------------------------------------------------------------------- |
| Linked diagrams | Auto-update slides when source diagrams change                        |
| Outline         | Slide navigator with nested slide hierarchy                           |
| Templates       | Architecture review, roadmap, postmortem, onboarding templates        |
| AI              | Generate deck outline, slide bullets, and speaker notes from diagrams |
| Collaboration   | Comments, permissions, co-editing                                     |
| Export          | PDF, image slides, Markdown package                                   |
| Versioning      | Deck history and restore                                              |
| Review          | Detect stale diagrams before presenting                               |
| Accessibility   | Diagram descriptions and semantic slide metadata                      |

## 26. Key Product Caveat

The Presentations feature should be modeled as a **Markdown deck system for Mermaid-centered storytelling**, not as a general-purpose Keynote/PowerPoint clone.

The ideal workflow is:

```text
Diagram or diagrams
→ Markdown presentation source
→ Slide preview
→ Presentation mode
→ Share / export
→ Diagrams stay linked or clearly snapshot-based
```

The most important design rule: **presentations should keep diagrams alive.** A deck should not become a dead-end collection of stale screenshots unless the user explicitly exports it that way.
