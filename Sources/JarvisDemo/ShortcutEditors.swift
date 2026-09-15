import SwiftUI
import AppKit
struct LinkEditor: View {
    var entry: LinkEntry? = nil
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var profile = ""
    @State private var startup = ""
    @State private var validation: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry == nil ? "Add a link" : "Edit link").font(.title2.bold())
            TextField("Website address", text: $address).textFieldStyle(.roundedBorder)
            Text("Use a website or local dashboard address, such as localhost:8080.").font(.caption).foregroundStyle(.secondary)
            Picker("Open in", selection: $profile) {
                Text("Default browser").tag("")
                ForEach(state.profiles) { tile in
                    if case .openChromeProfile(let dir) = tile.invocation { Text("Chrome · \(tile.label)").tag(dir) }
                }
                if !profile.isEmpty && !state.profiles.contains(where: { if case .openChromeProfile(let dir) = $0.invocation { return dir == profile }; return false }) {
                    Text("Unavailable profile: \(profile)").tag(profile)
                }
            }
            if isLocalServer((try? normalizedLink(address)) ?? "") {
                Divider()
                Text("Start this server when offline").font(.headline)
                Text("Choose an existing startup file. Server startup and external launching are disabled in this demo.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Text(startup.isEmpty ? "No startup file configured" : (startup as NSString).lastPathComponent).lineLimit(1).help(startup)
                    Spacer()
                    Button("Choose…") { pickStartup() }
                    if !startup.isEmpty { Button("Clear") { startup = "" } }
                }
            }
            if let validation { Text(validation).foregroundStyle(.red).font(.callout).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save Link") {
                    if state.saveLink(id: entry?.id, url: address, profile: profile.isEmpty ? nil : profile,
                                      startupFile: isLocalServer((try? normalizedLink(address)) ?? "") && !startup.isEmpty ? startup : nil) { dismiss() }
                    else { validation = state.errorMessage; state.errorMessage = nil }
                }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
        }.padding(24).frame(width: 500).background(OLED.surface).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
        .onAppear { address = entry?.url ?? ""; profile = entry?.profile ?? ""; startup = entry?.startupFile ?? "" }
    }
    private func pickStartup() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false
        panel.message = "Choose an existing .command, .sh or .app that starts this dashboard."
        if panel.runModal() == .OK, let url = panel.url {
            if ["command", "sh", "app"].contains(url.pathExtension.lowercased()) { startup = url.path; validation = nil }
            else { validation = "Choose a .command, .sh or .app startup file." }
        }
    }
}

struct WorkspaceEditor: View {
    var entry: WorkspaceEntry? = nil
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selection: [String] = []
    @State private var validation: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(entry == nil ? "New workspace" : "Edit workspace").font(.title2.bold())
            TextField("Workspace name, e.g. Studio A", text: $name).textFieldStyle(.roundedBorder)
            Text("Choose items in the order you want them to open. A link's assigned profile opens with it; a duplicate standalone profile is skipped.")
                .font(.callout).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(state.memberTiles) { tile in
                        Toggle(isOn: Binding(get: { selection.contains(tile.id) }, set: { on in
                            if on { selection.append(tile.id) } else { selection.removeAll { $0 == tile.id } }
                        })) {
                            HStack { TileIcon(tile: tile, size: 24); Text(tile.label); Spacer()
                                if let i = selection.firstIndex(of: tile.id) { Text("\(i + 1)").foregroundStyle(.secondary) }
                            }
                        }
                    }
                    ForEach(selection.filter { id in !state.memberTiles.contains(where: { $0.id == id }) }, id: \.self) { id in
                        HStack { Text("Unavailable: \(id)").font(.caption).foregroundStyle(.orange); Spacer(); Button("Remove") { selection.removeAll { $0 == id } } }
                    }
                }.padding(4)
            }.frame(height: 240)
            if let validation { Text(validation).foregroundStyle(.red).font(.callout) }
            HStack {
                Text("\(selection.count) selected").foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save Workspace") {
                    let next = WorkspaceEntry(id: entry?.id ?? UUID().uuidString, name: name, tileIDs: selection)
                    if state.saveWorkspace(next) { dismiss() } else { validation = state.errorMessage; state.errorMessage = nil }
                }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
        }.padding(24).frame(width: 500).background(OLED.surface).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
        .onAppear { name = entry?.name ?? ""; selection = entry?.tileIDs ?? [] }
    }
}

private struct OLEDToolbarButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundStyle(configuration.isPressed ? OLED.accent : OLED.muted)
            .frame(width: 32, height: 34)
            .background(configuration.isPressed ? OLED.raised : OLED.surface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(OLED.border, lineWidth: 1))
            .contentShape(Rectangle())
    }
}
