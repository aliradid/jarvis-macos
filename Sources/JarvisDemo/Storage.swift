import Foundation

struct ConfigLoad {
    var config: Config
    var notice: String? = nil
    var canSave = true
}

enum Storage {
    static var baseDir: URL {
        // Public edition: isolated temporary data only; never open the personal app's store.
        FileManager.default.temporaryDirectory
            .appendingPathComponent("JarvisPortfolioDemo", isDirectory: true)
    }
    static var configURL: URL { baseDir.appendingPathComponent("config.json") }
    static var iconsDir: URL { baseDir.appendingPathComponent("icons", isDirectory: true) }
    static func backupURL(for url: URL) -> URL { url.appendingPathExtension("backup") }

    static func ensureDirs() {
        try? FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
    }

    static func decode(_ data: Data) throws -> Config {
        let config = try JSONDecoder().decode(Config.self, from: data)
        guard Set(config.files.map(\.id)).count == config.files.count,
              Set(config.links.map(\.id)).count == config.links.count,
              Set(config.workspaces.map(\.id)).count == config.workspaces.count,
              Set(config.groups).count == config.groups.count else {
            throw LaunchpadError(message: "Settings contain duplicate tile or group IDs.")
        }
        return config
    }

    static func loadRecovering(from url: URL? = nil) -> ConfigLoad {
        let u = url ?? configURL
        guard FileManager.default.fileExists(atPath: u.path) else {
            if let data = try? Data(contentsOf: backupURL(for: u)), let config = try? decode(data) {
                return ConfigLoad(config: config, notice: "Settings were missing. Loaded the recovery backup.")
            }
            return ConfigLoad(config: Config())
        }
        do { return ConfigLoad(config: try decode(Data(contentsOf: u))) }
        catch {
            let originalError = error.localizedDescription
            // Preserve the original bytes before permitting any replacement.
            let damaged = u.deletingLastPathComponent().appendingPathComponent("config-unreadable-\(UUID().uuidString).json")
            do { try FileManager.default.copyItem(at: u, to: damaged) }
            catch { return ConfigLoad(config: Config(), notice: "Settings could not be read or backed up. Editing is disabled to protect them. \(originalError)", canSave: false) }
            if let data = try? Data(contentsOf: backupURL(for: u)), let recovered = try? decode(data) {
                return ConfigLoad(config: recovered, notice: "Recovered settings from the backup. The unreadable original is preserved as \(damaged.lastPathComponent).")
            }
            return ConfigLoad(config: Config(), notice: "Settings could not be read. The original is preserved as \(damaged.lastPathComponent). Restore a valid config.json in the settings folder, then relaunch. Editing is disabled. \(originalError)", canSave: false)
        }
    }

    // Compatibility helper for migration and model tests; production uses loadRecovering.
    static func loadConfig(from url: URL? = nil) -> Config {
        guard let data = try? Data(contentsOf: url ?? configURL), let config = try? decode(data) else { return Config() }
        return config
    }

    @discardableResult
    static func saveConfig(_ config: Config, to url: URL? = nil) -> Result<Void, Error> {
        Result {
            let u = url ?? configURL
            try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(config)
            _ = try decode(data)
            if FileManager.default.fileExists(atPath: u.path) {
                let previous = try Data(contentsOf: u)
                // Never overwrite a good backup with malformed settings.
                if (try? decode(previous)) != nil { try previous.write(to: backupURL(for: u), options: .atomic) }
            } else if !FileManager.default.fileExists(atPath: backupURL(for: u).path) {
                try data.write(to: backupURL(for: u), options: .atomic)
            }
            try data.write(to: u, options: .atomic)
        }
    }

    @discardableResult
    static func saveIcon(from src: URL, forTileID id: String, iconsOverride: URL? = nil) -> String? {
        try? storeIcon(from: src, forTileID: id, iconsOverride: iconsOverride)
    }

    static func storeIcon(from src: URL, forTileID id: String, iconsOverride: URL? = nil) throws -> String {
        let icons = iconsOverride ?? iconsDir
        // Read first; selecting the existing icon or a failed copy cannot destroy it.
        let data = try Data(contentsOf: src)
        guard !data.isEmpty else { throw LaunchpadError(message: "The selected image is empty.") }
        try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
        let ext = src.pathExtension.lowercased().isEmpty ? "png" : src.pathExtension.lowercased()
        let filename = "\(fileId(forPath: id)).\(UUID().uuidString).\(ext)"
        try data.write(to: icons.appendingPathComponent(filename), options: .atomic)
        // Retain previous artwork: the recovery config may still reference it.
        return filename
    }

    static func removeIcon(forTileID id: String, iconsOverride: URL? = nil) {
        let icons = iconsOverride ?? iconsDir
        let base = fileId(forPath: id)
        guard let existing = try? FileManager.default.contentsOfDirectory(atPath: icons.path) else { return }
        for f in existing where f.hasPrefix(base + ".") { try? FileManager.default.removeItem(at: icons.appendingPathComponent(f)) }
    }
}
