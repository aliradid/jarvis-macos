enum AIQuotaReaders {
    static func matchesWindow(_ label: String, weekly: Bool) -> Bool {
        let name = label.lowercased()
        if weekly { return name == "weekly" || name == "codex · weekly" }
        return name.contains("5 hours") || name.contains("5h") || name.hasPrefix("session")
    }
}
