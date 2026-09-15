import SwiftUI
import AppKit

struct DemoDashboard: View {
    @State var page = "Overview"
    @State private var query = ""
    @State private var config = DemoFixtures.config
    @State private var selectedID: String?
    @State private var alias = ""
    @State private var message = ""
    @State private var draft = ""
    @State private var tasks = ["Review the home layout"]
    @State private var done = Set<String>()
    @State private var pins: [String] = []
    @State private var input = "واش المشروع واجد؟"
    private let pages = [("Overview", "square.grid.2x2"), ("Assistant", "bubble.left.and.bubble.right"), ("Projects", "square.stack.3d.up"), ("Shortcuts", "command"), ("Subscriptions", "creditcard"), ("Cats", "pawprint.fill"), ("YouTube", "play.rectangle"), ("Revenue", "dollarsign.circle")]
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                JarvisAvatar().frame(width: 44, height: 44).padding(.top, 12)
                ForEach(pages, id: \.0) { item in
                    Button { page = item.0 } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.1).font(.system(size: 19, weight: .light))
                            Text(item.0 == "Overview" ? "Home" : item.0).font(.system(size: 8, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                        }.frame(width: 54, height: 54)
                            .background(page == item.0 ? Palette.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(page == item.0 ? Palette.accent : Palette.muted)
                    }.buttonStyle(.plain).accessibilityLabel(item.0)
                }
                Spacer()
                Text("DEMO").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(Palette.muted)
                Image(systemName: "moon.fill").foregroundStyle(Palette.accent).padding(.bottom, 16)
            }.frame(width: 76)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(page).font(.system(size: 14, weight: .medium))
                    DemoStatusStrip()
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                        TextField("Search your workspace", text: $query).textFieldStyle(.plain)
                            .onChange(of: query) { _ in if !query.isEmpty { page = "Shortcuts" } }
                    }.font(.system(size: 12)).padding(10).frame(width: 180).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                    Button { DemoWidgetController.shared.show() } label: { Image(systemName: "pip").frame(width: 24, height: 24) }.buttonStyle(.plain).help("Show floating widget").accessibilityLabel("Show floating widget")
                    Image(systemName: "bell").foregroundStyle(Palette.muted)
                }.padding(.horizontal, 20).padding(.vertical, 11)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if page == "Overview" { overview }
                        else if page == "Shortcuts" { shortcuts }
                        else if page == "Assistant" { assistant }
                        else if page == "Subscriptions" { DemoSpendingPage() }
                        else if page == "Cats" { DemoSpendingPage(pets: true) }
                        else if page == "YouTube" { DemoAnalyticsPage() }
                        else if page == "Revenue" { DemoAnalyticsPage(revenue: true) }
                        else { samplePage }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                }
                if !message.isEmpty {
                    HStack { Text(message).font(.system(size: 11)); Spacer(); Button("Dismiss") { message = "" }.buttonStyle(.plain) }.foregroundStyle(Palette.accent).padding(12)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(width: 1180, height: 900).background(Palette.background).foregroundStyle(.white).preferredColorScheme(.dark)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("Your workspace").font(.system(size: 19, weight: .medium)); Spacer(); Text("Sample workspace").font(.system(size: 11)).foregroundStyle(Palette.muted) }
            Button { page = "Projects" } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Needs your attention", systemImage: "exclamationmark.circle").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.accent)
                    HStack { Text("Studio · The next episode is ready for review").font(.system(size: 12)); Spacer(); Text("Review  ›").font(.system(size: 11)).foregroundStyle(Palette.accent) }
                }.padding(13).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain)
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    section("Mission Controls")
                    ForEach(Array(["Studio", "Research", "Design", "Development", "Writing", "Archive"].enumerated()), id: \.offset) { index, name in
                        Button { message = "Preview: \(name) workspace. No external service is opened." } label: {
                            HStack { Circle().fill(index == 0 ? Palette.online : Palette.accent).frame(width: 5, height: 5); Text(name).font(.system(size: 12)); Spacer(); Image(systemName: index == 0 ? "arrow.up.right" : "power").font(.system(size: 10)).foregroundStyle(Palette.muted) }
                        }.buttonStyle(.plain)
                    }
                }.frame(width: 190)
                VStack(alignment: .leading, spacing: 12) {
                    section("Quick access")
                    HStack(spacing: 6) { ForEach(["Studio EN", "Studio FR", "Studio ES", "Studio JP", "Studio IT"], id: \.self) { name in quickTile(name, symbol: "play.rectangle.fill", subtitle: "Chrome profile") } }
                    Text("PHOTOSHOP").font(.system(size: 9)).foregroundStyle(Palette.muted)
                    HStack(spacing: 6) { ForEach(["ENGLISH", "FRENCH", "SPANISH", "JAPANESE", "ITALIAN"], id: \.self) { name in quickTile(name, symbol: "doc.richtext", subtitle: "PSD") } }
                    Button("All files & shortcuts ↗") { page = "Shortcuts" }.font(.system(size: 11)).foregroundStyle(Palette.muted).buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            Divider()
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    section("Continue working")
                    recent("Episode draft", detail: "Studio · EN", symbol: "folder")
                    recent("Studio ES", detail: "Sample browser shortcut", symbol: "globe")
                    recent("Studio EN", detail: "Sample browser shortcut", symbol: "globe")
                    recent("SPANISH", detail: "PSD · Demo assets", symbol: "doc")
                    recent("ENGLISH", detail: "PSD · Demo assets", symbol: "doc")
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 12) {
                    HStack { section("My checklist"); Text("\(tasks.filter { !done.contains($0) }.count)").font(.caption).foregroundStyle(Palette.muted) }
                    HStack {
                        TextField("Add something to do…", text: $draft).textFieldStyle(.plain).onSubmit(addTask)
                        Button(action: addTask) { Image(systemName: "plus").frame(width: 26, height: 28) }.buttonStyle(.plain).accessibilityLabel("Add checklist item")
                    }.font(.system(size: 12)).padding(.leading, 10).padding(.trailing, 3).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                    ForEach(tasks, id: \.self) { task in
                        Button { if done.contains(task) { done.remove(task) } else { done.insert(task) } } label: {
                            HStack { Image(systemName: done.contains(task) ? "checkmark.circle.fill" : "circle").foregroundStyle(Palette.muted); Text(task).strikethrough(done.contains(task)); Spacer() }.font(.system(size: 12))
                        }.buttonStyle(.plain)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                section("Pinned actions")
                Spacer()
                Menu("+ Add pin") { ForEach(["Documentation", "Project board", "Design library"], id: \.self) { name in Button(name) { if !pins.contains(name) { pins.append(name) } } } }.menuStyle(.borderlessButton).fixedSize().font(.system(size: 11)).foregroundStyle(Palette.accent)
            }.padding(.top, 6)
            if pins.isEmpty { Text("Pin the files and channel shortcuts you want one click away.").font(.system(size: 12)).foregroundStyle(Palette.muted) }
            else { HStack { ForEach(pins, id: \.self) { name in quickTile(name, symbol: "pin", subtitle: "Sample shortcut") } } }
        }
    }
    private func section(_ title: String) -> some View { Text(title).font(.system(size: 15, weight: .medium)) }
    private func quickTile(_ title: String, symbol: String, subtitle: String) -> some View {
        Button { message = "Preview: \(title). Sample item; no file or browser is opened." } label: {
            VStack(spacing: 8) { BrandIcon(name: subtitle == "PSD" ? "photoshop" : "youtube").frame(width: 24, height: 24); Text(title).font(.system(size: 10, weight: .medium)); Text(subtitle).font(.system(size: 9)).foregroundStyle(Palette.muted) }
                .frame(width: 92, height: 78).background(Palette.surface, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }
    private func recent(_ title: String, detail: String, symbol: String) -> some View {
        Button { message = "Preview: \(title)" } label: {
            HStack(spacing: 10) { Image(systemName: symbol).foregroundStyle(Palette.muted); VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 12)); Text(detail).font(.system(size: 10)).foregroundStyle(Palette.muted) }; Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(Palette.muted) }
        }.buttonStyle(.plain)
    }
    private func addTask() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty && !tasks.contains(value) { tasks.append(value) }; draft = ""
    }
    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Files & shortcuts")
            Text("Search from the header. Select a shortcut to preview its launch plan or rename it.").font(.system(size: 12)).foregroundStyle(Palette.muted)
            let tiles = visibleTiles(applyConfig(config.links.map(linkTile), config: config), config: config, query: query)
            ForEach(tiles) { tile in
                Button { selectedID = tile.id; alias = tile.label; message = "Preview only: " + launchPlan(for: tile).target } label: {
                    HStack { Image(systemName: "globe").frame(width: 30); VStack(alignment: .leading, spacing: 5) { Text(tile.label); Text(tile.subtitle).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Image(systemName: "arrow.up.right") }.font(.system(size: 13)).padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
            if tiles.isEmpty { Text("No matching shortcuts").foregroundStyle(Palette.muted) }
            if let selectedID { HStack { TextField("Shortcut label", text: $alias).textFieldStyle(.roundedBorder); Button("Rename") { config = renamed(config, id: selectedID, label: alias) } } }
        }
    }
    private var assistant: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { JarvisAvatar().frame(width: 35, height: 35); section("Jarvis") }
            Text("Local language example").font(.system(size: 13, weight: .medium))
            Text("Try an Arabic-script Darija phrase. This demo converts it to Latin script on your Mac; it does not call an AI provider.").font(.system(size: 12)).foregroundStyle(Palette.muted)
            TextField("Type a phrase…", text: $input).font(.system(size: 22)).textFieldStyle(.plain).frame(height: 48).padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            Text(DarijaLatin.render(input)).font(.system(size: 22)).padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            Text("Transliteration changes the writing system, not the meaning. Names and unfamiliar words may need correction.").font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
    }
    private var samplePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            section(page)
            Text("Sample content · Personal records and connected services stay private.").font(.system(size: 12)).foregroundStyle(Palette.muted)
            if page == "Projects" {
                recent("Episode draft", detail: "Ready for review · Studio", symbol: "folder")
                recent("Interface study", detail: "In progress · Design", symbol: "folder")
            } else if page == "Subscriptions" {
                recent("Example editor", detail: "Sample plan · EUR 12 / month", symbol: "creditcard")
                recent("Example storage", detail: "Sample plan · EUR 5 / month", symbol: "externaldrive")
            } else {
                Text("This section is available in the personal app. Its data and integrations are not included in this demo.").font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
        }
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
        if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--render" {
            let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                let renders: [(String, AnyView, NSSize)] = [
                    ("overview", AnyView(DemoDashboard()), NSSize(width: 1180, height: 900)),
                    ("shortcuts", AnyView(DemoDashboard(page: "Shortcuts")), NSSize(width: 1180, height: 900)),
                    ("assistant", AnyView(DemoDashboard(page: "Assistant")), NSSize(width: 1180, height: 900)),
                    ("floating-widget", AnyView(DemoFloatingBar()), NSSize(width: 590, height: 58)),
                    ("widget-details", AnyView(DemoQuotaDetails()), NSSize(width: 474, height: 345)),
                    ("expenses", AnyView(DemoDashboard(page: "Subscriptions")), NSSize(width: 1180, height: 900)),
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
