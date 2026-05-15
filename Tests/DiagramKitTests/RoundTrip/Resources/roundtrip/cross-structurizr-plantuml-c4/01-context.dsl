workspace {
    model {
        customer = person "Customer"
        banking = softwareSystem "Banking System"
        customer -> banking "Uses"
    }

    views {
        systemContext banking "SystemContext" {
            include *
        }
    }
}
