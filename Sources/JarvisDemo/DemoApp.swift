import SwiftUI
import AppKit

// This public presentation uses fictional fixtures. It has no provider adapters,
// account discovery, shell execution, telemetry or production storage access.
private enum Palette {
    static let background = Color(red: 0.075, green: 0.08, blue: 0.085)
    static let surface = Color(red: 0.115, green: 0.12, blue: 0.13)
    static let muted = Color(red: 0.63, green: 0.65, blue: 0.68)
    static let accent = Color(red: 0.91, green: 0.96, blue: 0.49)
}


struct DemoDashboard: View {
    @State var page = "Overview"
    @State private var query = ""
    @State private var config = DemoFixtures.config
    @State private var message = "Choose a shortcut to preview its launch plan."
    @State private var input = "واش المشروع واجد؟"
    @State private var alias = ""
    @State private var selectedID: String? = nil
    private let pages = [("Overview", "square.grid.2x2"), ("Shortcuts", "command"), ("Language", "text.bubble")]

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle").font(.system(size: 26)).foregroundStyle(Palette.accent)
                    Text("JARVIS").font(.system(size: 17, weight: .bold)).tracking(3)
                }.padding(.bottom, 38)
                Text("WORKSPACE").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Palette.muted).padding(.bottom, 12)
                ForEach(pages, id: \.0) { item in
                    Button { page = item.0 } label: {
                        Label(item.0, systemImage: item.1)
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(13)
                            .background(page == item.0 ? Palette.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(page == item.0 ? Palette.accent : Palette.muted)
                    }.buttonStyle(.plain)
                }
                Spacer()
                Circle().fill(Palette.accent).frame(width: 7, height: 7)
                Text("Portfolio edition").font(.system(size: 12, weight: .medium))
                Text("Fictional data · Offline").font(.system(size: 11)).foregroundStyle(Palette.muted)
            }.padding(26).frame(width: 220).background(Color.black.opacity(0.16))
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text(page).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                    Spacer()
                    Text("NATIVE macOS / SWIFTUI").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Palette.muted)
                }
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                if page == "Overview" { overview }
                else if page == "Shortcuts" { shortcuts }
                else { language }
                Spacer(minLength: 0)
                HStack {
                    Text("JARVIS").font(.system(size: 10, weight: .bold)).tracking(2)
                    Spacer()
                    Text("Public demo · Sample readings · Changes last for this session")
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.frame(width: 1180, height: 840)
            .background(Palette.background).foregroundStyle(Color.white)
            .preferredColorScheme(.dark)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("A little less switching.").font(.system(size: 34, weight: .medium))
                Text("Tools, usage and work in one quiet place.").foregroundStyle(Palette.muted).font(.system(size: 14))
            }
            HStack(spacing: 14) {
                quota("Assistant A", value: "72%", caption: "Session remaining", progress: 0.72)
                quota("Assistant B", value: "46%", caption: "Weekly remaining", progress: 0.46)
                quota("Assistant C", value: "—", caption: "Unavailable sample", progress: nil)
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 19) {
                    heading("Workspace health", "SAMPLE")
                    health("Desktop", detail: "Local machine", value: "Ready", symbol: "desktopcomputer")
                    Divider()
                    health("Development service", detail: "Example environment", value: "Online", symbol: "server.rack")
                    Divider()
                    health("Remote workspace", detail: "No account connected", value: "Offline", symbol: "network", active: false)
                }.padding(22).frame(maxWidth: .infinity).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 19) {
                    heading("Ready to continue", "2 PROJECTS")
                    project("Documentation refresh", detail: "Writing · Review draft", symbol: "doc.text")
                    Divider()
                    project("Interface study", detail: "Design · Explore concepts", symbol: "rectangle.3.group")
                    Button { page = "Shortcuts" } label: {
                        HStack { Text("Explore shortcuts"); Spacer(); Image(systemName: "arrow.right") }
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.accent)
                    }.buttonStyle(.plain)
                }.padding(22).frame(maxWidth: .infinity).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
            }
            HStack(spacing: 14) {
                Image(systemName: "lock.shield").font(.system(size: 22)).foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Explore without connecting an account").font(.system(size: 13, weight: .medium))
                    Text("This demo uses sample data. Live integrations stay in the private application.")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }.padding(.top, 2)
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your next action, closer.").font(.system(size: 32, weight: .medium))
            Text("Search, select and rename sample shortcuts using the extracted app model.")
                .font(.system(size: 13)).foregroundStyle(Palette.muted)
            TextField("Search shortcuts", text: $query).textFieldStyle(.plain)
                .padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Search shortcuts")
            let tiles = visibleTiles(applyConfig(config.links.map(linkTile), config: config), config: config, query: query)
            if tiles.isEmpty { Text("No matching shortcuts.").foregroundStyle(Palette.muted).padding() }
            ForEach(tiles) { tile in
                Button {
                    selectedID = tile.id; alias = tile.label
                    let plan = launchPlan(for: tile)
                    message = "Preview only: \(plan.kind) → \(plan.target)"
                } label: {
                    HStack(spacing: 16) {
                        Text(initials(tile.label)).font(.system(size: 14, weight: .semibold))
                            .frame(width: 44, height: 44).background(Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(tile.label).font(.system(size: 14, weight: .medium))
                            Text(tile.subtitle).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(Palette.muted)
                    }.padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            if let selectedID {
                HStack {
                    TextField("Shortcut label", text: $alias).textFieldStyle(.roundedBorder)
                    Button("Rename") { config = renamed(config, id: selectedID, label: alias) }
                }
            }
            Text(message).font(.system(size: 12)).foregroundStyle(Palette.accent).textSelection(.enabled)
            Button("Reset sample shortcuts") {
                config = DemoFixtures.config; query = ""; selectedID = nil
                message = "Choose a shortcut to preview its launch plan."
            }.font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(Palette.muted)
        }
    }

    private var language: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("A familiar way to write.").font(.system(size: 32, weight: .medium))
            Text("A small local Darija transliterator extracted from Jarvis.")
                .font(.system(size: 14)).foregroundStyle(Palette.muted)
            VStack(alignment: .leading, spacing: 16) {
                heading("Arabic-script input", "EDITABLE")
                TextField("Enter a phrase", text: $input).font(.system(size: 25)).textFieldStyle(.plain)
                    .frame(height: 44).padding(12).background(Palette.background, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Arabic text to transliterate")
            }.padding(24).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
            Image(systemName: "arrow.down").foregroundStyle(Palette.accent).padding(.leading, 24)
            VStack(alignment: .leading, spacing: 16) {
                heading("Latin-script output", "ON DEVICE")
                Text(DarijaLatin.render(input)).font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Palette.accent).textSelection(.enabled)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
            Text("Transliteration changes the writing system; it does not translate meaning. Unknown words use the system transliterator. Names and spelling may need correction.")
                .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
        }
    }

    private func heading(_ title: String, _ detail: String) -> some View {
        HStack { Text(title).font(.system(size: 14, weight: .medium)); Spacer(); Text(detail).font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(Palette.muted) }
    }
    private func quota(_ title: String, value: String, caption: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 44, weight: .light, design: .rounded)).foregroundStyle(progress == nil ? Palette.muted : Palette.accent)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    if let progress { Capsule().fill(Palette.accent).frame(width: geometry.size.width * progress) }
                }
            }.frame(height: 4)
            Text(caption).font(.system(size: 11)).foregroundStyle(Palette.muted)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
    }
    private func health(_ title: String, detail: String, value: String, symbol: String, active: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 20).foregroundStyle(Palette.muted)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 12)); Text(detail).font(.system(size: 10)).foregroundStyle(Palette.muted) }
            Spacer()
            Text(value).font(.system(size: 10, weight: .medium)).foregroundStyle(active ? Palette.accent : Palette.muted)
        }
    }
    private func project(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 19)).foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 12, weight: .medium)); Text(detail).font(.system(size: 10)).foregroundStyle(Palette.muted) }
            Spacer()
        }
    }
}

struct PortfolioApp: App {
    var body: some Scene {
        WindowGroup("Jarvis · Portfolio edition") { DemoDashboard() }
            .windowResizability(.contentSize)
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
                for page in ["Overview", "Shortcuts", "Language"] {
                    _ = NSApplication.shared
                    let view = NSHostingView(rootView: DemoDashboard(page: page))
                    view.sizingOptions = []
                    view.frame = NSRect(x: 0, y: 0, width: 1180, height: 840)
                    let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                    window.appearance = NSAppearance(named: .darkAqua)
                    window.contentView = view
                    window.setContentSize(NSSize(width: 1180, height: 840))
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
                print("Rendered three fictional-data demo screens.")
            } catch { fputs("Render failed: \(error.localizedDescription)\n", stderr); exit(1) }
        } else { PortfolioApp.main() }
    }
}
