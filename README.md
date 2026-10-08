# DiagramKit

Turn diagram source into images, SVG, or terminal text with native Swift.
DiagramKit parses and lays out diagrams without a JavaScript runtime, and
includes SwiftUI, UIKit, and AppKit views for displaying them in your app.

- **Five source formats:** Mermaid, D2, Graphviz DOT, Structurizr, and PlantUML,
  with automatic format detection.
- **28 diagram families:** including flowcharts, sequence diagrams, class
  diagrams, ER diagrams, Gantt charts, mindmaps, and C4 models. Format support
  varies by family.
- **Beyond rendering:** parse into typed models, import and export supported
  formats, or interactively edit flowchart, sequence, and Gantt diagrams on
  Apple platforms.

## Requirements

Swift 6.3 or later. Apple apps require **macOS 27 or iOS 27**.

On Linux, parsing, layout, SVG, and ASCII rendering support all 28 families.
Text measurement uses estimates where CoreText is unavailable, so layout can
differ from Apple output. Native images and UI views are Apple-only.

## Install

Add the package to your `Package.swift`, pinning this prerelease exactly:

```swift
.package(url: "https://github.com/ajmcclary/DiagramKit.git", exact: "0.1.0-beta.5")
```

Add the `DiagramKit` product to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "DiagramKit", package: "DiagramKit")
    ]
)
```

The umbrella product provides the engine and re-exports the common model,
import/export, and Apple UI APIs. For individual products, see the
[package architecture](ARCHITECTURE.md).

## Render your first diagram

```swift
import DiagramKit

let source = """
flowchart LR
    A[Write source] --> B[Render diagram]
    B --> C[Share it]
"""

let svg = try await DiagramEngine.renderSVG(source: source)

let ascii = try await DiagramEngine.renderASCII(source: source)
print(ascii.text)
```

Engine methods are `async throws`. ASCII output also includes a
`diagnostics` array with rendering warnings. To parse without rendering, use
`try await DiagramEngine.parse(source)`.

On Apple platforms, render a native image from the main actor:

```swift
let image = try await DiagramEngine.renderImage(source: source, scale: 2.0)
```

The result is an optional `NSImage` on macOS or `UIImage` on iOS. To select a
format explicitly, pass `sourceFormat:` to a render method, such as `.d2` or
`.graphviz`.

## Display in SwiftUI

```swift
import SwiftUI
import DiagramKit

struct ContentView: View {
    let source: String

    init(source: String) {
        DiagramEngine.bootstrap()
        self.source = source
    }

    var body: some View {
        DiagramView(source: source)
            .frame(minWidth: 320, minHeight: 200)
    }
}
```

Call `DiagramEngine.bootstrap()` once before creating views if you haven't
already called an engine method. `DiagramView` handles asynchronous rendering;
use `DiagramNativeView` for UIKit or AppKit integration.

## Learn more

- [Architecture](ARCHITECTURE.md) — products, pipeline, and API boundaries.
- [Changelog](CHANGELOG.md) — release changes.
- [Contributing](CONTRIBUTING.md) — development and testing.

## License

DiagramKit is [MIT licensed](LICENSE). See
[third-party licenses](THIRD_PARTY_LICENSES.md) for bundled assets and
[attribution](ATTRIBUTION.md) for upstream projects.
