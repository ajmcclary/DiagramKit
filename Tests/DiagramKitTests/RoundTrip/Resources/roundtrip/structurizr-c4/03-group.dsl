workspace {
    model {
        customer = person "Customer"
        group "Internal" {
            banking = softwareSystem "Banking System"
            mainframe = softwareSystem "Mainframe"
        }
        customer -> banking "Uses"
        banking -> mainframe "Reads from"
    }

    views {
        systemContext banking "SystemContext" {
            include *
        }
    }
}
