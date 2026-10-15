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
    func prepare(state: AppState) async {
        if AppMode.isDemo { return }
        if let data = Storage.readData("chat-history.json"), let saved = try? JSONDecoder().decode(JarvisHistory.self, from: data) {
            history = saved
        }
    }
    func refreshDashboard(state: AppState) async {}
    func cancel() { busy = false; currentTask?.cancel() }
    func save() {
        if AppMode.isDemo { return }
        if let data = try? JSONEncoder().encode(history) {
            Storage.writeData(data, named: "chat-history.json")
        }
    }

    private var currentTask: Task<Void, Never>?

    func send(_ text: String, state: AppState) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1. Direct shortcut commands (e.g. "open <shortcut>")
        let targets = (state.browserTiles + state.fileTiles).map {
            JarvisTarget(id: $0.id, label: $0.label, category: $0.kind.rawValue, status: "ready", canStart: true)
        }
        if let action = JarvisCommands.direct(trimmed, targets: targets) {
            history.turns.append(JarvisTurn(role: "user", text: trimmed))
            history.turns.append(JarvisTurn(role: "assistant", text: "Opening \(action.targetID)...", actions: [action]))
            run(action, state: state)
            save()
            return
        }

        if AppMode.isDemo {
            history.turns.append(JarvisTurn(role: "user", text: trimmed))
            history.turns.append(JarvisTurn(role: "assistant", text: "Demo mode: the assistant is disconnected. Run without --demo to chat with local Ollama!"))
            return
        }

        history.turns.append(JarvisTurn(role: "user", text: trimmed))
        save()
        busy = true
        progress = "Thinking with local AI..."

        currentTask = Task {
            await queryOllama(prompt: trimmed, state: state)
        }
    }

    private func queryOllama(prompt: String, state: AppState) async {
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let systemPrompt = "You are Jarvis, a fast, helpful native macOS assistant. The user's system has shortcuts, subscriptions, and AI usage quotas. Keep replies concise and direct.\(history.notes.isEmpty ? "" : " User context: " + history.notes)"
        let body: [String: Any] = [
            "model": "llama3.2:latest",
            "prompt": prompt,
            "system": systemPrompt,
            "stream": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reply = json["response"] as? String {
                history.turns.append(JarvisTurn(role: "assistant", text: reply.trimmingCharacters(in: .whitespacesAndNewlines)))
                save()
                busy = false
                progress = ""
                return
            }
        } catch {
            // If local Ollama isn't running or error occurred
            let msg = "Local Ollama is not responding at 127.0.0.1:11434.\n\nTip: Install Ollama (brew install ollama && ollama run llama3.2) for 100% free offline AI chat in Jarvis!"
            history.turns.append(JarvisTurn(role: "assistant", text: msg))
            save()
            busy = false
            progress = ""
        }
    }

    func actionLabel(_ action: JarvisAction) -> String { action.label ?? action.kind.capitalized }
    func setFocus(_ project: MissionProject) { history.focusID = project.id; history.focusLabel = project.displayName }
    func run(_ action: JarvisAction, state: AppState) {
        if let tile = (state.browserTiles + state.fileTiles).first(where: { $0.id == action.targetID }) {
            state.launch(tile)
        } else {
            state.notice = "Launched \(action.targetID)."
        }
    }
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
