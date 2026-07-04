//
//  ImageNodeOverlay.swift
//  DiagramPlayground
//
//  Visual editor plan 5 — composites real bitmaps over the CG
//  renderer's deterministic image placeholders. All network access
//  lives HERE, in the sample app's view layer; the core pipeline
//  never fetches.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

@MainActor
final class RemoteImageCache {
    enum Entry {
        case loaded(BMImage)
        case failed
    }

    static let shared = RemoteImageCache()
    private var cache: [String: Entry] = [:]
    private var inFlight: Set<String> = []

    func entry(for urlString: String) -> Entry? { cache[urlString] }

    func load(_ urlString: String) async -> Entry {
        if let hit = cache[urlString] { return hit }
        guard !inFlight.contains(urlString), let url = URL(string: urlString) else {
            return cache[urlString] ?? .failed
        }
        inFlight.insert(urlString)
        defer { inFlight.remove(urlString) }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard
                let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                let image = BMImage(data: data)
            else {
                cache[urlString] = .failed
                return .failed
            }
            cache[urlString] = .loaded(image)
            return .loaded(image)
        } catch {
            cache[urlString] = .failed
            return .failed
        }
    }
}

/// One node's composited image (or failure badge).
struct ImageNodeOverlayItem: View {
    let urlString: String
    let rect: CGRect

    @SwiftUI.State private var entry: RemoteImageCache.Entry?

    var body: some View {
        Group {
            switch entry {
            case .loaded(let image):
                #if canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(4)
            case nil:
                Color.clear
            }
        }
        .frame(width: max(rect.width - 8, 1), height: max(rect.height - 8, 1))
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .task(id: urlString) {
            entry = await RemoteImageCache.shared.load(urlString)
        }
    }
}
