import Foundation
import CoreText

/// Registers BeautifulMermaid's bundled fonts (Noto Sans family + Noto Sans Mono)
/// with the process-wide CTFontManager.
///
/// Snapshot-image determinism depends on every host machine resolving identical
/// glyph outlines for a given (family, size, weight, italic) tuple. Apple's
/// system fonts (San Francisco, Menlo, etc.) drift across major OS updates, so
/// we bundle Noto Sans / Noto Sans Mono — both SIL OFL — and register them at
/// process load time. Once registered, `BMFont(name: "Noto Sans", size: …)`
/// and `BMFont(name: "Noto Sans Mono", size: …)` resolve to the bundled
/// glyphs regardless of what the host has installed.
///
/// The implementation mirrors `CoreGraphicsFontRegistry` in
/// `~/Workspace/packages/MusicToolkit/Sources/MusicToolkitRenderingCG/Canvas/CoreGraphicsCanvas.swift`.
public enum BeautifulMermaidFontRegistry {
    private static let lock = NSLock()
    /// Guarded by `lock` (NSLock). All reads and mutations of `didRegister`
    /// must hold the lock — see `registerBundledFontsIfNeeded()` below.
    private nonisolated(unsafe) static var didRegister = false

    /// Registers Noto Sans + Noto Sans Mono with the process-wide CTFontManager.
    ///
    /// Idempotent and thread-safe. Subsequent calls are a single locked bool
    /// check, so it is safe (and intended) to call from any render entry point.
    public static func registerBundledFontsIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !didRegister else { return }
        defer { didRegister = true }

        let fontPaths = [
            "Fonts/noto-sans/NotoSans-Regular.otf",
            "Fonts/noto-sans/NotoSans-Bold.otf",
            "Fonts/noto-sans/NotoSans-Italic.otf",
            "Fonts/noto-sans/NotoSans-BoldItalic.otf",
            "Fonts/noto-sans-mono/NotoSansMono-Regular.ttf",
            "Fonts/noto-sans-mono/NotoSansMono-Bold.ttf",
        ]

        guard let resourceRoot = Bundle.module.resourceURL else { return }

        for path in fontPaths {
            // Try both layouts: flat (resource at `Fonts/...`) and the
            // `.copy("Resources")` layout SwiftPM produces in some Xcode
            // bundle configurations, where the on-disk `Resources/`
            // directory is preserved as `Resources/Fonts/...` inside the
            // bundle. Without the second candidate, fonts silently fail to
            // register when the package is consumed via Xcode.
            let candidates = [
                resourceRoot.appendingPathComponent(path),
                resourceRoot.appendingPathComponent("Resources/\(path)"),
            ]
            for url in candidates
            where FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                break
            }
        }
    }
}
