import Foundation

/// Pins the Gantt "today" marker to a fixed date so Gantt renders are
/// deterministic regardless of when the suite runs. Honored by
/// `_ganttReferenceToday()` in `src_gantt_layout.swift`.
///
/// Every suite that renders a Gantt diagram (snapshot suites, ASCII
/// structural sweeps, layout/renderer unit tests) must call `set()` before
/// its first render. The variable is deliberately never unset: SwiftPM runs
/// the swift-testing suites in parallel inside one process, and an
/// `unsetenv` from one test body would race a concurrently rendering
/// corpus snapshot. A single shared constant keeps the pin consistent.
enum GanttTodayEnv {
    /// The pinned reference date (YYYY-MM-DD) shared by all Gantt suites.
    static let isoDate = "2024-06-15"

    static func set() {
        setenv("DIAGRAMKIT_GANTT_TODAY", isoDate, 1)
    }
}
