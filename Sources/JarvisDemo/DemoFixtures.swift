import Foundation

enum DemoFixtures {
    static let links = [
        LinkEntry(id: "docs", url: "https://example.com/documentation"),
        LinkEntry(id: "design", url: "https://example.com/design"),
        LinkEntry(id: "board", url: "https://example.com/project-board")
    ]
    static let labels = ["Documentation", "Design library", "Project board"]
    static var config: Config {
        var result = Config(links: links)
        for (entry, label) in zip(links, labels) {
            result = renamed(result, id: tileKey(.link, entry.id), label: label)
        }
        return result
    }
}
