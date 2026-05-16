stateDiagram-v2
    state "Connection Open" as Open
    state "Connection Closed" as Closed
    [*] --> Closed
    Closed --> Open : connect
    Open --> Closed : disconnect
