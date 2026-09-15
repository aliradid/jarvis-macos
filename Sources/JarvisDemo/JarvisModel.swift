import Foundation

struct JarvisAction: Codable, Equatable, Identifiable {
    var kind: String
    var targetID: String
    var label: String? = nil
    var id: String { kind + ":" + targetID }
}
struct JarvisReply: Codable { var reply: String; var actions: [JarvisAction] }
struct JarvisTurn: Codable, Identifiable {
    var id = UUID().uuidString
    var role: String
    var text: String
    var actions: [JarvisAction] = []
}
struct JarvisHistory: Codable {
    var turns: [JarvisTurn] = []
    var notes = ""
    var focusID: String? = nil
    var focusLabel: String? = nil
    var recentProjectIDs: [String]? = nil
}
struct JarvisTarget: Codable, Identifiable {
    var id: String
    var label: String
    var category: String
    var status: String
    var canStart: Bool
}

enum JarvisCommands {
    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    static func direct(_ text: String, targets: [JarvisTarget]) -> JarvisAction? {
        var words = normalized(text).split(separator: " ").map(String.init)
        if words.first == "please" { words.removeFirst() }
        guard let verb = words.first, ["open", "start", "launch"].contains(verb) else { return nil }
        words.removeFirst()
        // Only a single unambiguous saved item is automatically dispatched.
        guard !words.contains("and"), !words.contains("then"), !words.contains("not") else { return nil }
        let stop: Set<String> = ["my", "the", "please", "thumbnail", "psd", "file", "browser", "profile", "mission", "control", "server"]
        let wanted = words.filter { !stop.contains($0) }.joined(separator: " ")
        guard !wanted.isEmpty else { return nil }
        let candidates = targets.filter {
            normalized($0.label) == wanted && (verb != "start" || $0.canStart)
        }
        guard candidates.count == 1 else { return nil }
        return JarvisAction(kind: verb == "start" ? "start" : "open", targetID: candidates[0].id)
    }
    static func validated(_ actions: [JarvisAction], targets: [JarvisTarget]) -> [JarvisAction] {
        var seen = Set<String>()
        return actions.filter { action in
            guard ["open", "start", "prepare", "focus"].contains(action.kind), let target = targets.first(where: { $0.id == action.targetID }),
                  (action.kind != "start" || target.canStart),
                  (!["prepare", "focus"].contains(action.kind) || target.category == "mission_project") else { return false }
            return seen.insert(action.id).inserted
        }.prefix(6).map { $0 }
    }
}
