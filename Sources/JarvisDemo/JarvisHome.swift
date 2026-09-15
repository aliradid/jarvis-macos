import SwiftUI

struct JarvisHome: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var inbox: InboxStore
    @EnvironmentObject var jarvis: JarvisStore
    @StateObject private var subscriptions = SubscriptionStore()
    @StateObject private var cats = CatStore()
    @State private var selectedSubscription: String?
    @State private var pendingSubscription: String?
    @State private var subscriptionQuery = ""
    @StateObject private var youtube = YouTubeMonitorStore()
    @StateObject private var quotaStore = AIQuotaStore.shared
    @StateObject private var infrastructureStore = InfrastructureStore.shared
    @State private var query = ""
    @State var page = "Overview"
    @State private var composerDraft = ""
    @State private var messages = false
    @State private var diagnostics = false
    @State private var editingMission = false
    @State private var missionEntry: LinkEntry?
    @State private var projects = false
    @State private var projectFilter = "All"
    @State private var setupProject: MissionProject?
    @FocusState private var searchFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                JarvisAvatar().frame(width: 44, height: 44).padding(.top, 12)
                navigation("Overview", "square.grid.2x2")
                navigation("Assistant", "bubble.left.and.bubble.right")
                navigation("Projects", "square.stack.3d.up")
                navigation("Shortcuts", "command")
                navigation("Subscriptions", "creditcard")
                navigation("Cats", "pawprint.fill")
                navigation("YouTube", "play.rectangle")
                navigation("Revenue", "dollarsign.circle")
                Spacer()
                Text("DEMO").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(OLED.muted)
                Image(systemName: "moon.fill").foregroundStyle(OLED.accent).padding(.bottom, 16)
            }.padding(.horizontal, 14).frame(width: 76).background(OLED.canvas)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(page).font(.system(size: 14, weight: .medium))
                    WorkspaceStatusStrip(quotas: quotaStore, infrastructure: infrastructureStore)
                    Spacer(minLength: 4)
                    HStack { Image(systemName: "magnifyingglass").foregroundStyle(OLED.muted); TextField("Search your workspace", text: $query).textFieldStyle(.plain).focused($searchFocused).onChange(of: query) { _ in if !query.isEmpty { page = "Shortcuts" } } }.font(.system(size: 12)).padding(10).frame(minWidth: 100, maxWidth: 200).background(OLED.surface, in: RoundedRectangle(cornerRadius: 8))
                    Button { diagnostics = true } label: { Image(systemName: "waveform.path.ecg") }.buttonStyle(JarvisPlainButtonStyle()).help("Diagnostics").accessibilityLabel("Diagnostics")
                    Button { messages = true } label: { HStack(spacing: 7) { Image(systemName: inbox.unread > 0 ? "bell.badge" : "bell"); if inbox.unread > 0 { Text("\(inbox.unread)").monospacedDigit() } } }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("Messages")
                    Button { searchFocused = true } label: { EmptyView() }.keyboardShortcut("f").frame(width: 0).accessibilityHidden(true)
                }.padding(.horizontal, 20).padding(.vertical, 11)
                Divider()
                if let notice = state.notice { Text(notice).font(.caption).foregroundStyle(OLED.offline).padding(8) }
                RetainedPageHost(key: page, content: AnyView(ZStack {
                    if page == "Assistant" {
                        JarvisView(jarvis: jarvis, draft: $composerDraft, embedded: true).environmentObject(state)
                    } else if page == "Cats" {
                        CatsView(store: cats).environmentObject(subscriptions.fx)
                    } else if page == "Subscriptions" {
                        SubscriptionsPage(store: subscriptions, selectedID: selectedSubscription, initialQuery: subscriptionQuery, selectionConsumed: { selectedSubscription = nil })
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                if page == "Overview" {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text("Your workspace").font(.system(size: 19, weight: .medium))
                                        Spacer()
                                        Text(Date(), format: .dateTime.month(.abbreviated).day()).font(.system(size: 14)).foregroundStyle(OLED.muted)
                                    }.padding(.bottom, 2)
                                    HomeAttention(subscriptions: subscriptions, jarvis: jarvis, infrastructure: infrastructureStore,
                                        openSubscription: { id in selectedSubscription = id; subscriptionQuery = ""; page = "Subscriptions" },
                                        openProject: { project in setupProject = project })
                                    HStack(alignment: .top, spacing: 18) {
                                        VStack(alignment: .leading, spacing: 15) {
                                            HStack { Text("Mission Controls").font(.system(size: 15, weight: .medium)); Spacer() }
                                            VStack(alignment: .leading, spacing: 13) { ForEach(MissionSource.installed) { source in missionButton(source) } }
                                        }.frame(width: 200).padding(.top, 4)
                                        VStack(alignment: .leading, spacing: 15) {
                                            Text("Quick access").font(.system(size: 15, weight: .medium))
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
                                                ForEach(state.browserTiles.filter { tile in
                                                    guard let entry = state.linkEntry(for: tile), let port = URL(string: entry.url)?.port else { return true }
                                                    return !MissionSource.installed.contains { $0.port == port }
                                                }.prefix(6)) { tile in TileView(tile: tile, compact: true) }
                                            }
                                            let photoshopFiles = state.fileTiles.filter { tile in
                                                guard case .openFile(let path, _) = tile.invocation else { return false }
                                                return ["psd", "psb"].contains((path as NSString).pathExtension.lowercased())
                                            }
                                            if !photoshopFiles.isEmpty {
                                                Text("PHOTOSHOP").font(.system(size: 10, weight: .medium)).foregroundStyle(OLED.muted)
                                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
                                                    ForEach(photoshopFiles) { tile in TileView(tile: tile, compact: true) }
                                                }
                                            }
                                            Button("All files & shortcuts ↗") { page = "Shortcuts" }.buttonStyle(JarvisPlainButtonStyle()).font(.system(size: 12)).foregroundStyle(OLED.muted)
                                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                                    }
                                    HomeDesk(openProject: { project in setupProject = project })
                                } else if page == "Revenue" {
                                    YouTubeMonitorPage(store: youtube, revenueOnly: true)
                                } else if page == "YouTube" {
                                    YouTubeMonitorPage(store: youtube)

                                } else if page == "Projects" {
                                    Text("Your projects").font(.system(size: 30, weight: .medium))
                                    HStack(spacing: 16) { summary("Running", jarvis.runningProjects.count); summary("Ready", jarvis.readyProjects.count); summary("Needs you", jarvis.attentionProjects.count) }
                                    if !jarvis.attentionProjects.isEmpty { Text("Needs your attention").font(.title3); ForEach(jarvis.attentionProjects) { projectCard($0) } }
                                    Text("Finished videos").font(.title3)
                                    ForEach(jarvis.readyProjects) { projectCard($0) }
                                    if !jarvis.runningProjects.isEmpty { Text("In progress").font(.title3); ForEach(jarvis.runningProjects) { projectCard($0) } }
                                    Button("Browse all projects") { projects = true }.buttonStyle(JarvisControlStyle())
                                } else {
                                    Text("Everything, one click away.").font(.system(size: 30, weight: .medium))
                                    CommandShortcuts(query: query).environmentObject(state)
                                    if !query.isEmpty { ForEach(jarvis.dashboard.projects.filter { $0.displayName.localizedCaseInsensitiveContains(query) }.prefix(25)) { projectCard($0) } }
                                }
                            }.padding(20).frame(maxWidth: 1280).frame(maxWidth: .infinity)
                        }.background(OLED.canvas)
                    }
                }.environmentObject(state).environmentObject(inbox).environmentObject(jarvis)
                    .foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)))
            }
        }.frame(minWidth: 840, minHeight: 520).background(OLED.canvas).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
        .sheet(isPresented: $diagnostics) { DiagnosticsPanel() }
        .sheet(isPresented: $messages, onDismiss: {
            if let id = pendingSubscription { pendingSubscription = nil; selectedSubscription = id; subscriptionQuery = ""; page = "Subscriptions" }
        }) { InboxPanel(inbox: inbox) }
        .sheet(isPresented: $editingMission) { LinkEditor(entry: missionEntry).environmentObject(state) }
        .sheet(isPresented: $projects) { ProjectLibrary(jarvis: jarvis, filter: $projectFilter, select: { project in jarvis.setFocus(project); projects = false; page = "Assistant" }) }
        .sheet(item: $setupProject) { project in SetupPreview(project: project, jarvis: jarvis, state: state) }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("jarvis.focusComposer"))) { _ in page = "Assistant" }
        .task { await subscriptions.load(); inbox.ingestSubscriptions(SubscriptionStore.reminders(subscriptions.items)) }
        .onReceive(subscriptions.$items) { items in inbox.ingestSubscriptions(SubscriptionStore.reminders(items)) }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("jarvis.openSubscription"))) { note in
            if messages, let id = note.userInfo?["id"] as? String {
                pendingSubscription = id; messages = false
            } else {
                selectedSubscription = note.userInfo?["id"] as? String; subscriptionQuery = note.userInfo?["query"] as? String ?? ""; page = "Subscriptions"
            }
        }
        .task { while !Task.isCancelled { do { try await Task.sleep(nanoseconds: 3_600_000_000_000) } catch { return }; inbox.ingestSubscriptions(SubscriptionStore.reminders(subscriptions.items)) } }
        .task { while !Task.isCancelled { await youtube.reload(); do { try await Task.sleep(nanoseconds: 60_000_000_000) } catch { return } } }
        .task { await quotaStore.refresh() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in Task { await quotaStore.refresh() } }
        .task { inbox.start(); while !Task.isCancelled { await state.refreshStatus(); if !jarvis.busy { await jarvis.refreshDashboard(state: state) }; do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { break } } }
        .onChange(of: scenePhase) { phase in if phase == .active { inbox.ingestSubscriptions(SubscriptionStore.reminders(subscriptions.items)); state.reload(); Task { await quotaStore.refresh() }; Task { await state.refreshStatus(); await jarvis.refreshDashboard(state: state) } } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in jarvis.cancel() }
        .alert("Jarvis", isPresented: Binding(get: { state.errorMessage != nil }, set: { if !$0 { state.errorMessage = nil } })) { Button("OK") { state.errorMessage = nil } } message: { Text(state.errorMessage ?? "") }
    }
    private func navigation(_ title: String, _ icon: String) -> some View {
        Button { page = title } label: {
            VStack(spacing: 7) { Image(systemName: icon).font(.system(size: 19, weight: .light)); Text(title == "Overview" ? "Home" : title).font(.system(size: 8, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7) }
                .frame(width: 54, height: 54).background(page == title ? OLED.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(page == title ? OLED.accent : OLED.muted)
        }.buttonStyle(JarvisPlainButtonStyle()).help(title).accessibilityLabel(title)
    }
    private func missionButton(_ source: MissionSource) -> some View {
        let tile = state.browserTiles.first { state.linkEntry(for: $0).flatMap { URL(string: $0.url)?.port } == source.port }
        let status = tile.flatMap { state.linkEntry(for: $0) }.flatMap { state.statuses[$0.id] } ?? .checking
        return Button { if let tile { state.launch(tile) } } label: { HStack { Circle().fill(status == .online ? OLED.online : status == .checking ? OLED.muted : OLED.offline).frame(width: 6, height: 6); Text(source.name).font(.system(size: 12)); Spacer(); Image(systemName: status == .online ? "arrow.up.right" : "power").font(.system(size: 10)).foregroundStyle(OLED.muted) }.contentShape(Rectangle()) }.buttonStyle(JarvisPlainButtonStyle()).disabled(tile == nil).help(status == .online ? "Open \(source.name)" : "Start \(source.name)").contextMenu { if let tile, let entry = state.linkEntry(for: tile) { Button("Edit Mission Control…") { missionEntry = entry; editingMission = true } } }
    }
    private func summary(_ title: String, _ count: Int) -> some View {
        Button { projectFilter = title; projects = true } label: { HStack { Text(title).font(.system(size: 13)).foregroundStyle(OLED.muted); Spacer(); Text("\(count)").font(.system(size: 25, weight: .light)).foregroundStyle(title == "Needs you" && count > 0 ? OLED.offline : OLED.text) }.padding(20).background(OLED.surface, in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(JarvisPlainButtonStyle())
    }
    private func projectCard(_ project: MissionProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("\(project.source) · \(project.language.uppercased())").font(.system(size: 11, weight: .medium)).foregroundStyle(project.needsAttention ? OLED.offline : OLED.muted); Spacer(); Text(project.stage).font(.caption).foregroundStyle(OLED.muted) }
            Button { jarvis.setFocus(project); page = "Assistant" } label: { Text(project.title).font(.system(size: 16, weight: .medium)).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(JarvisPlainButtonStyle())
            if project.needsAttention { Text(project.detail).font(.caption).foregroundStyle(OLED.muted).lineLimit(2) }
            HStack { Button(project.video == nil ? "Open files ↗" : "Open video ↗") { jarvis.run(JarvisAction(kind: "open", targetID: project.id), state: state) }; Spacer(); Button("Open setup") { setupProject = project } }.font(.system(size: 12)).buttonStyle(JarvisPlainButtonStyle()).disabled(jarvis.busy)
        }.padding(.vertical, 5)
    }
}

private struct ProjectLibrary: View {
    @ObservedObject var jarvis: JarvisStore
    @Binding var filter: String
    let select: (MissionProject) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var items: [MissionProject] {
        jarvis.dashboard.projects.filter { p in
            (filter == "All" || (filter == "Ready" && p.isReady) || (filter == "Needs you" && p.needsAttention) || (filter == "Running" && p.status == "running")) && (query.isEmpty || p.displayName.localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        VStack(spacing: 15) {
            HStack { Text("Your projects").font(.title2.bold()); Spacer(); Button("Done") { dismiss() } }
            Picker("Show", selection: $filter) { ForEach(["All", "Running", "Ready", "Needs you"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
            TextField("Search channel, language or project…", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(spacing: 10) {
                    if items.isEmpty { Text("No matching projects").foregroundStyle(OLED.muted).padding(35) }
                    ForEach(items) { project in
                        Button { select(project) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(project.displayName).font(.callout.weight(.semibold))
                                Text("\(project.status.capitalized) · \(project.stage)").font(.caption).foregroundStyle(OLED.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(OLED.surface, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(JarvisPlainButtonStyle())
                    }
                }
            }
        }.padding(22).frame(width: 620, height: 560).background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)
    }
}
private struct SetupPreview: View {
    let project: MissionProject
    @ObservedObject var jarvis: JarvisStore
    let state: AppState
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let steps = jarvis.setupSteps(project, state: state)
        VStack(alignment: .leading, spacing: 15) {
            Text("Open your project setup").font(.title2.bold())
            Text(project.displayName).font(.callout).foregroundStyle(OLED.muted)
            ForEach(steps) { step in
                HStack { Image(systemName: step.kind == "dashboard" ? "globe" : step.kind == "folder" ? "folder" : "doc").foregroundStyle(OLED.accent); VStack(alignment: .leading) { Text(step.title); Text(step.kind == "dashboard" ? "Starts the server if needed" : (step.path as NSString).lastPathComponent).font(.caption).foregroundStyle(OLED.muted).lineLimit(2) } }
            }
            if project.video == nil { Text("No finished video exists yet.").foregroundStyle(OLED.offline).font(.caption) }
            if !steps.contains(where: { $0.title.contains("thumbnail") }) { Text("No thumbnail was found for this project.").foregroundStyle(OLED.offline).font(.caption) }
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Open \(steps.count) items") { dismiss(); jarvis.run(JarvisAction(kind: "prepare", targetID: project.id), state: state) }.disabled(jarvis.busy).buttonStyle(.borderedProminent) }
        }.padding(24).frame(width: 480).background(OLED.canvas).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
    }
}


// Native vector detailing stays crisp at every window scale.
struct JarvisPanel: Shape {
    var cut: CGFloat = 9
    func path(in rect: CGRect) -> Path { RoundedRectangle(cornerRadius: 12).path(in: rect) }

}

struct JarvisControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 11).padding(.vertical, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.07), in: JarvisPanel(cut: 5))
            .overlay(JarvisPanel(cut: 5).stroke(OLED.border, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

struct JarvisCore: View {
    var active = false
    var body: some View {
        GeometryReader { g in
            let size = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(RadialGradient(colors: [OLED.accent.opacity(active ? 0.24 : 0.12), .clear], center: .center, startRadius: 0, endRadius: size / 2))
                Circle().stroke(OLED.accent.opacity(0.14), lineWidth: 1)
                ForEach(0..<3) { i in
                    Circle().trim(from: 0.02, to: 0.27).stroke(OLED.accent.opacity(active ? 0.95 : 0.65), style: StrokeStyle(lineWidth: size * 0.035, lineCap: .butt))
                        .rotationEffect(.degrees(Double(i) * 120 - 90)).padding(size * 0.07)
                }
                Circle().stroke(OLED.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2, 5])).padding(size * 0.17)
                Circle().trim(from: 0.08, to: 0.82).stroke(OLED.accent.opacity(0.7), lineWidth: 1).rotationEffect(.degrees(40)).padding(size * 0.25)
                Image(systemName: active ? "waveform" : "sparkle").font(.system(size: size * 0.25, weight: .light)).foregroundStyle(OLED.accent)
            }.frame(width: size, height: size)
        }.accessibilityHidden(true)
    }
}

struct JarvisGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: CGFloat(0), through: size.width, by: 26) {
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat(0), through: size.height, by: 26) {
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(OLED.accent.opacity(0.055)), lineWidth: 0.5)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}


private struct CommandShortcuts: View {
    @EnvironmentObject var state: AppState
    let query: String
    @State private var addingLink = false
    @State private var showRemoved = false
    private var browsers: [Tile] {
        state.browserTiles.filter { tile in
            guard let entry = state.linkEntry(for: tile), let port = URL(string: entry.url)?.port else { return true }
            return !MissionSource.installed.contains { $0.port == port }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(query.isEmpty ? "QUICK ACCESS" : "SEARCH RESULTS").font(.system(size: 10, weight: .semibold, design: .monospaced)).kerning(1.4).foregroundStyle(OLED.accent)
                Spacer()
                Button { state.reload(); Task { await state.refreshStatus() } } label: { Image(systemName: "arrow.clockwise") }.help("Refresh shortcuts and servers")
                Menu {
                    Button("Add File…") {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.allowsMultipleSelection = true
                        if panel.runModal() == .OK { for url in panel.urls { state.addFile(url: url) } }
                    }
                    Button("Add Link…") { addingLink = true }
                    Toggle("Show removed browsers", isOn: $showRemoved)
                    Button("Open Settings Folder") { NSWorkspace.shared.open(Storage.baseDir) }
                } label: { Image(systemName: "plus") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Manage shortcuts")
            }.buttonStyle(JarvisPlainButtonStyle())
            if query.isEmpty {
                shortcutRow("BROWSERS", items: browsers)
                shortcutRow("THUMBNAILS / FILES", items: state.fileTiles)
                if showRemoved { shortcutRow("REMOVED", items: state.hiddenTiles, hidden: true) }
            } else {
                let results = state.memberTiles.filter { matches($0, query: query) }
                if results.isEmpty { Text("No matching shortcuts").font(.caption).foregroundStyle(OLED.muted) }
                else { shortcutRow("SHORTCUTS", items: results) }
            }
        }.padding(14).background(OLED.canvas)
            .sheet(isPresented: $addingLink) { LinkEditor().environmentObject(state) }
    }
    private func shortcutRow(_ title: String, items: [Tile], hidden: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(OLED.muted)
            if items.isEmpty { Text("Use + to add a shortcut").font(.caption).foregroundStyle(OLED.muted) }
            else {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(items) { tile in TileView(tile: tile, isHiddenTile: hidden, compact: true).frame(width: 88) }
                    }.padding(.bottom, 2)
                }
            }
        }
    }
}

struct JarvisAvatar: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(red: 0.67, green: 0.48, blue: 1), Color(red: 0.36, green: 0.19, blue: 0.78), Color(red: 0.13, green: 0.08, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(RadialGradient(colors: [.white.opacity(0.52), .clear], center: .topLeading, startRadius: 0, endRadius: g.size.width*0.65)).padding(3)
                HStack(spacing: g.size.width*0.15) {
                    Capsule().fill(Color(white: 0.08)).frame(width: g.size.width*0.10, height: g.size.width*0.26)
                    Capsule().fill(Color(white: 0.08)).frame(width: g.size.width*0.10, height: g.size.width*0.26)
                }.rotationEffect(.degrees(-18))
            }.overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
        }.accessibilityHidden(true)
    }
}

struct ProviderMark: View {
    let service: AIService
    private static let openAI = Bundle.module.url(forResource: "openai", withExtension: "png").flatMap { NSImage(contentsOf: $0) } ?? NSImage()
    private static let claude = Bundle.module.url(forResource: "anthropic", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    var body: some View {
        Group {
            if service == .openai { Image(nsImage: Self.openAI).resizable().scaledToFit() }
            else if let logo = Self.claude { Image(nsImage: logo).resizable().scaledToFit() }
            else { Text("Claude").font(.caption2) }
        }.accessibilityHidden(true)
    }
}

// Keep navigation pages alive without keeping hidden pages in the window's layout tree.
private struct RetainedPageHost: NSViewRepresentable {
    let key: String
    let content: AnyView
    final class Coordinator {
        var pages: [String: NSHostingView<AnyView>] = [:]
        var active: String?
    }
    private static func composer(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable,
           field.placeholderString == "Ask Jarvis or type a command…" { return field }
        for child in view.subviews { if let field = composer(in: child) { return field } }
        return nil
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ container: NSView, context: Context) {
        let coordinator = context.coordinator
        let host: NSHostingView<AnyView>
        if let existing = coordinator.pages[key] {
            host = existing
            host.rootView = content
        } else {
            host = NSHostingView(rootView: content)
            host.sizingOptions = []
            host.autoresizingMask = [.width, .height]
            coordinator.pages[key] = host
        }
        if coordinator.active != key {
            // Detached hosts retain view state but don't participate in window resizing.
            container.subviews.forEach { $0.removeFromSuperview() }
            host.frame = container.bounds
            container.addSubview(host)
            coordinator.active = key
            if key == "Assistant" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak host] in
                    guard let host, let window = host.window else { return }
                    host.layoutSubtreeIfNeeded()
                    if let field = Self.composer(in: host) { window.makeFirstResponder(field) }
                }
            }
        }
    }
}

/// Hit-test the entire laid-out label, including padding and transparent spaces.
/// Retains native Button activation, keyboard shortcuts and disabled handling.
struct JarvisPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// Observes status locally so timer updates do not rebuild the page content.
struct WorkspaceStatusStrip: View {
    @ObservedObject var quotas: AIQuotaStore
    @ObservedObject var infrastructure: InfrastructureStore
    @State private var showQuotas = false
    @State private var showSystems = false

    var body: some View {
        HStack(spacing: 6) {
            Button { showQuotas.toggle() } label: {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    HStack(spacing: 12) {
                        ForEach(AIService.allCases) { service in
                            HStack(spacing: 6) {
                                ProviderMark(service: service).frame(width: 18, height: 18)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(service == .openai ? "Codex Pro 20x" : "Claude Max x20").font(.system(size: 11, weight: .medium))
                                    HStack(spacing: 6) {
                                        if service == .claude { quotaValue(service, weekly: false, now: context.date) }
                                        quotaValue(service, weekly: true, now: context.date)
                                    }.font(.system(size: 10)).monospacedDigit()
                                }
                            }
                        }
                    }.padding(.horizontal, 9).frame(height: 40).contentShape(Rectangle())
                }
            }.buttonStyle(JarvisPlainButtonStyle())
                .background(OLED.surface, in: RoundedRectangle(cornerRadius: 8))
                .help("AI usage · Claude: 5h and weekly used. Codex: weekly used. Click for resets and refresh.")
                .accessibilityLabel("AI usage details, Claude 5h and weekly used, Codex weekly used")
                .popover(isPresented: $showQuotas, arrowEdge: .bottom) {
                    AIQuotaPanel(store: quotas).frame(width: 480).background(OLED.canvas)
                        .foregroundStyle(OLED.text).preferredColorScheme(.dark)
                }
            Button { showSystems.toggle() } label: {
                VStack(alignment: .leading, spacing: 4) {
                    healthLine("desktopcomputer", label: "Machines", healthy: infrastructure.machines.filter(\.online).count, total: infrastructure.machines.count)
                    healthLine("network", label: "Connections", healthy: infrastructure.connections.filter { $0.healthy == true }.count, total: infrastructure.connections.count)
                }.font(.system(size: 10)).monospacedDigit()
                    .padding(.horizontal, 9).frame(height: 40).contentShape(Rectangle())
            }.buttonStyle(JarvisPlainButtonStyle())
                .background(OLED.surface, in: RoundedRectangle(cornerRadius: 8))
                .help("Machines, VPS, tunnel and proxies · Click for details")
                .accessibilityLabel("Machine and connection status details")
                .popover(isPresented: $showSystems, arrowEdge: .bottom) {
                    InfrastructurePanel(store: infrastructure).frame(width: 570)
                        .background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)
                }
        }.fixedSize()
    }

    private func quotaValue(_ service: AIService, weekly: Bool, now: Date) -> some View {
        let row = quotas.entries(service).first { AIQuotaReaders.matchesWindow($0.window, weekly: weekly) }
        let value = row.flatMap { $0.usable(at: now) ? Int($0.used) : nil }
        let stale = row.map { now.timeIntervalSince($0.updated) > 600 } ?? false
        let countdown = resetCountdown(row, now: now)
        return HStack(spacing: 2) {
            Text(weekly ? "Weekly:" : "5h:").foregroundStyle(OLED.muted)
            Text(value.map { "\($0)%" } ?? "—")
                .foregroundStyle(stale || quotas.providerIssues[service.id] != nil || (value ?? 0) > 85 ? OLED.offline : OLED.text)
            if let countdown { Text("· \(countdown)").foregroundStyle(OLED.muted) }
        }.accessibilityLabel("\(service.title), \(weekly ? "weekly" : "session"): \(value.map { "\($0) percent used" } ?? "unavailable")\(resetAccessibility(row, now: now))\(stale ? ", outdated" : "")")
    }

    private func resetCountdown(_ row: AIQuota?, now: Date) -> String? {
        guard let reset = row?.reset, reset > now else { return nil }
        let minutes = max(1, Int(ceil(reset.timeIntervalSince(now) / 60)))
        if minutes >= 1440 { return "\(minutes / 1440)d left" }
        if minutes >= 60 { return "\(minutes / 60)h left" }
        return "\(minutes)m left"
    }

    private func resetAccessibility(_ row: AIQuota?, now: Date) -> String {
        guard let reset = row?.reset, reset > now else { return "" }
        let minutes = max(1, Int(ceil(reset.timeIntervalSince(now) / 60)))
        if minutes >= 1440 { return ", resets in \(minutes / 1440) days" }
        if minutes >= 60 { return ", resets in \(minutes / 60) hours" }
        return ", resets in \(minutes) minutes"
    }

    private func healthLine(_ icon: String, label: String, healthy: Int, total: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).frame(width: 13)
            Text(total == 0 ? "—" : "\(healthy)/\(total)")
            Circle().fill(total == 0 ? OLED.muted : healthy == total ? OLED.online : OLED.offline).frame(width: 4, height: 4)
        }.accessibilityLabel("\(label): \(total == 0 ? "checking" : "\(healthy) of \(total) healthy")")
    }
}
