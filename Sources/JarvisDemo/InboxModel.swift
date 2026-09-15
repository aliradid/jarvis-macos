import Foundation

struct InboxMessage: Codable, Identifiable, Equatable {
    var id: String
    var date: Date
    var source: String
    var title: String
    var detail: String
    var kind: String
    var path: String
    var read = false
}

struct InboxArchive: Codable, Equatable {
    var since = Date()
    var messages: [InboxMessage] = []
    var seen: [String: Date] = [:]
    var unreadMessages: [InboxMessage] { messages.filter { !$0.read } }

    mutating func ingest(_ events: [InboxMessage], now: Date = Date()) -> [InboxMessage] {
        let cutoff = max(since, now.addingTimeInterval(-90 * 86400))
        seen = seen.filter { $0.value >= cutoff }
        var added: [InboxMessage] = []
        for event in events.sorted(by: { $0.date > $1.date }) where event.date >= cutoff && seen[event.id] == nil {
            seen[event.id] = event.date
            messages.append(event)
            added.append(event)
        }
        messages.sort { $0.date > $1.date }
        messages = Array(messages.prefix(300))
        return added
    }
}
