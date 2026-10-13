// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitCommon
import DiagramKitModel
import CoreText
import os

/// Soft failure log for bundled-font registration gaps (M-CG-8). Failures
/// are environmental in the common case (host bundle layout without the
/// font resources), so they go to the unified log instead of the
/// issue-reporting channel, which would fail host XCTest runs.
private let _fontFailureLog = Logger(subsystem: "DiagramKit", category: "fonts")

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
public enum DiagramFontRegistry {
    private static let lock = NSLock()
    /// Guarded by `lock` (NSLock). All reads and mutations of `didRegister`
    /// must hold the lock — see `registerBundledFontsIfNeeded()` below.
    private nonisolated(unsafe) static var didRegister = false
    /// Families whose bundled font files registered successfully with the
    /// process-wide CTFontManager. Guarded by `lock`.
    private nonisolated(unsafe) static var registeredFamilies: [String] = []

    /// The bundled font families that are actually registered with the
    /// process-wide CTFontManager — empty when the bundled resources are
    /// missing or every registration failed (M-CG-8; previously this
    /// returned a constant list regardless of registration outcome).
    /// Ensures registration has run, then returns the recorded families.
    public static var registeredFontNames: [String] {
        registerBundledFontsIfNeeded()
        lock.lock()
        defer { lock.unlock() }
        return registeredFamilies
    }

    /// Registers Noto Sans + Noto Sans Mono with the process-wide CTFontManager.
    ///
    /// Idempotent and thread-safe. Subsequent calls are a single locked bool
    /// check, so it is safe (and intended) to call from any render entry point.
    ///
    /// Registration results are honored (M-CG-8): a failed registration does
    /// not add its family to ``registeredFontNames`` and is logged to the
    /// unified log (`DiagramKit/fonts`). Failures are logged rather than
    /// routed through `_reportDiagramIssue` because the common failure mode
    /// is environmental (a host bundle layout that does not carry the font
    /// resources) — an issue report there would fail every host XCTest run.
    public static func registerBundledFontsIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !didRegister else { return }
        defer { didRegister = true }

        // (bundle resource path, family the file belongs to)
        let fontFiles: [(path: String, family: String)] = [
            ("Fonts/noto-sans/NotoSans-Regular.otf", "Noto Sans"),
            ("Fonts/noto-sans/NotoSans-Bold.otf", "Noto Sans"),
            ("Fonts/noto-sans/NotoSans-Italic.otf", "Noto Sans"),
            ("Fonts/noto-sans/NotoSans-BoldItalic.otf", "Noto Sans"),
            ("Fonts/noto-sans-mono/NotoSansMono-Regular.ttf", "Noto Sans Mono"),
            ("Fonts/noto-sans-mono/NotoSansMono-Bold.ttf", "Noto Sans Mono"),
        ]

        guard let resourceRoot = Bundle.module.resourceURL else {
            _fontFailureLog.error("DiagramFontRegistry: bundled font resources are missing (no module resource URL); text rendering will fall back to system fonts.")
            return
        }

        var registered = Set<String>()
        for file in fontFiles {
            // Try both layouts: flat (resource at `Fonts/...`) and the
            // `.copy("Resources")` layout SwiftPM produces in some Xcode
            // bundle configurations, where the on-disk `Resources/`
            // directory is preserved as `Resources/Fonts/...` inside the
            // bundle. Without the second candidate, fonts silently fail to
            // register when the package is consumed via Xcode.
            let candidates = [
                resourceRoot.appendingPathComponent(file.path),
                resourceRoot.appendingPathComponent("Resources/\(file.path)"),
            ]
            var registeredURL = false
            for url in candidates
            where FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                // Returns `false` on failure (details go to the optional
                // out-error, which the log below carries).
                var registrationError: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registrationError) {
                    registeredURL = true
                    break
                }
                let detail = registrationError?.takeRetainedValue().localizedDescription ?? "unknown error"
                _fontFailureLog.error("DiagramFontRegistry: CTFontManagerRegisterFontsForURL failed for \(url.path, privacy: .public): \(detail, privacy: .public)")
            }
            if registeredURL {
                registered.insert(file.family)
            } else {
                _fontFailureLog.error("DiagramFontRegistry: could not register \(file.path, privacy: .public) (missing resource or CTFontManager rejection); the '\(file.family, privacy: .public)' family is not registered and rendering falls back to system fonts.")
            }
        }
        // Stable order regardless of per-file success.
        registeredFamilies = ["Noto Sans", "Noto Sans Mono"].filter { registered.contains($0) }
    }
}

#endif
