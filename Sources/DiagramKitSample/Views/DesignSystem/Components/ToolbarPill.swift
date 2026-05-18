//
//  ToolbarPill.swift
//  DiagramPlayground
//
//  Floating glass pill used by the canvas top toolbar: optional
//  leading status dot + label + optional trailing metric.
//

import SwiftUI

struct ToolbarPill: View {
    var label: String
    var dotColor: Color?
    var systemImage: String?
    var trailing: String?

    @Environment(\.playgroundTokens) private var tokens

    init(
        label: String,
        dotColor: Color? = nil,
        systemImage: String? = nil,
        trailing: String? = nil
    ) {
        self.label = label
        self.dotColor = dotColor
        self.systemImage = systemImage
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 6) {
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
            }
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tokens.palette.fg2)
            }
            Text(label)
                .font(PlaygroundFont.label)
                .foregroundStyle(tokens.palette.fg1)
            if let trailing {
                Text(trailing)
                    .font(PlaygroundFont.metric)
                    .foregroundStyle(tokens.palette.fg2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tokens.palette.glassBg)
                .overlay(
                    Capsule().stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                )
        )
    }
}
