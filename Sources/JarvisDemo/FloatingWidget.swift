import SwiftUI
import AppKit

struct DemoFloatingBar: View {
    var hide: () -> Void = {}
    var open: () -> Void = {}
    var body: some View {
        HStack(spacing: 5) {
            WidgetDragHandle().frame(width: 16, height: 44).help("Drag to move widget")
            WorkspaceStatusStrip(quotas: AIQuotaStore.shared, infrastructure: InfrastructureStore.shared)
            FloatingQuickLaunch(state: AppState.shared, infra: InfrastructureStore.shared)
            VStack(spacing: 2) {
                Button { hide() } label: { Image(systemName: "xmark").frame(width: 24, height: 22).contentShape(Rectangle()) }.accessibilityLabel("Hide floating widget").help("Hide widget; restore from the Widget menu")
                Button { open() } label: { Image(systemName: "arrow.up.right").frame(width: 24, height: 22).contentShape(Rectangle()) }.accessibilityLabel("Open Jarvis").help("Open Jarvis")
            }.font(.system(size: 11)).buttonStyle(JarvisPlainButtonStyle())
        }
        .padding(7)
        .background(OLED.canvas, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15)))
        .foregroundStyle(OLED.text)
        .preferredColorScheme(.dark)
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

private struct FloatingQuickLaunch: View {
    @ObservedObject var state: AppState
    @ObservedObject var infra: InfrastructureStore
    @State private var presented = false
    @State private var failure: String?

    private var launchers: [Tile] {
        Array((state.browserTiles + state.fileTiles).prefix(9))
    }

    var body: some View {
        Button { failure = nil; presented.toggle() } label: {
            Image(systemName: "command.square.fill").font(.system(size: 15)).frame(width: 36, height: 40).contentShape(Rectangle())
        }
        .buttonStyle(JarvisPlainButtonStyle())
        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(OLED.border, lineWidth: 1))
        .accessibilityLabel("Quick launchers & ports").help("Open developer launchers & active localhost ports")
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("QUICK LAUNCH & PORTS").font(.system(size: 9.5, weight: .bold, design: .monospaced)).kerning(1.2).foregroundStyle(OLED.accent)
                        Text("Developer Consoles & Localhost").font(.system(size: 14, weight: .semibold))
                    }
                    Spacer()
                    Button { presented = false } label: { Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle()) }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("Close quick launch")
                }

                let activePorts = infra.devPorts.filter(\.online)
                if !activePorts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(activePorts) { port in
                                Button {
                                    if let url = URL(string: "http://127.0.0.1:\(port.port)") { NSWorkspace.shared.open(url); presented = false }
                                } label: {
                                    HStack(spacing: 5) {
                                        Circle().fill(OLED.online).frame(width: 5.5, height: 5.5)
                                        Text(":\(port.port)").font(.system(size: 11, weight: .bold, design: .monospaced))
                                        Text(port.name).font(.system(size: 10.5)).foregroundStyle(OLED.muted).lineLimit(1)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .background(OLED.surface, in: Capsule())
                                    .overlay(Capsule().stroke(OLED.border, lineWidth: 1))
                                }.buttonStyle(JarvisPlainButtonStyle())
                            }
                        }
                    }
                }

                if launchers.isEmpty {
                    Text("Add developer shortcuts in Jarvis to launch them here.").font(.callout).foregroundStyle(OLED.muted)
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(launchers) { tile in
                                Button {
                                    failure = nil
                                    Task {
                                        do { try await state.performJarvisAction(tile, startOnly: false); presented = false }
                                        catch { failure = error.localizedDescription }
                                    }
                                } label: {
                                    VStack(spacing: 7) {
                                        TileIcon(tile: tile, size: 28)
                                        Text(tile.label).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 74)
                                    .background(OLED.surface, in: RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(OLED.border, lineWidth: 1))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(JarvisPlainButtonStyle())
                                .disabled(state.launching.contains(tile.id))
                                .accessibilityLabel("Open " + tile.label)
                            }
                        }
                    }.frame(height: min(260, CGFloat((launchers.count + 2) / 3) * 82))
                }
                if let failure { Text(failure).font(.caption).foregroundStyle(OLED.offline).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(14).frame(width: 350).background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)
        }
    }
}

@MainActor final class DemoWidgetController {
    static let shared = DemoWidgetController()
    private var panel: NSPanel?
    private var mainWindow: NSWindow?
    private var statusItem: NSStatusItem?

    func setupMenuBar() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let img = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Jarvis")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "Jarvis · AI & Developer Command Center (⌥⌘J)"
            button.action = #selector(MenuBarTarget.menuBarClicked)
            button.target = MenuBarTarget.shared
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func statusItemButton() -> NSStatusBarButton? { statusItem?.button }

    func toggleWidget() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        if mainWindow == nil { mainWindow = NSApp.windows.first(where: { $0 is NSPanel == false && $0.canBecomeKey }) }
        if panel == nil {
            let host = NSHostingView(rootView: DemoFloatingBar(hide: { self.hide() }, open: { self.openMainWindow() }))
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let size = host.fittingSize
            let window = NSPanel(contentRect: NSRect(x: screen.minX + 24, y: screen.maxY - size.height - 90, width: size.width, height: size.height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = AppMode.isDemo ? "Jarvis Demo · Floating HUD" : "Jarvis · Floating HUD"
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

@MainActor private final class MenuBarTarget: NSObject, NSMenuDelegate {
    static let shared = MenuBarTarget()
    @objc func menuBarClicked() {
        guard let event = NSApp.currentEvent else {
            DemoWidgetController.shared.toggleWidget()
            return
        }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            let tele = InfrastructureStore.shared.telemetry
            let memText = String(format: "%.1f / %.0f GB", tele.memoryUsedGB, tele.memoryTotalGB)
            let headerItem = NSMenuItem(title: "Jarvis · \(tele.chipName) (\(memText))", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            for quota in AIQuotaStore.shared.readings {
                let qItem = NSMenuItem(title: "\(quota.provider.capitalized) \(quota.window): \(Int(quota.remaining))% remaining", action: nil, keyEquivalent: "")
                qItem.isEnabled = false
                menu.addItem(qItem)
            }
            menu.addItem(NSMenuItem.separator())

            menu.addItem(NSMenuItem(title: "Toggle Floating HUD", action: #selector(toggleHUD), keyEquivalent: "j"))
            menu.items.last?.keyEquivalentModifierMask = [.command, .option]
            menu.items.last?.target = self

            menu.addItem(NSMenuItem(title: "Open Jarvis Command Center", action: #selector(openMain), keyEquivalent: "o"))
            menu.items.last?.target = self

            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Jarvis", action: #selector(quitApp), keyEquivalent: "q"))
            menu.items.last?.target = self

            if let button = DemoWidgetController.shared.statusItemButton() {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
            }
        } else {
            DemoWidgetController.shared.toggleWidget()
        }
    }
    @objc private func toggleHUD() { DemoWidgetController.shared.toggleWidget() }
    @objc private func openMain() { DemoWidgetController.shared.openMainWindow() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
