import SwiftUI
import AppKit

// These adapters feed the original views without discovering accounts, files or services.
@MainActor final class JarvisStore: ObservableObject {
    static let shared = JarvisStore()
    @Published var history = JarvisHistory(recentProjectIDs: ["project-1"])
    @Published var dashboard = MissionScan(projects: SampleData.projects)
    @Published var busy = false
    @Published var issue: String?
    var progress = ""
    var runningProjects: [MissionProject] { dashboard.projects.filter { $0.status == "running" } }
    var readyProjects: [MissionProject] { dashboard.projects.filter(\.isReady) }
    var attentionProjects: [MissionProject] { dashboard.projects.filter(\.needsAttention) }
    func prepare(state: AppState) async {}
    func refreshDashboard(state: AppState) async {}
    func cancel() { busy = false }
    func save() {}
    func send(_ text: String, state: AppState) { issue = "The assistant is disconnected in this demo. No message was sent." }
    func actionLabel(_ action: JarvisAction) -> String { action.label ?? action.kind.capitalized }
    func setFocus(_ project: MissionProject) { history.focusID = project.id; history.focusLabel = project.displayName }
    func run(_ action: JarvisAction, state: AppState) { state.notice = "External project actions are disabled in this demo." }
    func setupSteps(_ project: MissionProject, state: AppState) -> [ProjectSetupStep] { ProjectSetup.steps(project, dashboardID: "studio-0") }
}

@MainActor final class InboxStore: ObservableObject {
    static let shared = InboxStore()
    @Published var archive = InboxArchive()
    @Published var issue: String?
    @Published var desktopAlertsEnabled = false
    @Published var notificationStatus = ""
    var connectionSummary: String { "Sample workspace · no connected services" }
    var unread: Int { archive.unreadMessages.count }
    private let alerts = DesktopAlerts()
    func start() {}
    func refresh() async {}
    func ingestSubscriptions(_ events: [InboxMessage]) { _ = archive.ingest(events) }
    func markRead(_ id: String? = nil) { for i in archive.messages.indices where id == nil || archive.messages[i].id == id { archive.messages[i].read = true } }
    func setDesktopAlerts(_ enabled: Bool) { desktopAlertsEnabled = enabled }
    func testDesktopAlert() {
        alerts.show(InboxMessage(id: "sample-alert", date: Date(), source: "Demo", title: "Test alert", detail: "Sample notification", kind: "ready", path: ""), open: {})
    }
    func open(_ message: InboxMessage) {
        if message.kind == "subscription" { NotificationCenter.default.post(name: Notification.Name("jarvis.openSubscription"), object: nil, userInfo: ["id": message.path]) }
        else { notificationStatus = "External project actions are disabled in this demo." }
    }
}
