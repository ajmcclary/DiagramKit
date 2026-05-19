stateDiagram-v2
    [*] --> Idle
    Idle --> Active : trigger
    Active --> Done : complete
    Done --> [*]
