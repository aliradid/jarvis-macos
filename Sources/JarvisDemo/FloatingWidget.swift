import SwiftUI
import AppKit

// Same compact composition as the personal app; all readings here are fixtures.
struct DemoStatusStrip: View {
    @State private var quotas = false
    @State private var systems = false
    var body: some View {
        HStack(spacing: 6) {
            Button { quotas.toggle() } label: {
                HStack(spacing: 12) {
                    provider("Codex Pro 20x", brand: "openai", values: "Weekly: 42% · 4d left")
                    provider("Claude Max x20", brand: "anthropic", values: "5h: 18% · 2h left  Weekly: 31% · 5d left")
                }.padding(.horizontal, 9).frame(height: 40).contentShape(Rectangle())
            }.buttonStyle(.plain).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Quota details").help("Session and weekly usage details")
                .popover(isPresented: $quotas, arrowEdge: .bottom) { DemoQuotaDetails() }
            Button { systems.toggle() } label: {
                VStack(alignment: .leading, spacing: 4) {
                    health("desktopcomputer", "2/2")
                    health("network", "3/3")
                }.font(.system(size: 10)).padding(.horizontal, 9).frame(height: 40).contentShape(Rectangle())
            }.buttonStyle(.plain).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("System status").popover(isPresented: $systems, arrowEdge: .bottom) { DemoSystemDetails() }
        }.fixedSize().foregroundStyle(.white).preferredColorScheme(.dark)
    }
    private func provider(_ title: String, brand: String, values: String) -> some View {
        HStack(spacing: 6) {
            BrandIcon(name: brand).frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .medium))
                Text(values).font(.system(size: 10)).monospacedDigit().foregroundStyle(Color(white: 0.66))
            }
        }
    }
    private func health(_ symbol: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).frame(width: 13)
            Text(value).monospacedDigit()
            Circle().fill(Palette.online).frame(width: 4, height: 4)
        }
    }
}

struct DemoQuotaDetails: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("AI usage").font(.headline); Spacer(); Text("SAMPLE DATA").font(.system(size: 9)).foregroundStyle(Palette.accent) }
            row("Codex Pro 20x", window: "Weekly", used: 42, reset: "Resets in 4 days")
            Divider()
            row("Claude Max x20", window: "5-hour session", used: 18, reset: "Resets in 2 hours")
            row("Claude Max x20", window: "Weekly", used: 31, reset: "Resets in 5 days")
            Text("These are fixed demo readings. No accounts are connected.").font(.caption).foregroundStyle(Palette.muted)
        }.padding(22).frame(width: 430).background(Palette.background).foregroundStyle(.white).preferredColorScheme(.dark)
    }
    private func row(_ name: String, window: String, used: Int, reset: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(name).font(.system(size: 12, weight: .medium)); Spacer(); Text("\(used)% used").font(.system(size: 12)).monospacedDigit() }
            ProgressView(value: Double(used), total: 100).tint(Palette.accent)
            HStack { Text(window); Spacer(); Text(reset) }.font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
    }
}

struct DemoSystemDetails: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Machines & connections").font(.headline)
            ForEach(["Desktop", "Development machine", "Local service", "Preview connection", "Demo connection"], id: \.self) { name in
                HStack { Text(name); Spacer(); Circle().fill(Palette.online).frame(width: 6, height: 6); Text("Ready").foregroundStyle(Palette.muted) }.font(.system(size: 12))
            }
            Text("Fictional status · No infrastructure checks run").font(.caption).foregroundStyle(Palette.muted)
        }.padding(22).frame(width: 330).background(Palette.background).foregroundStyle(.white).preferredColorScheme(.dark)
    }
}

struct DemoQuickAccess: View {
    @State private var presented = false
    @State private var selected: String?
    var body: some View {
        Button { presented.toggle() } label: {
            Image(systemName: "square.grid.2x2").font(.system(size: 15)).frame(width: 36, height: 40).contentShape(Rectangle())
        }.buttonStyle(.plain).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Channel quick access")
            .popover(isPresented: $presented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your channels").font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                        ForEach(["Studio EN", "Studio FR", "Studio ES", "Studio JP", "Studio IT", "Design"], id: \.self) { title in
                            Button { selected = title } label: {
                                VStack(spacing: 8) { BrandIcon(name: title == "Design" ? "photoshop" : "youtube").frame(width: 28, height: 28); Text(title).font(.system(size: 11)) }
                                    .frame(maxWidth: .infinity).frame(height: 70).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                        }
                    }
                    Text(selected.map { "Preview: \($0). No browser is opened." } ?? "Sample shortcuts · Select to preview").font(.caption).foregroundStyle(Palette.muted)
                }.padding(18).frame(width: 330).background(Palette.background).foregroundStyle(.white).preferredColorScheme(.dark)
            }
    }
}

struct DemoFloatingBar: View {
    var hide: () -> Void = {}
    var open: () -> Void = {}
    var body: some View {
        HStack(spacing: 5) {
            DemoDragHandle().frame(width: 16, height: 44).help("Drag to move widget")
            DemoStatusStrip()
            DemoQuickAccess()
            VStack(spacing: 2) {
                Button(action: hide) { Image(systemName: "xmark").frame(width: 24, height: 22).contentShape(Rectangle()) }.accessibilityLabel("Hide floating widget")
                Button(action: open) { Image(systemName: "arrow.up.right").frame(width: 24, height: 22).contentShape(Rectangle()) }.accessibilityLabel("Open Jarvis")
            }.font(.system(size: 11)).buttonStyle(.plain)
        }.padding(7).background(Palette.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15)))
            .foregroundStyle(.white).preferredColorScheme(.dark).fixedSize()
    }
}

private struct DemoDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Handle() }
    func updateNSView(_ view: NSView, context: Context) {}
    private final class Handle: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.gray.setFill()
            for x in [5.0, 10.0] { for y in [16.0, 22.0, 28.0] { NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2, height: 2)).fill() } }
        }
    }
}

@MainActor final class DemoWidgetController {
    static let shared = DemoWidgetController()
    private var panel: NSPanel?
    private var mainWindow: NSWindow?
    func show() {
        if mainWindow == nil { mainWindow = NSApp.windows.first(where: { $0 is NSPanel == false && $0.canBecomeKey }) }
        if panel == nil {
            let host = NSHostingView(rootView: DemoFloatingBar(hide: { self.hide() }, open: { self.openMainWindow() }))
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let size = host.fittingSize
            let window = NSPanel(contentRect: NSRect(x: screen.minX + 24, y: screen.maxY - size.height - 90, width: size.width, height: size.height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = "Jarvis Demo · Floating widget"
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.contentView = host
            panel = window
        }
        panel?.orderFrontRegardless()
    }
    func hide() { panel?.orderOut(nil) }
    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.deminiaturize(nil)
        mainWindow?.makeKeyAndOrderFront(nil)
    }
}
