# Mermaid Visual Editor Requirements

## 1. Core Visual Editing Scope

| ID     | Requirement                                                                                                                                                                               | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| VE-001 | The Visual Editor shall allow users to create and edit Mermaid diagrams without directly writing Mermaid syntax.                                                                          |       P1 |
| VE-002 | The Visual Editor shall support direct manipulation of diagram elements using pointer/click/tap interactions.                                                                             |       P1 |
| VE-003 | The Visual Editor shall maintain synchronization between the visual diagram and the underlying Mermaid source.                                                                            |       P1 |
| VE-004 | The Visual Editor shall expose the Mermaid source as an editable text representation alongside or adjacent to the visual surface.                                                         |       P1 |
| VE-005 | The Visual Editor shall warn or disclose that visual edits may normalize, prettify, or rewrite the Mermaid source formatting.                                                             |       P1 |
| VE-006 | The Visual Editor shall preserve the semantic structure of the diagram when formatting or regenerating Mermaid source.                                                                    |       P1 |
| VE-007 | The Visual Editor shall initially prioritize **flowchart editing**, since Mermaid’s own Visual Editor documentation describes flowcharts as the primary supported visual-editing surface. |       P1 |
| VE-008 | The system should support future expansion to additional diagram types such as ER diagrams, sequence diagrams, class diagrams, state diagrams, mind maps, and architecture diagrams.      |       P2 |

## 2. Canvas and Diagram Surface

| ID     | Requirement                                                                                         | Priority |
| ------ | --------------------------------------------------------------------------------------------------- | -------: |
| VE-009 | The Visual Editor shall provide a canvas/workspace for viewing and editing the rendered diagram.    |       P1 |
| VE-010 | The canvas shall support pan and zoom.                                                              |       P1 |
| VE-011 | The canvas shall support selecting nodes and edges.                                                 |       P1 |
| VE-012 | The canvas shall visually indicate selected elements.                                               |       P1 |
| VE-013 | The canvas shall support deselecting elements by clicking/tapping empty space.                      |       P1 |
| VE-014 | The canvas should support fit-to-screen or reset-view behavior.                                     |       P2 |
| VE-015 | The canvas should support zoom controls such as zoom in, zoom out, reset zoom, and fit diagram.     |       P2 |
| VE-016 | The canvas should support keyboard navigation for common operations.                                |       P2 |
| VE-017 | The canvas should support large diagrams without the editor chrome overwhelming the diagram itself. |       P2 |

## 3. Node Creation and Editing

| ID     | Requirement                                                                                | Priority |
| ------ | ------------------------------------------------------------------------------------------ | -------: |
| VE-018 | Users shall be able to add new nodes visually.                                             |       P1 |
| VE-019 | Users shall be able to edit node labels visually.                                          |       P1 |
| VE-020 | Users shall be able to delete nodes visually.                                              |       P1 |
| VE-021 | Users shall be able to change a node’s shape.                                              |       P1 |
| VE-022 | Users shall be able to change a node’s border style.                                       |       P1 |
| VE-023 | Users shall be able to change a node’s border color.                                       |       P1 |
| VE-024 | Users shall be able to change a node’s background color.                                   |       P1 |
| VE-025 | Users shall be able to change a node’s text color.                                         |       P1 |
| VE-026 | Users should be able to duplicate a node.                                                  |       P2 |
| VE-027 | Users should be able to copy and paste nodes.                                              |       P2 |
| VE-028 | Users should be able to multi-select nodes.                                                |       P2 |
| VE-029 | Users should be able to align, distribute, or organize selected nodes when layout permits. |       P3 |
| VE-030 | Users should be able to group or visually associate related nodes.                         |       P3 |

## 4. Edge / Connector Creation and Editing

| ID     | Requirement                                                                                                                                | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------ | -------: |
| VE-031 | Users shall be able to create connections between nodes visually.                                                                          |       P1 |
| VE-032 | Users shall be able to edit edge labels visually.                                                                                          |       P1 |
| VE-033 | Users shall be able to delete edges visually.                                                                                              |       P1 |
| VE-034 | Users shall be able to change edge arrow type.                                                                                             |       P1 |
| VE-035 | Users shall be able to change edge stroke style.                                                                                           |       P1 |
| VE-036 | Users shall be able to change edge color.                                                                                                  |       P1 |
| VE-037 | Users should be able to reverse edge direction.                                                                                            |       P2 |
| VE-038 | Users should be able to convert between common connector styles, such as arrow, open link, dotted line, thick line, and labeled connector. |       P2 |
| VE-039 | The editor should prevent invalid edge connections or explain why a requested connection cannot be represented in Mermaid syntax.          |       P2 |

## 5. Contextual Editing Controls

| ID     | Requirement                                                                                                                          | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------ | -------: |
| VE-040 | Selecting a node shall expose node-specific editing controls.                                                                        |       P1 |
| VE-041 | Selecting an edge shall expose edge-specific editing controls.                                                                       |       P1 |
| VE-042 | Right-click or secondary-click should expose a context menu for deletion and common object actions.                                  |       P1 |
| VE-043 | The editor shall distinguish between node controls and edge controls to avoid applying invalid properties to the wrong element type. |       P1 |
| VE-044 | The editor should provide inline label editing where practical.                                                                      |       P2 |
| VE-045 | The editor should provide an inspector/sidebar for advanced styling and metadata.                                                    |       P2 |
| VE-046 | The editor should support command discoverability through tooltips, labels, or an always-available help affordance.                  |       P2 |

## 6. Mermaid Source Synchronization

| ID     | Requirement                                                                                          | Priority |
| ------ | ---------------------------------------------------------------------------------------------------- | -------: |
| VE-047 | Visual changes shall update the Mermaid source.                                                      |       P1 |
| VE-048 | Source changes shall update the visual diagram.                                                      |       P1 |
| VE-049 | The editor shall validate Mermaid source before applying changes to the visual model.                |       P1 |
| VE-050 | The editor shall show syntax errors when source cannot be rendered or converted into a visual model. |       P1 |
| VE-051 | The editor shall preserve valid user-authored source as much as possible.                            |       P1 |
| VE-052 | The editor shall clearly communicate when formatting or syntax normalization will occur.             |       P1 |
| VE-053 | The editor should provide a preview of source changes before destructive normalization.              |       P2 |
| VE-054 | The editor should support undo/redo across both visual and source edits.                             |       P1 |
| VE-055 | Undo/redo should treat visual and code edits as part of one unified edit history.                    |       P2 |

## 7. Supported Flowchart Features

| ID     | Requirement                                                                                                                                                                                               | Priority |
| ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| VE-056 | The Visual Editor shall support standard flowchart nodes.                                                                                                                                                 |       P1 |
| VE-057 | The Visual Editor shall support standard Mermaid flowchart connectors.                                                                                                                                    |       P1 |
| VE-058 | The Visual Editor shall support labeled edges.                                                                                                                                                            |       P1 |
| VE-059 | The Visual Editor shall support decision-style nodes.                                                                                                                                                     |       P1 |
| VE-060 | The Visual Editor should support common flowchart node shapes such as rectangle, rounded rectangle, circle, diamond, stadium, subroutine, cylinder, and document-like shapes where Mermaid supports them. |       P2 |
| VE-061 | The Visual Editor should support subgraphs or containers where Mermaid flowchart syntax supports them.                                                                                                    |       P2 |
| VE-062 | The Visual Editor should support Mermaid flowchart direction changes, such as top-down, left-right, right-left, and bottom-up.                                                                            |       P2 |
| VE-063 | The Visual Editor should expose layout direction as a diagram-level setting.                                                                                                                              |       P2 |

## 8. Styling and Appearance

| ID     | Requirement                                                                                                      | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------- | -------: |
| VE-064 | Users shall be able to modify node fill/background color.                                                        |       P1 |
| VE-065 | Users shall be able to modify node border color.                                                                 |       P1 |
| VE-066 | Users shall be able to modify node text color.                                                                   |       P1 |
| VE-067 | Users shall be able to modify edge color.                                                                        |       P1 |
| VE-068 | Users shall be able to modify edge stroke style.                                                                 |       P1 |
| VE-069 | The editor should expose diagram-level theme selection.                                                          |       P2 |
| VE-070 | The editor should distinguish between semantic structure and purely visual styling.                              |       P2 |
| VE-071 | The editor should support light and dark editor appearances independent of the diagram theme.                    |       P2 |
| VE-072 | The editor should support applying a theme without destroying user-selected custom styles.                       |       P2 |
| VE-073 | The editor should indicate whether style changes are stored as Mermaid syntax, theme config, or editor metadata. |       P2 |

## 9. Cheat Sheet and Help

| ID     | Requirement                                                                                   | Priority |
| ------ | --------------------------------------------------------------------------------------------- | -------: |
| VE-074 | The Visual Editor shall provide access to a cheat sheet or help panel.                        |       P1 |
| VE-075 | The cheat sheet shall explain supported visual editor operations.                             |       P1 |
| VE-076 | The cheat sheet should include Mermaid syntax examples for the currently edited diagram type. |       P2 |
| VE-077 | The help panel should explain the difference between visual editing and code editing.         |       P2 |
| VE-078 | The help panel should disclose current diagram-type limitations.                              |       P1 |
| VE-079 | The help panel should link to full Mermaid documentation for deeper syntax reference.         |       P2 |

## 10. Diagram-Type Limitations and Unsupported States

| ID     | Requirement                                                                                                            | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------- | -------: |
| VE-080 | The Visual Editor shall clearly state which diagram types are visually editable.                                       |       P1 |
| VE-081 | The Visual Editor shall not imply full Mermaid syntax coverage when only a subset is supported.                        |       P1 |
| VE-082 | If a diagram type is unsupported, the editor shall allow code editing and preview but disable visual editing controls. |       P1 |
| VE-083 | If a diagram contains unsupported syntax, the editor shall explain which portion cannot be visually edited.            |       P1 |
| VE-084 | Unsupported syntax shall not be silently deleted.                                                                      |       P1 |
| VE-085 | The editor should offer a “view-only visual preview” mode for unsupported diagrams.                                    |       P2 |
| VE-086 | The editor should offer a safe fallback to code mode when visual editing cannot represent the diagram.                 |       P1 |

## 11. Layout Behavior

| ID     | Requirement                                                                                                                                      | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------: |
| VE-087 | The Visual Editor shall preserve Mermaid’s auto-layout behavior unless the product explicitly introduces manual layout metadata.                 |       P1 |
| VE-088 | The editor shall distinguish between logical diagram relationships and visual placement.                                                         |       P1 |
| VE-089 | The editor should avoid suggesting that users can freely position every node if the underlying Mermaid syntax does not preserve exact positions. |       P1 |
| VE-090 | The editor should provide layout refresh/reflow controls.                                                                                        |       P2 |
| VE-091 | The editor should support diagram direction controls for supported diagram types.                                                                |       P2 |
| VE-092 | The editor should communicate when layout is generated automatically.                                                                            |       P2 |

## 12. Collaboration Features

| ID     | Requirement                                                                                                       | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------- | -------: |
| VE-093 | The Visual Editor should support collaborative diagram editing where the product includes collaboration features. |       P2 |
| VE-094 | The editor should support view/comment collaboration separately from edit collaboration.                          |       P2 |
| VE-095 | The editor should expose presence indicators for collaborators.                                                   |       P3 |
| VE-096 | The editor should prevent conflicting edits where two collaborators modify the same node, edge, or source region. |       P3 |
| VE-097 | The editor should expose permissions for who can view, comment, or edit.                                          |       P2 |
| VE-098 | The editor should support externally shared diagrams where the plan permits external sharing.                     |       P2 |

## 13. Export and Share

| ID     | Requirement                                                                                   | Priority |
| ------ | --------------------------------------------------------------------------------------------- | -------: |
| VE-099 | Users shall be able to export visual diagrams.                                                |       P1 |
| VE-100 | Export should support PNG.                                                                    |       P1 |
| VE-101 | Export should support SVG.                                                                    |       P1 |
| VE-102 | Export should support Mermaid source/MMD.                                                     |       P1 |
| VE-103 | Exported diagrams should reflect current visual styling.                                      |       P1 |
| VE-104 | Exported diagrams should preserve readable text and correct colors in light and dark themes.  |       P2 |
| VE-105 | Users should be able to copy the diagram image to clipboard.                                  |       P2 |
| VE-106 | Users should be able to copy Mermaid source to clipboard.                                     |       P1 |
| VE-107 | Users should be able to share diagrams through links if cloud sharing is part of the product. |       P2 |
| VE-108 | Shared diagrams should respect viewer/editor permissions.                                     |       P2 |

## 14. Version History and Recovery

| ID     | Requirement                                                                                              | Priority |
| ------ | -------------------------------------------------------------------------------------------------------- | -------: |
| VE-109 | The editor should maintain local edit history.                                                           |       P1 |
| VE-110 | The editor should support undo and redo.                                                                 |       P1 |
| VE-111 | The editor should support saved revisions or timeline history where the product supports versioning.     |       P2 |
| VE-112 | Users should be able to restore an earlier version of a diagram.                                         |       P2 |
| VE-113 | The editor should distinguish autosaved changes from explicitly saved versions.                          |       P2 |
| VE-114 | The editor should protect users from losing source changes when switching between visual and code modes. |       P1 |

## 15. AI Interoperability

| ID     | Requirement                                                                                          | Priority |
| ------ | ---------------------------------------------------------------------------------------------------- | -------: |
| VE-115 | The Visual Editor should allow AI-generated diagrams to be opened for visual refinement.             |       P2 |
| VE-116 | The editor should allow users to move from AI generation into manual visual editing.                 |       P2 |
| VE-117 | The editor should preserve generated Mermaid source so users can inspect and refine it.              |       P2 |
| VE-118 | The editor should support “edit with AI” or “refine with AI” actions where AI features are included. |       P3 |
| VE-119 | AI-generated diagrams should be validated before entering the visual editor.                         |       P1 |
| VE-120 | AI-generated unsupported syntax should gracefully fall back to code/preview mode.                    |       P1 |

## 16. Icons and Visual Assets

| ID     | Requirement                                                                                                       | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------- | -------: |
| VE-121 | The editor should support inserting icons where Mermaid syntax and diagram type support icons.                    |       P2 |
| VE-122 | The editor should provide an icon picker where icon-based diagrams are supported.                                 |       P2 |
| VE-123 | The icon picker should support searching or browsing supported icon packs.                                        |       P2 |
| VE-124 | The editor should support cloud/provider icon families such as AWS, Azure, GCP, and Font Awesome where available. |       P2 |
| VE-125 | The editor should allow users to change icon color where supported.                                               |       P2 |
| VE-126 | The editor should allow users to change icon size where supported.                                                |       P2 |
| VE-127 | The editor should preserve icon references in Mermaid source.                                                     |       P1 |

## 17. Accessibility Requirements

| ID     | Requirement                                                                                                       | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------- | -------: |
| VE-128 | All editor controls shall be keyboard accessible.                                                                 |       P1 |
| VE-129 | The selected element state shall not rely on color alone.                                                         |       P1 |
| VE-130 | The editor shall support accessible labels for toolbar buttons, context menu items, and inspector controls.       |       P1 |
| VE-131 | The editor should support reduced-motion behavior.                                                                |       P2 |
| VE-132 | The editor should support sufficient contrast in light and dark modes.                                            |       P1 |
| VE-133 | The editor should expose diagram title and description metadata where supported by Mermaid accessibility options. |       P2 |
| VE-134 | Error messages shall be readable by assistive technologies.                                                       |       P1 |

## 18. Error Handling

| ID     | Requirement                                                                                                                       | Priority |
| ------ | --------------------------------------------------------------------------------------------------------------------------------- | -------: |
| VE-135 | The editor shall show syntax errors when Mermaid source cannot be parsed.                                                         |       P1 |
| VE-136 | The editor shall show visual-editing limitations when syntax cannot be represented visually.                                      |       P1 |
| VE-137 | The editor shall not destroy unsupported Mermaid source.                                                                          |       P1 |
| VE-138 | The editor shall recover gracefully from render failures.                                                                         |       P1 |
| VE-139 | The editor should allow users to revert to the last valid diagram state.                                                          |       P1 |
| VE-140 | The editor should identify whether an error came from syntax, rendering, unsupported visual conversion, export, or collaboration. |       P2 |

## 19. Product Gating / Plan Awareness

| ID     | Requirement                                                                                                                | Priority |
| ------ | -------------------------------------------------------------------------------------------------------------------------- | -------: |
| VE-141 | The Visual Editor should respect product-plan limits for diagram count, diagram size, collaboration, and external sharing. |       P2 |
| VE-142 | The editor should show clear upgrade messaging when a user attempts a plan-gated action.                                   |       P2 |
| VE-143 | The editor should allow local editing where possible even when cloud features are unavailable.                             |       P2 |
| VE-144 | The editor should distinguish local-only actions from cloud/account-dependent actions.                                     |       P2 |

## 20. Recommended MVP Scope

For an MVP visual editor, I would treat these as the **must-have feature set**:

| Area           | MVP Requirement                                                                          |
| -------------- | ---------------------------------------------------------------------------------------- |
| Diagram type   | Flowchart visual editing                                                                 |
| Editing        | Add node, edit label, delete node, connect nodes, delete edge                            |
| Styling        | Node shape, node fill, node border, node text color, edge arrow, edge stroke, edge color |
| Sync           | Bidirectional visual/source sync                                                         |
| Safety         | Syntax validation, unsupported syntax fallback, non-destructive source handling          |
| Navigation     | Pan, zoom, fit to screen                                                                 |
| Help           | Cheat sheet and visual editor limitations disclosure                                     |
| Export         | SVG, PNG, Mermaid source                                                                 |
| History        | Undo/redo                                                                                |
| Mode switching | Code mode ↔ visual mode without silent data loss                                         |

## 21. Key Product Caveat

The most important requirement is this:

> The Visual Editor should be treated as a **diagram-type-specific authoring surface**, not a universal Mermaid WYSIWYG editor.

That means the product should not promise that every Mermaid diagram can be visually edited. A strong design would support:

**Visual-editable diagrams**
Flowcharts first, then ER diagrams and other diagram types over time.

**Code-editable diagrams**
All valid Mermaid diagrams.

**Preview-only diagrams**
Valid Mermaid diagrams that render correctly but cannot be safely converted into a visual editing model.

**Unsupported/invalid diagrams**
Diagrams with syntax errors or features the current renderer/editor cannot interpret.
