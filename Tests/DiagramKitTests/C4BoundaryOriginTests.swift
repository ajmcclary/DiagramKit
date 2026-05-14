import Foundation
import Testing
import DiagramKitModel

@Suite("C4BoundaryOrigin")
struct C4BoundaryOriginTests {

    @Test("Default origin is .authored")
    func defaultOriginIsAuthored() {
        let boundary = C4Boundary(alias: "b0", label: "Group 0")
        #expect(boundary.origin == .authored)
    }

    @Test("Origin round-trips through Equatable")
    func originRoundTrips() {
        let a = C4Boundary(alias: "b0", label: "G", origin: .authored)
        let b = C4Boundary(alias: "b0", label: "G", origin: .authored)
        let c = C4Boundary(alias: "b0", label: "G", origin: .viewScopeSynthesized)
        #expect(a == b)
        #expect(a != c)
    }
}
