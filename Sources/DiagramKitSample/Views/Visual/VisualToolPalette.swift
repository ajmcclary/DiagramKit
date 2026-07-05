//
//  VisualToolPalette.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.2 — vertical floating tool strip (Select / Pan /
//  Marquee / Connector + divider + Undo / Redo). Bound to
//  store.state.visualTool and the persistent editor's undo manager.
//

import SwiftUI

struct VisualToolPalette: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(spacing: 4) {
            ForEach(VisualEditorState.Tool.allCases, id: \.self) { tool in
                toolButton(for: tool)
            }
            Divider()
                .frame(width: 22)
                .padding(.vertical, 2)
            undoButton
            redoButton
            if !store.state.marqueeSelection.isEmpty {
                Divider()
                    .frame(width: 22)
                    .padding(.vertical, 2)
                groupButton
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tokens.palette.bgChrome.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.toolPalette)
    }

    private func toolButton(for tool: VisualEditorState.Tool) -> some View {
        let isOn = store.state.visualTool == tool
        return Button {
            store.setVisualTool(tool)
        } label: {
            Image(systemName: tool.sfSymbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .foregroundStyle(isOn ? tokens.palette.accent : tokens.palette.fg2)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? tokens.palette.accentTint16 : Color.clear)
                )
        }
        .buttonStyle(.playground)
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
            Image(systemName: "arrow.uturn.backward")
                .frame(width: 30, height: 30)
                .foregroundStyle(tokens.palette.fg2)
        }
        .buttonStyle(.playground)
        .disabled(!canUndo)
        .opacity(canUndo ? 1 : 0.35)
        .help(store.editor?.undoActionName ?? "Undo")
        .a11y(label: "Undo", id: A11yID.Visual.tool("undo"))
    }

    private var redoButton: some View {
        let canRedo = store.editor?.canRedo ?? false
        return Button {
            store.redoStructural()
        } label: {
            Image(systemName: "arrow.uturn.forward")
                .frame(width: 30, height: 30)
                .foregroundStyle(tokens.palette.fg2)
        }
        .buttonStyle(.playground)
        .disabled(!canRedo)
        .opacity(canRedo ? 1 : 0.35)
        .help(store.editor?.redoActionName ?? "Redo")
        .a11y(label: "Redo", id: A11yID.Visual.tool("redo"))
    }

    private var groupButton: some View {
        Button {
            store.openSubgraphPrompt()
        } label: {
            Image(systemName: "rectangle.stack.badge.plus")
                .frame(width: 30, height: 30)
                .foregroundStyle(tokens.palette.accent)
        }
        .buttonStyle(.playground)
        .help("Group selected nodes into a subgraph")
        .a11y(label: "Group selection", id: A11yID.Visual.groupButton)
    }
}
