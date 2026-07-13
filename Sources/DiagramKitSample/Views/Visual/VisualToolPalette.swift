//
//  VisualToolPalette.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.2 — vertical floating tool strip (Select / Pan /
//  Marquee / Connector + divider + Undo / Redo). Bound to
//  store.state.visualTool and the persistent editor's undo manager.
//

import SwiftUI
import DesignKitThemes

struct VisualToolPalette: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        DSGlassSurface(role: .toolbar) {
        VStack(spacing: Tokens.Spacing.xxs) {
            ForEach(VisualEditorState.Tool.allCases, id: \.self) { tool in
                toolButton(for: tool)
            }
            Divider()
                .frame(width: 22)
                .padding(.vertical, Tokens.Spacing.xxxs)
            undoButton
            redoButton
            if !store.state.marqueeSelection.isEmpty {
                Divider()
                    .frame(width: 22)
                    .padding(.vertical, Tokens.Spacing.xxxs)
                groupButton
            }
        }
        .padding(Tokens.Spacing.xs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.toolPalette)
    }

    private func toolButton(for tool: VisualEditorState.Tool) -> some View {
        let isOn = store.state.visualTool == tool
        return Button {
            store.setVisualTool(tool)
        } label: {
            DSIconView(
                icon(for: tool),
                size: Tokens.Size.Icon.xs,
                colorRole: isOn ? .onAccent : .muted
            )
                .frame(width: Tokens.Size.Control.height, height: Tokens.Size.Control.height)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
                        .fill(
                            isOn
                                ? theme.colors.accent.color
                                : Color.clear
                        )
                )
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .help(tool.label)
        .a11yToggle(
            label: LocalizedStringKey(tool.label),
            isOn: isOn,
            id: A11yID.Visual.tool(tool.rawValue)
        )
    }

    private var undoButton: some View {
        let canUndo = store.editor?.canUndo ?? false
        return Button {
            store.undoStructural()
            store.setVisualStage(.undone)
        } label: {
            DSIconView(.undo, colorRole: .muted)
                .frame(width: Tokens.Size.Control.height, height: Tokens.Size.Control.height)
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .disabled(!canUndo)
        .opacity(canUndo ? 1 : Tokens.Opacity.disabled)
        .help(store.editor?.undoActionName ?? "Undo")
        .a11y(label: "Undo", id: A11yID.Visual.tool("undo"))
    }

    private var redoButton: some View {
        let canRedo = store.editor?.canRedo ?? false
        return Button {
            store.redoStructural()
        } label: {
            DSIconView(.redo, colorRole: .muted)
                .frame(width: Tokens.Size.Control.height, height: Tokens.Size.Control.height)
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .disabled(!canRedo)
        .opacity(canRedo ? 1 : Tokens.Opacity.disabled)
        .help(store.editor?.redoActionName ?? "Redo")
        .a11y(label: "Redo", id: A11yID.Visual.tool("redo"))
    }

    private var groupButton: some View {
        Button {
            store.openSubgraphPrompt()
        } label: {
            DSIconView(.subgraph, colorRole: .info)
                .frame(width: Tokens.Size.Control.height, height: Tokens.Size.Control.height)
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .help("Group selected nodes into a subgraph")
        .a11y(label: "Group selection", id: A11yID.Visual.groupButton)
    }

    private func icon(for tool: VisualEditorState.Tool) -> DSIcon {
        switch tool {
        case .select: .cursor
        case .pan: .pan
        case .marquee: .marquee
        case .connector: .connector
        }
    }
}
