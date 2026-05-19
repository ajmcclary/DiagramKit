workspace {
    model {
        group "outer" {
            outerSystem = softwareSystem "Outer System"
        }
        group "inner" {
            # diagramkit:boundary-parent=outer
            innerSystem = softwareSystem "Inner System"
        }
        outerSystem -> innerSystem "Talks to"
    }

    views {
        systemContext outerSystem "SystemContext" {
            include *
        }
    }
}
