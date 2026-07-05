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

        // Enable native full screen on the main window as it appears
        // (see enableFullScreen(for:)).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enableFullScreen(for:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @MainActor
    @objc private func enableFullScreen(for notification: Notification) {
        // The main window ships with `.fullScreenNone`, which forbids native
        // full screen and leaves the green button stuck on zoom (maximize).
        // Clear it and opt into full screen. Skip the borderless helper
        // window (no title bar), which has no green button anyway.
        guard let window = notification.object as? NSWindow,
              window.styleMask.contains(.titled) else { return }
        window.collectionBehavior.remove(.fullScreenNone)
        window.collectionBehavior.insert(.fullScreenPrimary)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
#endif
