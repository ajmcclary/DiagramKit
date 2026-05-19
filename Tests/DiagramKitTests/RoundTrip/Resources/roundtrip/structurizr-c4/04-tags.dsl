workspace {
    model {
        customer = person "Customer"
        # diagramkit:tag=external
        banking = softwareSystem "Banking System"
        # diagramkit:tag=core
        customer -> banking "Uses"
    }

    views {
        systemContext banking "SystemContext" {
            include *
        }
    }
}
