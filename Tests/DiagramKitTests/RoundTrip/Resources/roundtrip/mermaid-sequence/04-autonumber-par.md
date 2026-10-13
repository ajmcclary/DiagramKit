sequenceDiagram
    autonumber
    participant A as Alice
    participant B as Bob
    par init
        A->>B: start
    and cleanup
        A->>B: stop
    end
