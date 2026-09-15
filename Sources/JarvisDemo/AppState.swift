import Foundation
import SwiftUI
import AppKit

enum ServerStatus: String { case checking = "Checking", online = "Online", offline = "Offline", starting = "Starting" }

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published private(set) var browserTiles: [Tile] = []
    @Published private(set) var fileTiles: [Tile] = []
    @Published private(set) var workspaceTiles: [Tile] = []
    @Published private(set) var browserSections: [TileSection] = []
    @Published private(set) var fileSections: [TileSection] = []
    @Published private(set) var hiddenTiles: [Tile] = []
    @Published private(set) var profiles: [Tile] = []
    @Published private(set) var statuses: [String: ServerStatus] = [:]
    @Published private(set) var launching = Set<String>()
    @Published var errorMessage: String?
    @Published var notice: String?
    private(set) var config = Config()
    private var canSave = true
    private var refreshing = false
    private var startupTasks = Set<String>()
    private var detectedTiles: [Tile] = []
    private var discoveryTask: Task<Void, Never>?

    init() { config = SampleData.workspace; reload() }

    var allTiles: [Tile] { workspaceTiles + browserTiles + fileTiles }
    var memberTiles: [Tile] { browserTiles + fileTiles }
    var groups: [String] { config.groups }
    var workspaces: [WorkspaceEntry] { config.workspaces }
    var collapsedGroups: [String] { config.collapsedGroups }

    func reload() { applyDetectedTiles(SampleData.browserProfiles) }

    private func applyDetectedTiles(_ detected: [Tile]) {
        let merged = applyConfig(detected + config.links.map(linkTile) + config.files.map(fileTile), config: config).map(resolveImage)
        let nextbrowserTiles = merged.filter { $0.kind != .file }
        if browserTiles != nextbrowserTiles { browserTiles = nextbrowserTiles }
        let nextfileTiles = merged.filter { $0.kind == .file }
        if fileTiles != nextfileTiles { fileTiles = nextfileTiles }
        let nextworkspaceTiles = config.workspaces.map(workspaceTile)
        if workspaceTiles != nextworkspaceTiles { workspaceTiles = nextworkspaceTiles }
        let nextprofiles = applyConfig(detected.filter { $0.kind == .chromeProfile }, config: Config(overrides: config.overrides))
        if profiles != nextprofiles { profiles = nextprofiles }
        let nextbrowserSections = grouped(browserTiles, config: config)
        if browserSections != nextbrowserSections { browserSections = nextbrowserSections }
        let nextfileSections = grouped(fileTiles, config: config)
        if fileSections != nextfileSections { fileSections = nextfileSections }
        let nexthiddenTiles = detected.filter { config.hidden.contains($0.id) }
        if hiddenTiles != nexthiddenTiles { hiddenTiles = nexthiddenTiles }
    }

    private func resolveImage(_ tile: Tile) -> Tile {
        var t = tile
        if let img = t.customImage { t.customImage = Storage.iconsDir.appendingPathComponent(img).path }
        return t
    }

    @discardableResult
    private func commit(_ next: Config) -> Bool {
        guard canSave else { errorMessage = "Editing is disabled until settings are recovered. Open the settings folder from the recovery banner."; return false }
        config = next; reload(); return true
    }

    func rename(_ tile: Tile, to label: String) { commit(renamed(config, id: tile.id, label: label)) }
    func reset(_ tile: Tile) { commit(resetTile(config, id: tile.id)) }
    func clearImage(_ tile: Tile) { commit(imageSet(config, id: tile.id, filename: "")) }
    func setImage(_ tile: Tile, from src: URL) {
        guard NSImage(contentsOf: src) != nil else { errorMessage = "That file could not be read as an image."; return }
        do { let name = try Storage.storeIcon(from: src, forTileID: tile.id); commit(imageSet(config, id: tile.id, filename: name)) }
        catch { errorMessage = "The image could not be replaced. Your previous image is intact.\n\(error.localizedDescription)" }
    }
    func removeFile(_ tile: Tile) { commit(removedFile(config, fileId: String(tile.id.dropFirst("file:".count)))) }
    func removeBrowser(_ tile: Tile) { commit(hidTile(config, id: tile.id)) }
    func removeLink(_ tile: Tile) { commit(removedLink(config, linkId: String(tile.id.dropFirst("link:".count)))) }
    func unhide(_ tile: Tile) { commit(unhidTile(config, id: tile.id)) }
    func setFileApp(_ tile: Tile, to url: URL?) { commit(fileAppSet(config, fileId: String(tile.id.dropFirst("file:".count)), app: url?.path)) }
    func addFile(url: URL) { commit(addedFile(config, path: url.path)) }
    func locateFile(_ tile: Tile, at url: URL) {
        do { commit(try relocatedFile(config, id: tile.id, path: url.path)) } catch { errorMessage = error.localizedDescription }
    }
    func linkEntry(for tile: Tile) -> LinkEntry? { config.links.first { tileKey(.link, $0.id) == tile.id } }
    @discardableResult
    func saveLink(id: String?, url: String, profile: String?, startupFile: String?) -> Bool {
        do {
            let success = commit(try editedLink(config, id: id, url: url, profile: profile, startupFile: startupFile))
            if success { Task { await refreshStatus() } }
            return success
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func groupName(for id: String) -> String? { config.tileGroups[id] }
    func setGroup(id: String, to name: String?) {
        guard memberTiles.contains(where: { $0.id == id }) else { return }
        commit(assignedGroup(config, id: id, group: name))
    }
    func renameGroup(from old: String, to new: String) {
        var next = renamedGroup(config, from: old, to: new)
        if config.collapsedGroups.contains(old) { next.collapsedGroups.removeAll { $0 == old }; next.collapsedGroups.append(new.trimmingCharacters(in: .whitespacesAndNewlines)) }
        commit(next)
    }
    func moveGroup(_ name: String, by delta: Int) { commit(movedGroup(config, name: name, by: delta)) }
    func removeGroup(_ name: String) { var next = removedGroup(config, name: name); next.collapsedGroups.removeAll { $0 == name }; commit(next) }
    func toggleGroup(_ name: String) {
        var next = config
        if next.collapsedGroups.contains(name) { next.collapsedGroups.removeAll { $0 == name } } else { next.collapsedGroups.append(name) }
        commit(next)
    }
    func orderedVisible(_ tiles: [Tile], query: String) -> [Tile] { visibleTiles(tiles, config: config, query: query) }

    func move(draggedID: String, beforeID: String, inFileSection: Bool) {
        var ids = (inFileSection ? fileTiles : browserTiles).map(\.id)
        guard let from = ids.firstIndex(of: draggedID), ids.contains(beforeID) else { return }
        let item = ids.remove(at: from)
        ids.insert(item, at: ids.firstIndex(of: beforeID) ?? ids.count)
        let others = (inFileSection ? browserTiles : fileTiles).map(\.id)
        var next = reordered(config, orderedIDs: inFileSection ? others : ids, otherIDs: inFileSection ? ids : others)
        // Dropping onto a tile moves into that tile's group as well as its position.
        next = assignedGroup(next, id: draggedID, group: config.tileGroups[beforeID])
        commit(next)
    }
    func moveToEnd(draggedID: String, inFileSection: Bool) {
        var ids = (inFileSection ? fileTiles : browserTiles).map(\.id)
        guard let from = ids.firstIndex(of: draggedID) else { return }
        ids.append(ids.remove(at: from))
        let others = (inFileSection ? browserTiles : fileTiles).map(\.id)
        commit(reordered(config, orderedIDs: inFileSection ? others : ids, otherIDs: inFileSection ? ids : others))
    }
    @discardableResult
    func saveWorkspace(_ entry: WorkspaceEntry) -> Bool {
        var entry = entry; entry.name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.name.isEmpty, !entry.tileIDs.isEmpty else { errorMessage = "Give the workspace a name and choose at least one item."; return false }
        var next = config
        if let i = next.workspaces.firstIndex(where: { $0.id == entry.id }) { next.workspaces[i] = entry }
        else { next.workspaces.append(entry) }
        return commit(next)
    }
    func removeWorkspace(_ id: String) { var next = config; next.workspaces.removeAll { $0.id == id }; commit(next) }

    func launch(_ tile: Tile) { HomeDeskStore.shared.record(tile.id); notice = "Sample shortcut: " + tile.label + ". External launching is disabled in this demo." }
    func performJarvisAction(_ tile: Tile, startOnly: Bool) async throws { launch(tile) }
    func startServer(_ tile: Tile) { notice = "Server startup is disabled in this demo." }
    func refreshStatus() async { for link in config.links where isLocalServer(link.url) { statuses[link.id] = .online } }
}
