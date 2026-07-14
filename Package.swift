// swift-tools-version: 6.3
import PackageDescription

// `InferSendableFromCaptures` is already on by default in Swift 6 mode;
// re-enabling it via `.enableUpcomingFeature` emits a "feature is already
// enabled" warning per source file (one per compile job). We keep
// `StrictConcurrency` for documented intent and forward-compat against
// future toolchain shifts — it's silent under Swift 6.
let strictConcurrencySettings: [SwiftSetting] = [
    .enableUpcomingFeature("StrictConcurrency")
]

let package = Package(
    name: "DiagramKit",
    platforms: [
        // Floor: macOS 14 / iOS 17 — the deployment target of the Observation
        // framework's `@Observable` macro, applied to `DiagramEditor` in
        // `DiagramKitInteractive`. That is the highest OS requirement any
        // first-party API in the package genuinely imposes: the package builds
        // and its full test suite passes at this floor, and drops to a hard
        // `'Observable()' is only available in macOS 14.0 or newer` error at
        // macOS 13 / iOS 16. The previous macOS 26.3 / iOS 26.3 floor was
        // inherited from the former in-package sample app's external
        // code-editor dependency (the sample was extracted to
        // apps/DiagramStudio in the workspace reorganization) and was never a
        // real API requirement of DiagramKit itself.
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "DiagramKit", targets: ["DiagramKit"]),
        .library(name: "DiagramKitImport", targets: ["DiagramKitImport"]),
        .library(name: "DiagramKitCommon", targets: ["DiagramKitCommon"]),
        .library(name: "DiagramKitModel", targets: ["DiagramKitModel"]),
        .library(name: "DiagramKitRenderingCG", targets: ["DiagramKitRenderingCG"]),
        .library(name: "DiagramKitViews", targets: ["DiagramKitViews"]),
        .library(name: "DiagramKitTestSupport", targets: ["DiagramKitTestSupport"]),
        // Internal test/tooling corpus (not advertised for external reuse);
        // shipped as a product only so the path-dependency app can import it.
        .library(name: "DiagramKitCorpus", targets: ["DiagramKitCorpus"]),
        .library(name: "DiagramKitD2", targets: ["DiagramKitD2"]),
        .library(name: "DiagramKitGraphviz", targets: ["DiagramKitGraphviz"]),
        .library(name: "DiagramKitStructurizr", targets: ["DiagramKitStructurizr"]),
        .library(name: "DiagramKitPlantUML", targets: ["DiagramKitPlantUML"]),
        .library(name: "DiagramKitExport", targets: ["DiagramKitExport"]),
        .library(name: "DiagramKitMermaid", targets: ["DiagramKitMermaid"]),
        .library(name: "DiagramKitInteractive", targets: ["DiagramKitInteractive"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        // swift-crypto provides the CryptoKit API surface on Linux. On Apple
        // platforms `import CryptoKit` is preferred (zero-cost), but to keep
        // DiagramKitCommon Linux-portable for `StableID.derive(...)`, we
        // import `Crypto` from this package when CryptoKit is unavailable.
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
        // Test-only dependency. Upstream 1.19.3 builds cleanly under the Apple
        // Swift 6.4 / Xcode 27 toolchain this workspace targets; the former
        // `ajmcclary/swift-snapshot-testing@fix-swift-6.3-attachable` fork was
        // only required on the open-source `swift-6.3-RELEASE` toolchain, where
        // the cross-import-overlay `Attachable` conformances aren't visible to
        // the SnapshotTesting library target. Version-pinned so DiagramKit stays
        // consumable by stable-version dependents.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.3")
    ],
    targets: [
        .target(
            name: "DiagramKitCommon",
            dependencies: [
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitModel",
            dependencies: ["DiagramKitCommon"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitImport",
            dependencies: ["DiagramKitModel"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitD2",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitGraphviz",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitStructurizr",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitPlantUML",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitExport",
            dependencies: ["DiagramKitCommon", "DiagramKitModel"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitMermaid",
            dependencies: ["DiagramKitCommon", "DiagramKitModel", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitInteractive",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitImport",
                "DiagramKitExport",
                "DiagramKitRenderingCG"
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitRenderingCG",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitViews",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitRenderingCG"
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitCorpus",
            dependencies: ["DiagramKitCommon"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitTestSupport",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitImport",
                "DiagramKitExport",
                "DiagramKitCorpus"
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKit",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitImport",
                "DiagramKitExport",
                "DiagramKitMermaid",
                "DiagramKitInteractive",
                "DiagramKitD2",
                "DiagramKitGraphviz",
                "DiagramKitStructurizr",
                "DiagramKitPlantUML",
                "DiagramKitRenderingCG",
                "DiagramKitViews"
            ],
            swiftSettings: strictConcurrencySettings
        ),


        .testTarget(
            name: "DiagramKitTests",
            dependencies: [
                "DiagramKit",
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitExport",
                "DiagramKitMermaid",
                "DiagramKitInteractive",
                "DiagramKitTestSupport",
                "DiagramKitCorpus",
                "DiagramKitD2",
                "DiagramKitGraphviz",
                "DiagramKitStructurizr",
                "DiagramKitPlantUML",
                "DiagramKitRenderingCG",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: [
                "__Snapshots__",
                // RoundTrip fixtures are loaded directly from the source tree
                // via `#filePath`, not from the test bundle. Excluding them
                // here avoids SwiftPM's "unhandled file" warnings for the
                // `.md` / `.puml` / `.d2` / `.dot` / `.dsl` corpus files.
                "RoundTrip/Resources",
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "DiagramKitLinuxTests",
            dependencies: [
                "DiagramKit",
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitTestSupport",
            ],
            swiftSettings: strictConcurrencySettings
        )
    ],
    swiftLanguageModes: [.v6]
)
