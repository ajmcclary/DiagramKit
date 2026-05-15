erDiagram
    CUSTOMER {
        string name
        string email
    }
    ORDER {
        int id
        date placedAt
    }
    CUSTOMER ||--o{ ORDER : places
