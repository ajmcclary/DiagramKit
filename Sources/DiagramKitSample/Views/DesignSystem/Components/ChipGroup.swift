//
//  ChipGroup.swift
//  DiagramPlayground
//
//  Segmented horizontal row of pills. Used for format chips,
//  state-machine steppers, style-class pickers, render-backend
//  selectors. Supports single- or multi-select.
//

import SwiftUI

struct ChipGroup<Value: Hashable>: View {
    var items: [ChipItem<Value>]
    @Binding var selection: Set<Value>
    var allowsMultipleSelection: Bool
    var allowsDeselection: Bool

    @Environment(\.playgroundTokens) private var tokens

    init(
        items: [ChipItem<Value>],
        selection: Binding<Set<Value>>,
        allowsMultipleSelection: Bool = false,
        allowsDeselection: Bool = false
    ) {
        self.items = items
        self._selection = selection
        self.allowsMultipleSelection = allowsMultipleSelection
        self.allowsDeselection = allowsDeselection
    }

    /// Single-select convenience.
    init(
        items: [ChipItem<Value>],
        selection: Binding<Value>
    ) {
        self.items = items
        self._selection = Binding(
            get: { [selection.wrappedValue] },
            set: { newValue in
                if let only = newValue.first { selection.wrappedValue = only }
            }
        )
        self.allowsMultipleSelection = false
        self.allowsDeselection = false
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.value) { item in
                chip(for: item)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: PlaygroundRadius.chip + 3, style: .continuous)
                .fill(tokens.palette.bgSurface.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: PlaygroundRadius.chip + 3, style: .continuous)
                        .stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func chip(for item: ChipItem<Value>) -> some View {
        let isSelected = selection.contains(item.value)
        Button {
            toggle(item.value)
        } label: {
            HStack(spacing: 4) {
                if let leadingDotColor = item.dotColor {
                    Circle()
                        .fill(leadingDotColor)
                        .frame(width: 6, height: 6)
                }
                if let systemImage = item.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(item.label)
                    .font(PlaygroundFont.label)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(isSelected ? tokens.palette.fg1 : tokens.palette.fg2)
            .background(
                RoundedRectangle(cornerRadius: PlaygroundRadius.chip, style: .continuous)
                    .fill(isSelected ? tokens.palette.rowSelected : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ value: Value) {
        if selection.contains(value) {
            if allowsDeselection || (allowsMultipleSelection && selection.count > 1) {
                selection.remove(value)
            }
        } else {
            if !allowsMultipleSelection {
                selection.removeAll()
            }
            selection.insert(value)
        }
    }
}

struct ChipItem<Value: Hashable>: Hashable {
    var value: Value
    var label: String
    var systemImage: String?
    var dotColor: Color?

    init(value: Value, label: String, systemImage: String? = nil, dotColor: Color? = nil) {
        self.value = value
        self.label = label
        self.systemImage = systemImage
        self.dotColor = dotColor
    }
}
