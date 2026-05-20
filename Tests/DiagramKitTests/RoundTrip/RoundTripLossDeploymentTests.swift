import Testing
import DiagramKitCommon
@testable import DiagramKitTestSupport

@Suite("RoundTripLossDeploymentTests")
struct RoundTripLossDeploymentTests {

    @Test func deploymentShapeFlattenedExists() {
        let loss = RoundTripLoss.deploymentShapeFlattened(
            serviceID: "db", kindRawValue: "database"
        )
        #expect(loss.kind == .deploymentShapeFlattened)
    }

    @Test func deploymentDecorationDroppedExists() {
        let loss = RoundTripLoss.deploymentDecorationDropped(
            serviceID: "worker", decoration: "stereotype"
        )
        #expect(loss.kind == .deploymentDecorationDropped)
    }

    @Test func deploymentLegendDroppedExists() {
        let loss = RoundTripLoss.deploymentLegendDropped
        #expect(loss.kind == .deploymentLegendDropped)
    }

    @Test func allDeploymentKindsAreCaseIterable() {
        let deploymentKinds: Set<RoundTripLossKind> = [
            .deploymentShapeFlattened,
            .deploymentDecorationDropped,
            .deploymentLegendDropped
        ]
        for kind in deploymentKinds {
            #expect(RoundTripLossKind.allCases.contains(kind))
        }
    }
}
