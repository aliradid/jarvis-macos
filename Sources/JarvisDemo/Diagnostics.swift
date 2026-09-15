import SwiftUI
import AppKit

struct DiagnosticEvent: Identifiable, Equatable, Sendable {
    var id: String
    var date: Date
    var source: String
    var message: String
    var failed: Bool
}

enum DiagnosticReason: String, Sendable {
    case success = "Check completed"
    case timeout = "Check timed out. The previous reading was retained."
    case authentication = "Sign-in is unavailable. Check the provider’s signed-in app."
    case unavailable = "Provider is unavailable. Check its app or connection."
    case invalidResponse = "Provider returned an unreadable or unsupported response."
    case storage = "The reading could not be saved. Check local storage."
    case offline = "Connection check failed. Check the service or tunnel."
    static func classify(_ error: Error) -> Self {
        // Classify known failures without recording raw errors, paths or payloads.
        let text = error.localizedDescription.lowercased()
        if text.contains("timed out") || text.contains("timeout") { return .timeout }
        if text.contains("sign-in") || text.contains("sign in") || text.contains("credential") { return .authentication }
        if text.contains("response") || (error as NSError).domain == NSCocoaErrorDomain { return .invalidResponse }
        return .unavailable
    }
}

actor DiagnosticJournal {
    static let shared = DiagnosticJournal()
    func events() async throws -> [DiagnosticEvent] { [DiagnosticEvent(id: "sample-check", date: Date(), source: "Demo", message: "Sample diagnostic record", failed: false)] }
}

struct DiagnosticsContent: View {
    let events: [DiagnosticEvent]
    let issue: String?
    @Binding var failuresOnly: Bool
    var visible: [DiagnosticEvent] { failuresOnly ? events.filter(\.failed) : events }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent checks").font(.title2.weight(.semibold))
            Text("Local results and timings. No passwords, tokens or response bodies are recorded.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle("Failures only", isOn: $failuresOnly).toggleStyle(.checkbox)
            if let issue { Text(issue).foregroundStyle(.orange).font(.callout) }
            if visible.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: failuresOnly ? "checkmark.circle" : "clock").font(.largeTitle)
                    Text(failuresOnly ? "No failures in these records" : "No checks recorded yet")
                    Text("Refresh a quota or connection check, then reload this panel.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visible) { event in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: event.failed ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                        .foregroundStyle(event.failed ? Color.orange : Color.green)
                                    Text(event.source).fontWeight(.medium)
                                    Spacer()
                                    Text(event.date, format: .dateTime.month(.abbreviated).day().hour().minute().second())
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Text(event.message).font(.callout).textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
            }
        }.padding(20).background(Color.black).foregroundStyle(.white).preferredColorScheme(.dark)
    }
}

struct DiagnosticsPanel: View {
    @Environment(\.dismiss) private var dismiss
    @State private var events: [DiagnosticEvent] = []
    @State private var issue: String?
    @State private var failuresOnly = false
    @State private var loading = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Diagnostics").font(.headline)
                Spacer()
                Button("Reload") { Task { await reload() } }.disabled(loading)
                Button("Copy report") {
                    let report = events.map { "\($0.date.ISO8601Format()) | \($0.source) | \($0.message)" }.joined(separator: "\n")
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(report, forType: .string)
                }.disabled(events.isEmpty)
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(16)
            Divider()
            DiagnosticsContent(events: events, issue: issue, failuresOnly: $failuresOnly)
        }.frame(width: 700, height: 510).background(Color.black).preferredColorScheme(.dark)
        .task { await reload() }
    }
    private func reload() async {
        guard !loading else { return }; loading = true
        defer { loading = false }
        do { events = try await DiagnosticJournal.shared.events(); issue = nil }
        catch { issue = "The diagnostic history could not be opened. Your existing records were preserved." }
    }
}
