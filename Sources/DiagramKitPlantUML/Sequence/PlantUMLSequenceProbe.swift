import Foundation

/// Returns `true` when the PlantUML body contains sequence diagram syntax.
/// This is the broadest fallback within PlantUML — it fires when
/// no other family-specific probe matches.
public func isPlantUMLSequenceBody(_ body: String) -> Bool {
    let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()

        // Participant/actor declarations
        if lower.hasPrefix("participant ") || lower.hasPrefix("actor ") {
            return true
        }
        // Sequence arrows (A -> B, A --> B, etc.)
        if _containsSequenceArrow(trimmed) {
            return true
        }
        // Activation keywords
        if lower.hasPrefix("activate ") || lower.hasPrefix("deactivate ") {
            return true
        }
        if lower == "activate" || lower == "deactivate" {
            return true
        }
        // Note syntax
        if lower.hasPrefix("note ") {
            return true
        }
        // Grouping constructs
        if lower.hasPrefix("alt ") || lower.hasPrefix("loop ") || lower.hasPrefix("opt ") {
            return true
        }
        if lower.hasPrefix("group ") {
            return true
        }
        if lower.hasPrefix("box ") {
            return true
        }
        // Auto-number
        if lower.hasPrefix("autonumber") {
            return true
        }
    }
    return false
}

/// Check if a trimmed line contains a PlantUML sequence arrow pattern.
private func _containsSequenceArrow(_ line: String) -> Bool {
    // PlantUML arrows: ->, -->, ->>, ->o, ->x, <->, <-, <--, <<-, etc.
    // We look for a pattern: word arrow word [optional colon label]
    let arrowPatterns = ["->>", "-->", "->o", "->x", "<->",
                         "<--", "<<-", "<<--",
                         "->", "<-",
                         "o->", "x->", "o-", "x-"]
    for pattern in arrowPatterns {
        if line.contains(pattern) {
            return true
        }
    }
    return false
}
