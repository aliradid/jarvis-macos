import SwiftUI
import AppKit
struct InboxPanel: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var inbox: InboxStore
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Messages").font(.title2.bold())
                Spacer()
                Button("Mark all read") { inbox.markRead() }.disabled(inbox.unread == 0)
                Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("Close messages")
            }
            HStack(spacing: 6) {
                Circle().fill(inbox.issue == nil ? OLED.online : OLED.offline).frame(width: 6, height: 6)
                Text(inbox.connectionSummary).font(.caption).foregroundStyle(OLED.muted)
                Spacer()
                Button { Task { await inbox.refresh() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh messages")
            }
            HStack {
                Toggle("Launchpad desktop alerts", isOn: Binding(get: { inbox.desktopAlertsEnabled }, set: { inbox.setDesktopAlerts($0) })).font(.callout)
                Spacer()
                Button("Test alert") { inbox.testDesktopAlert() }
            }
            Text("These are Launchpad’s own banners. Native Notification Center alerts are unavailable in this locally signed build.").font(.caption2).foregroundStyle(OLED.muted)
            if !inbox.notificationStatus.isEmpty { Text(inbox.notificationStatus).font(.caption).foregroundStyle(OLED.offline) }
            if let issue = inbox.issue { Text(issue).font(.caption).foregroundStyle(OLED.offline).textSelection(.enabled) }
            Divider()
            ScrollView {
                if inbox.archive.unreadMessages.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bell.badge").font(.system(size: 28)).foregroundStyle(OLED.accent)
                        Text("You’re all caught up").font(.headline)
                        Text("New finished videos, subscription reminders, pipeline failures and requests for review will appear here.").multilineTextAlignment(.center).foregroundStyle(OLED.muted)
                    }.frame(maxWidth: .infinity).padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(inbox.archive.unreadMessages) { message in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Circle().fill(message.read ? .clear : OLED.accent).frame(width: 6, height: 6)
                                    Text(message.source).font(.caption.weight(.semibold)).foregroundStyle(OLED.muted)
                                    Spacer()
                                    Text(message.date, style: .relative).font(.caption2).foregroundStyle(OLED.muted)
                                }
                                Label(message.title, systemImage: message.kind == "ready" ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.headline).foregroundStyle(message.kind == "ready" ? OLED.online : OLED.offline)
                                Text(message.detail).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                HStack {
                                    Button(message.kind == "subscription" ? "Open subscription" : message.kind == "ready" ? "Open video" : "Open project folder") { inbox.open(message) }
                                    Spacer()
                                    if !message.read { Button("Mark read") { inbox.markRead(message.id) } }
                                }.font(.caption)
                            }.padding(12).background(OLED.surface, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(OLED.border, lineWidth: 1))
                        }
                    }
                }
            }.frame(height: 340)
            Text("Read messages leave this list. Launchpad keeps watching while hidden; new updates appear here.")
                .font(.caption2).foregroundStyle(OLED.muted)
        }.padding(18).frame(width: 420).background(OLED.canvas).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
    }
}

@MainActor
final class DesktopAlerts {
    private var panels: [NSPanel] = []

    func show(_ message: InboxMessage, open: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }
        if panels.count >= 3 { dismiss(panels[0]) }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 150),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.identifier = NSUserInterfaceItemIdentifier(message.id)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: DesktopAlertView(message: message, open: { [weak self, weak panel] in
            open()
            if let panel { self?.dismiss(panel) }
        }, close: { [weak self, weak panel] in
            if let panel { self?.dismiss(panel) }
        }))
        let area = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: area.minX + 20, y: area.maxY - 170 - CGFloat(panels.count * 164)))
        panels.append(panel)
        panel.orderFrontRegardless()
        Task { [weak self, weak panel] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            if let panel { self?.dismiss(panel) }
        }
    }

    func dismiss(messageID: String) {
        for panel in panels.filter({ $0.identifier?.rawValue == messageID }) { dismiss(panel) }
    }
    func dismissAll() { for panel in panels { panel.close() }; panels.removeAll() }
    private func dismiss(_ panel: NSPanel) { panel.close(); panels.removeAll { $0 === panel } }
}

private struct DesktopAlertView: View {
    let message: InboxMessage
    let open: () -> Void
    let close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Launchpad · \(message.source)", systemImage: "bell.fill").font(.caption).foregroundStyle(OLED.accent)
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("Dismiss alert")
            }
            Text(message.title).font(.headline)
            Text(message.detail).font(.callout).foregroundStyle(OLED.muted).lineLimit(2)
            Button(message.kind == "test" ? "Dismiss test" : message.kind == "subscription" ? "Open subscription" : message.kind == "ready" ? "Open video" : "Open project folder", action: open)
                .buttonStyle(JarvisPlainButtonStyle()).foregroundStyle(OLED.accent).font(.callout.weight(.semibold))
        }.padding(16).frame(width: 360, height: 150, alignment: .topLeading)
            .background(OLED.canvas, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(OLED.border, lineWidth: 1))
            .foregroundStyle(OLED.text).preferredColorScheme(.dark)
    }
}
