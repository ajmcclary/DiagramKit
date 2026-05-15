workspace {
    model {
        customer = person "Customer"
        system = softwareSystem "Banking System"
        customer -> system "Uses"
    }

    views {
        systemContext system "SystemContext" {
            include *
        }
    }
}
