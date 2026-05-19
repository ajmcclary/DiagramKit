workspace {
    model {
        customer = person "Customer"
        group "outer" {
            banking = softwareSystem "Banking System"
        }
        group "inner" {
            # diagramkit:boundary-parent=outer
            payments = softwareSystem "Payments"
        }
        customer -> banking "Uses"
        banking -> payments "Calls"
    }

    views {
        systemContext banking "SystemContext" {
            include *
        }
    }
}
