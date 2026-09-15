import SwiftUI
import AppKit

struct DemoDashboard: View {
    var page = "Overview"
    var body: some View {
        JarvisHome(page: page).environmentObject(AppState.shared).environmentObject(InboxStore.shared).environmentObject(JarvisStore.shared).frame(width: 1180, height: 900)
    }
}
struct PortfolioApp: App {
    var body: some Scene {
        WindowGroup("Jarvis Demo") {
            DemoDashboard().onAppear { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
        }.windowStyle(.hiddenTitleBar).windowResizability(.contentSize)
            .commands { CommandMenu("Widget") {
                Button("Show floating widget") { DemoWidgetController.shared.show() }
                Button("Hide floating widget") { DemoWidgetController.shared.hide() }
            } }
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
                let renders: [(String, AnyView, NSSize)] = [
                    ("overview", AnyView(DemoDashboard()), NSSize(width: 1180, height: 900)),
                    ("shortcuts", AnyView(DemoDashboard(page: "Shortcuts")), NSSize(width: 1180, height: 900)),
                    ("assistant", AnyView(DemoDashboard(page: "Assistant")), NSSize(width: 1180, height: 900)),
                    ("floating-widget", AnyView(DemoFloatingBar()), NSSize(width: 590, height: 58)),
                    ("widget-details", AnyView(AIQuotaPanel(store: AIQuotaStore.shared).background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)), NSSize(width: 480, height: 340)),
                    ("subscriptions", AnyView(DemoDashboard(page: "Subscriptions")), NSSize(width: 1180, height: 900)),
                    ("cats", AnyView(DemoDashboard(page: "Cats")), NSSize(width: 1180, height: 900)),
                    ("projects", AnyView(DemoDashboard(page: "Projects")), NSSize(width: 1180, height: 900)),
                    ("youtube", AnyView(DemoDashboard(page: "YouTube")), NSSize(width: 1180, height: 900)),
                    ("revenue", AnyView(DemoDashboard(page: "Revenue")), NSSize(width: 1180, height: 900))
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
