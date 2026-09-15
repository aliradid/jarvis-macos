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
    init() { archive = DeskArchive(tasks: [DeskTask(title: "Review the sample project")], recent: ["chrome-profile:sample-0"], pins: []) }
    private func update(_ change: (inout DeskArchive) -> Void) { change(&archive) }
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
    private var recentTiles: [Tile] { store.archive.recent.compactMap { id in state.memberTiles.first { $0.id == id } } }
    private var recentProjects: [MissionProject] { (jarvis.history.recentProjectIDs ?? []).prefix(3).compactMap { id in jarvis.dashboard.projects.first { $0.id == id } } }
    private var visibleTasks: [DeskTask] { store.archive.tasks.filter { showCompleted || !$0.done } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Divider()
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Continue working").font(.system(size: 15, weight: .medium))
                    if recentTiles.isEmpty && recentProjects.isEmpty {
                        Text("Open a shortcut or project in Jarvis. Your recent work will appear here.")
                            .font(.system(size: 12)).foregroundStyle(OLED.muted).fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)
                    }
                    ForEach(recentProjects.prefix(2)) { project in
                        Button { openProject(project) } label: {
                            deskRow(icon: "folder", title: project.title, subtitle: "\(project.source) · \(project.language.uppercased())")
                        }.buttonStyle(JarvisPlainButtonStyle())
                    }
                    ForEach(recentTiles.prefix(4)) { tile in
                        Button { state.launch(tile) } label: { deskRow(icon: tile.kind == .file ? "doc" : "globe", title: tile.label, subtitle: tile.subtitle) }
                            .buttonStyle(JarvisPlainButtonStyle()).disabled(state.launching.contains(tile.id))
                            .contextMenu { Button(store.archive.pins.contains(tile.id) ? "Unpin" : "Pin to Home") { store.pin(tile.id) } }
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("My checklist").font(.system(size: 15, weight: .medium))
                        Text("\(store.archive.tasks.filter { !$0.done }.count)").font(.caption).foregroundStyle(OLED.muted)
                        Spacer()
                        if store.archive.tasks.contains(where: \.done) {
                            Button(showCompleted ? "Hide done" : "Show done") { showCompleted.toggle() }.font(.caption).buttonStyle(JarvisPlainButtonStyle()).foregroundStyle(OLED.muted)
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("Add something to do…", text: $draft).textFieldStyle(.plain).onSubmit(addTask)
                        Button(action: addTask) { Image(systemName: "plus").frame(width: 28, height: 28) }
                            .buttonStyle(JarvisPlainButtonStyle()).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Add checklist item")
                    }.font(.system(size: 12)).padding(.leading, 10).padding(.trailing, 3).padding(.vertical, 3)
                        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 8))
                    if visibleTasks.isEmpty { Text("Keep your next steps here.").font(.system(size: 12)).foregroundStyle(OLED.muted).padding(.vertical, 4) }
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(visibleTasks) { item in
                                Button { store.toggle(item.id) } label: {
                                    HStack(alignment: .top, spacing: 9) {
                                        Image(systemName: item.done ? "checkmark.circle.fill" : "circle").foregroundStyle(item.done ? OLED.online : OLED.muted)
                                        Text(item.title).strikethrough(item.done).foregroundStyle(item.done ? OLED.muted : OLED.text).multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                    }.font(.system(size: 12)).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("\(item.done ? "Completed" : "To do"): \(item.title)")
                                    .contextMenu { Button("Delete item", role: .destructive) { store.remove(item.id) } }
                            }
                        }
                    }.frame(maxHeight: visibleTasks.isEmpty ? 0 : min(CGFloat(visibleTasks.count) * 44, 190))
                }.frame(maxWidth: .infinity, alignment: .topLeading)
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Pinned actions").font(.system(size: 15, weight: .medium))
                    Spacer()
                    Menu {
                        ForEach(state.memberTiles) { tile in
                            Button { store.pin(tile.id) } label: {
                                Label(tile.label, systemImage: store.archive.pins.contains(tile.id) ? "checkmark" : "plus")
                            }
                        }
                    } label: { Label("Add pin", systemImage: "plus").font(.system(size: 12)) }.menuStyle(.borderlessButton).fixedSize()
                }
                if store.archive.pins.isEmpty { Text("Pin the files and channel shortcuts you want one click away.").font(.system(size: 12)).foregroundStyle(OLED.muted) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145, maximum: 240), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(store.archive.pins.compactMap { id in state.memberTiles.first { $0.id == id } }) { tile in
                        Button { state.launch(tile) } label: {
                            HStack(spacing: 8) { Image(systemName: tile.kind == .file ? "doc" : "arrow.up.right"); Text(tile.label).lineLimit(1); Spacer(minLength: 0) }
                                .font(.system(size: 12)).padding(11).frame(maxWidth: .infinity).background(OLED.surface, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(JarvisPlainButtonStyle()).disabled(state.launching.contains(tile.id))
                            .contextMenu { Button("Unpin") { store.pin(tile.id) } }
                    }
                }
            }
            if let issue = store.issue { Text(issue).font(.caption).foregroundStyle(OLED.offline) }
        }.padding(.top, 6)
    }
    private func addTask() { store.add(draft); if store.issue == nil { draft = "" } }
    private func deskRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 16, weight: .light)).foregroundStyle(OLED.muted).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1); Text(subtitle).font(.system(size: 10)).foregroundStyle(OLED.muted).lineLimit(1) }
            Spacer(minLength: 4); Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(OLED.muted)
        }.padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}

struct HomeAttention: View {
    @ObservedObject var subscriptions: SubscriptionStore
    @ObservedObject var jarvis: JarvisStore
    @ObservedObject var infrastructure: InfrastructureStore
    let openSubscription: (String) -> Void
    let openProject: (MissionProject) -> Void
    @State private var systems = false
    var body: some View {
        let trials = subscriptions.items.filter { $0.status == "Trial" && $0.hasDate && (0...7).contains($0.days) }.sorted { $0.days < $1.days }
        let failures = infrastructure.connections.filter { $0.healthy == false }
        let projects = Array(jarvis.attentionProjects.prefix(2))
        if !trials.isEmpty || !failures.isEmpty || !projects.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Label("Needs your attention", systemImage: "exclamationmark.circle").font(.system(size: 12, weight: .medium)).foregroundStyle(OLED.offline).padding(.bottom, 3)
                ForEach(trials.prefix(2)) { item in
                    Button { openSubscription(item.id.uuidString) } label: { attentionRow("\(item.name) · trial \(item.days == 0 ? "ends today" : "ends in \(item.days)d")", action: "Review trial") }.buttonStyle(JarvisPlainButtonStyle())
                }
                ForEach(projects) { project in
                    Button { openProject(project) } label: { attentionRow("\(project.source) · \(project.title)", action: "Review") }.buttonStyle(JarvisPlainButtonStyle())
                }
                if !failures.isEmpty {
                    Button { systems = true } label: { attentionRow(failures.map(\.name).joined(separator: ", ") + " unavailable", action: "Inspect") }.buttonStyle(JarvisPlainButtonStyle())
                }
            }.padding(12).background(OLED.surface, in: RoundedRectangle(cornerRadius: 10))
                .popover(isPresented: $systems) { InfrastructurePanel(store: infrastructure).frame(width: 570).preferredColorScheme(.dark) }
        }
    }
    private func attentionRow(_ title: String, action: String) -> some View {
        HStack { Text(title).lineLimit(1); Spacer(minLength: 10); Text(action).foregroundStyle(OLED.accent); Image(systemName: "chevron.right").font(.system(size: 9)) }
            .font(.system(size: 12)).padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}
