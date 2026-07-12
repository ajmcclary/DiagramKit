//
//  SectionHeader.swift
//  DiagramPlayground
//
//  Uppercase overline header used by every inspector section and
//  sidebar group, with optional leading icon, trailing chip text,
//  and disclosure caret.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SectionHeader<Trailing: View>: View {
    var title: String
    var systemImage: String?
    @ViewBuilder var trailing: () -> Trailing

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
        HStack(spacing: DSTokens.Spacing.xs) {
            DSSectionHeader(title)
            Spacer(minLength: DSTokens.Spacing.xs)
            trailing()
        }
        .padding(.bottom, DSTokens.Spacing.xxxs)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, systemImage: String? = nil) {
        self.init(title, systemImage: systemImage, trailing: { EmptyView() })
    }
}
