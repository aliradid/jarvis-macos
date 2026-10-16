import SwiftUI
import AppKit

@MainActor final class JarvisStore: ObservableObject {
    static let shared = JarvisStore()
    @Published var history = JarvisHistory(recentProjectIDs: ["project-0"])
    @Published var dashboard = MissionScan(projects: SampleData.projects)
    @Published var busy = false
    @Published var issue: String?
    @Published var selectedModel = "llama3.2:latest"
    @Published var activePreset = "Architecture & Code"
    @Published var includeQuotasContext = true
    @Published var includePortsContext = true
    @Published var includeHardwareContext = true
    @Published var includeReposContext = true
    @Published var pinnedRepoPaths: [String] = []
    var progress = ""

    var runningProjects: [MissionProject] { dashboard.projects.filter { $0.status == "running" } }
    var readyProjects: [MissionProject] { dashboard.projects.filter(\.isReady) }
    var attentionProjects: [MissionProject] { dashboard.projects.filter(\.needsAttention) }

    var availableModels: [String] {
        let detected = InfrastructureStore.shared.ollamaModels.map(\.name)
        let defaults = ["llama3.2:latest", "deepseek-r1:14b", "qwen2.5-coder:32b"]
        var combined: [String] = []
        for m in detected + defaults where !combined.contains(m) { combined.append(m) }
        return Array(combined.prefix(4))
    }

    func prepare(state: AppState) async {
        if AppMode.isDemo { return }
        if let data = Storage.readData("chat-history.json"), let saved = try? JSONDecoder().decode(JarvisHistory.self, from: data) {
            history = saved
        }
        if let repoData = Storage.readData("pinned-repos.json"), let savedRepos = try? JSONDecoder().decode([String].self, from: repoData) {
            pinnedRepoPaths = savedRepos
        }
        await refreshDashboard(state: state)
    }

    func pinLocalRepository(url: URL, state: AppState) {
        let path = url.standardizedFileURL.path
        if !pinnedRepoPaths.contains(path) {
            pinnedRepoPaths.insert(path, at: 0)
            if !AppMode.isDemo, let data = try? JSONEncoder().encode(pinnedRepoPaths) {
                Storage.writeData(data, named: "pinned-repos.json")
            }
        }
        if let project = Self.inspectGitRepository(at: url) {
            var current = dashboard.projects.filter { $0.folder != project.folder && $0.title != project.title }
            current.insert(project, at: 0)
            dashboard = MissionScan(projects: current, connected: ["git", "localhost"])
            state.notice = "Pinned repository \(project.title) (\(project.language))."
        }
    }

    func refreshDashboard(state: AppState) async {
        if AppMode.isDemo {
            if dashboard.projects != SampleData.projects {
                dashboard = MissionScan(projects: SampleData.projects)
            }
            return
        }
        let extraPaths = pinnedRepoPaths
        let discovered = await Task.detached(priority: .utility) {
            Self.scanLocalGitRepositories(extraPaths: extraPaths)
        }.value
        if !discovered.isEmpty {
            dashboard = MissionScan(projects: discovered, connected: ["git", "localhost"])
        }
    }

    nonisolated private static func inspectGitRepository(at url: URL) -> MissionProject? {
        let fm = FileManager.default
        let path = url.standardizedFileURL.path
        guard fm.fileExists(atPath: path) else { return nil }
        let name = url.lastPathComponent
        let headPath = url.appendingPathComponent(".git/HEAD").path
        var branch = "main"
        if let head = try? String(contentsOfFile: headPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
            if head.hasPrefix("ref: refs/heads/") {
                branch = String(head.dropFirst("ref: refs/heads/".count))
            } else {
                branch = String(head.prefix(7))
            }
        }
        let lang: String
        let sourceID: String
        if fm.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            lang = "Swift 6.0"; sourceID = "nextjs"
        } else if fm.fileExists(atPath: url.appendingPathComponent("tsconfig.json").path) || fm.fileExists(atPath: url.appendingPathComponent("package.json").path) {
            lang = "TypeScript"; sourceID = "nextjs"
        } else if fm.fileExists(atPath: url.appendingPathComponent("pyproject.toml").path) || fm.fileExists(atPath: url.appendingPathComponent("requirements.txt").path) {
            lang = "Python"; sourceID = "fastapi"
        } else if fm.fileExists(atPath: url.appendingPathComponent("Cargo.toml").path) {
            lang = "Rust"; sourceID = "postgres"
        } else if fm.fileExists(atPath: url.appendingPathComponent("go.mod").path) {
            lang = "Go"; sourceID = "ollama"
        } else {
            lang = "Git Repo"; sourceID = "nextjs"
        }
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        return MissionProject(
            id: MissionProject.identity(url),
            sourceID: sourceID,
            source: "Local Git Repository",
            language: lang,
            title: name,
            folder: path,
            status: "running",
            stage: "\(branch) · Local Clone",
            detail: path,
            modified: modDate,
            video: "ready",
            thumbnails: []
        )
    }

    nonisolated private static func scanLocalGitRepositories(extraPaths: [String] = []) -> [MissionProject] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let searchRoots = [
            "Developer", "Projects", "Code", "GitHub", "Workspace", "Desktop",
            ".gemini/antigravity/scratch"
        ].map { home.appendingPathComponent($0, isDirectory: true) }

        var repoURLs: [URL] = extraPaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
        for root in searchRoots where fm.fileExists(atPath: root.path) {
            let gitSelf = root.appendingPathComponent(".git")
            if fm.fileExists(atPath: gitSelf.path) {
                repoURLs.append(root)
            }
            guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }
            for child in children {
                let gitDir = child.appendingPathComponent(".git")
                if fm.fileExists(atPath: gitDir.path) {
                    repoURLs.append(child)
                }
            }
        }

        var seen = Set<String>()
        var projects: [MissionProject] = []
        for url in repoURLs {
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted,
                  let proj = inspectGitRepository(at: url) else { continue }
            projects.append(proj)
        }
        projects.sort { $0.modified > $1.modified }
        return Array(projects.prefix(8))
    }

    func cancel() { busy = false; currentTask?.cancel() }
    func clearHistory() {
        history.turns.removeAll()
        save()
    }
    func exportMarkdown() -> String {
        var lines = ["# Jarvis AI Assistant Transcript", "Model: `\(selectedModel)` · Preset: `\(activePreset)`", ""]
        for turn in history.turns {
            let speaker = turn.role == "user" ? "### Developer" : "### Jarvis (\(selectedModel))"
            lines.append(speaker)
            lines.append(turn.text)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
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

        // 0. Instant Slash Commands (/quotas, /ports, /hardware, /repos, /spend, /clear)
        if trimmed.lowercased() == "/clear" {
            clearHistory()
            state.notice = "Cleared AI Assistant conversation history."
            return
        }
        if let slashReply = handleSlashCommand(trimmed) {
            history.turns.append(JarvisTurn(role: "user", text: trimmed))
            history.turns.append(JarvisTurn(role: "assistant", text: slashReply))
            save()
            return
        }

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
            history.turns.append(JarvisTurn(role: "assistant", text: Self.synthesizedTelemetryReply(for: trimmed)))
            return
        }

        history.turns.append(JarvisTurn(role: "user", text: trimmed))
        save()
        busy = true
        progress = "Streaming from \(selectedModel)..."

        currentTask = Task {
            await queryOllama(prompt: trimmed, state: state)
        }
    }

    private func handleSlashCommand(_ command: String) -> String? {
        let cmd = command.lowercased()
        let tele = InfrastructureStore.shared.telemetry
        if cmd.hasPrefix("/quotas") {
            let readings = AIQuotaStore.shared.readings
            let rows = readings.map { "• \($0.provider.uppercased()) (\($0.window) window): \(Int($0.used))% used · \(Int($0.remaining))% remaining" }.joined(separator: "\n")
            let models = InfrastructureStore.shared.ollamaModels.map { "\($0.name) (\($0.parameterSize), \($0.quantization))" }.joined(separator: ", ")
            return "AI Quota & Local Model Diagnostic:\n\n\(rows.isEmpty ? "• No cloud OAuth sessions active." : rows)\n• Local Ollama Fallback (:11434): \(models.isEmpty ? "Offline" : models) ($0/token)"
        } else if cmd.hasPrefix("/ports") {
            let ports = InfrastructureStore.shared.devPorts
            let active = ports.filter(\.online)
            let lines = active.map { "• :\($0.port) — \($0.name) (\($0.processBadge ?? $0.stack)) · \($0.responseMs)ms" }.joined(separator: "\n")
            return "Listening Localhost TCP Ports (\(active.count)/\(ports.count) online):\n\n\(lines.isEmpty ? "• Zero listening ports detected on 127.0.0.1." : lines)"
        } else if cmd.hasPrefix("/hardware") {
            return String(format: "macOS Darwin Hardware Telemetry (%@ · %@):\n\n• CPU Load: %.0f%% (1m load avg %.2f across %d cores)\n• Unified Memory: %.1f / %.0f GB used (%.0f%%)\n• SSD Storage: %.0f / %.0f GB used (%.0f%% free)\n• Thermal & Uptime: %@ thermal state · Uptime %@", tele.chipName, tele.osVersion, tele.cpuUsagePercent, tele.loadAverage1m, tele.cpuCores, tele.memoryUsedGB, tele.memoryTotalGB, tele.memoryPercent, tele.diskUsedGB, tele.diskTotalGB, 100 - tele.diskPercent, tele.thermalState, tele.uptimeString)
        } else if cmd.hasPrefix("/repos") {
            let list = dashboard.projects.map { "• \($0.title) [\($0.language)] — \($0.stage) (\($0.detail))" }.joined(separator: "\n")
            return "Active Git Repositories (\(dashboard.projects.count) tracked):\n\n\(list.isEmpty ? "• No local Git repositories discovered." : list)"
        } else if cmd.hasPrefix("/spend") {
            let store = SubscriptionStore()
            let active = store.items.filter { $0.isRecurring }
            return "AI & Cloud Recurring Spend Summary:\n\n• Active Subscriptions: \(active.count) plans (\(store.totals)/mo)\n• Top Stack: " + active.prefix(5).map { "\($0.name) (\($0.money))" }.joined(separator: ", ")
        }
        return nil
    }

    private func liveContextSummary() -> String {
        var parts: [String] = []
        if includeHardwareContext {
            let tele = InfrastructureStore.shared.telemetry
            let memText = String(format: "%.1f / %.0f GB", tele.memoryUsedGB, tele.memoryTotalGB)
            let loadText = String(format: "%.2f", tele.loadAverage1m)
            let diskText = String(format: "%.0f / %.0f GB", tele.diskUsedGB, tele.diskTotalGB)
            parts.append("System: \(tele.chipName) (\(tele.osVersion)), RAM \(memText), Load \(loadText), Disk \(diskText)")
        }
        if includePortsContext {
            let ports = InfrastructureStore.shared.devPorts.filter(\.online).map { "\($0.name) (:\($0.port))" }.joined(separator: ", ")
            parts.append("Active Ports: \(ports.isEmpty ? "none" : ports)")
        }
        if includeQuotasContext {
            let quotas = AIQuotaStore.shared.readings.map { "\($0.provider.uppercased()) \($0.window): \(Int($0.remaining))% left" }.joined(separator: ", ")
            parts.append("Quotas: \(quotas.isEmpty ? "none" : quotas)")
        }
        if includeReposContext {
            let repos = dashboard.projects.prefix(5).map { "\($0.title) [\($0.language)]" }.joined(separator: ", ")
            parts.append("Git Repos: \(repos.isEmpty ? "none" : repos)")
        }
        return parts.joined(separator: ". ")
    }

    private static func synthesizedTelemetryReply(for prompt: String) -> String {
        let tele = InfrastructureStore.shared.telemetry
        let onlinePorts = InfrastructureStore.shared.devPorts.filter(\.online)
        let quotas = AIQuotaStore.shared.readings
        let quotaLines = quotas.isEmpty
            ? "• AI Quotas: Sign into Claude Code (`claude`) or Codex (`codex`) to stream live OAuth rate limits."
            : quotas.map { "• \($0.provider.capitalized) (\($0.window)): \(Int($0.remaining))% remaining" }.joined(separator: "\n")
        let portLines = onlinePorts.isEmpty
            ? "• Localhost Ports: No active dev servers detected on standard ports (:3000, :5173, :8000, :11434)."
            : "• Active Ports (\(onlinePorts.count) listening): " + onlinePorts.map { "\($0.name) on :\($0.port) (\($0.responseMs)ms)" }.joined(separator: ", ")
        let memText = String(format: "%.1f / %.0f GB", tele.memoryUsedGB, tele.memoryTotalGB)
        let loadText = String(format: "%.2f", tele.loadAverage1m)
        let diskText = String(format: "%.0f / %.0f GB used", tele.diskUsedGB, tele.diskTotalGB)

        return """
        Live macOS Command Center Telemetry (\(tele.chipName) · \(tele.osVersion)):

        • Hardware: \(memText) unified memory (\(Int(tele.memoryPercent))%) · CPU load \(loadText) · \(diskText)
        \(quotaLines)
        \(portLines)

        Tip: Start local Ollama (`ollama serve` & `ollama run llama3.2`) on 127.0.0.1:11434 for live streaming LLM synthesis, or use `/quotas`, `/ports`, `/hardware`, `/repos`, `/spend`.
        """
    }

    private func queryOllama(prompt: String, state: AppState) async {
        var modelToUse = selectedModel
        if let firstDetected = InfrastructureStore.shared.ollamaModels.first?.name,
           !InfrastructureStore.shared.ollamaModels.contains(where: { $0.name == modelToUse }) {
            modelToUse = firstDetected
            selectedModel = firstDetected
        }

        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let context = liveContextSummary()
        let systemPrompt = "You are Jarvis, a native macOS AI & Developer Command Center assistant (\(activePreset) mode). Live Mac telemetry: \(context). Keep replies concise, technical, and direct.\(history.notes.isEmpty ? "" : " User context: " + history.notes)"
        let body: [String: Any] = [
            "model": modelToUse,
            "prompt": prompt,
            "system": systemPrompt,
            "stream": true
        ]

        let turnID = UUID().uuidString
        history.turns.append(JarvisTurn(id: turnID, role: "assistant", text: ""))

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            var accumulated = ""
            for try await line in bytes.lines {
                if Task.isCancelled { break }
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let token = json["response"] as? String else { continue }
                accumulated += token
                if let idx = history.turns.firstIndex(where: { $0.id == turnID }) {
                    history.turns[idx].text = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if accumulated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let idx = history.turns.firstIndex(where: { $0.id == turnID }) {
                history.turns[idx].text = Self.synthesizedTelemetryReply(for: prompt)
            }
            save()
            busy = false
            progress = ""
        } catch {
            if let idx = history.turns.firstIndex(where: { $0.id == turnID }) {
                history.turns[idx].text = Self.synthesizedTelemetryReply(for: prompt)
            }
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
    var connectionSummary: String {
        AppMode.isDemo ? "Local macOS Command Center · 3 providers active" : "Local macOS telemetry · Keychain + localhost"
    }
    var unread: Int { archive.unreadMessages.count }
    private let alerts = DesktopAlerts()
    func start() {}
    func refresh() async {}
    func ingestSubscriptions(_ events: [InboxMessage]) { _ = archive.ingest(events) }
    func markRead(_ id: String? = nil) { for i in archive.messages.indices where id == nil || archive.messages[i].id == id { archive.messages[i].read = true } }
    func setDesktopAlerts(_ enabled: Bool) { desktopAlertsEnabled = enabled }
    func testDesktopAlert() {
        alerts.show(InboxMessage(id: "sample-alert", date: Date(), source: "Jarvis HUD", title: "Quota & Port Alert", detail: "Claude 5h window at 76% · 6 localhost ports listening.", kind: "ready", path: ""), open: {})
    }
    func open(_ message: InboxMessage) {
        if message.kind == "subscription" {
            NotificationCenter.default.post(name: Notification.Name("jarvis.openSubscription"), object: nil, userInfo: ["id": message.path])
        } else if !message.path.isEmpty, FileManager.default.fileExists(atPath: message.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: message.path)
        } else {
            notificationStatus = "Item opened in workspace."
        }
    }
}
