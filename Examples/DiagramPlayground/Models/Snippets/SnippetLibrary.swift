//
//  SnippetLibrary.swift
//  DiagramPlayground
//
//  Phase 9 / Task 9.3 — embedded library of 28 paste-ready snippets,
//  one per DiagramType. The plan asked for resource files; embedding
//  them as Swift constants keeps the snippets versioned with the
//  code and avoids SwiftPM resource-bundling overhead for what is
//  fundamentally a few KB of text.
//

import Foundation
import DiagramKitModel

public enum SnippetLibrary {

    public static let all: [Snippet] = [
        Snippet(id: "flowchart", title: "Flowchart", family: .flowchart, body: """
        flowchart TD
          A[Start] --> B{Decide}
          B -->|Yes| C[Continue]
          B -->|No| D[Stop]
        """),
        Snippet(id: "sequence", title: "Sequence", family: .sequenceDiagram, body: """
        sequenceDiagram
          participant A as Alice
          participant B as Bob
          A->>B: Hello
          B-->>A: Hi
        """),
        Snippet(id: "state", title: "State", family: .stateDiagram, body: """
        stateDiagram-v2
          [*] --> Idle
          Idle --> Running: start
          Running --> Idle: stop
          Running --> [*]: shutdown
        """),
        Snippet(id: "class", title: "Class", family: .classDiagram, body: """
        classDiagram
          class Animal {
            +String name
            +eat()
          }
          class Dog
          Animal <|-- Dog
        """),
        Snippet(id: "er", title: "Entity-relationship", family: .erDiagram, body: """
        erDiagram
          CUSTOMER ||--o{ ORDER : places
          ORDER ||--|{ LINE_ITEM : contains
        """),
        Snippet(id: "gantt", title: "Gantt", family: .gantt, body: """
        gantt
          title Roadmap
          dateFormat  YYYY-MM-DD
          section Plan
          Spec     :a1, 2026-01-01, 7d
          Build    :a2, after a1, 14d
        """),
        Snippet(id: "pie", title: "Pie", family: .pie, body: """
        pie title Languages
          "Swift" : 60
          "Other" : 40
        """),
        Snippet(id: "journey", title: "User journey", family: .journey, body: """
        journey
          title Onboarding
          section Signup
            Visit page : 5: User
            Submit form : 4: User
        """),
        Snippet(id: "gitGraph", title: "Git graph", family: .gitGraph, body: """
        gitGraph
          commit
          branch feat
          checkout feat
          commit
          checkout main
          merge feat
        """),
        Snippet(id: "mindmap", title: "Mindmap", family: .mindmap, body: """
        mindmap
          root((DiagramKit))
            Parsers
            Renderers
            Tests
        """),
        Snippet(id: "timeline", title: "Timeline", family: .timeline, body: """
        timeline
          title Project history
          2024 : Bootstrap
          2025 : v1.0
        """),
        Snippet(id: "quadrant", title: "Quadrant", family: .quadrantChart, body: """
        quadrantChart
          title Effort vs impact
          x-axis Low effort --> High effort
          y-axis Low impact --> High impact
          A: [0.2, 0.8]
          B: [0.7, 0.4]
        """),
        Snippet(id: "requirement", title: "Requirement", family: .requirement, body: """
        requirementDiagram
          requirement perf {
            id: "R1"
            text: "p99 < 100ms"
          }
        """),
        Snippet(id: "sankey", title: "Sankey", family: .sankey, body: """
        sankey-beta
          A,B,10
          A,C,5
          B,D,8
        """),
        Snippet(id: "block", title: "Block", family: .block, body: """
        block-beta
          columns 2
          A B
          C D
        """),
        Snippet(id: "packet", title: "Packet", family: .packet, body: """
        packet-beta
          0-15: "src"
          16-31: "dst"
        """),
        Snippet(id: "kanban", title: "Kanban", family: .kanban, body: """
        kanban
          backlog[Backlog]
            id1[Spec the feature]
          inProgress[In progress]
            id2[Wire the API]
          done[Done]
            id3[Land the patch]
        """),
        Snippet(id: "architecture", title: "Architecture", family: .architecture, body: """
        architecture-beta
          group api(cloud)[API]
          service db(database)[Postgres] in api
        """),
        Snippet(id: "radar", title: "Radar", family: .radar, body: """
        radar
          title Skills
          axes Coding, Testing, Design
          A: 4, 3, 5
          B: 5, 4, 3
        """),
        Snippet(id: "treemap", title: "Treemap", family: .treemap, body: """
        treemap-beta
          A 30
          B 20
          C 50
        """),
        Snippet(id: "venn", title: "Venn", family: .venn, body: """
        venn
          A & B
          A & C
        """),
        Snippet(id: "ishikawa", title: "Ishikawa", family: .ishikawa, body: """
        ishikawa
          title Why slow?
          People
          Process
          Tools
        """),
        Snippet(id: "treeView", title: "Tree view", family: .treeView, body: """
        treeView
          root
            child1
            child2
              grandchild
        """),
        Snippet(id: "eventModeling", title: "Event modeling", family: .eventModeling, body: """
        eventModeling
          command:Place Order
          event:Order Placed
        """),
        Snippet(id: "wardley", title: "Wardley", family: .wardleyBeta, body: """
        wardleyBeta
          title Mapping
          component A: Genesis
          component B: Custom
        """),
        Snippet(id: "c4", title: "C4 context", family: .c4, body: """
        C4Context
          Person(user, "User")
          System(app, "App", "Does the thing")
          Rel(user, app, "uses")
        """),
        Snippet(id: "zenuml", title: "ZenUML", family: .zenuml, body: """
        zenuml
          A.method() {
            B.respond()
          }
        """),
        Snippet(id: "xychart", title: "XY chart", family: .xyChart, body: """
        xychart-beta
          title Demand
          x-axis [Q1, Q2, Q3, Q4]
          y-axis "Units" 0 --> 200
          bar  [50, 100, 150, 200]
        """)
    ]

    /// Filter snippets by free-text search across id / title / family.
    public static func filtered(_ search: String) -> [Snippet] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return all }
        return all.filter { snippet in
            let haystack = "\(snippet.id) \(snippet.title) \(snippet.family.rawValue)".lowercased()
            return haystack.contains(needle)
        }
    }
}
