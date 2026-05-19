import Testing
@testable import DiagramKitPlantUML

@Suite("PlantUMLProbeDisambiguationTests")
struct PlantUMLProbeDisambiguationTests {

    @Test func activityBodyDoesNotMatchStateProbe() {
        let body = """
        start
        :Step 1;
        :Step 2;
        stop
        """
        #expect(isPlantUMLActivityBody(body))
        #expect(!isPlantUMLStateBody(body))
    }

    @Test func stateBodyDoesNotMatchActivityProbe() {
        let body = """
        [*] --> Idle
        Idle --> Active : trigger
        Active --> [*]
        """
        #expect(isPlantUMLStateBody(body))
        #expect(!isPlantUMLActivityBody(body))
    }

    @Test func partitionRoutesToActivity() {
        let body = """
        start
        partition Lane1 {
          :Step 1;
        }
        stop
        """
        #expect(isPlantUMLActivityBody(body))
        #expect(!isPlantUMLStateBody(body))
    }

    @Test func erBodyMatchesERProbe() {
        let body = """
        entity Customer {
          * id : number
          name : text
        }
        Customer ||--o{ Order
        """
        #expect(isPlantUMLERBody(body))
    }

    @Test func useCaseBodyMatchesUseCaseProbe() {
        let body = """
        :User: as user
        (Login) as UC1
        user --> UC1
        """
        #expect(isPlantUMLUseCaseBody(body))
    }

    @Test func objectBodyMatchesObjectProbe() {
        let body = """
        object foo
        object bar
        foo --> bar
        """
        #expect(isPlantUMLObjectBody(body))
        #expect(!isPlantUMLClassBody(body))
    }

    @Test func componentBodyMatchesComponentProbe() {
        let body = """
        [Web] --> [API]
        interface HTTP
        [API] --> HTTP
        """
        #expect(isPlantUMLComponentBody(body))
    }
}
