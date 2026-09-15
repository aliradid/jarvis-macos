import SwiftUI
import AppKit
struct DemoFloatingBar: View {
    var hide: () -> Void = {}
    var open: () -> Void = {}
    var body: some View { HStack(spacing: 5) {
                WidgetDragHandle().frame(width: 16, height: 44).help("Drag to move widget")
                WorkspaceStatusStrip(quotas: AIQuotaStore.shared, infrastructure: InfrastructureStore.shared)
                FloatingChannelAccess(state: AppState.shared)
                VStack(spacing: 2) {
                    Button { hide() } label: { Image(systemName: "xmark").frame(width: 24, height: 22).contentShape(Rectangle()) }.accessibilityLabel("Hide floating widget").help("Hide widget; restore from the Widget menu")
                    Button { open() } label: { Image(systemName: "arrow.up.right").frame(width: 24, height: 22).contentShape(Rectangle()) }.accessibilityLabel("Open Jarvis").help("Open Jarvis")
                }.font(.system(size: 11)).buttonStyle(JarvisPlainButtonStyle())
            }.padding(7).background(OLED.canvas, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15))).foregroundStyle(OLED.text).preferredColorScheme(.dark)
    }
}
private struct WidgetDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Handle() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private final class Handle: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.gray.setFill()
            for x in [5.0, 10.0] { for y in [16.0, 22.0, 28.0] { NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 2, height: 2)).fill() } }
        }
    }
}

private struct FloatingChannelAccess: View {
    @ObservedObject var state: AppState
    @State private var presented = false
    @State private var failure: String?
    private var channels: [Tile] {
        state.browserTiles.filter { tile in
            guard let entry = state.linkEntry(for: tile), let port = URL(string: entry.url)?.port else { return true }
            return !MissionSource.installed.contains { $0.port == port }
        }
    }
    var body: some View {
        Button { failure = nil; presented.toggle() } label: {
            Image(systemName: "square.grid.2x2").font(.system(size: 15)).frame(width: 36, height: 40).contentShape(Rectangle())
        }.buttonStyle(JarvisPlainButtonStyle()).background(OLED.surface, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Channel quick access").help("Open your channels")
            .popover(isPresented: $presented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Your channels").font(.system(size: 15, weight: .semibold)); Spacer(); Button { presented = false } label: { Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle()) }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("Close channel shortcuts") }
                    if channels.isEmpty { Text("Add browser shortcuts in Jarvis to see them here.").font(.callout).foregroundStyle(OLED.muted) }
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(channels) { tile in
                                Button {
                                    failure = nil
                                    Task {
                                        do { try await state.performJarvisAction(tile, startOnly: false); presented = false }
                                        catch { failure = error.localizedDescription }
                                    }
                                } label: {
                                    VStack(spacing: 8) { TileIcon(tile: tile, size: 30); Text(tile.label).font(.system(size: 12, weight: .medium)).lineLimit(2) }
                                        .frame(maxWidth: .infinity).frame(height: 78).background(OLED.surface, in: RoundedRectangle(cornerRadius: 9)).contentShape(Rectangle())
                                }.buttonStyle(JarvisPlainButtonStyle()).disabled(state.launching.contains(tile.id)).accessibilityLabel("Open " + tile.label)
                            }
                        }
                    }.frame(height: min(290, CGFloat((channels.count + 2) / 3) * 86))
                    if let failure { Text(failure).font(.caption).foregroundStyle(OLED.offline).fixedSize(horizontal: false, vertical: true) }
                }.padding(14).frame(width: 330).background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)
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
