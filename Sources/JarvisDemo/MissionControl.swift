import Foundation
import CryptoKit

struct MissionSource: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let root: String
    let port: Int
    let primaryLanguage: String
    static var installed: [MissionSource] { SampleData.sources }
}

struct MissionProject: Identifiable, Codable, Equatable {
    var id: String
    var sourceID: String
    var source: String
    var language: String
    var title: String
    var folder: String
    var status: String
    var stage: String
    var detail: String
    var modified: Date
    var video: String?
    var thumbnails: [String]
    var needsAttention: Bool { ["failed", "review", "interrupted", "unknown"].contains(status) }
    var isReady: Bool { video != nil && status != "running" && !needsAttention }
    var displayName: String { "\(source) · \(language.uppercased()) · \(title)" }
    static func identity(_ folder: URL) -> String {
        "mission:" + SHA256.hash(data: Data(folder.standardizedFileURL.resolvingSymlinksInPath().path.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}
struct MissionScan: Equatable {
    var projects: [MissionProject] = []
    var events: [InboxMessage] = []
    var connected: [String] = []
    var warnings: [String] = []
}

struct ProjectSetupStep: Identifiable, Equatable {
    var id: String { kind + ":" + path }
    var kind: String
    var title: String
    var path: String
}
enum ProjectSetup {
    static func steps(_ project: MissionProject, sharedThumbnail: String? = nil, dashboardID: String? = nil) -> [ProjectSetupStep] {
        var result: [ProjectSetupStep] = []
        if let video = project.video { result.append(ProjectSetupStep(kind: "file", title: "Finished video", path: video)) }
        if let thumb = project.thumbnails.first ?? sharedThumbnail { result.append(ProjectSetupStep(kind: "file", title: project.thumbnails.isEmpty ? "Shared language thumbnail" : "Project thumbnail", path: thumb)) }
        result.append(ProjectSetupStep(kind: "folder", title: "Project files", path: project.folder))
        if let dashboardID { result.append(ProjectSetupStep(kind: "dashboard", title: "\(project.source) Mission Control", path: dashboardID)) }
        return result
    }
}
