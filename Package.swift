// swift-tools-version: 6.3
import PackageDescription

// Workspace-standard Swift 6 settings, applied per target so the policy is
// checkable target-by-target (the package-level `swiftLanguageModes: [.v6]`
// below is kept as well — redundant but explicit).
//
// `InferSendableFromCaptures` is deliberately NOT listed: it is already on by
// default in Swift 6 mode, and re-enabling it emits a "feature is already
// enabled" warning per compile job. `StrictConcurrency` is kept for documented
// intent and forward-compat against future toolchain shifts — it is silent
// under Swift 6.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "DiagramKit",
    // Workspace-standard floor. String form (`"27.0"`) rather than `.v27`:
    // the enum case requires `_PackageDescription 6.4`, while the string form
    // parses at every tools-version used in this workspace. iOS is retained —
    // the package builds clean for `generic/platform=iOS`.
    platforms: [
        .macOS("27.0"),
        .iOS("27.0")
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
        // 3..<6: only `SHA256.hash` is used, which is stable across 3.x-5.x.
        .package(url: "https://github.com/apple/swift-crypto", "3.0.0"..<"6.0.0"),
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
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitModel",
            dependencies: ["DiagramKitCommon"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitImport",
            dependencies: ["DiagramKitModel"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitD2",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitGraphviz",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitStructurizr",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitPlantUML",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitExport",
            dependencies: ["DiagramKitCommon", "DiagramKitModel"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitMermaid",
            dependencies: ["DiagramKitCommon", "DiagramKitModel", "DiagramKitExport"],
            swiftSettings: swiftSettings
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
            swiftSettings: swiftSettings
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
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitViews",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitRenderingCG"
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "DiagramKitCorpus",
            dependencies: ["DiagramKitCommon"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: swiftSettings
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
            swiftSettings: swiftSettings
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
            swiftSettings: swiftSettings
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
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "DiagramKitLinuxTests",
            dependencies: [
                "DiagramKit",
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitTestSupport",
            ],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
