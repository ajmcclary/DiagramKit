graph TD
    A[Start] --> B{Decision}
    B -->|yes| C[Option A]
    B -->|no| D[Option B]
    C --> E[Merge]
    D --> E
