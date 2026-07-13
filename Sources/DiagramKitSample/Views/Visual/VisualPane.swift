//
//  VisualPane.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.2 — root view for the Visual workspace mode. Hosts
//  family dispatch (Flowchart in Phase 3; sequence + gantt in Phase 4),
//  the floating VisualToolPalette, the SelectionHUD, the optional
//  StateStepper demo widget (Task 3.6), and the bottom UndoTimeline
//  strip (Task 3.6).
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DiagramKitInteractive
import DesignKitThemes

struct VisualPane: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        ZStack(alignment: .topLeading) {
            family
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(A11yID.Visual.pane)

            VStack {
                HStack(alignment: .top) {
                    VisualToolPalette(store: store)
                        .padding(.leading, Tokens.Spacing.md)
                        .padding(.top, Tokens.Spacing.md)
                    Spacer()
                    SelectionHUD(store: store)
                        .padding(.trailing, Tokens.Spacing.md)
                        .padding(.top, Tokens.Spacing.md)
                }
                Spacer()
                if store.state.demoStepperVisible {
                    StateStepper(store: store)
                        .padding(.bottom, Tokens.Spacing.sm)
                }
                if let editor = store.visualEditor,
                   editor.document.type == .flowchart || editor.document.type == .stateDiagram {
                    CanvasCenterToolbar(store: store)
                        .padding(.bottom, Tokens.Spacing.sm)
                }
                HStack {
                    UndoTimelineView(store: store)
                    Spacer()
                }
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.bottom, Tokens.Spacing.md)
            }

            stageBanner

            stagePopover

            subgraphLayer
        }
    }

    @ViewBuilder
    private var subgraphLayer: some View {
        // Bottom-trailing toast.
        if let commit = store.lastSubgraphCommit {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    SubgraphCommitToast(store: store, commit: commit)
                        .padding(.trailing, Tokens.Spacing.md)
                        .padding(.bottom, 60)
                }
            }
        }

        // Centered prompt sheet.
        if store.isSubgraphPromptOpen {
            ZStack {
                theme.colors.surfaceBackground.color.opacity(Tokens.Opacity.strong)
                    .ignoresSafeArea()
                    .onTapGesture { store.cancelSubgraphPrompt() }
                SubgraphPromptSheet(store: store)
            }
        }

        // Title prompt (empty-subgraph insert / rename).
        if let prompt = store.subgraphTitlePrompt {
            ZStack {
                theme.colors.surfaceBackground.color.opacity(Tokens.Opacity.strong)
                    .ignoresSafeArea()
                    .onTapGesture { store.cancelTitlePrompt() }
                SubgraphTitleSheet(store: store, prompt: prompt)
            }
        }

        // Image-URL sheet.
        if store.isImageSheetOpen {
            ZStack {
                theme.colors.surfaceBackground.color.opacity(Tokens.Opacity.strong)
                    .ignoresSafeArea()
                    .onTapGesture { store.cancelImageSheet() }
                ImageURLSheet(store: store)
            }
        }
    }

    @ViewBuilder
    private var stagePopover: some View {
        switch store.state.visualStage {
        case .labelEdited:
            VStack {
                Spacer()
                if store.editor?.selection?.elementID.hasPrefix("edge:") == true {
                    EdgeEditPopover(store: store)
                        .padding(.bottom, 60)
                } else {
                    NodeEditPopover(store: store)
                        .padding(.bottom, 60)
                }
            }
        default:
            EmptyView()
        }

        if !store.diagnostics.isEmpty {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    QuickFixCard(store: store)
                        .padding(.trailing, Tokens.Spacing.md)
                        .padding(.bottom, 60)
                }
            }
        }
    }

    @ViewBuilder
    private var family: some View {
        if let editor = store.visualEditor {
            switch editor.document.type {
            case .flowchart, .stateDiagram:
                FlowchartEditCanvas(store: store)
            case .sequenceDiagram:
                SequenceEditCanvas(store: store)
            case .gantt:
                GanttEditCanvas(store: store)
            default:
                unsupportedFamily(editor.document.type)
            }
        } else {
            // No editor yet (parse not run). Reuse the preview surface, which
            // already carries the full zoom/pan/toolbar stack, so Editor mode
            // always supports zoom/pan even before the editor is populated.
            PreviewCanvas(store: store, onFullWindowPreview: nil)
        }
    }

    @ViewBuilder
    private var stageBanner: some View {
        let stage = store.state.visualStage
        let label = stage.label
        if stage != .idle {
            VStack {
                HStack {
                    Spacer()
                    DSGlassSurface(role: .popover) {
                        Text(label)
                            .dsFont(.badge)
                            .padding(.horizontal, Tokens.Spacing.smMd)
                            .padding(.vertical, Tokens.Spacing.xxs)
                            .foregroundStyle(theme.colors.textSecondary.color)
                    }
                        .accessibilityIdentifier(A11yID.Visual.stateBanner(stage.rawValue))
                    Spacer()
                }
                .padding(.top, Tokens.Size.Icon.xxl + Tokens.Spacing.sm)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func unsupportedFamily(_ type: DiagramType) -> some View {
        VStack(spacing: Tokens.Spacing.sm) {
            DSIconView(.diagram, size: Tokens.Size.Icon.lg, colorRole: .muted)
            Text("Visual mode for \(type.rawValue) is coming in Phase 4.")
                .dsFont(.caption)
                .foregroundStyle(theme.colors.textSecondary.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(store.theme.background))
    }
}
