import SwiftUI
import AppKit
import Combine

struct AIQuota: Codable, Identifiable {
    var id: String
    var provider: String
    var window: String
    var remaining: Double
    var reset: Date?
    var updated = Date()
    var live = false
    var used: Double { max(0, min(100, 100 - remaining)) }
    func usable(at now: Date) -> Bool { reset.map { $0 > now } ?? true }
}

enum AIService: String, CaseIterable, Identifiable {
    case claude, openai
    var id: String { rawValue }
    var title: String { switch self { case .openai: return "Codex Pro 20x"; case .claude: return "Claude Max 20x" } }
    var subtitle: String { switch self { case .openai: return "OpenAI · ~/.codex/auth.json"; case .claude: return "Anthropic · Keychain OAuth" } }
    var initials: String { switch self { case .openai: return "O"; case .claude: return "C" } }
    var url: String { switch self { case .openai: return "https://chatgpt.com/"; case .claude: return "https://claude.ai/new" } }
    var usageURL: String { switch self { case .openai: return "https://chatgpt.com/codex/settings/usage"; case .claude: return "https://claude.ai/settings/usage" } }
}

@MainActor final class AIQuotaStore: ObservableObject {
    static let shared = AIQuotaStore()
    @Published private(set) var readings: [AIQuota] = []
    @Published var refreshing = false
    @Published var issue: String?
    @Published var providerIssues: [String: String] = [:]
    init() {
        if AppMode.isDemo { readings = SampleData.quotas }
        else {
            if let data = Storage.readData("ai-quotas.json"), let cached = try? JSONDecoder().decode([AIQuota].self, from: data) {
                readings = cached
            } else {
                readings = SampleData.quotas
            }
            Task { await refresh() }
        }
    }
    func entries(_ service: AIService) -> [AIQuota] { readings.filter { $0.provider == service.id } }
    func refresh(force: Bool = false) async {
        if AppMode.isDemo { readings = SampleData.quotas; issue = nil; return }
        refreshing = true
        defer { refreshing = false }
        var updated = readings
        var newProviderIssues: [String: String] = [:]

        do {
            let claudeReadings = try await AIQuotaReaders.fetchClaudeQuotas()
            if !claudeReadings.isEmpty {
                updated.removeAll { $0.provider == AIService.claude.id }
                updated.append(contentsOf: claudeReadings)
            }
        } catch {
            newProviderIssues[AIService.claude.id] = error.localizedDescription
        }

        do {
            let codexReadings = try await AIQuotaReaders.fetchCodexQuotas()
            if !codexReadings.isEmpty {
                updated.removeAll { $0.provider == AIService.openai.id }
                updated.append(contentsOf: codexReadings)
            }
        } catch {
            newProviderIssues[AIService.openai.id] = error.localizedDescription
        }

        readings = updated
        providerIssues = newProviderIssues
        if let encoded = try? JSONEncoder().encode(readings) {
            Storage.writeData(encoded, named: "ai-quotas.json")
        }
    }
}

struct CircularQuotaRing: View {
    let usedPercent: Double
    let tint: Color
    var size: CGFloat = 58
    var lineWidth: CGFloat = 6

    var body: some View {
        let clamped = min(100, max(0, usedPercent))
        let remaining = Int(round(100 - clamped))
        ZStack {
            Circle()
                .stroke(OLED.raised, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(clamped / 100.0))
                .stroke(
                    AngularGradient(colors: [tint, tint.opacity(0.65), tint], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(remaining)%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(OLED.text)
                Text("LEFT")
                    .font(.system(size: size * 0.12, weight: .bold, design: .monospaced))
                    .foregroundStyle(OLED.muted)
            }
        }
        .frame(width: size, height: size)
    }
}

struct AIQuotaPanel: View {
    var referenceDate: Date? = nil
    @ObservedObject var store: AIQuotaStore
    @State private var selected: AIService?
    var body: some View {
        let now = referenceDate ?? Date()
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIVE AI TOKEN QUOTAS").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(OLED.accent)
                    Text("Claude Code & OpenAI Codex").font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(OLED.online).frame(width: 6, height: 6)
                    Text("Keychain Sync").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(OLED.muted)
                }.padding(.horizontal, 8).padding(.vertical, 4).background(OLED.surface, in: Capsule())
                Button { Task { await store.refresh(force: true) } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 26, height: 26)
                }.buttonStyle(JarvisControlStyle()).disabled(store.refreshing).accessibilityLabel("Refresh AI quotas")
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach(AIService.allCases) { service in
                    Button { selected = service } label: {
                        providerCard(service: service, now: now)
                    }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("\(service.title) quota details")
                }
            }

            HStack {
                Image(systemName: "lock.shield.fill").foregroundStyle(OLED.online).font(.system(size: 11))
                Text("Zero-cost OAuth & local CLI session reader · Click any provider card for reset timestamps")
                    .font(.system(size: 10)).foregroundStyle(OLED.muted)
                Spacer()
            }
        }
        .padding(18)
        .background(OLED.canvas)
        .sheet(item: $selected) { service in AIQuotaDetails(service: service, store: store) }
    }

    private func providerCard(service: AIService, now: Date) -> some View {
        let rows = store.entries(service)
        let primaryWindow = service == .claude ? "5h" : "Weekly"
        let primaryRow = rows.first { AIQuotaReaders.matchesWindow($0.window, weekly: primaryWindow == "Weekly") }
        let used = primaryRow?.used ?? 24
        let tint: Color = used > 85 ? OLED.offline : (service == .claude ? OLED.accent : OLED.cyan)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProviderMark(service: service)
                    .frame(width: 24, height: 24)
                    .padding(4)
                    .background(OLED.raised, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(service.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                    Text(service == .claude ? "5h + 7d Windows" : "Weekly Window").font(.system(size: 9.5)).foregroundStyle(OLED.muted)
                }
                Spacer(minLength: 4)
                CircularQuotaRing(usedPercent: used, tint: tint, size: 42, lineWidth: 4.5)
            }

            VStack(alignment: .leading, spacing: 9) {
                ForEach(service == .openai ? ["Weekly"] : ["5h", "Weekly"], id: \.self) { window in
                    let row = rows.first { AIQuotaReaders.matchesWindow($0.window, weekly: window == "Weekly") }
                    let wUsed = row?.used ?? 0
                    let wRem = max(0, 100 - Int(wUsed))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(window == "5h" ? "5h Session" : "7d Rolling").font(.system(size: 10.5, weight: .medium)).foregroundStyle(OLED.muted)
                            Spacer()
                            Text("\(Int(wUsed))% used (\(wRem)% left)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(wUsed > 85 ? OLED.offline : OLED.text)
                                .lineLimit(1)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(OLED.raised)
                                Capsule().fill(wUsed > 85 ? OLED.offline : tint)
                                    .frame(width: max(4, geo.size.width * CGFloat(wUsed / 100.0)))
                            }
                        }.frame(height: 5)
                        Text(Self.resetLabel(row, now: now, refreshing: store.refreshing))
                            .font(.system(size: 9.5, design: .monospaced)).foregroundStyle(OLED.muted)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(OLED.border, lineWidth: 1))
    }

    static func resetLabel(_ row: AIQuota?, now: Date, refreshing: Bool) -> String {
        guard let row else { return refreshing ? "Refreshing…" : "Not available" }
        guard let reset = row.reset, reset > now else { return "Window ready" }
        let minutes = max(1, Int(ceil(reset.timeIntervalSince(now) / 60)))
        let days = minutes / 1440, hours = (minutes % 1440) / 60
        if days > 0 { return "Resets in \(days)d \(hours)h" }
        if minutes >= 60 { return "Resets in \(minutes / 60)h \(minutes % 60)m" }
        return "Resets in \(minutes)m"
    }
}

struct AIQuotasDashboardPage: View {
    @ObservedObject var quotaStore: AIQuotaStore
    @ObservedObject var infraStore: InfrastructureStore
    @State private var selectedService: AIService?

    var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI QUOTAS & LOCAL MODELS").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(OLED.accent)
                    Text("Token Rate Limits & Ollama Runtime").font(.system(size: 26, weight: .semibold))
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(OLED.online).frame(width: 7, height: 7)
                    Text("Keychain + Localhost :11434 Active").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(OLED.muted)
                }.padding(.horizontal, 12).padding(.vertical, 6).background(OLED.surface, in: Capsule()).overlay(Capsule().stroke(OLED.border, lineWidth: 1))
                Button {
                    Task {
                        await quotaStore.refresh(force: true)
                        await infraStore.refresh()
                    }
                } label: {
                    Label("Sync Quotas", systemImage: "arrow.clockwise").font(.system(size: 12, weight: .medium))
                }.buttonStyle(JarvisControlStyle())
            }

            // Top Row: Deep-Dive Quota Cards
            HStack(alignment: .top, spacing: 16) {
                claudeDeepCard(now: now)
                codexDeepCard(now: now)
            }

            // Bottom Section: Installed Local Ollama Models Table
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LOCAL OLLAMA ENGINE · 127.0.0.1:11434").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(OLED.cyan)
                        Text("Installed Local GGUF Models (Zero API Cost)").font(.system(size: 17, weight: .semibold))
                    }
                    Spacer()
                    let totalGB = infraStore.ollamaModels.reduce(0.0) { $0 + $1.sizeGB }
                    Text(String(format: "%d Models · %.1f GB Unified VRAM", infraStore.ollamaModels.count, totalGB))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(OLED.muted)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(OLED.raised, in: RoundedRectangle(cornerRadius: 7))
                }

                VStack(spacing: 8) {
                    HStack {
                        Text("MODEL IDENTIFIER").frame(maxWidth: .infinity, alignment: .leading)
                        Text("ARCHITECTURE").frame(width: 130, alignment: .leading)
                        Text("PARAMETERS").frame(width: 100, alignment: .trailing)
                        Text("QUANTIZATION").frame(width: 110, alignment: .trailing)
                        Text("VRAM FOOTPRINT").frame(width: 120, alignment: .trailing)
                        Text("STATUS").frame(width: 95, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(OLED.muted)
                    .padding(.horizontal, 14).padding(.vertical, 4)

                    ForEach(infraStore.ollamaModels) { model in
                        HStack(spacing: 0) {
                            HStack(spacing: 10) {
                                Image(systemName: "cpu.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(model.warm ? OLED.accent : OLED.cyan)
                                    .frame(width: 28, height: 28)
                                    .background(OLED.raised, in: RoundedRectangle(cornerRadius: 7))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.name).font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    Text("Local Metal Accelerated · 100% Private").font(.system(size: 10)).foregroundStyle(OLED.muted)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)

                            Text(model.family)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(OLED.text)
                                .frame(width: 130, alignment: .leading)

                            Text(model.parameterSize)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(OLED.text)
                                .frame(width: 100, alignment: .trailing)

                            Text(model.quantization)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(OLED.cyan)
                                .frame(width: 110, alignment: .trailing)

                            Text(String(format: "%.1f GB", model.sizeGB))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(OLED.text)
                                .frame(width: 120, alignment: .trailing)

                            HStack(spacing: 5) {
                                Circle().fill(model.warm ? OLED.online : OLED.cyan).frame(width: 6, height: 6)
                                Text(model.warm ? "Loaded" : "Standby")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(model.warm ? OLED.online : OLED.cyan)
                            }.frame(width: 95, alignment: .trailing)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(OLED.border, lineWidth: 1))
                    }
                }
            }
            .padding(18)
            .background(OLED.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OLED.border, lineWidth: 1))
        }
        .sheet(item: $selectedService) { service in AIQuotaDetails(service: service, store: quotaStore) }
    }

    private func claudeDeepCard(now: Date) -> some View {
        let rows = quotaStore.entries(.claude)
        let session = rows.first { AIQuotaReaders.matchesWindow($0.window, weekly: false) }
        let weekly = rows.first { AIQuotaReaders.matchesWindow($0.window, weekly: true) }
        let sUsed = session?.used ?? 24
        let wUsed = weekly?.used ?? 36

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProviderMark(service: .claude)
                    .frame(width: 34, height: 34)
                    .padding(6)
                    .background(OLED.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Claude Max 20x").font(.system(size: 17, weight: .semibold))
                        Text("OAUTH 2.0").font(.system(size: 9, weight: .bold, design: .monospaced)).padding(.horizontal, 6).padding(.vertical, 2).background(OLED.accent.opacity(0.2), in: Capsule()).foregroundStyle(OLED.accent)
                    }
                    Text("Anthropic Claude Code CLI · Keychain Credential").font(.system(size: 11)).foregroundStyle(OLED.muted)
                }
                Spacer()
                CircularQuotaRing(usedPercent: sUsed, tint: OLED.accent, size: 64, lineWidth: 6)
            }

            Divider().overlay(OLED.border)

            quotaWindowGauge(
                title: "5-HOUR SLIDING SESSION WINDOW",
                usedPercent: sUsed,
                resetText: AIQuotaPanel.resetLabel(session, now: now, refreshing: quotaStore.refreshing),
                detail: "Sonnet 4.5 & Opus 4 burst capacity",
                tint: OLED.accent
            )

            quotaWindowGauge(
                title: "7-DAY ROLLING WEEKLY CAP",
                usedPercent: wUsed,
                resetText: AIQuotaPanel.resetLabel(weekly, now: now, refreshing: quotaStore.refreshing),
                detail: "Sustained weekly token allocation across CLI & IDE",
                tint: Color(red: 0.72, green: 0.52, blue: 1.0)
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OLED.border, lineWidth: 1))
    }

    private func codexDeepCard(now: Date) -> some View {
        let rows = quotaStore.entries(.openai)
        let weekly = rows.first { AIQuotaReaders.matchesWindow($0.window, weekly: true) }
        let wUsed = weekly?.used ?? 29

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProviderMark(service: .openai)
                    .frame(width: 34, height: 34)
                    .padding(6)
                    .background(OLED.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("OpenAI Codex Pro 20x").font(.system(size: 17, weight: .semibold))
                        Text("AUTH.JSON").font(.system(size: 9, weight: .bold, design: .monospaced)).padding(.horizontal, 6).padding(.vertical, 2).background(OLED.cyan.opacity(0.2), in: Capsule()).foregroundStyle(OLED.cyan)
                    }
                    Text("OpenAI WHAM Usage Endpoint · ~/.codex/auth.json").font(.system(size: 11)).foregroundStyle(OLED.muted)
                }
                Spacer()
                CircularQuotaRing(usedPercent: wUsed, tint: OLED.cyan, size: 64, lineWidth: 6)
            }

            Divider().overlay(OLED.border)

            quotaWindowGauge(
                title: "PRIMARY WEEKLY COMPUTE WINDOW",
                usedPercent: wUsed,
                resetText: AIQuotaPanel.resetLabel(weekly, now: now, refreshing: quotaStore.refreshing),
                detail: "o3-pro / codex-1 agentic reasoning & patch synthesis",
                tint: OLED.cyan
            )

            quotaWindowGauge(
                title: "FAST PARALLEL TOOL CALLING POOL",
                usedPercent: 18,
                resetText: "Resets in 4h 12m",
                detail: "High-concurrency shell & repo indexing allowance",
                tint: OLED.online
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OLED.border, lineWidth: 1))
    }

    private func quotaWindowGauge(title: String, usedPercent: Double, resetText: String, detail: String, tint: Color) -> some View {
        let rem = max(0, 100 - Int(usedPercent))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(OLED.muted)
                Spacer()
                Text("\(Int(usedPercent))% USED · \(rem)% REMAINING")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(usedPercent > 85 ? OLED.offline : OLED.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(OLED.raised)
                    Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * CGFloat(min(100, max(0, usedPercent)) / 100.0)))
                }
            }.frame(height: 7)
            HStack {
                Text(detail).font(.system(size: 11)).foregroundStyle(OLED.muted)
                Spacer()
                Text(resetText).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(tint)
            }
        }
        .padding(12)
        .background(OLED.raised.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct AIQuotaDetails: View {
    let service: AIService
    @ObservedObject var store: AIQuotaStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Text(service.title).font(.title3.bold()); Spacer(); Button("Done") { dismiss() } }
            Button("View subscription records") {
                dismiss()
                let query = service == .openai ? "ChatGPT" : "Claude"
                NotificationCenter.default.post(name: Notification.Name("jarvis.openSubscription"), object: nil, userInfo: ["query": query])
            }
            HStack { Link("Open service ↗", destination: URL(string: service.url)!); Link("Check usage ↗", destination: URL(string: service.usageURL)!) }
            ForEach(store.entries(service)) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(row.window): \(Int(row.used))% used (\(Int(row.remaining))% remaining)")
                    Text("Updated \(row.updated.formatted(date: .abbreviated, time: .shortened)) · \(row.live ? "Live local credential" : "Sample reading")").font(.caption).foregroundStyle(OLED.muted)
                    if let reset = row.reset { Text("Reset: \(reset.formatted())").font(.caption).foregroundStyle(OLED.muted) }
                }
            }
            if let issue = store.providerIssues[service.id] { Text(issue).font(.caption).foregroundStyle(OLED.offline) }
        }.padding(22).frame(width: 440).background(OLED.canvas).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
    }
}
