//
//  ChipGroup.swift
//  DiagramPlayground
//
//  Segmented horizontal row of pills. Used for format chips,
//  state-machine steppers, style-class pickers, render-backend
//  selectors. Supports single- or multi-select.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct ChipGroup<Value: Hashable>: View {
    var items: [ChipItem<Value>]
    @Binding var selection: Set<Value>
    var allowsMultipleSelection: Bool
    var allowsDeselection: Bool

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
        DSChipGroup {
            ForEach(items, id: \.value) { item in
                chip(for: item)
            }
        }
    }

    @ViewBuilder
    private func chip(for item: ChipItem<Value>) -> some View {
        let isSelected = selection.contains(item.value)
        DSChip(isSelected: isSelected) {
            toggle(item.value)
        } label: {
            HStack(spacing: DSTokens.Spacing.xxs) {
                if let leadingDotColor = item.dotColor {
                    Circle()
                        .fill(leadingDotColor)
                        .frame(width: DSTokens.Icon.indicator, height: DSTokens.Icon.indicator)
                }
                Text(item.label)
                    .dsFont(.badge)
            }
            .contentShape(Rectangle())
        }
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
