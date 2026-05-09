// DiagramKitViews target retained as a placeholder. The actual Views/ files
// live inside the DiagramKit umbrella target since they depend on
// MermaidPipeline (also in umbrella). A future stage may extract Views
// once a closure-based Preparer protocol is introduced.
//
// Apple-only target. SwiftUI/UIView wrappers compile out on Linux.
#if canImport(UIKit) || canImport(AppKit)
public enum DiagramKitViews {}
#endif

