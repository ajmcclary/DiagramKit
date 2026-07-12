//
//  Surface.swift
//  DiagramPlayground
//
//  Reusable card / popover container. Centralizes corner radius,
//  border, shadow, and optional blur so every panel matches the
//  v2.1 mockup.
//

import SwiftUI
import DiagramKitSampleDesignSystem

enum SurfaceStyle {
    case card       // flat surface used inside inspector sections
    case elevated   // popover-style with shadow
    case sunken     // depressed background, e.g. code editor frame
    // Floating-toolbar glass now lives in `.glassChrome` (real Liquid Glass);
    // the old `.glass` Surface case (a solid `glassBg` fill) was unused and
    // removed with the `glassBg` token.
}

struct Surface<Content: View>: View {
    var style: SurfaceStyle
    var radius: CGFloat
    var padding: CGFloat?
    var stroke: Bool
    @ViewBuilder var content: () -> Content

    init(
        _ style: SurfaceStyle = .card,
        radius: CGFloat = DSTokens.Radius.lg,
        padding: CGFloat? = nil,
        stroke: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.radius = radius
        self.padding = padding
        self.stroke = stroke
        self.content = content
    }

    var body: some View {
        DSSurface(role: role) {
            content()
                .padding(padding ?? DSTokens.Spacing.md)
        }
    }

    private var role: DSSurfaceRole {
        switch style {
        case .card: .card
        case .elevated: .popover
        case .sunken: .sunken
        }
    }
}
