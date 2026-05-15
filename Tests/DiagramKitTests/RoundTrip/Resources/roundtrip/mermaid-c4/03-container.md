C4Container
    Person(customer, "Customer")
    Container(api, "API", "Java")
    Container(db, "Database", "PostgreSQL")
    Rel(customer, api, "Calls")
    Rel(api, db, "Reads/Writes")
