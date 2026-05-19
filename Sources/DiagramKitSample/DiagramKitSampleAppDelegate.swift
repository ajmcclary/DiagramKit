#if canImport(AppKit)
import AppKit

/// Promotes the SwiftPM-launched binary to a regular macOS application:
/// it gets a Dock entry, a menu bar (so cmd-Q quits and the Window menu
/// works), and stops behaving like a faceless background agent attached
/// to the launching process. Without this, `swift run DiagramKitSample`
/// produces a window with no menu bar and no Dock icon.
final class DiagramKitSampleAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
#endif
