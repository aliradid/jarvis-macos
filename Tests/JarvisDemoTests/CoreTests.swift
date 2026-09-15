import Foundation

final class CoreTests {
    var cleanup: [() -> Void] = []
    deinit { cleanup.reversed().forEach { $0() } }
    func addTeardownBlock(_ block: @escaping () -> Void) { cleanup.append(block) }
    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testCorruptSettingsRecoverPreviousValidConfiguration() throws {
        let directory = try temporaryFolder()
        let url = directory.appendingPathComponent("config.json")
        let first = Config(groups: ["Original"])
        try Storage.saveConfig(first, to: url).get()
        try Storage.saveConfig(Config(groups: ["Changed"]), to: url).get()
        let damaged = Data("{broken".utf8)
        try damaged.write(to: url)
        let recovered = Storage.loadRecovering(from: url)
        expectEqual(recovered.config, first)
        expectTrue(recovered.canSave)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let copies = files.filter { $0.lastPathComponent.hasPrefix("config-unreadable-") }
        expectEqual(copies.count, 1)
        try expectEqual(try Data(contentsOf: unwrap(copies.first)), damaged)
    }

    func testUnrecoverableSettingsDisableSaving() throws {
        let url = try temporaryFolder().appendingPathComponent("config.json")
        try Data("invalid".utf8).write(to: url)
        expectFalse(Storage.loadRecovering(from: url).canSave)
    }

    func testMalformedExistingFileCannotReplaceGoodBackup() throws {
        let url = try temporaryFolder().appendingPathComponent("config.json")
        let original = Config(groups: ["Preserved"])
        try Storage.saveConfig(original, to: url).get()
        try Data("invalid".utf8).write(to: url)
        try Storage.saveConfig(Config(groups: ["New"]), to: url).get()
        try expectEqual(try Storage.decode(Data(contentsOf: Storage.backupURL(for: url))), original)
    }

    func testDuplicateIDsAreRejected() throws {
        let entry = LinkEntry(id: "duplicate", url: "https://example.com")
        let data = try JSONEncoder().encode(Config(links: [entry, entry]))
        expectThrows(try Storage.decode(data))
    }

    func testOlderConfigurationDecodesButMalformedFieldsFail() throws {
        try expectEqual(try Storage.decode(Data("{}".utf8)), Config())
        expectThrows(try Storage.decode(Data("{\"links\":42}".utf8)))
    }

    func testLinkValidationRejectsExecutableSchemesAndEmbeddedCredentials() throws {
        for value in ["javascript://example.com", "file:///tmp/example", "https://user:pass@example.com", "https://example.com:99999", "https://exa mple.com"] {
            expectThrows(try normalizedLink(value), value)
        }
        try expectEqual(try normalizedLink("example.com"), "https://example.com")
        expectTrue(isLocalServer("http://127.0.0.1:8080"))
        expectFalse(isLocalServer("https://localhost.example.com"))
    }

    func testRenamingPreservesTargetAndSearchFindsNewName() throws {
        let fixture = DemoFixtures.config
        let id = tileKey(.link, "docs")
        let changed = renamed(fixture, id: id, label: "Reference manual")
        let tiles = applyConfig(changed.links.map(linkTile), config: changed)
        let result = try unwrap(visibleTiles(tiles, config: changed, query: "reference").first)
        expectEqual(result.label, "Reference manual")
        expectEqual(launchPlan(for: result).target, "https://example.com/documentation")
        expectEqual(changed.links, fixture.links)
    }

    func testWorkspaceRejectsMissingMemberAndDeduplicates() throws {
        let available = DemoFixtures.links.map(linkTile)
        let id = available[0].id
        try expectEqual(try workspaceMembers(WorkspaceEntry(name: "Example", tileIDs: [id, id]), available: available).count, 1)
        expectThrows(try workspaceMembers(WorkspaceEntry(name: "Example", tileIDs: ["missing"]), available: available))
    }

    func testSearchFindsItemsInCollapsedGroups() {
        let tile = linkTile(DemoFixtures.links[0])
        var config = assignedGroup(Config(), id: tile.id, group: "Reference")
        config.collapsedGroups = ["Reference"]
        expectTrue(visibleTiles([tile], config: config, query: "").isEmpty)
        expectEqual(visibleTiles([tile], config: config, query: "documentation").count, 1)
    }

    func testDarijaMixedTextDiacriticsAndUnknownWords() {
        expectEqual(DarijaLatin.render("واش المشروع واجد؟"), "wach lprojet wajed?")
        expectEqual(DarijaLatin.render("عافاك ورّيني شنو خاصني ندير"), "3afak werrini chno khassni ndir")
        expectEqual(DarijaLatin.render("vidéo EN 2026"), "vidéo EN 2026")
        expectEqual(DarijaLatin.render("واش\nالفيديو"), "wach\nlvideo")
        expectNil(DarijaLatin.render("تنظيم الملفات").range(of: "\\p{Arabic}", options: .regularExpression))
    }
}


private func expectEqual<T: Equatable>(_ actual: @autoclosure () throws -> T, _ expected: @autoclosure () throws -> T, file: StaticString = #fileID, line: UInt = #line) rethrows {
    let a = try actual(), b = try expected()
    guard a == b else { fatalError("Values differ", file: file, line: line) }
}
private func expectTrue(_ value: Bool, file: StaticString = #fileID, line: UInt = #line) {
    guard value else { fatalError("Expected true", file: file, line: line) }
}
private func expectFalse(_ value: Bool, file: StaticString = #fileID, line: UInt = #line) { expectTrue(!value, file: file, line: line) }
private func expectNil<T>(_ value: T?, file: StaticString = #fileID, line: UInt = #line) { expectTrue(value == nil, file: file, line: line) }
private func expectThrows<T>(_ expression: @autoclosure () throws -> T, _ context: String = "", file: StaticString = #fileID, line: UInt = #line) {
    do { _ = try expression() } catch { return }
    fatalError("Expected an error: " + context, file: file, line: line)
}
private func unwrap<T>(_ value: T?, file: StaticString = #fileID, line: UInt = #line) throws -> T {
    guard let value else { fatalError("Expected a value", file: file, line: line) }
    return value
}

@main struct CoreTestRunner {
    static func main() throws {
        let suite = CoreTests()
        let tests: [(String, () throws -> Void)] = [
            ("Corruption recovery", suite.testCorruptSettingsRecoverPreviousValidConfiguration),
            ("Unrecoverable settings", suite.testUnrecoverableSettingsDisableSaving),
            ("Backup preservation", suite.testMalformedExistingFileCannotReplaceGoodBackup),
            ("Duplicate IDs", suite.testDuplicateIDsAreRejected),
            ("Schema compatibility", suite.testOlderConfigurationDecodesButMalformedFieldsFail),
            ("URL rejection", suite.testLinkValidationRejectsExecutableSchemesAndEmbeddedCredentials),
            ("Rename and search", suite.testRenamingPreservesTargetAndSearchFindsNewName),
            ("Workspace validation", suite.testWorkspaceRejectsMissingMemberAndDeduplicates),
            ("Collapsed group search", suite.testSearchFindsItemsInCollapsedGroups),
            ("Darija transliteration", suite.testDarijaMixedTextDiacriticsAndUnknownWords)
        ]
        for (name, test) in tests { try test(); print("PASS: " + name) }
        print("All \(tests.count) regression checks passed.")
    }
}
