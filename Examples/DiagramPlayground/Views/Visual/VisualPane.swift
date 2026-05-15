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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct VisualPane: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        ZStack(alignment: .topLeading) {
            family
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(A11yID.Visual.pane)

            VStack {
                HStack(alignment: .top) {
                    VisualToolPalette(store: store)
                        .padding(.leading, 12)
                        .padding(.top, 12)
                    Spacer()
                    SelectionHUD(store: store)
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                }
                Spacer()
                if store.state.demoStepperVisible {
                    StateStepper(store: store)
                        .padding(.bottom, 8)
                }
                UndoTimelineView(store: store)
                    .padding(.bottom, 8)
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
                        .padding(.trailing, 12)
                        .padding(.bottom, 60)
                }
            }
        }

        // Centered prompt sheet.
        if store.isSubgraphPromptOpen {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { store.cancelSubgraphPrompt() }
                SubgraphPromptSheet(store: store)
            }
        }
    }

    @ViewBuilder
    private var stagePopover: some View {
        switch store.state.visualStage {
        case .labelEdited:
            VStack {
                Spacer()
                NodeEditPopover(store: store)
                    .padding(.bottom, 60)
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
                        .padding(.trailing, 12)
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
            // No editor yet (parse not run). Surface DiagramView as a
            // read-only fallback so the user sees something during the
            // first render.
            DiagramView(
                source: store.previewSource,
                theme: store.previewTheme,
                layoutConfig: store.previewLayoutConfig,
                sourceFormat: store.state.sourceFormat.formatID
            )
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
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.regularMaterial))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(A11yID.Visual.stateBanner(stage.rawValue))
                    Spacer()
                }
                .padding(.top, 56)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func unsupportedFamily(_ type: DiagramType) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Visual mode for \(type.rawValue) is coming in Phase 4.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(store.theme.background))
    }
}
