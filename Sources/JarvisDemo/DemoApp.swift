import SwiftUI
import AppKit

struct DemoDashboard: View {
    var page = "Overview"
    var body: some View {
        JarvisHome(page: page)
            .environmentObject(AppState.shared)
            .environmentObject(InboxStore.shared)
            .environmentObject(JarvisStore.shared)
            .frame(width: 1180, height: 900)
    }
}

struct PortfolioApp: App {
    var body: some Scene {
        WindowGroup(AppMode.isDemo ? "Jarvis Demo" : "Jarvis") {
            DemoDashboard().onAppear {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                DemoWidgetController.shared.setupMenuBar()
                if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
                   let icon = NSImage(contentsOf: iconURL) {
                    NSApp.applicationIconImage = icon
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Widget") {
                Button("Toggle floating widget") { DemoWidgetController.shared.toggleWidget() }
                    .keyboardShortcut("j", modifiers: [.command, .option])
                Button("Show floating widget") { DemoWidgetController.shared.show() }
                    .keyboardShortcut("w", modifiers: [.command, .option])
                Button("Hide floating widget") { DemoWidgetController.shared.hide() }
            }
        }
    }
}

@main
struct DemoEntry {
    static func withoutPNGMetadata(_ data: Data) throws -> Data {
        guard data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else {
            throw LaunchpadError(message: "Invalid rendered PNG.")
        }
        var output = Data(data.prefix(8))
        var offset = 8
        while offset + 12 <= data.count {
            let length = data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
            let end = offset + length + 12
            guard end <= data.count else { throw LaunchpadError(message: "Incomplete rendered PNG.") }
            let kind = String(decoding: data[(offset + 4)..<(offset + 8)], as: UTF8.self)
            if ["IHDR", "IDAT", "IEND", "sRGB"].contains(kind) { output.append(data[offset..<end]) }
            offset = end
        }
        return output
    }

    @MainActor static func main() {
        if CommandLine.arguments == [CommandLine.arguments[0], "--check"] {
            do { try DemoChecks.run() } catch { fputs("Check failed: \(error.localizedDescription)\n", stderr); exit(1) }
        } else if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--render" {
            let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                JarvisStore.shared.history.turns = [
                    JarvisTurn(
                        role: "user",
                        text: "Audit my AI token quotas, active localhost ports, and local Ollama models before I kick off the multi-repo refactor."
                    ),
                    JarvisTurn(
                        role: "assistant",
                        text: "All systems are green on your M3 Max (18.6 / 36 GB RAM used, 14-core load 1.42):\n\n• Claude Code Max 20x: 76% remaining in your 5h sliding window (resets in 3h 18m) and 64% remaining on your 7-day rolling cap.\n• OpenAI Codex Pro 20x: 71% weekly compute remaining (resets in 4d).\n• Local Ollama (:11434): Online (1ms ping) with llama3.2:latest and deepseek-r1:14b warm in Metal unified memory.\n• Dev Ports: Next.js (:3000), Vite (:5173), FastAPI (:8000), and PostgreSQL (:5432) are listening.",
                        actions: [
                            JarvisAction(kind: "open", targetID: "dev:cursor", label: "Open Cursor AI IDE"),
                            JarvisAction(kind: "open", targetID: "link:nextjs", label: "Launch Next.js (:3000)"),
                            JarvisAction(kind: "open", targetID: "dev:github", label: "Review GitHub PRs")
                        ]
                    ),
                    JarvisTurn(
                        role: "user",
                        text: "Switch local inference to deepseek-r1:14b for offline test generation so we preserve the Claude 5h burst window."
                    ),
                    JarvisTurn(
                        role: "assistant",
                        text: "Routed local code generation and test synthesis to deepseek-r1:14b (Q4_K_M · 9.0 GB VRAM · 48 tok/s). Zero external API tokens will be consumed.",
                        actions: [
                            JarvisAction(kind: "open", targetID: "dev:terminal", label: "Open Ghostty / iTerm")
                        ]
                    )
                ]
                let renders: [(String, AnyView, NSSize)] = [
                    ("overview", AnyView(DemoDashboard(page: "Overview")), NSSize(width: 1180, height: 900)),
                    ("assistant", AnyView(DemoDashboard(page: "Assistant")), NSSize(width: 1180, height: 900)),
                    ("projects", AnyView(DemoDashboard(page: "Projects")), NSSize(width: 1180, height: 900)),
                    ("shortcuts", AnyView(DemoDashboard(page: "Shortcuts")), NSSize(width: 1180, height: 900)),
                    ("subscriptions", AnyView(DemoDashboard(page: "Subscriptions")), NSSize(width: 1180, height: 900)),
                    ("floating-widget", AnyView(DemoFloatingBar()), NSSize(width: 680, height: 58)),
                    ("widget-details", AnyView(AIQuotaPanel(store: AIQuotaStore.shared).background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)), NSSize(width: 540, height: 340)),
                    ("cats", AnyView(DemoDashboard(page: "Quotas")), NSSize(width: 1180, height: 900)),
                    ("youtube", AnyView(DemoDashboard(page: "Projects")), NSSize(width: 1180, height: 900)),
                    ("revenue", AnyView(InfrastructurePanel(store: InfrastructureStore.shared).background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)), NSSize(width: 640, height: 490))
                ]
                for (page, content, size) in renders {
                    _ = NSApplication.shared
                    let view = NSHostingView(rootView: content)
                    view.sizingOptions = []
                    view.frame = NSRect(origin: .zero, size: size)
                    let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                    window.appearance = NSAppearance(named: .darkAqua)
                    window.contentView = view
                    window.setContentSize(size)
                    window.setFrameOrigin(.zero)
                    view.layoutSubtreeIfNeeded()
                    window.displayIfNeeded()
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                        throw LaunchpadError(message: "Could not allocate a render for \(page).")
                    }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let data = bitmap.representation(using: .png, properties: [:]) else {
                        throw LaunchpadError(message: "Could not encode \(page).")
                    }
                    try withoutPNGMetadata(data).write(to: output.appendingPathComponent(page.lowercased() + ".png"))
                    window.contentView = nil
                }
                print("Rendered the workspace and floating-widget demo screens.")
            } catch { fputs("Render failed: \(error.localizedDescription)\n", stderr); exit(1) }
        } else { PortfolioApp.main() }
    }
}
