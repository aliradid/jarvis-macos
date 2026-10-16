import SwiftUI
import AppKit

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
            // Left Sidebar: 5 Cohesive Developer & AI Pillars
            VStack(spacing: 10) {
                JarvisAvatar().frame(width: 44, height: 44).padding(.top, 14).padding(.bottom, 4)
                navigation("Command", "square.grid.2x2.fill", pageKey: "Overview")
                navigation("Assistant", "sparkles.rectangle.stack.fill", pageKey: "Assistant")
                navigation("Quotas", "gauge.with.dots.needle.67percent", pageKey: "Quotas")
                navigation("Dev Env", "terminal.fill", pageKey: "Projects")
                navigation("Launchers", "command.square.fill", pageKey: "Shortcuts")
                navigation("AI Spend", "creditcard.fill", pageKey: "Subscriptions")
                Spacer()
                VStack(spacing: 4) {
                    Circle().fill(OLED.online).frame(width: 6, height: 6)
                    Text("LOCAL").font(.system(size: 7.5, weight: .bold, design: .monospaced)).foregroundStyle(OLED.muted)
                }.padding(.bottom, 16)
            }
            .padding(.horizontal, 12)
            .frame(width: 78)
            .background(OLED.canvas)
            .overlay(alignment: .trailing) { Rectangle().fill(OLED.border).frame(width: 1) }

            // Main Content Column
            VStack(spacing: 0) {
                // Top Status & Search Bar
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("JARVIS").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.6).foregroundStyle(OLED.accent)
                        Text("/").foregroundStyle(OLED.muted)
                        Text(displayTitle(for: page)).font(.system(size: 14, weight: .semibold))
                    }
                    Spacer(minLength: 8)
                    WorkspaceStatusStrip(quotas: quotaStore, infrastructure: infrastructureStore)
                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass").foregroundStyle(OLED.muted).font(.system(size: 11))
                        TextField("Search commands & ports…", text: $query)
                            .textFieldStyle(.plain)
                            .focused($searchFocused)
                            .onChange(of: query) { _ in if !query.isEmpty { page = "Shortcuts" } }
                        Text("⌘F").font(.system(size: 9.5, weight: .semibold, design: .monospaced)).foregroundStyle(OLED.muted).padding(.horizontal, 5).padding(.vertical, 2).background(OLED.raised, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(width: 245)
                    .background(OLED.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(OLED.border, lineWidth: 1))

                    Button { diagnostics = true } label: {
                        Image(systemName: "waveform.path.ecg").frame(width: 30, height: 30)
                    }.buttonStyle(JarvisControlStyle()).help("Diagnostics").accessibilityLabel("Diagnostics")

                    Button { messages = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: inbox.unread > 0 ? "bell.badge.fill" : "bell.fill")
                            if inbox.unread > 0 { Text("\(inbox.unread)").font(.system(size: 10.5, weight: .bold, design: .monospaced)) }
                        }.frame(height: 18)
                    }.buttonStyle(JarvisControlStyle()).accessibilityLabel("Messages")

                    Button { searchFocused = true } label: { EmptyView() }.keyboardShortcut("f").frame(width: 0).accessibilityHidden(true)
                }
                .padding(.horizontal, 22).padding(.vertical, 10)
                .background(OLED.canvas)

                Divider().overlay(OLED.border)

                if let notice = state.notice {
                    HStack {
                        Image(systemName: "info.circle.fill").foregroundStyle(OLED.accent)
                        Text(notice).font(.system(size: 11.5, weight: .medium))
                        Spacer()
                        Button("Dismiss") { state.notice = nil }.font(.caption).buttonStyle(JarvisPlainButtonStyle()).foregroundStyle(OLED.muted)
                    }.padding(.horizontal, 20).padding(.vertical, 8).background(OLED.surface)
                }

                RetainedPageHost(key: page, content: AnyView(ZStack {
                    if page == "Assistant" {
                        JarvisView(jarvis: jarvis, draft: $composerDraft, embedded: true).environmentObject(state)
                    } else if page == "Subscriptions" {
                        SubscriptionsPage(store: subscriptions, selectedID: selectedSubscription, initialQuery: subscriptionQuery, selectionConsumed: { selectedSubscription = nil })
                    } else if page == "Cats" || page == "Expenses" {
                        AIQuotasDashboardPage(quotaStore: quotaStore, infraStore: infrastructureStore)
                            .padding(22).frame(maxWidth: 1280, maxHeight: .infinity, alignment: .topLeading)
                    } else if page == "YouTube" || page == "Revenue" {
                        DevEnvironmentPage(infraStore: infrastructureStore, jarvis: jarvis, state: state, openProject: { setupProject = $0 })
                            .padding(22).frame(maxWidth: 1280, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if page == "Overview" {
                                    commandCenterOverview
                                } else if page == "Quotas" {
                                    AIQuotasDashboardPage(quotaStore: quotaStore, infraStore: infrastructureStore)
                                } else if page == "Projects" {
                                    DevEnvironmentPage(infraStore: infrastructureStore, jarvis: jarvis, state: state, openProject: { setupProject = $0 })
                                } else {
                                    CommandShortcuts(query: query, infraStore: infrastructureStore, jarvis: jarvis, openProject: { setupProject = $0 })
                                        .environmentObject(state)
                                }
                            }
                            .padding(22)
                            .frame(maxWidth: 1280)
                            .frame(maxWidth: .infinity)
                        }.background(OLED.canvas)
                    }
                }.environmentObject(state).environmentObject(inbox).environmentObject(jarvis)
                    .foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)))
            }
        }
        .frame(minWidth: 960, minHeight: 620)
        .background(OLED.canvas).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
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
        .task { await quotaStore.refresh(); await infrastructureStore.refresh() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in Task { await quotaStore.refresh(); await infrastructureStore.refresh() } }
        .task { inbox.start(); while !Task.isCancelled { await state.refreshStatus(); if !jarvis.busy { await jarvis.refreshDashboard(state: state) }; do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { break } } }
        .onChange(of: scenePhase) { phase in if phase == .active { inbox.ingestSubscriptions(SubscriptionStore.reminders(subscriptions.items)); state.reload(); Task { await quotaStore.refresh(); await infrastructureStore.refresh() }; Task { await state.refreshStatus(); await jarvis.refreshDashboard(state: state) } } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in jarvis.cancel() }
        .alert("Jarvis", isPresented: Binding(get: { state.errorMessage != nil }, set: { if !$0 { state.errorMessage = nil } })) { Button("OK") { state.errorMessage = nil } } message: { Text(state.errorMessage ?? "") }
    }

    private func displayTitle(for key: String) -> String {
        switch key {
        case "Overview": return "Command Center"
        case "Assistant": return "Ollama AI Assistant"
        case "Quotas", "Cats", "Expenses": return "AI Quotas & Models"
        case "Projects", "YouTube", "Revenue": return "Dev Environment & Ports"
        case "Shortcuts": return "Quick Launchers & Assets"
        case "Subscriptions": return "AI & Cloud Spend"
        default: return key
        }
    }

    // MARK: - Command Center Overview (Pillar 1)
    private var commandCenterOverview: some View {
        let claude5h = quotaStore.entries(.claude).first { AIQuotaReaders.matchesWindow($0.window, weekly: false) }
        let claudeWeekly = quotaStore.entries(.claude).first { AIQuotaReaders.matchesWindow($0.window, weekly: true) }
        let codexWeekly = quotaStore.entries(.openai).first { AIQuotaReaders.matchesWindow($0.window, weekly: true) }
        let tele = infrastructureStore.telemetry

        return VStack(alignment: .leading, spacing: 16) {
            // Hero Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MACOS AI & DEVELOPER COMMAND CENTER").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(OLED.accent)
                    Text("Everything running on your Mac, at a glance.").font(.system(size: 24, weight: .semibold))
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(OLED.online).frame(width: 7, height: 7)
                    Text("\(tele.chipName) · \(tele.osVersion) · Uptime \(tele.uptimeString)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(OLED.muted)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(OLED.surface, in: Capsule())
                .overlay(Capsule().stroke(OLED.border, lineWidth: 1))
            }

            // Row 1: 4 Telemetry & Quota Hero Cards
            HStack(spacing: 12) {
                heroQuotaCard(
                    title: "CLAUDE CODE · 5H",
                    subtitle: "Max 20x · Resets in 3h 18m",
                    usedPercent: claude5h?.used ?? 24,
                    secondaryLabel: "7d Weekly: \(Int(claudeWeekly?.used ?? 36))% used",
                    tint: OLED.accent,
                    service: .claude
                ) { page = "Quotas" }

                heroQuotaCard(
                    title: "OPENAI CODEX PRO",
                    subtitle: "20x Tier · Resets in 4d",
                    usedPercent: codexWeekly?.used ?? 29,
                    secondaryLabel: "o3-pro + codex-1 active",
                    tint: OLED.cyan,
                    service: .openai
                ) { page = "Quotas" }

                Button { page = "Assistant" } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "cpu.fill").font(.system(size: 15)).foregroundStyle(OLED.online).frame(width: 30, height: 30).background(OLED.raised, in: RoundedRectangle(cornerRadius: 8))
                            Spacer()
                            Text("127.0.0.1:11434").font(.system(size: 9.5, weight: .bold, design: .monospaced)).padding(.horizontal, 7).padding(.vertical, 3).background(OLED.online.opacity(0.16), in: Capsule()).foregroundStyle(OLED.online)
                        }
                        Text("LOCAL OLLAMA LLM").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(OLED.muted)
                        Text("llama3.2 + R1").font(.system(size: 19, weight: .bold, design: .rounded))
                        Text("\(infrastructureStore.ollamaModels.count) GGUF models · $0 API cost").font(.system(size: 10.5)).foregroundStyle(OLED.muted)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OLED.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(OLED.border, lineWidth: 1))
                }.buttonStyle(JarvisPlainButtonStyle())

                Button { diagnostics = true } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("MAC TELEMETRY").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(OLED.muted)
                            Spacer()
                            Text(tele.thermalState.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(OLED.online)
                        }
                        miniMeterRow(label: "CPU", value: String(format: "%.0f%%", tele.cpuUsagePercent), percent: tele.cpuUsagePercent, tint: OLED.accent)
                        miniMeterRow(label: "RAM", value: String(format: "%.1f/%.0fG", tele.memoryUsedGB, tele.memoryTotalGB), percent: tele.memoryPercent, tint: OLED.cyan)
                        miniMeterRow(label: "SSD", value: String(format: "%.0f%%", tele.diskPercent), percent: tele.diskPercent, tint: OLED.online)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OLED.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(OLED.border, lineWidth: 1))
                }.buttonStyle(JarvisPlainButtonStyle())
            }

            // Row 2: Active Localhost Dev Servers + Quick Launchers & Workspace Assets
            HStack(alignment: .top, spacing: 16) {
                // Left: Listening Localhost Ports
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Label("LOCALHOST DEV SERVERS", systemImage: "network")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(OLED.accent)
                        Spacer()
                        Button("Inspect all ↗") { page = "Projects" }.buttonStyle(JarvisPlainButtonStyle()).font(.system(size: 11, weight: .medium)).foregroundStyle(OLED.accent)
                    }
                    VStack(spacing: 7) {
                        ForEach(infrastructureStore.devPorts.prefix(6)) { svc in
                            HStack(spacing: 10) {
                                Image(systemName: svc.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(svc.online ? OLED.accent : OLED.muted)
                                    .frame(width: 28, height: 28)
                                    .background(OLED.raised, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                VStack(alignment: .leading, spacing: 1.5) {
                                    Text(svc.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    Text(svc.stack).font(.system(size: 10)).foregroundStyle(OLED.muted).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Text(":" + String(svc.port))
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(OLED.raised, in: RoundedRectangle(cornerRadius: 5))
                                HStack(spacing: 4) {
                                    Circle().fill(svc.online ? OLED.online : OLED.muted.opacity(0.4)).frame(width: 5.5, height: 5.5)
                                    Text(svc.online ? "\(svc.responseMs)ms" : "Idle")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(svc.online ? OLED.online : OLED.muted)
                                }.frame(width: 46, alignment: .trailing)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(OLED.raised.opacity(0.45), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(OLED.border, lineWidth: 1))
                        }
                    }
                }
                .padding(15)
                .frame(width: 390, alignment: .topLeading)
                .background(OLED.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(OLED.border, lineWidth: 1))

                // Right: Quick Launchers & Workspace Assets Grid
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("QUICK LAUNCHERS & IDE PROFILES", systemImage: "bolt.fill")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(OLED.cyan)
                        Spacer()
                        Button("All shortcuts (⌘1–⌘9) ↗") { page = "Shortcuts" }.buttonStyle(JarvisPlainButtonStyle()).font(.system(size: 11, weight: .medium)).foregroundStyle(OLED.accent)
                    }

                    let topLaunchers = state.browserTiles.filter { tile in
                        guard let entry = state.linkEntry(for: tile), let port = URL(string: entry.url)?.port else { return true }
                        return !MissionSource.installed.contains { $0.port == port }
                    }.prefix(6)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(Array(topLaunchers.enumerated()), id: \.element.id) { idx, tile in
                            TileView(tile: tile, shortcutIndex: idx, compact: true)
                        }
                    }

                    HStack {
                        Label("PINNED WORKSPACE ASSETS & SPECS", systemImage: "cube.box.fill")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(OLED.muted)
                        Spacer()
                    }.padding(.top, 2)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(state.fileTiles.prefix(6)) { tile in
                            TileView(tile: tile, compact: true)
                        }
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(OLED.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(OLED.border, lineWidth: 1))
            }

            // Row 3: Active Git Repositories & Engineering Focus Queue
            HomeDesk(openProject: { project in setupProject = project })
        }
    }

    private func heroQuotaCard(title: String, subtitle: String, usedPercent: Double, secondaryLabel: String, tint: Color, service: AIService, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ProviderMark(service: service).frame(width: 16, height: 16)
                        Text(title).font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.0).foregroundStyle(OLED.muted)
                    }
                    Text("\(Int(round(100 - usedPercent)))% Left")
                        .font(.system(size: 21, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(subtitle).font(.system(size: 10.5, weight: .medium)).foregroundStyle(tint).lineLimit(1)
                    Text(secondaryLabel).font(.system(size: 10)).foregroundStyle(OLED.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                CircularQuotaRing(usedPercent: usedPercent, tint: tint, size: 54, lineWidth: 5)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OLED.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(OLED.border, lineWidth: 1))
        }.buttonStyle(JarvisPlainButtonStyle())
    }

    private func miniMeterRow(label: String, value: String, percent: Double, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(OLED.muted).frame(width: 28, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(OLED.raised)
                    Capsule().fill(tint).frame(width: max(4, geo.size.width * CGFloat(min(100, max(0, percent)) / 100.0)))
                }
            }.frame(height: 5)
            Text(value).font(.system(size: 10, weight: .semibold, design: .monospaced)).frame(width: 58, alignment: .trailing)
        }
    }

    private func navigation(_ title: String, _ icon: String, pageKey: String? = nil) -> some View {
        let target = pageKey ?? title
        let isSelected = page == target
            || (target == "Quotas" && (page == "Cats" || page == "Expenses"))
            || (target == "Projects" && (page == "YouTube" || page == "Revenue"))
        return Button { page = target } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17, weight: .medium))
                Text(title).font(.system(size: 9, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(width: 58, height: 52)
            .background(isSelected ? OLED.accent.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isSelected ? OLED.accent.opacity(0.45) : .clear, lineWidth: 1))
            .foregroundStyle(isSelected ? OLED.accent : OLED.muted)
        }.buttonStyle(JarvisPlainButtonStyle()).help(title).accessibilityLabel(title)
    }
}

// MARK: - Dev Environment & Localhost Ports Page (Pillar 4)
struct DevEnvironmentPage: View {
    @ObservedObject var infraStore: InfrastructureStore
    @ObservedObject var jarvis: JarvisStore
    let state: AppState
    let openProject: (MissionProject) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEV ENVIRONMENT · PORTS & REPOSITORIES").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(OLED.cyan)
                    Text("Localhost Services, Containers & Git Worktrees").font(.system(size: 26, weight: .semibold))
                }
                Spacer()
                let onlinePorts = infraStore.devPorts.filter(\.online).count
                HStack(spacing: 7) {
                    Circle().fill(OLED.online).frame(width: 7, height: 7)
                    Text("\(onlinePorts)/\(infraStore.devPorts.count) Local Ports Listening").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(OLED.online)
                }.padding(.horizontal, 12).padding(.vertical, 6).background(OLED.surface, in: Capsule()).overlay(Capsule().stroke(OLED.border, lineWidth: 1))

                Button { Task { await infraStore.refresh() } } label: {
                    Label("Scan Ports", systemImage: "arrow.clockwise").font(.system(size: 12, weight: .medium))
                }.buttonStyle(JarvisControlStyle())
            }

            // Summary KPI Strip
            HStack(spacing: 12) {
                devSummaryTile(title: "LISTENING PORTS", value: "\(infraStore.devPorts.filter(\.online).count)", subtitle: "TCP IPv4 127.0.0.1 sockets", tint: OLED.online)
                devSummaryTile(title: "ACTIVE GIT REPOS", value: "\(jarvis.dashboard.projects.count)", subtitle: "2 running · 1 ready · 1 PR review", tint: OLED.accent)
                devSummaryTile(title: "CPU & UNIFIED RAM", value: String(format: "%.1f GB", infraStore.telemetry.memoryUsedGB), subtitle: "Load \(String(format: "%.2f", infraStore.telemetry.loadAverage1m)) on \(infraStore.telemetry.chipName)", tint: OLED.cyan)
                devSummaryTile(title: "LOCAL LLM RUNTIME", value: ":11434", subtitle: "Ollama Metal GPU · 1ms ping", tint: OLED.online)
            }

            // Listening Ports Table
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("AUTO-DETECTED LOCALHOST PORTS").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(OLED.accent)
                    Spacer()
                    Text("Probed via non-blocking Darwin BSD socket connect").font(.system(size: 10.5)).foregroundStyle(OLED.muted)
                }

                VStack(spacing: 6) {
                    ForEach(infraStore.devPorts) { svc in
                        HStack(spacing: 12) {
                            Image(systemName: svc.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(svc.online ? OLED.accent : OLED.muted)
                                .frame(width: 30, height: 30)
                                .background(OLED.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(svc.name).font(.system(size: 13, weight: .semibold))
                                Text(svc.stack).font(.system(size: 11)).foregroundStyle(OLED.muted)
                            }
                            Spacer()
                            Text(svc.url)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(OLED.muted)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(OLED.raised.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

                            HStack(spacing: 5) {
                                Circle().fill(svc.online ? OLED.online : OLED.muted.opacity(0.4)).frame(width: 6, height: 6)
                                Text(svc.online ? "ONLINE · \(svc.responseMs)ms" : "OFFLINE")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(svc.online ? OLED.online : OLED.muted)
                            }.frame(width: 115, alignment: .trailing)

                            Button {
                                if let tile = state.browserTiles.first(where: { $0.subtitle.contains(":\(svc.port)") }) {
                                    state.launch(tile)
                                } else {
                                    state.notice = "Opened \(svc.url) in browser."
                                }
                            } label: {
                                Label("Open", systemImage: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(OLED.raised, in: RoundedRectangle(cornerRadius: 7))
                            }.buttonStyle(JarvisPlainButtonStyle())
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(OLED.border, lineWidth: 1))
                    }
                }
            }
            .padding(16)
            .background(OLED.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OLED.border, lineWidth: 1))

            // Active Repositories Grid
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ACTIVE GIT WORKTREES & REPOSITORIES").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(OLED.cyan)
                    Spacer()
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(jarvis.dashboard.projects) { project in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Circle().fill(project.status == "running" ? OLED.online : project.needsAttention ? OLED.warning : OLED.accent).frame(width: 7, height: 7)
                                    Text(project.title).font(.system(size: 14, weight: .semibold, design: .monospaced))
                                }
                                Spacer()
                                Text(project.language)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(OLED.raised, in: Capsule())
                                    .foregroundStyle(OLED.cyan)
                            }
                            Text(project.detail).font(.system(size: 12)).foregroundStyle(OLED.muted).lineLimit(1)
                            HStack {
                                Label(project.stage, systemImage: "arrow.triangle.branch")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(OLED.text)
                                Spacer()
                                Button("Open IDE & Stack ↗") { openProject(project) }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(OLED.accent)
                                    .buttonStyle(JarvisPlainButtonStyle())
                            }
                        }
                        .padding(14)
                        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(OLED.border, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func devSummaryTile(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(OLED.muted)
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(tint).monospacedDigit()
            Text(subtitle).font(.system(size: 10.5)).foregroundStyle(OLED.muted).lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(OLED.border, lineWidth: 1))
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
            HStack { Text("Workspace Repositories").font(.title2.bold()); Spacer(); Button("Done") { dismiss() } }
            Picker("Show", selection: $filter) { ForEach(["All", "Running", "Ready", "Needs you"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
            TextField("Search repository, language or branch…", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(spacing: 10) {
                    if items.isEmpty { Text("No matching repositories").foregroundStyle(OLED.muted).padding(35) }
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
            Text("Launch Project Stack").font(.title2.bold())
            Text(project.displayName).font(.callout).foregroundStyle(OLED.muted)
            ForEach(steps) { step in
                HStack {
                    Image(systemName: step.kind == "dashboard" ? "globe" : step.kind == "folder" ? "folder" : "doc").foregroundStyle(OLED.accent)
                    VStack(alignment: .leading) {
                        Text(step.title)
                        Text(step.kind == "dashboard" ? "Starts local server if needed" : (step.path as NSString).lastPathComponent).font(.caption).foregroundStyle(OLED.muted).lineLimit(2)
                    }
                }
            }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Launch \(steps.count) items") {
                    dismiss()
                    jarvis.run(JarvisAction(kind: "prepare", targetID: project.id), state: state)
                }.disabled(jarvis.busy).buttonStyle(.borderedProminent)
            }
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
        configuration.label.padding(.horizontal, 11).padding(.vertical, 7)
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
                Circle().fill(RadialGradient(colors: [OLED.accent.opacity(active ? 0.28 : 0.16), .clear], center: .center, startRadius: 0, endRadius: size / 2))
                Circle().stroke(OLED.accent.opacity(0.22), lineWidth: 1)
                ForEach(0..<3) { i in
                    Circle().trim(from: 0.02, to: 0.27).stroke(OLED.accent.opacity(active ? 0.95 : 0.75), style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                        .rotationEffect(.degrees(Double(i) * 120 - 90)).padding(size * 0.07)
                }
                Circle().stroke(OLED.cyan.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [2, 5])).padding(size * 0.17)
                Circle().trim(from: 0.08, to: 0.82).stroke(OLED.accent.opacity(0.75), lineWidth: 1).rotationEffect(.degrees(40)).padding(size * 0.25)
                Image(systemName: active ? "waveform" : "sparkle").font(.system(size: size * 0.26, weight: .semibold)).foregroundStyle(OLED.accent)
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

// MARK: - Quick Launchers & Keyboard Shortcuts Page (Pillar 4 / Shortcuts)
private struct CommandShortcuts: View {
    @EnvironmentObject var state: AppState
    let query: String
    @ObservedObject var infraStore: InfrastructureStore
    @ObservedObject var jarvis: JarvisStore
    let openProject: (MissionProject) -> Void
    @State private var addingLink = false
    @State private var showRemoved = false

    private var browsers: [Tile] {
        state.browserTiles.filter { tile in
            guard let entry = state.linkEntry(for: tile), let port = URL(string: entry.url)?.port else { return true }
            return !MissionSource.installed.contains { $0.port == port }
        }
    }

    private var serverTiles: [Tile] {
        state.browserTiles.filter { tile in
            guard let entry = state.linkEntry(for: tile), let port = URL(string: entry.url)?.port else { return false }
            return MissionSource.installed.contains { $0.port == port }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(query.isEmpty ? "INSTANT LAUNCHPAD · KEYBOARD PALETTE" : "FILTERED WORKSPACE RESULTS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).kerning(1.5).foregroundStyle(OLED.accent)
                    Text("Everything on your Mac, one keystroke away.").font(.system(size: 26, weight: .semibold))
                }
                Spacer()
                Button { state.reload(); Task { await state.refreshStatus() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise").font(.system(size: 12, weight: .medium))
                }.buttonStyle(JarvisControlStyle())
                Button { addingLink = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("Add Shortcut").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(OLED.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(Color.white)
                }.buttonStyle(JarvisPlainButtonStyle())
            }

            if query.isEmpty {
                shortcutGridSection("IDE & CLOUD CONSOLES (⌘1 – ⌘6)", subtitle: "Instant single-keystroke developer workflows", items: browsers, assignShortcuts: true)
                shortcutGridSection("LOCALHOST DEV SERVERS & RUNTIME ENDPOINTS", subtitle: "Auto-monitored local HTTP & database endpoints", items: serverTiles, assignShortcuts: false)
                shortcutGridSection("WORKSPACE SPECS, SCHEMAS & MODEL WEIGHTS", subtitle: "Pinned local files opened with default macOS apps", items: state.fileTiles, assignShortcuts: false)
                if showRemoved { shortcutGridSection("HIDDEN ITEMS", subtitle: "Right-click to restore", items: state.hiddenTiles, hidden: true) }
            } else {
                let results = state.memberTiles.filter { matches($0, query: query) }
                if results.isEmpty {
                    Text("No matching shortcuts").font(.callout).foregroundStyle(OLED.muted).padding(20)
                } else {
                    shortcutGridSection("MATCHING SHORTCUTS", subtitle: "Filtered by '\(query)'", items: results)
                }
            }
        }
        .sheet(isPresented: $addingLink) { LinkEditor().environmentObject(state) }
    }

    private func shortcutGridSection(_ title: String, subtitle: String, items: [Tile], hidden: Bool = false, assignShortcuts: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(OLED.cyan)
                Spacer()
                Text(subtitle).font(.system(size: 11)).foregroundStyle(OLED.muted)
            }
            if items.isEmpty {
                Text("Use '+ Add Shortcut' to pin an application, URL, or file.").font(.caption).foregroundStyle(OLED.muted)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, tile in
                        TileView(tile: tile, isHiddenTile: hidden, shortcutIndex: assignShortcuts ? idx : nil, compact: false)
                    }
                }
            }
        }
        .padding(16)
        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(OLED.border, lineWidth: 1))
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
            }.overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
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
        if let field = view as? NSTextField, field.isEditable { return field }
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
        HStack(spacing: 8) {
            Button { showQuotas.toggle() } label: {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    HStack(spacing: 14) {
                        ForEach(AIService.allCases) { service in
                            HStack(spacing: 7) {
                                ProviderMark(service: service).frame(width: 18, height: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(service.title).font(.system(size: 11, weight: .semibold))
                                    HStack(spacing: 6) {
                                        if service == .claude { quotaValue(service, weekly: false, now: context.date) }
                                        quotaValue(service, weekly: true, now: context.date)
                                    }.font(.system(size: 10, design: .monospaced)).monospacedDigit()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 11).frame(height: 38).contentShape(Rectangle())
                }
            }
            .buttonStyle(JarvisPlainButtonStyle())
            .background(OLED.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(OLED.border, lineWidth: 1))
            .help("Live AI token quotas · Click for circular gauges & reset timers")
            .popover(isPresented: $showQuotas, arrowEdge: .bottom) {
                AIQuotaPanel(store: quotas).frame(width: 500).background(OLED.canvas)
                    .foregroundStyle(OLED.text).preferredColorScheme(.dark)
            }

            Button { showSystems.toggle() } label: {
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "cpu").foregroundStyle(OLED.accent).font(.system(size: 11))
                        Text(String(format: "%.0f%%", infrastructure.telemetry.cpuUsagePercent))
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "memorychip").foregroundStyle(OLED.cyan).font(.system(size: 11))
                        Text(String(format: "%.0fG", infrastructure.telemetry.memoryUsedGB))
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    }
                    HStack(spacing: 4) {
                        Circle().fill(OLED.online).frame(width: 5.5, height: 5.5)
                        Text("\(infrastructure.devPorts.filter(\.online).count) ports")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(OLED.online)
                    }
                }
                .padding(.horizontal, 11).frame(height: 38).contentShape(Rectangle())
            }
            .buttonStyle(JarvisPlainButtonStyle())
            .background(OLED.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(OLED.border, lineWidth: 1))
            .help("Mac Darwin telemetry & active localhost ports · Click to inspect")
            .popover(isPresented: $showSystems, arrowEdge: .bottom) {
                InfrastructurePanel(store: infrastructure).frame(width: 560)
                    .background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)
            }
        }.fixedSize()
    }

    private func quotaValue(_ service: AIService, weekly: Bool, now: Date) -> some View {
        let row = quotas.entries(service).first { AIQuotaReaders.matchesWindow($0.window, weekly: weekly) }
        let value = row.flatMap { $0.usable(at: now) ? Int($0.used) : nil }
        return HStack(spacing: 2) {
            Text(weekly ? "7d:" : "5h:").foregroundStyle(OLED.muted)
            Text(value.map { "\($0)%" } ?? "—")
                .foregroundStyle((value ?? 0) > 85 ? OLED.offline : OLED.text)
        }
    }
}
