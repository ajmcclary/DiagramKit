//
//  KeyValueRow.swift
//  DiagramPlayground
//
//  Left label / right monospaced value pair used in DOCUMENT,
//  RENDER BACKEND, and PLATFORM inspector sections.
//

import SwiftUI

struct KeyValueRow<Value: View>: View {
    var key: String
    var copyableValue: String?
    @ViewBuilder var value: () -> Value

    @Environment(\.playgroundTokens) private var tokens
    @SwiftUI.State private var didCopy = false

    init(
        _ key: String,
        copyableValue: String? = nil,
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.key = key
        self.copyableValue = copyableValue
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PlaygroundSpacing.sm) {
            Text(key)
                .font(PlaygroundFont.caption)
                .foregroundStyle(tokens.palette.fg2)
            Spacer(minLength: PlaygroundSpacing.sm)
            value()
                .font(PlaygroundFont.metric)
                .foregroundStyle(tokens.palette.fg1)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
            if copyableValue != nil {
                copyButton
            }
        }
        .frame(minHeight: 22)
    }

    @ViewBuilder
    private var copyButton: some View {
        if let value = copyableValue {
            Button {
                copy(value)
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(didCopy ? tokens.palette.statusSuccess : tokens.palette.fg3)
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
    }

    private func copy(_ value: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = value
        #endif
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            didCopy = false
        }
    }
}

extension KeyValueRow where Value == Text {
    init(_ key: String, value: String, copyable: Bool = false) {
        self.init(key, copyableValue: copyable ? value : nil) {
            Text(value)
        }
    }
}

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif
