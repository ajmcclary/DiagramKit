C4Context
    Person(customer, "Customer")
    Boundary(outer, "outer") {
      System(banking, "Banking System")
      Boundary(inner, "inner") {
        System(payments, "Payments")
      }
    }
    Rel(customer, banking, "Uses")
    Rel(banking, payments, "Calls")
