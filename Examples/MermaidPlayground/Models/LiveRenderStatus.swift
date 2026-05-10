//
//  LiveRenderStatus.swift
//  MermaidPlayground
//
//  Tracks where the current preview render is in its lifecycle.
//

import Foundation

/// The render state of the live preview.
///
/// The store drives this state machine:
/// ```
/// idle ──(setSource/setTheme)──► rendering ──(success)──► rendered
///                                   │                      │
///                                   │                      │
///                                   ▼                      ▼
///                                failed ◄──(new edit)── rendering
/// ```
public enum LiveRenderStatus: Equatable, Sendable {

    /// No diagram to render (empty source).
    case idle

    /// A render has been requested and the debounce timer is running.
    case pending

    /// A render is executing on a background thread.
    case rendering

    /// The most recent render completed successfully.
    case rendered

    /// The most recent render failed (parse error, layout error, etc.).
    /// The last valid preview stays visible in a dimmed state.
    case failed
}
