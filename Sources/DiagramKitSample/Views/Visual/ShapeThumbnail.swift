//
//  ShapeThumbnail.swift
//  DiagramPlayground
//
//  True-to-pipeline shape preview: renders a one-node diagram
//  (`p[" "]@{ shape: <alias> }`) through DiagramImageRenderer and
//  caches the bitmap per alias. Previews can never drift from the
//  real renderer because they ARE the real renderer.
//
//  Cache note: DiagramTheme carries no identity/name, so the cache
//  keys on alias alone with the theme captured at first render. The
//  catalog always passes the store's current preview theme; a theme
//  switch mid-session serves slightly stale previews until relaunch,
//  which is acceptable for 44×32pt thumbnails.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

@MainActor
final class ShapeThumbnailCache {
    static let shared = ShapeThumbnailCache()
    private var cache: [String: BMImage] = [:]

    func image(alias: String, theme: DiagramTheme) async -> BMImage? {
        if let hit = cache[alias] { return hit }
        let source = "flowchart TD\n  p[\" \"]@{ shape: \(alias) }\n"
        let renderer = DiagramImageRenderer(theme: theme)
        renderer.scale = 2
        guard let image = try? await renderer.renderImage(from: source) else { return nil }
        cache[alias] = image
        return image
    }
}

struct ShapeThumbnail: View {
    let alias: String
    let theme: DiagramTheme

    @SwiftUI.State private var image: BMImage?

    var body: some View {
        Group {
            if let image {
                #if canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.08))
            }
        }
        .frame(width: 44, height: 32)
        .task(id: alias) {
            image = await ShapeThumbnailCache.shared.image(alias: alias, theme: theme)
        }
    }
}
