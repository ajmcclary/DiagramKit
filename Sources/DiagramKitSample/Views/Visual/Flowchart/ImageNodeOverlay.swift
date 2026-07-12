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
import DiagramKitSampleDesignSystem

@MainActor
final class RemoteImageCache {
    enum Entry {
        case loaded(BMImage)
        case failed
    }

    static let shared = RemoteImageCache()
    private var cache: [String: Entry] = [:]
    /// In-flight fetches keyed by URL, so concurrent requests for the same
    /// image share one download instead of the second caller getting a
    /// premature `.failed` (which showed a spurious badge on a duplicate node).
    private var inFlight: [String: Task<Entry, Never>] = [:]
    /// Cap on cached entries so a document that references many image URLs
    /// can't grow the cache without bound for the life of the process.
    private let maxEntries = 64

    func entry(for urlString: String) -> Entry? { cache[urlString] }

    func load(_ urlString: String) async -> Entry {
        if let hit = cache[urlString] { return hit }
        if let existing = inFlight[urlString] { return await existing.value }

        let task = Task<Entry, Never> {
            guard let url = URL(string: urlString) else { return .failed }
            do {
                // Bounded + scheme/host-validated fetch (see RemoteFetch).
                let (data, http) = try await RemoteFetch.boundedData(from: url)
                guard (200..<300).contains(http.statusCode),
                      let image = BMImage(data: data) else {
                    return .failed
                }
                return .loaded(image)
            } catch {
                return .failed
            }
        }
        inFlight[urlString] = task
        let result = await task.value
        inFlight[urlString] = nil
        cache[urlString] = result
        evictIfNeeded()
        return result
    }

    private func evictIfNeeded() {
        guard cache.count > maxEntries else { return }
        for key in cache.keys.prefix(cache.count - maxEntries) {
            cache.removeValue(forKey: key)
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
                DSIconView(.warning, size: DSTokens.Icon.micro, colorRole: .warning)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(DSTokens.Spacing.xxs)
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
