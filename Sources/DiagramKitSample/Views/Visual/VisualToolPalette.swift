//
//  VisualToolPalette.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.2 — vertical floating tool strip (Select / Pan /
//  Marquee / Connector + divider + Undo / Redo). Bound to
//  store.state.visualTool and the persistent editor's undo manager.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct VisualToolPalette: View {
    @Bindable var store: LiveEditorStore

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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
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
                .foregroundStyle(isOn ? Color.accentColor : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? Color.accentColor.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.plain)
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
        }
        .buttonStyle(.plain)
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
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .help("Group selected nodes into a subgraph")
        .a11y(label: "Group selection", id: A11yID.Visual.groupButton)
    }
}
