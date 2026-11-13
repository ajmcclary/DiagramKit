// Every string a sequence diagram holds, rewritten by one function. The
// Mermaid importer parses a sequence diagram with its entity codes
// shielded (so a coded `;`, `#` or `%%` is text, not syntax) and uses this
// to put the decoded characters back afterwards.

extension SequenceDiagram {
    public func _mappingText(_ f: (String) -> String) -> SequenceDiagram {
        func actor(_ a: SequenceActor) -> SequenceActor {
            var a = a
            a.id = f(a.id)
            a.label = f(a.label)
            if var config = a.config {
                config.alias = config.alias.map(f)
                a.config = config
            }
            a.boxId = a.boxId.map(f)
            a.links = Dictionary(a.links.map { (f($0.key), f($0.value)) }, uniquingKeysWith: { _, new in new })
            a.properties = Dictionary(a.properties.map { (f($0.key), f($0.value)) }, uniquingKeysWith: { _, new in new })
            a.detailsElementId = a.detailsElementId.map(f)
            return a
        }
        let mapped: [SequenceItem] = items.map { item in
            switch item {
            case .actor(let a): return .actor(actor(a))
            case .createParticipant(let a): return .createParticipant(actor(a))
            case .message(var m):
                m.from = f(m.from)
                m.to = f(m.to)
                m.label = f(m.label)
                return .message(m)
            case .note(var n):
                n.actorIds = n.actorIds.map(f)
                n.text = f(n.text)
                return .note(n)
            case .activationStart(let id): return .activationStart(actorId: f(id))
            case .activationEnd(let id): return .activationEnd(actorId: f(id))
            case .destroyParticipant(let id): return .destroyParticipant(actorId: f(id))
            case .autonumberEvent: return item
            case .blockStart(let type, let label): return .blockStart(type: type, label: f(label))
            case .blockDivider(let type, let label): return .blockDivider(type: type, label: f(label))
            case .blockEnd: return item
            case .boxStart(let fill, let title, let wrap): return .boxStart(fill: f(fill), title: title.map(f), wrap: wrap)
            case .boxEnd: return item
            case .title(let t): return .title(f(t))
            case .accTitle(let t): return .accTitle(f(t))
            case .accDescr(let t): return .accDescr(f(t))
            case .link(let id, let label, let url): return .link(f(id), label: f(label), url: f(url))
            case .links(let id, let json): return .links(f(id), json: f(json))
            case .properties(let id, let json): return .properties(f(id), json: f(json))
            case .details(let id, let element): return .details(f(id), elementId: f(element))
            }
        }
        return SequenceDiagram(items: mapped)
    }
}
