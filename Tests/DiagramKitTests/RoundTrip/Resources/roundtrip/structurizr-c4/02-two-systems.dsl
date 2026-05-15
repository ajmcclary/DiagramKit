workspace {
    model {
        customer = person "Customer"
        banking = softwareSystem "Banking System"
        mainframe = softwareSystem "Mainframe"
        customer -> banking "Uses"
        banking -> mainframe "Reads from"
    }

    views {
        systemContext banking "SystemContext" {
            include *
        }
    }
}
