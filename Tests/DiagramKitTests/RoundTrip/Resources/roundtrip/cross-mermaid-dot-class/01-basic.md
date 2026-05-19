classDiagram
    class Animal {
        +name: string
        +sound() void
    }
    class Dog {
        +breed: string
        +bark() void
    }
    Animal <|-- Dog
