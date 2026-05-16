//
//  Surface.swift
//  DiagramPlayground
//
//  Reusable card / popover container. Centralizes corner radius,
//  border, shadow, and optional blur so every panel matches the
//  v2.1 mockup.
//

import SwiftUI

enum SurfaceStyle {
    case card       // flat surface used inside inspector sections
    case elevated   // popover-style with shadow
    case sunken     // depressed background, e.g. code editor frame
    case glass      // translucent blur, used for floating toolbars
}

struct Surface<Content: View>: View {
    var style: SurfaceStyle
    var radius: CGFloat
    var padding: CGFloat?
    var stroke: Bool
    @ViewBuilder var content: () -> Content

    @Environment(\.playgroundTokens) private var tokens

    init(
        _ style: SurfaceStyle = .card,
        radius: CGFloat = PlaygroundRadius.lg,
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
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content()
            .padding(padding ?? PlaygroundSpacing.md)
            .background(background(in: shape))
            .overlay {
                if stroke {
                    shape.stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                }
            }
            .modifier(SurfaceShadow(style: style))
    }

    @ViewBuilder
    private func background(in shape: RoundedRectangle) -> some View {
        switch style {
        case .card:
            shape.fill(tokens.palette.bgSurface)
        case .elevated:
            shape.fill(tokens.palette.bgElevated)
        case .sunken:
            shape.fill(tokens.palette.bgSunken)
        case .glass:
            shape.fill(tokens.palette.glassBg)
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

private struct SurfaceShadow: ViewModifier {
    var style: SurfaceStyle

    func body(content: Content) -> some View {
        switch style {
        case .card:
            content.shadow(color: PlaygroundShadow.card.color,
                           radius: PlaygroundShadow.card.radius,
                           x: PlaygroundShadow.card.x,
                           y: PlaygroundShadow.card.y)
        case .elevated:
            content.shadow(color: PlaygroundShadow.elevated.color,
                           radius: PlaygroundShadow.elevated.radius,
                           x: PlaygroundShadow.elevated.x,
                           y: PlaygroundShadow.elevated.y)
        case .glass:
            content.shadow(color: PlaygroundShadow.dropdown.color,
                           radius: PlaygroundShadow.dropdown.radius,
                           x: PlaygroundShadow.dropdown.x,
                           y: PlaygroundShadow.dropdown.y)
        case .sunken:
            content
        }
    }
}
