C4Context
    Person(customer, "Customer")
    System(banking, "Banking System")
    System(mainframe, "Mainframe")
    Rel(customer, banking, "Uses")
    Rel(banking, mainframe, "Reads from")
