//
//  SampleDiagrams.swift
//  MermaidPlayground
//
//  Sample Mermaid diagrams for testing
//

import Foundation
import IssueReporting

/// Collection of sample diagrams
public struct SampleDiagrams {

    // MARK: - Flowcharts

    public static let flowchart = """
    graph TD
        A[Start] --> B{Is it working?}
        B -->|Yes| C[Great!]
        B -->|No| D[Debug]
        D --> B
        C --> E[Ship it!]
    """

    public static let flowchartComplex = """
    graph TD
        A[Client] --> B[Load Balancer]
        B --> C[Server 1]
        B --> D[Server 2]
        B --> E[Server 3]

        subgraph Servers[Server Cluster]
            C --> F[(Database)]
            D --> F
            E --> F
        end

        F --> G[Cache]
        G --> C
        G --> D
        G --> E
    """

    public static let infrastructure = """
    graph TD
        LB([Load Balancer])

        LB --> WS1
        LB --> WS2

        subgraph Cloud
            subgraph USEast[US East Region]
                WS1[Web Server] --> AS1[App Server]
            end

            subgraph USWest[US West Region]
                WS2[Web Server] --> AS2[App Server]
            end
        end
    """

    public static let flowchartShapes = """
    graph LR
        A[Rectangle]
        B(Rounded)
        C([Stadium])
        D((Circle))
        E{Diamond}
        F{{Hexagon}}
        G[(Database)]
        H[[Subroutine]]

        A --> B --> C --> D
        E --> F --> G --> H
    """

    public static let flowchartStyles = """
    graph TD
        A[Normal] --> B[Styled]
        B --> C[Highlighted]

        classDef important fill:#f96,stroke:#333,stroke-width:2px
        classDef highlighted fill:#9cf,stroke:#06c

        class B important
        class C highlighted
    """

    // MARK: - State Diagrams

    public static let stateDiagram = """
    stateDiagram-v2
        [*] --> Idle
        Idle --> Processing : Start
        Processing --> Completed : Success
        Processing --> Failed : Error
        Failed --> Idle : Retry
        Completed --> [*]
    """

    public static let stateDiagramNested = """
    stateDiagram-v2
        [*] --> Active

        state Active {
            [*] --> Running
            Running --> Paused : Pause
            Paused --> Running : Resume
            Running --> [*] : Stop
        }

        Active --> Finished : Complete
        Finished --> [*]
    """

    // MARK: - Sequence Diagrams

    public static let sequenceDiagram = """
    sequenceDiagram
        participant A as Alice
        participant B as Bob
        participant C as Charlie

        A->>B: Hello Bob!
        B-->>A: Hi Alice!
        A->>C: Hey Charlie
        C->>B: Bob, did you hear?
        B-->>C: Yes, I did!
    """

    public static let sequenceDiagramAuth = """
    sequenceDiagram
        participant U as User
        participant C as Client
        participant S as Server
        participant D as Database

        U->>C: Login Request
        C->>S: POST /auth
        S->>D: Query User
        D-->>S: User Data
        S-->>C: JWT Token
        C-->>U: Login Success
    """

    // MARK: - Class Diagrams

    public static let classDiagram = """
    classDiagram
        class Animal {
            +String name
            +int age
            +makeSound()
        }

        class Dog {
            +String breed
            +bark()
        }

        class Cat {
            +int lives
            +meow()
        }

        Animal <|-- Dog
        Animal <|-- Cat
    """

    public static let classDiagramRelations = """
    classDiagram
        class Order {
            +int orderId
            +Date orderDate
            +calculateTotal()
        }

        class Customer {
            +String name
            +String email
        }

        class Product {
            +String name
            +float price
        }

        class LineItem {
            +int quantity
        }

        Customer "1" --> "*" Order : places
        Order "1" --> "*" LineItem : contains
        LineItem "*" --> "1" Product : refers to
    """

    // MARK: - ER Diagrams

    public static let erDiagram = """
    erDiagram
        CUSTOMER ||--o{ ORDER : places
        ORDER ||--|{ LINE-ITEM : contains
        PRODUCT ||--o{ LINE-ITEM : includes
        CUSTOMER {
            string name
            string email
        }
        ORDER {
            int orderNumber
            date orderDate
        }
    """

    // MARK: - All Samples

    public static let allSamples: [(name: String, category: String, source: String)] = [
        ("Basic Flowchart", "Flowchart", flowchart),
        ("Complex Flowchart", "Flowchart", flowchartComplex),
        ("Infrastructure", "Flowchart", infrastructure),
        ("All Shapes", "Flowchart", flowchartShapes),
        ("Styled Flowchart", "Flowchart", flowchartStyles),
        ("State Machine", "State", stateDiagram),
        ("Nested States", "State", stateDiagramNested),
        ("Basic Sequence", "Sequence", sequenceDiagram),
        ("Auth Flow", "Sequence", sequenceDiagramAuth),
        ("Class Hierarchy", "Class", classDiagram),
        ("Class Relations", "Class", classDiagramRelations),
        ("ER Diagram", "ER", erDiagram)
    ]

    /// Get samples by category
    public static func samples(for category: String) -> [(name: String, source: String)] {
        allSamples.filter { $0.category == category }.map { ($0.name, $0.source) }
    }

    /// All categories
    public static let categories = ["Flowchart", "State", "Sequence", "Class", "ER"]
}

// MARK: - Test Diagrams from Verification Suite

/// A single test diagram entry
public struct TestDiagram: Codable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let name: String
    public let source: String
    public var options: [String: Bool]? = nil
}

/// A diagram-family category shown in the playground picker.
public struct TestDiagramCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// Container for all test diagrams (matches verification/shared/test-diagrams.json)
public struct TestDiagramsFile: Codable, Sendable {
    public let version: String
    public let description: String
    public let diagrams: [TestDiagram]
}

/// Provides access to test diagrams from the verification suite
public struct TestDiagrams {

    /// All loaded test diagrams
    public static let all: [TestDiagram] = loadDiagrams()

    /// Diagram families tracked by GAPS.md, in coverage-table order.
    public static let gapCategories: [TestDiagramCategory] = [
        TestDiagramCategory(id: "flowchart", title: "Flowchart"),
        TestDiagramCategory(id: "sequence", title: "Sequence Diagram"),
        TestDiagramCategory(id: "class", title: "Class Diagram"),
        TestDiagramCategory(id: "state", title: "State Diagram"),
        TestDiagramCategory(id: "er", title: "Entity Relationship"),
        TestDiagramCategory(id: "journey", title: "User Journey"),
        TestDiagramCategory(id: "gantt", title: "Gantt"),
        TestDiagramCategory(id: "pie", title: "Pie Chart"),
        TestDiagramCategory(id: "quadrantChart", title: "Quadrant Chart"),
        TestDiagramCategory(id: "requirement", title: "Requirement Diagram"),
        TestDiagramCategory(id: "gitGraph", title: "GitGraph"),
        TestDiagramCategory(id: "c4", title: "C4 Diagram"),
        TestDiagramCategory(id: "mindmap", title: "Mindmap"),
        TestDiagramCategory(id: "timeline", title: "Timeline"),
        TestDiagramCategory(id: "zenuml", title: "ZenUML"),
        TestDiagramCategory(id: "sankey", title: "Sankey"),
        TestDiagramCategory(id: "xychart", title: "XY Chart"),
        TestDiagramCategory(id: "block", title: "Block Diagram"),
        TestDiagramCategory(id: "packet", title: "Packet"),
        TestDiagramCategory(id: "kanban", title: "Kanban"),
        TestDiagramCategory(id: "architecture", title: "Architecture"),
        TestDiagramCategory(id: "radar", title: "Radar"),
        TestDiagramCategory(id: "treemap", title: "Treemap"),
        TestDiagramCategory(id: "venn", title: "Venn"),
        TestDiagramCategory(id: "ishikawa", title: "Ishikawa"),
        TestDiagramCategory(id: "treeView", title: "TreeView"),
        TestDiagramCategory(id: "eventmodeling", title: "Event Modeling"),
        TestDiagramCategory(id: "wardleyBeta", title: "Wardley Map"),
    ]

    /// Categories available in the loaded corpus, ordered by GAPS.md and followed by unknown extras.
    public static var orderedCategories: [TestDiagramCategory] {
        let availableCategories = Set(all.map(\.category))
        let ordered = gapCategories.filter { availableCategories.contains($0.id) }
        let knownCategoryIDs = Set(gapCategories.map(\.id))
        let extras = availableCategories
            .subtracting(knownCategoryIDs)
            .sorted()
            .map { TestDiagramCategory(id: $0, title: title(for: $0)) }

        return ordered + extras
    }

    /// Get all unique categories
    public static var categories: [String] {
        orderedCategories.map(\.id)
    }

    /// Human-readable menu title for a category identifier.
    public static func title(for category: String) -> String {
        if let knownCategory = gapCategories.first(where: { $0.id == category }) {
            return knownCategory.title
        }

        return category
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    /// Get diagrams by category
    public static func diagrams(for category: String) -> [TestDiagram] {
        all.filter { $0.category == category }
    }

    /// Find diagram by ID
    public static func diagram(withId id: String) -> TestDiagram? {
        all.first { $0.id == id }
    }

    // MARK: - Loading

    private static func loadDiagrams() -> [TestDiagram] {
        for bundleURL in resourceURLs() {
            do {
                let data = try Data(contentsOf: bundleURL)
                let file = try JSONDecoder().decode(TestDiagramsFile.self, from: data)
                return file.diagrams
            } catch {
                reportIssue(error)
            }
        }

        // Fallback: return embedded diagrams
        return embeddedDiagrams
    }

    private static func resourceURLs() -> [URL] {
        var urls: [URL] = []
        let bundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks

        for bundle in bundles {
            if let url = bundle.url(forResource: "test-diagrams", withExtension: "json") {
                urls.append(url)
            }
        }

        if let developmentURL = developmentResourceURL() {
            urls.append(developmentURL)
        }

        var seen: Set<String> = []
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            return seen.insert(path).inserted
        }
    }

    private static func developmentResourceURL() -> URL? {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("Resources/test-diagrams.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }

        return nil
    }

    /// Embedded diagrams as fallback when JSON file isn't available at runtime.
    private static let embeddedDiagrams: [TestDiagram] = [
        // Flowchart
        TestDiagram(id: "flow-1-simple", category: "flowchart", name: "Simple Flow",
                    source: "graph TD\n  A[Start] --> B[Process] --> C[End]"),
        TestDiagram(id: "flow-2-original-shapes", category: "flowchart", name: "Original Node Shapes",
                    source: "graph LR\n  A[Rectangle] --> B(Rounded)\n  B --> C{Diamond}\n  C --> D([Stadium])\n  D --> E((Circle))"),
        TestDiagram(id: "flow-5-all-12-shapes", category: "flowchart", name: "All 12 Flowchart Shapes",
                    source: "graph LR\n  A[Rectangle] --> B(Rounded)\n  B --> C{Diamond}\n  C --> D([Stadium])\n  D --> E((Circle))\n  E --> F[[Subroutine]]\n  F --> G(((Double Circle)))\n  G --> H{{Hexagon}}\n  H --> I[(Database)]\n  I --> J>Flag]\n  J --> K[/Trapezoid\\]\n  K --> L[\\Inverse Trap/]"),
        TestDiagram(id: "flow-6-edge-styles", category: "flowchart", name: "All Edge Styles",
                    source: "graph TD\n  A[Source] -->|solid| B[Target 1]\n  A -.->|dotted| C[Target 2]\n  A ==>|thick| D[Target 3]"),
        TestDiagram(id: "flow-8-text-embedded", category: "flowchart", name: "Text-Embedded Labels",
                    source: "graph TD\n  A[Start] -- first step --> B[Middle]\n  B -- second step --> C[End]"),
        TestDiagram(id: "flow-9-bidirectional", category: "flowchart", name: "Bidirectional Arrows",
                    source: "graph LR\n  A[Client] <-->|sync| B[Server]\n  B <-.->|heartbeat| C[Monitor]\n  C <==>|data| D[Storage]"),
        TestDiagram(id: "flow-14-direction-lr", category: "flowchart", name: "Direction: Left-Right",
                    source: "graph LR\n  A[Input] --> B[Process] --> C[Output]"),
        TestDiagram(id: "flow-15-direction-bt", category: "flowchart", name: "Direction: Bottom-Top",
                    source: "graph BT\n  A[Foundation] --> B[Walls] --> C[Roof]"),
        TestDiagram(id: "flow-16-subgraphs", category: "flowchart", name: "Subgraphs",
                    source: "graph TD\n  subgraph Frontend\n    A[React App] --> B[State Manager]\n  end\n  subgraph Backend\n    C[API Server] --> D[Database]\n  end\n  B --> C"),
        TestDiagram(id: "flow-17-nested-subgraphs", category: "flowchart", name: "Nested Subgraphs",
                    source: "graph TD\n  subgraph Cloud\n    subgraph us-east [US East Region]\n      A[Web Server] --> B[App Server]\n    end\n    subgraph us-west [US West Region]\n      C[Web Server] --> D[App Server]\n    end\n  end\n  E[Load Balancer] --> A\n  E --> C"),
        TestDiagram(id: "flow-21-cicd-pipeline", category: "flowchart", name: "CI/CD Pipeline",
                    source: "graph TD\n  subgraph ci [CI Pipeline]\n    A[Push Code] --> B{Tests Pass?}\n    B -->|Yes| C[Build Image]\n    B -->|No| D[Fix & Retry]\n    D -.-> A\n  end\n  C --> E([Deploy Staging])\n  E --> F{QA Approved?}\n  F -->|Yes| G((Production))\n  F -->|No| D"),
        TestDiagram(id: "flow-22-system-architecture", category: "flowchart", name: "System Architecture",
                    source: "graph LR\n  subgraph clients [Client Layer]\n    A([Web App]) --> B[API Gateway]\n    C([Mobile App]) --> B\n  end\n  subgraph services [Service Layer]\n    B --> D[Auth Service]\n    B --> E[User Service]\n    B --> F[Order Service]\n  end\n  subgraph data [Data Layer]\n    D --> G[(Auth DB)]\n    E --> H[(User DB)]\n    F --> I[(Order DB)]\n    F --> J([Message Queue])\n  end"),
        TestDiagram(id: "flow-23-decision-tree", category: "flowchart", name: "Decision Tree",
                    source: "graph TD\n  A{Is it raining?} -->|Yes| B{Have umbrella?}\n  A -->|No| C([Go outside])\n  B -->|Yes| D([Go with umbrella])\n  B -->|No| E{Is it heavy?}\n  E -->|Yes| F([Stay inside])\n  E -->|No| G([Run for it])"),
        TestDiagram(id: "flow-25-self-loop", category: "flowchart", name: "Self-Loop Edge",
                    source: "graph TD\n  A[Retry Node] --> A"),
        TestDiagram(id: "flow-26-self-loop-label", category: "flowchart", name: "Self-Loop with Label",
                    source: "graph TD\n  A[Retry Node] -->|retry| A"),
        // State
        TestDiagram(id: "state-1-basic", category: "state", name: "Basic State Diagram",
                    source: "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Active : start\n  Active --> Idle : cancel\n  Active --> Done : complete\n  Done --> [*]"),
        TestDiagram(id: "state-2-composite", category: "state", name: "Composite States",
                    source: "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Processing : submit\n  state Processing {\n    parse --> validate\n    validate --> execute\n  }\n  Processing --> Complete : done\n  Processing --> Error : fail\n  Error --> Idle : retry\n  Complete --> [*]"),
        TestDiagram(id: "state-3-connection-lifecycle", category: "state", name: "Connection Lifecycle",
                    source: "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"),
        // Sequence
        TestDiagram(id: "seq-1-basic", category: "sequence", name: "Basic Messages",
                    source: "sequenceDiagram\n  Alice->>Bob: Hello Bob!\n  Bob-->>Alice: Hi Alice!"),
        TestDiagram(id: "seq-3-actors", category: "sequence", name: "Actor Stick Figures",
                    source: "sequenceDiagram\n  actor U as User\n  participant S as System\n  U->>S: Request\n  S-->>U: Response"),
        TestDiagram(id: "seq-5-activations", category: "sequence", name: "Activation Boxes",
                    source: "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>+S: Request\n  S->>+S: Process\n  S->>-S: Done\n  S-->>-C: Response"),
        TestDiagram(id: "seq-7-loop", category: "sequence", name: "Loop Block",
                    source: "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>S: Connect\n  loop Every 30s\n    C->>S: Heartbeat\n    S-->>C: Ack\n  end\n  C->>S: Disconnect"),
        TestDiagram(id: "seq-8-alt-else", category: "sequence", name: "Alt/Else Block",
                    source: "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>S: Login\n  alt valid credentials\n    S-->>C: Token\n  else invalid\n    S-->>C: 401 Error\n  end"),
        TestDiagram(id: "seq-12-notes", category: "sequence", name: "Notes",
                    source: "sequenceDiagram\n  participant A as Alice\n  participant B as Bob\n  Note right of A: Alice thinks\n  A->>B: Message\n  Note left of B: Bob ponders\n  Note over A,B: Both agree"),
        TestDiagram(id: "seq-13-oauth", category: "sequence", name: "OAuth 2.0 Flow",
                    source: "sequenceDiagram\n  actor U as User\n  participant App as Client App\n  participant Auth as Auth Server\n  participant API as Resource API\n  U->>App: Click Login\n  App->>Auth: Authorization request\n  Auth->>U: Login page\n  U->>Auth: Credentials\n  Auth-->>App: Authorization code\n  App->>Auth: Exchange code for token\n  Auth-->>App: Access token\n  App->>API: Request + token\n  API-->>App: Protected resource\n  App-->>U: Display data"),
        // Class
        TestDiagram(id: "class-1-basic", category: "class", name: "Basic Class",
                    source: "classDiagram\n  class Animal {\n    +String name\n    +int age\n    +eat() void\n    +sleep() void\n  }"),
        TestDiagram(id: "class-6-inheritance", category: "class", name: "Inheritance",
                    source: "classDiagram\n  class Animal {\n    +String name\n    +eat() void\n  }\n  class Dog {\n    +String breed\n    +bark() void\n  }\n  class Cat {\n    +bool isIndoor\n    +meow() void\n  }\n  Animal <|-- Dog\n  Animal <|-- Cat"),
        TestDiagram(id: "class-12-all-relationships", category: "class", name: "All 6 Relationship Types",
                    source: "classDiagram\n  A <|-- B : inheritance\n  C *-- D : composition\n  E o-- F : aggregation\n  G --> H : association\n  I ..> J : dependency\n  K ..|> L : realization"),
        TestDiagram(id: "class-13-labels", category: "class", name: "Relationship Labels",
                    source: "classDiagram\n  class Student {\n    +name String\n  }\n  class Teacher {\n    +name String\n  }\n  class Course {\n    +title String\n  }\n  Student \"*\" --> \"*\" Course : enrolled in\n  Teacher \"1\" --> \"*\" Course : teaches"),
        TestDiagram(id: "class-15-mvc", category: "class", name: "MVC Architecture",
                    source: "classDiagram\n  class Model {\n    -data Map\n    +getData() Map\n    +setData(key, val) void\n    +notify() void\n  }\n  class View {\n    -model Model\n    +render() void\n    +update() void\n  }\n  class Controller {\n    -model Model\n    -view View\n    +handleInput(event) void\n    +updateModel(data) void\n  }\n  Controller --> Model : updates\n  Controller --> View : refreshes\n  View --> Model : reads\n  Model ..> View : notifies"),
        // ER
        TestDiagram(id: "er-1-basic", category: "er", name: "Basic Relationship",
                    source: "erDiagram\n  CUSTOMER ||--o{ ORDER : places"),
        TestDiagram(id: "er-8-all-cardinality", category: "er", name: "All Cardinality Types",
                    source: "erDiagram\n  A ||--|| B : one-to-one\n  C ||--o{ D : one-to-many\n  E |o--|{ F : opt-to-many\n  G }|--o{ H : many-to-many"),
        TestDiagram(id: "er-12-ecommerce", category: "er", name: "E-Commerce Schema",
                    source: "erDiagram\n  CUSTOMER {\n    int id PK\n    string name\n    string email UK\n  }\n  ORDER {\n    int id PK\n    date created\n    int customer_id FK\n  }\n  PRODUCT {\n    int id PK\n    string name\n    float price\n  }\n  LINE_ITEM {\n    int id PK\n    int order_id FK\n    int product_id FK\n    int quantity\n  }\n  CUSTOMER ||--o{ ORDER : places\n  ORDER ||--|{ LINE_ITEM : contains\n  PRODUCT ||--o{ LINE_ITEM : includes"),
        // XY Chart
        TestDiagram(id: "xychart-1-bar", category: "xychart", name: "Simple Bar Chart",
                    source: "xychart-beta\n    title \"Product Sales\"\n    x-axis [Widgets, Gadgets, Gizmos, Doodads, Thingamajigs]\n    bar [150, 230, 180, 95, 310]"),
        TestDiagram(id: "xychart-2-line", category: "xychart", name: "Line Chart",
                    source: "xychart-beta\n    title \"Revenue Growth\"\n    x-axis [2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025]\n    line [320, 420, 540, 680, 820, 950, 1080, 1200]"),
        TestDiagram(id: "xychart-3-bar-line", category: "xychart", name: "Bar and Line Overlay",
                    source: "xychart-beta\n    title \"Monthly Revenue\"\n    x-axis \"Month\" [Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec]\n    y-axis \"Revenue (USD)\" 0 --> 10000\n    bar [4200, 5000, 5800, 6200, 5500, 7000, 7800, 7200, 8400, 8100, 9000, 9200]\n    line [4200, 5000, 5800, 6200, 5500, 7000, 7800, 7200, 8400, 8100, 9000, 9200]"),
        TestDiagram(id: "xychart-4-horizontal", category: "xychart", name: "Horizontal Bars",
                    source: "xychart-beta horizontal\n    title \"Language Popularity\"\n    x-axis [Python, JavaScript, Java, Go, Rust]\n    bar [30, 25, 20, 12, 8]"),
        TestDiagram(id: "xychart-5-multi-bar", category: "xychart", name: "Multiple Bar Series",
                    source: "xychart-beta\n    title \"2023 vs 2024 Sales\"\n    x-axis [Q1, Q2, Q3, Q4]\n    bar [200, 250, 300, 280]\n    bar [230, 280, 320, 350]"),
        TestDiagram(id: "xychart-7-numeric-x", category: "xychart", name: "Numeric X-Axis",
                    source: "xychart-beta\n    title \"Distribution Curve\"\n    x-axis 0 --> 100\n    line [4, 7, 13, 21, 31, 43, 58, 71, 84, 91, 95, 91, 84, 71, 58, 43, 31, 21, 13, 7, 4]"),
        TestDiagram(id: "xychart-10-burndown", category: "xychart", name: "Sprint Burndown",
                    source: "xychart-beta\n    title \"Sprint Burndown\"\n    x-axis [D1, D2, D3, D4, D5, D6, D7, D8, D9, D10]\n    y-axis \"Story Points\" 0 --> 80\n    line [72, 65, 58, 50, 45, 38, 30, 22, 12, 0]\n    line [72, 65, 58, 50, 43, 36, 29, 22, 14, 0]"),
        // New XY Chart parity examples
        TestDiagram(id: "xychart-11-simplest", category: "xychart", name: "Simplest Line Chart",
                    source: "xychart\n    line [1.3, .6, 2.4, -.34]"),
        TestDiagram(id: "xychart-12-unquoted-title", category: "xychart", name: "Unquoted Title",
                    source: "xychart\n    title SalesRevenue\n    x-axis [Q1, Q2, Q3, Q4]\n    bar [100, 200, 150, 300]"),
        TestDiagram(id: "xychart-13-titled-series", category: "xychart", name: "Titled Series",
                    source: "xychart\n    title \"Product Comparison\"\n    x-axis [A, B, C, D]\n    line LineA [1, 2, 3, 4]\n    bar BarB [4, 5, 6, 7]"),
        TestDiagram(id: "xychart-14-quoted-cats", category: "xychart", name: "Quoted Categories",
                    source: "xychart\n    title \"Sales by Region\"\n    x-axis [\"North America\", \"Europe\", \"Asia\", \"South America\"]\n    bar [450, 320, 580, 210]"),
        TestDiagram(id: "xychart-15-accessibility", category: "xychart", name: "Accessibility Chart",
                    source: "xychart\n    accTitle: Quarterly Revenue Overview\n    accDescr: This chart shows quarterly revenue across four quarters\n    title \"Q4 Revenue\"\n    x-axis [Q1, Q2, Q3, Q4]\n    bar [100, 200, 150, 300]\n    line [120, 180, 160, 280]"),
        TestDiagram(id: "xychart-16-vertical-explicit", category: "xychart", name: "Explicit Vertical",
                    source: "xychart vertical\n    x-axis [A, B, C]\n    bar [10, 20, 30]"),
        TestDiagram(id: "xychart-17-numeric-x-axis", category: "xychart", name: "Linear X-Axis",
                    source: "xychart\n    x-axis \"Temperature\" 0 --> 100\n    line [10, 30, 50, 70, 90]"),
        // Additional GAPS.md families
        TestDiagram(id: "journey-1", category: "journey", name: "My Working Day",
                    source: "journey\n    title My working day\n    section Go to work\n      Make tea: 5: Me\n      Go upstairs: 3: Me\n      Do work: 1: Me, Cat\n    section Go home\n      Go downstairs: 5: Me\n      Sit down: 5: Me"),
        TestDiagram(id: "gantt-1-basic", category: "gantt", name: "Basic Project Schedule",
                    source: "gantt\n    title A Gantt Diagram\n    dateFormat YYYY-MM-DD\n    section Section\n        A task       :a1, 2014-01-01, 30d\n        Another task :after a1, 20d"),
        TestDiagram(id: "pie-1-basic", category: "pie", name: "Basic Pie Chart",
                    source: "pie\n    \"Dogs\": 386\n    \"Cats\": 85\n    \"Rats\": 15"),
        TestDiagram(id: "quadrant-1-empty", category: "quadrantChart", name: "Empty Quadrant Chart",
                    source: "quadrantChart"),
        TestDiagram(id: "req-1-basic", category: "requirement", name: "Basic Requirement",
                    source: "requirementDiagram\n\nrequirement test_req {\n  id: 1\n  text: the test text.\n  risk: high\n  verifymethod: test\n}\n\nelement test_entity {\n  type: simulation\n}\n\ntest_entity - satisfies -> test_req"),
        TestDiagram(id: "git-1-basic", category: "gitGraph", name: "Basic Commits",
                    source: "gitGraph\n   commit\n   commit\n   commit"),
        TestDiagram(id: "c4-context", category: "c4", name: "C4 System Context",
                    source: "C4Context\ntitle System Context diagram for Internet Banking System\nEnterprise_Boundary(b0, \"BankBoundary0\") {\n  Person(customerA, \"Banking Customer A\", \"A customer of the bank.\")\n  Person_Ext(customerC, \"Banking Customer C\", \"desc\")\n  System(SystemAA, \"Internet Banking System\", \"Allows customers to view information.\")\n  Enterprise_Boundary(b1, \"BankBoundary\") {\n    SystemDb_Ext(SystemE, \"Mainframe Banking System\")\n    System_Boundary(b2, \"BankBoundary2\") {\n      System(SystemA, \"Banking System A\")\n      System(SystemB, \"Banking System B\")\n    }\n  }\n}\nBiRel(customerA, SystemAA, \"Uses\")\nBiRel(SystemAA, SystemE, \"Uses\")\nRel(SystemAA, SystemC, \"Sends e-mails\", \"SMTP\")\nUpdateElementStyle(customerA, $fontColor=\"red\", $bgColor=\"grey\")"),
        TestDiagram(id: "mindmap-1-simple", category: "mindmap", name: "Simple Root",
                    source: "mindmap\n  root((mindmap))\n    A\n    B"),
        TestDiagram(id: "timeline-1-basic", category: "timeline", name: "Basic No-Section Social Media Timeline",
                    source: "timeline\n    title History of Social Media Platform\n    2002 : LinkedIn\n    2004 : Facebook : Google\n    2005 : YouTube\n    2006 : Twitter"),
        TestDiagram(id: "zenuml-1-simple", category: "zenuml", name: "Simple Async",
                    source: "zenuml\nAlice->Bob: Hello"),
        TestDiagram(id: "sankey-1-minimal", category: "sankey", name: "Minimal Sankey",
                    source: "sankey\nA,B,10"),
        TestDiagram(id: "block-1-simple", category: "block", name: "Simple Blocks",
                    source: "block\n  a b c"),
        TestDiagram(id: "packet-1-tcp", category: "packet", name: "TCP Packet",
                    source: "---\ntitle: \"TCP Packet\"\n---\npacket\n0-15: \"Source Port\"\n16-31: \"Destination Port\"\n32-63: \"Sequence Number\"\n64-95: \"Acknowledgment Number\"\n96-99: \"Data Offset\"\n100-105: \"Reserved\"\n106: \"URG\"\n107: \"ACK\"\n108: \"PSH\"\n109: \"RST\"\n110: \"SYN\"\n111: \"FIN\"\n112-127: \"Window\"\n128-143: \"Checksum\"\n144-159: \"Urgent Pointer\"\n160-191: \"(Options and Padding)\"\n192-255: \"Data (variable length)\""),
        TestDiagram(id: "kanban-simple", category: "kanban", name: "Kanban - Simple Board",
                    source: "kanban\n  Todo\n    [Create Documentation]\n    docs[Create Blog about the new diagram]\n  id7[In progress]\n    id8[Design grammar]@{ assigned: 'knsv' }"),
        TestDiagram(id: "architecture-basic", category: "architecture", name: "Architecture - Basic",
                    source: "architecture-beta\n    group api(cloud)[API]\n    service db(database)[Database] in api\n    service server(server)[Server] in api\n    db:L -- R:server"),
        TestDiagram(id: "radar-empty", category: "radar", name: "Radar - Empty",
                    source: "radar-beta"),
        TestDiagram(id: "treemap-basic", category: "treemap", name: "Treemap - Basic",
                    source: "treemap-beta\n\"Category A\"\n    \"Item A1\": 10\n    \"Item A2\": 20\n\"Category B\"\n    \"Item B1\": 15\n    \"Item B2\": 25"),
        TestDiagram(id: "venn-simple-two-set", category: "venn", name: "Venn - Simple Two Set",
                    source: "venn-beta\n  set A\n  set B\n  union A,B"),
        TestDiagram(id: "ishikawa-simple", category: "ishikawa", name: "Ishikawa - Simple Fishbone",
                    source: "ishikawa-beta\nBlurry Photo\n    Process\n        Out of focus\n    User\n        Shaky hands"),
        TestDiagram(id: "treeview-basic-tree", category: "treeView", name: "TreeView - Basic File Tree",
                    source: "treeView-beta\n    src/\n        index.js\n    package.json\n    README.md"),
        TestDiagram(id: "eventmodeling-simple-state-change", category: "eventmodeling", name: "Event Modeling - Simple State Change",
                    source: "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"),
        TestDiagram(id: "wardley-1-tea-shop", category: "wardleyBeta", name: "Wardley Map - Tea Shop Value Chain",
                    source: "wardley-beta\ntitle Tea Shop Value Chain\nanchor Business [0.95, 0.63]\ncomponent Cup of Tea [0.79, 0.61]\ncomponent Tea [0.63, 0.81]\nBusiness -> Cup of Tea\nCup of Tea -> Tea\nevolve Tea 0.89"),
    ]
}
