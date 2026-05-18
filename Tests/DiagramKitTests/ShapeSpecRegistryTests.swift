import XCTest
@testable import DiagramKitModel

final class ShapeSpecRegistryTests: XCTestCase {

    func testRegisteredSpecLookupCaseInsensitive() {
        XCTAssertNotNil(ShapeSpecRegistry.registeredSpec(for: "rectangle"))
        XCTAssertNotNil(ShapeSpecRegistry.registeredSpec(for: "Rectangle"))
        XCTAssertNotNil(ShapeSpecRegistry.registeredSpec(for: "RECTANGLE"))
    }

    func testRegisteredSpecReturnsNilForUnknown() {
        XCTAssertNil(ShapeSpecRegistry.registeredSpec(for: "not-a-real-shape"))
    }

    func testSpecAlwaysReturnsFallbackForUnknown() {
        // Contract: `spec(for:)` is non-Optional. Unknown names resolve to
        // the rectangle fallback so renderers can use the result directly
        // without nil-handling. Callers that need to distinguish should use
        // `registeredSpec(for:)`.
        let unknown = ShapeSpecRegistry.spec(for: "not-a-real-shape")
        let rectangle = ShapeSpecRegistry.spec(for: "rectangle")
        XCTAssertEqual(unknown.aliases, rectangle.aliases)
    }

    func testSpecMatchesRegisteredWhenAvailable() {
        let viaSpec = ShapeSpecRegistry.spec(for: "hexagon")
        let viaRegistered = ShapeSpecRegistry.registeredSpec(for: "hexagon")
        XCTAssertNotNil(viaRegistered)
        XCTAssertEqual(viaSpec.aliases, viaRegistered?.aliases)
    }
}
