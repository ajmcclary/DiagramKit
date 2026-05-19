erDiagram
    Customer ||--o{ Order : has
    Customer {
        number id
        text name
    }
    Order {
        number id
        number total
    }
