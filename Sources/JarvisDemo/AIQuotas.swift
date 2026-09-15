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
    case openai, claude
    var id: String { rawValue }
    var title: String { switch self { case .openai: return "Codex Pro 20x"; case .claude: return "Claude Max x20" } }
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
    init() { readings = SampleData.quotas }
    func entries(_ service: AIService) -> [AIQuota] { readings.filter { $0.provider == service.id } }
    func refresh(force: Bool = false) async { readings = SampleData.quotas }
}


struct AIQuotaPanel: View {
    var referenceDate: Date? = nil
    @ObservedObject var store: AIQuotaStore
    @State private var selected: AIService?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quotas · CodexBar").font(.system(size: 16, weight: .medium))
                Spacer()
                Button { Task { await store.refresh(force: true) } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(JarvisPlainButtonStyle()).disabled(store.refreshing).accessibilityLabel("Refresh AI quotas")
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(AIService.allCases) { service in
                    if service != AIService.allCases.first { Rectangle().fill(OLED.border).frame(width: 1, height: 230).padding(.horizontal, 18) }
                    Button { selected = service } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { ProviderMark(service: service).frame(width: 27, height: 27); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(OLED.muted) }
                            Text(service.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            let rows = store.entries(service)
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                let displayDate = referenceDate ?? context.date
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(service == .openai ? ["Weekly"] : ["5h", "Weekly"], id: \.self) { window in
                                        let row = rows.first { item in
                                            AIQuotaReaders.matchesWindow(item.window, weekly: window == "Weekly")
                                        }
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                                Text(window).font(.system(size: 11)).foregroundStyle(OLED.muted)
                                                Spacer(minLength: 2)
                                                Text(row.flatMap { $0.usable(at: displayDate) ? String(Int($0.used)) : nil } ?? "—")
                                                    .font(.system(size: 27, weight: .regular, design: .rounded)).monospacedDigit()
                                                if let row, row.usable(at: displayDate) { Text("%").font(.system(size: 12)) }
                                            }.foregroundStyle((row?.used ?? 0) > 85 ? OLED.offline : OLED.text)
                                            Capsule().fill(OLED.raised).overlay {
                                                Capsule().fill((row?.used ?? 0) > 85 ? OLED.offline : OLED.text)
                                                    .scaleEffect(x: row.flatMap { $0.usable(at: displayDate) ? $0.used / 100 : nil } ?? 0, y: 1, anchor: .leading)
                                            }.frame(height: 4).accessibilityHidden(true)
                                            Text(Self.resetLabel(row, now: displayDate, refreshing: store.refreshing))
                                                .font(.system(size: 10)).foregroundStyle(OLED.muted).lineLimit(1)
                                            if let row, displayDate.timeIntervalSince(row.updated) > 600 {
                                                Text("Updated \(Int(displayDate.timeIntervalSince(row.updated) / 60)) min ago")
                                                    .font(.system(size: 9)).foregroundStyle(OLED.offline)
                                            }
                                        }.accessibilityElement(children: .combine)
                                    }
                                    Text(service == .openai ? "Codex · quota used" : "Claude · quota used").font(.system(size: 10)).foregroundStyle(OLED.muted)
                                    if store.providerIssues[service.id] != nil { Text("Provider unavailable").font(.system(size: 10)).foregroundStyle(OLED.offline) }
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("\(service.title) quota details")
                }
            }
            if let issue = store.issue { Text(issue).font(.caption).foregroundStyle(OLED.offline) }
        }.padding(18)
            .sheet(item: $selected) { service in AIQuotaDetails(service: service, store: store) }

    }
    // A quota reset needs minute precision, not a live per-second text subscription.
    private static func resetLabel(_ row: AIQuota?, now: Date, refreshing: Bool) -> String {
        guard let row else { return refreshing ? "Refreshing…" : "Not available" }
        guard let reset = row.reset, reset > now else { return "Refresh needed" }
        let minutes = max(1, Int(ceil(reset.timeIntervalSince(now) / 60)))
        let days = minutes / 1440, hours = (minutes % 1440) / 60
        if days > 0 { return "Resets in \(days)d \(hours)h" }
        if minutes >= 60 { return "Resets in \(minutes / 60)h \(minutes % 60)m" }
        return "Resets in \(minutes)m"
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
            if service == .openai {
                Text("Sample readings show the Codex quota interface. No account is connected in this demo.").font(.callout).foregroundStyle(OLED.muted)
                Button(store.refreshing ? "Refreshing…" : "Refresh Codex") { Task { await store.refresh(force: true) } }.disabled(store.refreshing)
            } else if service == .claude {
                Text("Sample readings show the Claude quota interface. The personal app uses CodexBar; this demo does not run the CLI or access accounts.").font(.callout).foregroundStyle(OLED.muted)
                Button(store.refreshing ? "Refreshing…" : "Refresh Claude") { Task { await store.refresh(force: true) } }.disabled(store.refreshing)
            }
            ForEach(store.entries(service)) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(row.window): \(Int(row.used))% used")
                    Text("Updated \(row.updated.formatted(date: .abbreviated, time: .shortened)) · \(row.live ? "Signed-in account" : "Sample reading")").font(.caption).foregroundStyle(OLED.muted)
                    if let reset = row.reset { Text("Reset: \(reset.formatted())").font(.caption).foregroundStyle(OLED.muted) }
                }
            }
            if let issue = store.providerIssues[service.id] { Text(issue).font(.caption).foregroundStyle(OLED.offline) }
        }.padding(22).frame(width: 440).background(OLED.canvas).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
    }
}
