//
//  SectionHeader.swift
//  DiagramPlayground
//
//  Uppercase overline header used by every inspector section and
//  sidebar group, with optional leading icon, trailing chip text,
//  and disclosure caret.
//

import SwiftUI

struct SectionHeader<Trailing: View>: View {
    var title: String
    var systemImage: String?
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.playgroundTokens) private var tokens

    init(
        _ title: String,
        systemImage: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: PlaygroundSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tokens.palette.fg2)
            }
            Text(title.uppercased())
                .font(PlaygroundFont.overline)
                .tracking(0.4)
                .foregroundStyle(tokens.palette.fg2)
            Spacer(minLength: PlaygroundSpacing.xs)
            trailing()
        }
        .padding(.bottom, 2)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, systemImage: String? = nil) {
        self.init(title, systemImage: systemImage, trailing: { EmptyView() })
    }
}
