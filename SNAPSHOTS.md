# Snapshot Review Tracking

> **161 image snapshot baselines** spanning 14 diagram types.
> Base directory: `Tests/BeautifulMermaidSwiftTests/__Snapshots__/CorpusSnapshotTests/`

---

## Instructions for Reviewing Agents

When reviewing a snapshot, follow these steps **in order**:

1. **Inspect the image** — Use the `read_file` tool to open the `.png` file from the path below. The tool supports vision — you will see the rendered diagram directly.

2. **Determine correctness** — Evaluate the diagram against these criteria:
   - **Orientation**: Is the diagram oriented correctly (not mirrored, flipped, or backwards)?
   - **Layout**: Are nodes, labels, and edges reasonably positioned without severe crowding, overlapping, or clipping?
   - **Text rendering**: Are labels, titles, and annotations legible and properly placed?
   - **Edge/arrow rendering**: Are lines, arrows, and connectors drawn correctly (no broken paths, missing arrowheads, or garbled routing)?
   - **Color/style**: Are colors and styles applied as expected for the diagram type?
   - **Completeness**: Are all expected elements of the diagram present?

3. **Update the table** — After reviewing, update the row for that snapshot:
   - Set **Status** to one of: `🟢 Pass`, `🟡 Needs Review`, or `🔴 Fail`
   - Add a brief **Reviewer Comments** note summarizing what you observed (e.g., "All good", or "Overlapping labels on nodes X and Y")
   - If there is a problem, be specific about what you see

### Status Legend

| Status | Meaning |
|--------|---------|
| 🔴 Pending | Not yet reviewed |
| 🟢 Pass | Diagram renders correctly |
| 🟡 Needs Review | Minor issues / uncertain — needs human judgment |
| 🔴 Fail | Clear rendering bug (misaligned, missing elements, garbled text, etc.) |

---

## Class Diagrams (36 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.class-1-basic.png` | 🔴 Fail | Diagram text is vertically mirrored/upside down; class box is otherwise present. |
| 2 | `imageSnapshot-_.class-3-interface.png` | 🔴 Fail | Annotation and member text are vertically mirrored/upside down. |
| 3 | `imageSnapshot-_.class-4-abstract.png` | 🔴 Fail | Annotation and member text are vertically mirrored/upside down. |
| 4 | `imageSnapshot-_.class-5-enum.png` | 🔴 Fail | Enum label and values are vertically mirrored/upside down. |
| 5 | `imageSnapshot-_.class-6-inheritance.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; inheritance edges are visible. |
| 6 | `imageSnapshot-_.class-7-composition.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; composition edge/diamond is visible. |
| 7 | `imageSnapshot-_.class-8-aggregation.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; aggregation edge/diamond is visible. |
| 8 | `imageSnapshot-_.class-9-association.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; association edge is visible. |
| 9 | `imageSnapshot-_.class-10-dependency.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; dashed dependency edge is visible. |
| 10 | `imageSnapshot-_.class-11-realization.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; dashed realization edge is visible. |
| 11 | `imageSnapshot-_.class-14-observer.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; class boxes and relationships appear present. |
| 12 | `imageSnapshot-_.class-15-mvc.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; relationship labels are also inverted. |
| 13 | `imageSnapshot-_.class-17-v2-header.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; inheritance edge is visible. |
| 14 | `imageSnapshot-_.class-18-square-label.png` | 🔴 Fail | Square-bracket class labels are vertically mirrored/upside down. |
| 15 | `imageSnapshot-_.class-20-generic-declaration.png` | 🔴 Fail | Generic class labels are vertically mirrored/upside down. |
| 16 | `imageSnapshot-_.class-22-inline-annotation.png` | 🔴 Fail | Inline annotations and class labels are vertically mirrored/upside down. |
| 17 | `imageSnapshot-_.class-23-multiple-annotations.png` | 🔴 Fail | Multiple annotations and class label are vertically mirrored/upside down. |
| 18 | `imageSnapshot-_.class-24-inline-annotation-members.png` | 🔴 Fail | Inline annotation, members, and class labels are vertically mirrored/upside down. |
| 19 | `imageSnapshot-_.class-26-generic-method.png` | 🔴 Fail | Generic method signatures are vertically mirrored/upside down. |
| 20 | `imageSnapshot-_.class-27-member-separators.png` | 🔴 Fail | Member text is vertically mirrored/upside down; separator lines are present. |
| 21 | `imageSnapshot-_.class-30-two-ended-composition.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; two-ended composition markers are visible. |
| 22 | `imageSnapshot-_.class-32-lollipop.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; lollipop connector is visible. |
| 23 | `imageSnapshot-_.class-33-dashed-no-arrow.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; dashed no-arrow edge is visible. |
| 24 | `imageSnapshot-_.class-36-dotted-aggregation.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; dotted aggregation marker is visible. |
| 25 | `imageSnapshot-_.class-39-namespace-label.png` | 🔴 Fail | Namespace frame and classes are present, but all labels are vertically mirrored/upside down. |
| 26 | `imageSnapshot-_.class-40-namespace-dotted.png` | 🔴 Fail | Namespace frame and classes are present, but all labels are vertically mirrored/upside down. |
| 27 | `imageSnapshot-_.class-45-style-basic.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; expected pink style fill is not visible. |
| 28 | `imageSnapshot-_.class-46-classdef-basic.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; classDef declaration has no visible styling effect. |
| 29 | `imageSnapshot-_.class-47-classdef-default.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; default classDef fill/color is not visible. |
| 30 | `imageSnapshot-_.class-48-css-class.png` | 🔴 Fail | Diagram text is vertically mirrored/upside down; cssClass fill is not visible. |
| 31 | `imageSnapshot-_.class-49-css-multi.png` | 🔴 Fail | Diagram text is vertically mirrored/upside down; multi-class cssClass fill is not visible. |
| 32 | `imageSnapshot-_.class-50-shorthand.png` | 🔴 Fail | Diagram text is vertically mirrored/upside down; shorthand style fill is not visible. |
| 33 | `imageSnapshot-_.class-51-link.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; inheritance edge is visible. |
| 34 | `imageSnapshot-_.class-55-acc-title.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; accessibility title does not render visibly. |
| 35 | `imageSnapshot-_.class-58-direction-tb.png` | 🔴 Fail | Diagram is vertically mirrored/upside down, and the chained `A --> B --> C` relationship is incomplete. |
| 36 | `imageSnapshot-_.class-60-frontmatter-title.png` | 🔴 Fail | Diagram is vertically mirrored/upside down; expected frontmatter title is not visible. |

## ER Diagrams (7 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.er-3-keys.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.er-14-school.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.er-15-standalone.png` | 🔴 Pending | |
| 4 | `imageSnapshot-_.er-16-aliases.png` | 🔴 Pending | |
| 5 | `imageSnapshot-_.er-18-long-cardinality.png` | 🔴 Pending | |
| 6 | `imageSnapshot-_.er-20-cycles.png` | 🔴 Pending | |
| 7 | `imageSnapshot-_.er-23-neo-look.png` | 🔴 Pending | |

## Flowcharts (19 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.flow-1-simple.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.flow-3-batch1-shapes.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.flow-4-batch2-shapes.png` | 🔴 Pending | |
| 4 | `imageSnapshot-_.flow-5-all-12-shapes.png` | 🔴 Pending | |
| 5 | `imageSnapshot-_.flow-6-edge-styles.png` | 🔴 Pending | |
| 6 | `imageSnapshot-_.flow-9-bidirectional.png` | 🔴 Pending | |
| 7 | `imageSnapshot-_.flow-10-parallel.png` | 🔴 Pending | |
| 8 | `imageSnapshot-_.flow-11-chained.png` | 🔴 Pending | |
| 9 | `imageSnapshot-_.flow-14-direction-lr.png` | 🔴 Pending | |
| 10 | `imageSnapshot-_.flow-15-direction-bt.png` | 🔴 Pending | |
| 11 | `imageSnapshot-_.flow-16-subgraphs.png` | 🔴 Pending | |
| 12 | `imageSnapshot-_.flow-17-nested-subgraphs.png` | 🔴 Pending | |
| 13 | `imageSnapshot-_.flow-18-subgraph-direction.png` | 🔴 Pending | |
| 14 | `imageSnapshot-_.flow-20-inline-style.png` | 🔴 Pending | |
| 15 | `imageSnapshot-_.flow-22-system-architecture.png` | 🔴 Pending | |
| 16 | `imageSnapshot-_.flow-23-decision-tree.png` | 🔴 Pending | |
| 17 | `imageSnapshot-_.flow-24-git-branching.png` | 🔴 Pending | |
| 18 | `imageSnapshot-_.flow-25-self-loop.png` | 🔴 Pending | |
| 19 | `imageSnapshot-_.flow-26-self-loop-label.png` | 🔴 Pending | |

## Gantt Charts (3 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.gantt-1-basic.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.gantt-3-compact.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.gantt-6-click.png` | 🔴 Pending | |

## Git Graphs (11 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.git-1-basic.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.git-5-commit-properties.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.git-6-multiple-tags.png` | 🔴 Pending | |
| 4 | `imageSnapshot-_.git-8-branch-order.png` | 🔴 Pending | |
| 5 | `imageSnapshot-_.git-10-cherry-pick-merge.png` | 🔴 Pending | |
| 6 | `imageSnapshot-_.git-11-title-acc.png` | 🔴 Pending | |
| 7 | `imageSnapshot-_.git-14-complex.png` | 🔴 Pending | |
| 8 | `imageSnapshot-_.git-15-neo-look.png` | 🔴 Pending | |
| 9 | `imageSnapshot-_.git-16-redux-theme.png` | 🔴 Pending | |
| 10 | `imageSnapshot-_.git-17-parallel-commits.png` | 🔴 Pending | |
| 11 | `imageSnapshot-_.git-18-branch-order-complex.png` | 🔴 Pending | |

## Ishikawa (1 file)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.ishikawa-simple.png` | 🔴 Pending | |

## Journey (3 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.journey-1.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.journey-2.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.journey-3.png` | 🔴 Pending | |

## Mindmaps (2 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.mindmap-1-simple.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.mindmap-7-siblings.png` | 🔴 Pending | |

## Pie Charts (14 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.pie-1-basic.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.pie-2-showData.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.pie-3-title-inline.png` | 🔴 Pending | |
| 4 | `imageSnapshot-_.pie-4-title-newline.png` | 🔴 Pending | |
| 5 | `imageSnapshot-_.pie-5-accTitle-inline.png` | 🔴 Pending | |
| 6 | `imageSnapshot-_.pie-6-accDescr-inline.png` | 🔴 Pending | |
| 7 | `imageSnapshot-_.pie-7-accTitle-subsequent.png` | 🔴 Pending | |
| 8 | `imageSnapshot-_.pie-8-accDescr-multiline.png` | 🔴 Pending | |
| 9 | `imageSnapshot-_.pie-9-decimal.png` | 🔴 Pending | |
| 10 | `imageSnapshot-_.pie-10-zero.png` | 🔴 Pending | |
| 11 | `imageSnapshot-_.pie-11-all-zero.png` | 🔴 Pending | |
| 12 | `imageSnapshot-_.pie-12-single-quoted.png` | 🔴 Pending | |
| 13 | `imageSnapshot-_.pie-13-many.png` | 🔴 Pending | |
| 14 | `imageSnapshot-_.pie-14-config.png` | 🔴 Pending | |

## Quadrant Charts (12 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.quadrant-1-empty.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.quadrant-2-docs-example.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.quadrant-3-single-axis.png` | 🔴 Pending | |
| 4 | `imageSnapshot-_.quadrant-4-trailing-delimiter.png` | 🔴 Pending | |
| 5 | `imageSnapshot-_.quadrant-5-no-points.png` | 🔴 Pending | |
| 6 | `imageSnapshot-_.quadrant-6-with-points.png` | 🔴 Pending | |
| 7 | `imageSnapshot-_.quadrant-7-point-styles.png` | 🔴 Pending | |
| 8 | `imageSnapshot-_.quadrant-8-class-styles.png` | 🔴 Pending | |
| 9 | `imageSnapshot-_.quadrant-9-unicode.png` | 🔴 Pending | |
| 10 | `imageSnapshot-_.quadrant-10-frontmatter.png` | 🔴 Pending | |
| 11 | `imageSnapshot-_.quadrant-11-edge-coords.png` | 🔴 Pending | |
| 12 | `imageSnapshot-_.quadrant-12-accessibility.png` | 🔴 Pending | |

## Sequence Diagrams (16 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.seq-1-basic.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.seq-2-aliases.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.seq-3-actors.png` | 🔴 Pending | |
| 4 | `imageSnapshot-_.seq-4-arrow-types.png` | 🔴 Pending | |
| 5 | `imageSnapshot-_.seq-5-activations.png` | 🔴 Pending | |
| 6 | `imageSnapshot-_.seq-6-self-messages.png` | 🔴 Pending | |
| 7 | `imageSnapshot-_.seq-7-loop.png` | 🔴 Pending | |
| 8 | `imageSnapshot-_.seq-10-par.png` | 🔴 Pending | |
| 9 | `imageSnapshot-_.seq-11-critical.png` | 🔴 Pending | |
| 10 | `imageSnapshot-_.seq-12-notes.png` | 🔴 Pending | |
| 11 | `imageSnapshot-_.seq-13-oauth.png` | 🔴 Pending | |
| 12 | `imageSnapshot-_.seq-14-db-transaction.png` | 🔴 Pending | |
| 13 | `imageSnapshot-_.seq-15-microservice.png` | 🔴 Pending | |
| 14 | `imageSnapshot-_.seq-16-self-notes.png` | 🔴 Pending | |
| 15 | `imageSnapshot-_.seq-17-reverse-arrows.png` | 🔴 Pending | |
| 16 | `imageSnapshot-_.seq-20-lifecycle.png` | 🔴 Pending | |

## State Diagrams (8 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.state-1-basic.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.state-3-connection-lifecycle.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.state-4-cjk.png` | 🔴 Pending | |
| 4 | `imageSnapshot-_.state-5-standalone.png` | 🔴 Pending | |
| 5 | `imageSnapshot-_.state-6-choice-fork.png` | 🔴 Pending | |
| 6 | `imageSnapshot-_.state-8-notes.png` | 🔴 Pending | |
| 7 | `imageSnapshot-_.state-10-click.png` | 🔴 Pending | |
| 8 | `imageSnapshot-_.state-12-complex.png` | 🔴 Pending | |

## Treemap (1 file)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.treemap-basic.png` | 🔴 Pending | |

## Treeview (2 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.treeview-annotations.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.treeview-icons.png` | 🔴 Pending | |

## XY Charts (26 files)

| # | Snapshot | Status | Reviewer Comments |
|---|----------|--------|-------------------|
| 1 | `imageSnapshot-_.xychart-1-bar.png` | 🔴 Pending | |
| 2 | `imageSnapshot-_.xychart-2-line.png` | 🔴 Pending | |
| 3 | `imageSnapshot-_.xychart-3-bar-line.png` | 🔴 Pending | |
| 4 | `imageSnapshot-_.xychart-4-horizontal.png` | 🔴 Pending | |
| 5 | `imageSnapshot-_.xychart-5-multi-bar.png` | 🔴 Pending | |
| 6 | `imageSnapshot-_.xychart-6-dual-lines.png` | 🔴 Pending | |
| 7 | `imageSnapshot-_.xychart-7-numeric-x.png` | 🔴 Pending | |
| 8 | `imageSnapshot-_.xychart-8-12month.png` | 🔴 Pending | |
| 9 | `imageSnapshot-_.xychart-9-horizontal-combined.png` | 🔴 Pending | |
| 10 | `imageSnapshot-_.xychart-10-burndown.png` | 🔴 Pending | |
| 11 | `imageSnapshot-_.xychart-11-simplest.png` | 🔴 Pending | |
| 12 | `imageSnapshot-_.xychart-12-unquoted-title.png` | 🔴 Pending | |
| 13 | `imageSnapshot-_.xychart-13-titled-series.png` | 🔴 Pending | |
| 14 | `imageSnapshot-_.xychart-14-quoted-cats.png` | 🔴 Pending | |
| 15 | `imageSnapshot-_.xychart-15-accessibility.png` | 🔴 Pending | |
| 16 | `imageSnapshot-_.xychart-16-vertical-explicit.png` | 🔴 Pending | |
| 17 | `imageSnapshot-_.xychart-17-numeric-x-axis.png` | 🔴 Pending | |
| 18 | `imageSnapshot-_.xychart-18-config-size.png` | 🔴 Pending | |
| 19 | `imageSnapshot-_.xychart-19-data-labels.png` | 🔴 Pending | |
| 20 | `imageSnapshot-_.xychart-20-data-labels-outside.png` | 🔴 Pending | |
| 21 | `imageSnapshot-_.xychart-21-horizontal-data-labels.png` | 🔴 Pending | |
| 22 | `imageSnapshot-_.xychart-22-theme-palette.png` | 🔴 Pending | |
| 23 | `imageSnapshot-_.xychart-23-hidden-axis-elements.png` | 🔴 Pending | |
| 24 | `imageSnapshot-_.xychart-24-multi-line-data.png` | 🔴 Pending | |
| 25 | `imageSnapshot-_.xychart-25-multiline-accdescr.png` | 🔴 Pending | |
| 26 | `imageSnapshot-_.xychart-26-negative-values.png` | 🔴 Pending | |

---

## Progress Summary

| Diagram Type | Total | Pending | Pass | Needs Review | Fail |
|-------------|-------|---------|------|-------------|------|
| Class | 36 | 0 | 0 | 0 | 36 |
| ER | 7 | 7 | 0 | 0 | 0 |
| Flowchart | 19 | 19 | 0 | 0 | 0 |
| Gantt | 3 | 3 | 0 | 0 | 0 |
| Git | 11 | 11 | 0 | 0 | 0 |
| Ishikawa | 1 | 1 | 0 | 0 | 0 |
| Journey | 3 | 3 | 0 | 0 | 0 |
| Mindmap | 2 | 2 | 0 | 0 | 0 |
| Pie | 14 | 14 | 0 | 0 | 0 |
| Quadrant | 12 | 12 | 0 | 0 | 0 |
| Sequence | 16 | 16 | 0 | 0 | 0 |
| State | 8 | 8 | 0 | 0 | 0 |
| Treemap | 1 | 1 | 0 | 0 | 0 |
| Treeview | 2 | 2 | 0 | 0 | 0 |
| XY Chart | 26 | 26 | 0 | 0 | 0 |
| **Total** | **161** | **125** | **0** | **0** | **36** |
