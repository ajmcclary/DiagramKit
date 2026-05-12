// Re-exports keep the public API surface of the umbrella stable as
// individual subsystems migrate out of `Sources/DiagramKit/` into
// dedicated targets. Consumers that say `import DiagramKit` still see
// every view, preparer, and rendering type they did before.
#if canImport(CoreGraphics)
@_exported import DiagramKitViews
@_exported import DiagramKitRenderingCG
#endif
@_exported import DiagramKitModel
@_exported import DiagramKitImport
@_exported import DiagramKitCommon
