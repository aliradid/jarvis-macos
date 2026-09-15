import Foundation
import CryptoKit

enum TileKind: String, Codable, Equatable {
    case chromeProfile = "chrome-profile"
    case browser
    case file
    case link
    case workspace
}

enum LaunchInvocation: Equatable {
    case openFile(path: String, app: String?)
    case openApp(name: String)
    case openChromeProfile(dir: String)
    case openURL(url: String, profile: String? = nil)
    case workspace(id: String)
}

struct Override: Codable, Equatable {
    var label: String?
    var image: String?   // filename inside icons/
    var isEmpty: Bool { (label?.isEmpty ?? true) && (image?.isEmpty ?? true) }
}

struct FileEntry: Codable, Equatable {
    var id: String
    var path: String
    var app: String? = nil   // optional .app path to open the file with
}

struct LinkEntry: Codable, Equatable {
    var id: String
    var url: String
    var profile: String? = nil
    var startupFile: String? = nil
}

struct WorkspaceEntry: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var tileIDs: [String]
}


struct Config: Codable, Equatable {
    var order: [String] = []
    var overrides: [String: Override] = [:]
    var files: [FileEntry] = []
    var links: [LinkEntry] = []
    var workspaces: [WorkspaceEntry] = []
    var collapsedGroups: [String] = []
    var hidden: [String] = []           // tile ids of removed (auto-detected) browsers/profiles
    var groups: [String] = []           // ordered group names
    var tileGroups: [String: String] = [:]  // tile id -> group name

    init(order: [String] = [], overrides: [String: Override] = [:], files: [FileEntry] = [],
         links: [LinkEntry] = [], workspaces: [WorkspaceEntry] = [], collapsedGroups: [String] = [],
         hidden: [String] = [], groups: [String] = [], tileGroups: [String: String] = [:]) {
        self.order = order; self.overrides = overrides; self.files = files; self.links = links
        self.workspaces = workspaces; self.collapsedGroups = collapsedGroups
        self.hidden = hidden; self.groups = groups; self.tileGroups = tileGroups
    }

    enum CodingKeys: String, CodingKey { case order, overrides, files, links, hidden, groups, tileGroups, workspaces, collapsedGroups }

    // Missing fields are compatible with older versions; malformed fields must not silently erase data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order = try c.decodeIfPresent([String].self, forKey: .order) ?? []
        overrides = try c.decodeIfPresent([String: Override].self, forKey: .overrides) ?? [:]
        files = try c.decodeIfPresent([FileEntry].self, forKey: .files) ?? []
        links = try c.decodeIfPresent([LinkEntry].self, forKey: .links) ?? []
        workspaces = try c.decodeIfPresent([WorkspaceEntry].self, forKey: .workspaces) ?? []
        collapsedGroups = try c.decodeIfPresent([String].self, forKey: .collapsedGroups) ?? []
        hidden = try c.decodeIfPresent([String].self, forKey: .hidden) ?? []
        groups = try c.decodeIfPresent([String].self, forKey: .groups) ?? []
        tileGroups = try c.decodeIfPresent([String: String].self, forKey: .tileGroups) ?? [:]
    }
}

struct Tile: Identifiable, Equatable {
    let id: String              // "<kind>:<rawId>"
    let kind: TileKind
    var label: String
    let detectedLabel: String
    let subtitle: String
    let invocation: LaunchInvocation
    var customImage: String?    // filename in icons/, or nil
    let iconSourcePath: String? // app-bundle path or file path to derive the system icon
}

func tileKey(_ kind: TileKind, _ rawId: String) -> String { "\(kind.rawValue):\(rawId)" }

func fileId(forPath path: String) -> String {
    let digest = Insecure.SHA1.hash(data: Data(path.utf8))
    return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
}

func fileTile(_ entry: FileEntry) -> Tile {
    let ns = entry.path as NSString
    let name = ns.lastPathComponent
    let stem = (name as NSString).deletingPathExtension
    let ext = (name as NSString).pathExtension.uppercased()
    let folder = (ns.deletingLastPathComponent as NSString).lastPathComponent
    let kindLabel = ext.isEmpty ? "FILE" : ext
    return Tile(
        id: tileKey(.file, entry.id), kind: .file,
        label: stem.isEmpty ? name : stem, detectedLabel: stem.isEmpty ? name : stem,
        subtitle: "\(kindLabel) · \(folder.isEmpty ? "/" : folder)",
        invocation: .openFile(path: entry.path, app: entry.app), customImage: nil, iconSourcePath: entry.path
    )
}

// A link tile: label defaults to host:port ("localhost:8080"), subtitle is the
// full URL so search can match it. No filesystem icon; TileIcon shows a globe.
func linkTile(_ entry: LinkEntry) -> Tile {
    var label = entry.url
    if let u = URL(string: entry.url), let host = u.host {
        label = u.port.map { "\(host):\($0)" } ?? host
    }
    return Tile(
        id: tileKey(.link, entry.id), kind: .link,
        label: label, detectedLabel: label,
        subtitle: entry.url,
        invocation: .openURL(url: entry.url, profile: entry.profile), customImage: nil, iconSourcePath: nil
    )
}

// A row of identical globe icons is unreadable, so each link gets a glanceable
// stand-in instead: its port number, or the start of the host when there is none.
func linkBadgeText(_ urlString: String) -> String {
    guard let u = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else { return "WWW" }
    if let port = u.port { return String(port) }
    guard let host = u.host, !host.isEmpty else { return "WWW" }
    let core = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    return String(core.prefix(2)).uppercased()
}

// Stable hue in 0..<1, so a link keeps the same colour across relaunches.
// FNV-1a: cheap, well-spread, and doesn't drag in CryptoKit for a display detail.
func linkHue(_ urlString: String) -> Double {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in urlString.utf8 {
        hash = (hash ^ UInt64(byte)) &* 0x100000001b3
    }
    return Double(hash % 360) / 360.0
}

// Pure, testable mapping of a tile to what should be launched.
func launchPlan(for tile: Tile) -> (kind: String, target: String, args: [String]) {
    switch tile.invocation {
    case .openFile(let p, let a): return ("file", p, a.map { [$0] } ?? [])
    case .openApp(let n): return ("app", n, [])
    case .openChromeProfile(let d): return ("chrome", "Google Chrome", ["--profile-directory=\(d)"])
    case .openURL(let u, let p): return ("url", u, p.map { ["--profile-directory=\($0)"] } ?? [])
    case .workspace(let id): return ("workspace", id, [])
    }
}

// Search filter: blank query matches everything.
func matches(_ tile: Tile, query: String) -> Bool {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if q.isEmpty { return true }
    return tile.label.localizedCaseInsensitiveContains(q)
        || tile.subtitle.localizedCaseInsensitiveContains(q)
}

// Layer overrides (label, image) and saved order onto detected tiles.
func applyConfig(_ tiles: [Tile], config: Config) -> [Tile] {
    let visible = tiles.filter { !config.hidden.contains($0.id) }
    let withOverrides = visible.map { tile -> Tile in
        var t = tile
        if let ov = config.overrides[t.id] {
            if let l = ov.label, !l.isEmpty { t.label = l }
            t.customImage = ov.image
        }
        return t
    }
    var pos: [String: Int] = [:]
    for (i, key) in config.order.enumerated() { pos[key] = i }
    // Stable: listed by saved position, the rest keep detection order.
    return withOverrides.enumerated().sorted { lhs, rhs in
        let pa = pos[lhs.element.id] ?? Int.max
        let pb = pos[rhs.element.id] ?? Int.max
        if pa != pb { return pa < pb }
        return lhs.offset < rhs.offset
    }.map { $0.element }
}

func renamed(_ config: Config, id: String, label: String) -> Config {
    var c = config
    var ov = c.overrides[id] ?? Override()
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    ov.label = trimmed.isEmpty ? nil : trimmed
    c.overrides[id] = ov.isEmpty ? nil : ov
    return c
}

func imageSet(_ config: Config, id: String, filename: String) -> Config {
    var c = config
    var ov = c.overrides[id] ?? Override()
    ov.image = filename.isEmpty ? nil : filename
    c.overrides[id] = ov.isEmpty ? nil : ov
    return c
}

func resetTile(_ config: Config, id: String) -> Config {
    var c = config
    c.overrides[id] = nil
    return c
}

func addedFile(_ config: Config, path: String) -> Config {
    var c = config
    let fid = fileId(forPath: path)
    if !c.files.contains(where: { $0.id == fid || $0.path == path }) {
        c.files.append(FileEntry(id: fid, path: path))
    }
    return c
}

func removedFile(_ config: Config, fileId fid: String) -> Config {
    var c = config
    c.files.removeAll { $0.id == fid }
    c.overrides[tileKey(.file, fid)] = nil
    c.order.removeAll { $0 == tileKey(.file, fid) }
    c.tileGroups[tileKey(.file, fid)] = nil
    return c
}

// Link ids reuse the SHA1-prefix scheme (of the URL), so re-adding the same URL dedupes.
func addedLink(_ config: Config, url: String) -> Config {
    var c = config
    let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return c }
    let lid = fileId(forPath: trimmed)
    if !c.links.contains(where: { $0.id == lid }) {
        c.links.append(LinkEntry(id: lid, url: trimmed))
    }
    return c
}

func removedLink(_ config: Config, linkId lid: String) -> Config {
    var c = config
    c.links.removeAll { $0.id == lid }
    c.overrides[tileKey(.link, lid)] = nil
    c.order.removeAll { $0 == tileKey(.link, lid) }
    c.tileGroups[tileKey(.link, lid)] = nil
    return c
}

// Hide an auto-detected tile (browser/profile): drop its overrides/order entry
// and remember the id so detection keeps skipping it.
func hidTile(_ config: Config, id: String) -> Config {
    var c = config
    if !c.hidden.contains(id) { c.hidden.append(id) }
    c.overrides[id] = nil
    c.order.removeAll { $0 == id }
    c.tileGroups[id] = nil
    return c
}

func unhidTile(_ config: Config, id: String) -> Config {
    var c = config
    c.hidden.removeAll { $0 == id }
    return c
}

// Point a file entry at a specific app to open it with; nil/blank = default app.
func fileAppSet(_ config: Config, fileId fid: String, app: String?) -> Config {
    var c = config
    if let i = c.files.firstIndex(where: { $0.id == fid }) {
        c.files[i].app = (app?.isEmpty ?? true) ? nil : app
    }
    return c
}

func addedGroup(_ config: Config, name: String) -> Config {
    var c = config
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty && !c.groups.contains(trimmed) { c.groups.append(trimmed) }
    return c
}

func removedGroup(_ config: Config, name: String) -> Config {
    var c = config
    c.groups.removeAll { $0 == name }
    c.tileGroups = c.tileGroups.filter { $0.value != name }
    return c
}

// Assign a tile to a group (auto-creating it); nil/blank unassigns.
func assignedGroup(_ config: Config, id: String, group name: String?) -> Config {
    var c = config
    let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        c.tileGroups[id] = nil
    } else {
        if !c.groups.contains(trimmed) { c.groups.append(trimmed) }
        c.tileGroups[id] = trimmed
    }
    return c
}

// Rename a group and retarget its members; renaming to an existing group merges.
func renamedGroup(_ config: Config, from old: String, to new: String) -> Config {
    var c = config
    let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != old, c.groups.contains(old) else { return c }
    if c.groups.contains(trimmed) {
        c.groups.removeAll { $0 == old }
    } else if let i = c.groups.firstIndex(of: old) {
        c.groups[i] = trimmed
    }
    for (k, v) in c.tileGroups where v == old { c.tileGroups[k] = trimmed }
    return c
}

// Move a group up (-1) or down (+1); clamps at the edges.
func movedGroup(_ config: Config, name: String, by delta: Int) -> Config {
    var c = config
    guard let i = c.groups.firstIndex(of: name) else { return c }
    let j = i + delta
    guard c.groups.indices.contains(j) else { return c }
    c.groups.swapAt(i, j)
    return c
}

struct TileSection: Equatable {
    var name: String?   // nil = ungrouped
    var tiles: [Tile]
}

// The ungrouped pile only needs a heading when there are real groups below it to
// tell it apart from; on its own it is just "the list" and a header adds noise.
func sectionHeading(_ section: TileSection, totalSections: Int) -> String? {
    if let name = section.name { return name }
    return totalSections > 1 ? "Other" : nil
}

// Split ordered tiles into an ungrouped section plus one section per group
// (in configured group order). Stale memberships count as ungrouped.
func grouped(_ tiles: [Tile], config: Config) -> [TileSection] {
    var sections: [TileSection] = []
    let ungrouped = tiles.filter { t in
        guard let g = config.tileGroups[t.id] else { return true }
        return !config.groups.contains(g)
    }
    if !ungrouped.isEmpty { sections.append(TileSection(name: nil, tiles: ungrouped)) }
    for g in config.groups {
        let members = tiles.filter { config.tileGroups[$0.id] == g }
        if !members.isEmpty { sections.append(TileSection(name: g, tiles: members)) }
    }
    return sections
}

func reordered(_ config: Config, orderedIDs: [String], otherIDs: [String]) -> Config {
    var c = config
    c.order = orderedIDs + otherIDs
    return c
}

struct LaunchpadError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func normalizedLink(_ raw: String) throws -> String {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw LaunchpadError(message: "Enter a website address.") }
    if !text.contains("://") {
        let isLocal = text == "localhost" || text.hasPrefix("localhost:") || text.hasPrefix("localhost/")
            || text.hasPrefix("127.0.0.1") || text.hasPrefix("[::1]")
        text = (isLocal ? "http://" : "https://") + text
    }
    guard !text.contains(where: { $0.isWhitespace }),
          let parts = URLComponents(string: text),
          let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
          let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
          !(parts.port.map { !(1...65535).contains($0) } ?? false),
          !text.hasSuffix(":"), let url = parts.url else {
        throw LaunchpadError(message: "Enter a valid http or https address, such as localhost:8080 or example.com.")
    }
    return url.absoluteString
}

func isLocalServer(_ text: String) -> Bool {
    guard let u = URL(string: text), ["http", "https"].contains(u.scheme?.lowercased() ?? "") else { return false }
    return ["localhost", "127.0.0.1", "::1", "[::1]"].contains(u.host?.lowercased() ?? "")
}

func workspaceTile(_ entry: WorkspaceEntry) -> Tile {
    Tile(id: tileKey(.workspace, entry.id), kind: .workspace, label: entry.name,
         detectedLabel: entry.name, subtitle: "Workspace · \(entry.tileIDs.count) items",
         invocation: .workspace(id: entry.id), customImage: nil, iconSourcePath: nil)
}

func relocatedFile(_ config: Config, id: String, path: String) throws -> Config {
    var next = config
    guard let i = next.files.firstIndex(where: { tileKey(.file, $0.id) == id }) else {
        throw LaunchpadError(message: "This file tile no longer exists.")
    }
    guard !next.files.contains(where: { $0.path == path && tileKey(.file, $0.id) != id }) else {
        throw LaunchpadError(message: "That file already has a tile.")
    }
    next.files[i].path = path // Keep stable ID, artwork, group, workspace membership and chosen app.
    return next
}

func editedLink(_ config: Config, id: String?, url: String, profile: String?, startupFile: String?) throws -> Config {
    let address = try normalizedLink(url)
    var next = config
    guard !next.links.contains(where: { $0.url == address && $0.id != id }) else {
        throw LaunchpadError(message: "That address already has a tile. Edit the existing link instead.")
    }
    let entry = LinkEntry(id: id ?? UUID().uuidString, url: address, profile: profile, startupFile: startupFile)
    if let id = id {
        guard let i = next.links.firstIndex(where: { $0.id == id }) else { throw LaunchpadError(message: "This link no longer exists.") }
        next.links[i] = entry
    } else { next.links.append(entry) }
    return next
}

func workspaceMembers(_ entry: WorkspaceEntry, available: [Tile]) throws -> [Tile] {
    var result: [Tile] = []
    var seen = Set<String>()
    for id in entry.tileIDs where seen.insert(id).inserted {
        guard let tile = available.first(where: { $0.id == id && $0.kind != .workspace }) else {
            throw LaunchpadError(message: "A workspace item is unavailable (\(id)). Edit the workspace to reconnect or remove it.")
        }
        result.append(tile)
    }
    guard !result.isEmpty else { throw LaunchpadError(message: "Choose at least one item for this workspace.") }
    let profilesInLinks = Set(result.compactMap { tile -> String? in
        if case .openURL(_, let profile) = tile.invocation { return profile }; return nil
    })
    return result.filter { tile in
        if case .openChromeProfile(let dir) = tile.invocation { return !profilesInLinks.contains(dir) }
        return true
    }
}

func initials(_ name: String) -> String {
    let parts = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" })
    if parts.count > 1 { return parts.prefix(2).compactMap(\.first).map(String.init).joined().uppercased() }
    return String(name.prefix(2)).uppercased()
}

func fileAvailability(_ path: String, exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> String? {
    if exists(path) { return nil }
    let parts = (path as NSString).pathComponents
    if parts.count > 2 && parts[1] == "Volumes" && !exists("/Volumes/" + parts[2]) {
        return "Drive disconnected: " + parts[2]
    }
    return "File not found — use Locate File…"
}

func visibleTiles(_ tiles: [Tile], config: Config, query: String) -> [Tile] {
    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return tiles.filter { matches($0, query: query) } }
    return grouped(tiles, config: config).filter { !config.collapsedGroups.contains($0.name ?? "") }.flatMap(\.tiles)
}
