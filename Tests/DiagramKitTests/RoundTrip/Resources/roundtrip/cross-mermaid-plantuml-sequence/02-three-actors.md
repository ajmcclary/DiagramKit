sequenceDiagram
    Client->>Server: Query
    Server->>Database: Fetch
    Database-->>Server: Rows
    Server-->>Client: JSON
