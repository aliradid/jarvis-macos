import SwiftUI

struct DeskTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var done = false
}
struct DeskArchive: Codable {
    var tasks: [DeskTask] = []
    var recent: [String] = []
    var pins: [String] = []
}

@MainActor final class HomeDeskStore: ObservableObject {
    static let shared = HomeDeskStore()
    @Published private(set) var archive = DeskArchive()
    @Published private(set) var issue: String?
    init() {
        if AppMode.isDemo {
            archive = DeskArchive(
                tasks: [
                    DeskTask(title: "Benchmark deepseek-r1:14b Metal token throughput on M3 Max"),
                    DeskTask(title: "Verify Claude Code 5h sliding window before multi-repo refactor"),
                    DeskTask(title: "Ship v2.0.0 signed macOS universal DMG release")
                ],
                recent: ["dev:cursor", "dev:github", "dev:claude", "dev:terminal"],
                pins: ["dev:cursor", "dev:github", "dev:claude", "dev:localhost"]
            )
        } else if let data = Storage.readData("desk.json"), let saved = try? JSONDecoder().decode(DeskArchive.self, from: data) {
            archive = saved
        }
    }
    private func update(_ change: (inout DeskArchive) -> Void) {
        change(&archive)
        if let data = try? JSONEncoder().encode(archive) { Storage.writeData(data, named: "desk.json") }
    }
    func add(_ title: String) {
        let text = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        guard !text.isEmpty else { return }
        update { $0.tasks.append(DeskTask(title: text)) }
    }
    func toggle(_ id: UUID) { update { if let i = $0.tasks.firstIndex(where: { $0.id == id }) { $0.tasks[i].done.toggle() } } }
    func remove(_ id: UUID) { update { $0.tasks.removeAll { $0.id == id } } }
    func record(_ id: String) { update { $0.recent = Array(([id] + $0.recent.filter { $0 != id }).prefix(12)) } }
    func pin(_ id: String) { update { if $0.pins.contains(id) { $0.pins.removeAll { $0 == id } } else { $0.pins.append(id) } } }
}

struct HomeDesk: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var jarvis: JarvisStore
    @ObservedObject var store = HomeDeskStore.shared
    let openProject: (MissionProject) -> Void
    @State private var draft = ""
    @State private var showCompleted = false
    private var visibleTasks: [DeskTask] { store.archive.tasks.filter { showCompleted || !$0.done } }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left Card: Active Git Repositories
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("ACTIVE REPOSITORIES", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(OLED.cyan)
                    Spacer()
                    Text("\(jarvis.dashboard.projects.count) tracked").font(.system(size: 11, design: .monospaced)).foregroundStyle(OLED.muted)
                }
                VStack(spacing: 7) {
                    ForEach(jarvis.dashboard.projects.prefix(3)) { project in
                        Button { openProject(project) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: project.status == "running" ? "bolt.horizontal.circle.fill" : project.needsAttention ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(project.status == "running" ? OLED.online : project.needsAttention ? OLED.warning : OLED.accent)
                                    .frame(width: 28, height: 28)
                                    .background(OLED.raised, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(project.title).font(.system(size: 12.5, weight: .semibold, design: .monospaced)).lineLimit(1)
                                        Text(project.language).font(.system(size: 9.5, weight: .semibold)).padding(.horizontal, 5).padding(.vertical, 1.5).background(OLED.raised, in: Capsule()).foregroundStyle(OLED.muted)
                                    }
                                    Text(project.detail).font(.system(size: 10.5)).foregroundStyle(OLED.muted).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Text(project.stage).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(OLED.accent)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(OLED.raised.opacity(0.45), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(OLED.border, lineWidth: 1))
                        }.buttonStyle(JarvisPlainButtonStyle())
                    }
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(OLED.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(OLED.border, lineWidth: 1))

            // Right Card: Engineering Focus Checklist
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("ENGINEERING FOCUS QUEUE", systemImage: "checklist")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(OLED.accent)
                    Spacer()
                    Text("\(store.archive.tasks.filter { !$0.done }.count) open").font(.system(size: 11, design: .monospaced)).foregroundStyle(OLED.muted)
                    if store.archive.tasks.contains(where: \.done) {
                        Button(showCompleted ? "Hide done" : "Show done") { showCompleted.toggle() }.font(.caption).buttonStyle(JarvisPlainButtonStyle()).foregroundStyle(OLED.muted)
                    }
                }

                VStack(spacing: 6) {
                    ForEach(visibleTasks.prefix(3)) { item in
                        Button { store.toggle(item.id) } label: {
                            HStack(spacing: 9) {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(item.done ? OLED.online : OLED.accent)
                                Text(item.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .strikethrough(item.done)
                                    .foregroundStyle(item.done ? OLED.muted : OLED.text)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(OLED.raised.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(OLED.border, lineWidth: 1))
                        }
                        .buttonStyle(JarvisPlainButtonStyle())
                        .contextMenu { Button("Delete item", role: .destructive) { store.remove(item.id) } }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(OLED.accent).font(.system(size: 13))
                    TextField("Add sprint task or deployment note…", text: $draft).textFieldStyle(.plain).onSubmit(addTask)
                }
                .font(.system(size: 11.5))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(OLED.raised.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(OLED.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(OLED.border, lineWidth: 1))
        }
    }

    private func addTask() { store.add(draft); if store.issue == nil { draft = "" } }
}

struct HomeAttention: View {
    @ObservedObject var subscriptions: SubscriptionStore
    @ObservedObject var jarvis: JarvisStore
    @ObservedObject var infrastructure: InfrastructureStore
    let openSubscription: (String) -> Void
    let openProject: (MissionProject) -> Void
    var body: some View {
        EmptyView()
    }
}
