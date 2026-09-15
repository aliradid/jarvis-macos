import SwiftUI
import AppKit
import ImageIO

// Opaque surfaces keep the canvas truly black, independent of wallpaper or system tint.
enum OLED {
    static let canvas = Color.black
    static let surface = Color(red: 0.078, green: 0.076, blue: 0.071)
    static let raised = Color(white: 0.075)
    static let border = Color(white: 0.15)
    static let text = Color(white: 0.94)
    static let muted = Color(white: 0.64)
    static let accent = Color(red: 1, green: 0.78, blue: 0.12)
    static let online = Color(red: 0.29, green: 0.92, blue: 0.60)
    static let offline = Color(red: 0.98, green: 0.69, blue: 0.32)
}

struct LinkBadge: View {
    let url: String
    var label: String = ""
    let size: CGFloat
    var body: some View {
        let color = Color(hue: linkHue(url), saturation: 0.55, brightness: 0.95)
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(color.opacity(0.13))
            .overlay(RoundedRectangle(cornerRadius: size * 0.26).stroke(color.opacity(0.32), lineWidth: 1))
            .overlay(
                Text(label.isEmpty ? linkBadgeText(url) : initials(label))
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                    .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 2)
            ).frame(width: size, height: size)
    }
}

struct TileIcon: View {
    let tile: Tile
    var size: CGFloat = 34

    private var loadedImage: NSImage? {
        if let custom = tile.customImage { return NSImage(contentsOfFile: custom) }
        let name: String
        if tile.id.hasPrefix("chrome-profile:sample-") { name = "youtube" }
        else if tile.id.hasPrefix("file:artwork-") { name = "photoshop" }
        else { return nil }
        return Bundle.module.url(forResource: name, withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    }
    private var imageKey: String { (tile.customImage ?? "") + "|" + (tile.iconSourcePath ?? "") }

    var body: some View {
        Group {
            if let nsImage = loadedImage {
                Image(nsImage: nsImage).resizable().aspectRatio(contentMode: tile.customImage == nil ? .fit : .fill)
            } else if case .openURL(let u, _) = tile.invocation {
                LinkBadge(url: u, label: tile.label, size: size)
            } else if tile.kind == .workspace {
                Image(systemName: "square.stack.3d.up.fill").resizable().aspectRatio(contentMode: .fit).foregroundStyle(.tint)
            } else {
                Image(systemName: "app.dashed").resizable().aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}


struct TileView: View {
    let tile: Tile
    var isHiddenTile = false
    /// 0-based position in the visible list; the first nine get ⌘1…⌘9.
    var shortcutIndex: Int? = nil
    var isSelected = false
    var compact = false

    @EnvironmentObject var state: AppState
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var renaming = false
    @State private var draftName = ""
    @State private var addingGroup = false
    @State private var draftGroup = ""
    @State private var editingLink = false
    @State private var editingWorkspace = false

    private var iconSize: CGFloat { compact ? 24 : 36 }
    private var tileHeight: CGFloat { compact ? 76 : 100 }

    @State private var unavailableReason: String?
    var fileMissing: Bool { unavailableReason != nil }
    private var filePath: String? {
        if case .openFile(let path, _) = tile.invocation { return path }
        return nil
    }

    var fileApp: String? {
        if case .openFile(_, let a) = tile.invocation { return a }
        return nil
    }

    /// Full detail lives in the tooltip and in VoiceOver rather than on the tile,
    /// where a truncated address costs a whole line and tells you nothing.
    private var detail: String {
        if isHiddenTile { return "Removed — right-click to restore" }
        if let reason = unavailableReason { return reason }
        if let status = serverStatus { return "\(tile.subtitle) · \(status.rawValue)" }
        return tile.subtitle
    }

    private var serverStatus: ServerStatus? {
        guard let entry = state.linkEntry(for: tile), isLocalServer(entry.url) else { return nil }
        return state.statuses[entry.id] ?? .checking
    }
    var body: some View {
        tileContent
    }
    @ViewBuilder private var tileContent: some View {
        if isHiddenTile {
            tileButton
                .opacity(0.45)
                .help("\(tile.label) — \(detail)")
                .contextMenu {
                    Button("Restore") { state.unhide(tile) }
                }
        } else {
            tileButton
                .opacity(fileMissing ? 0.45 : 1)
                .help(detail.isEmpty ? tile.label : "\(tile.label) — \(detail)")
                .draggable(tile.id)
                .dropDestination(for: String.self) { items, _ in
                    guard let dragged = items.first, dragged != tile.id else { return false }
                    state.move(draggedID: dragged, beforeID: tile.id, inFileSection: tile.kind == .file)
                    return true
                }
                .contextMenu { normalMenu }
                .popover(isPresented: $renaming) { renamePopover }
                .popover(isPresented: $addingGroup) { groupPopover }
                .sheet(isPresented: $editingLink) { LinkEditor(entry: state.linkEntry(for: tile)) }
                .sheet(isPresented: $editingWorkspace) {
                    if case .workspace(let id) = tile.invocation {
                        WorkspaceEditor(entry: state.workspaces.first { $0.id == id })
                    }
                }
        }
    }

    private var statusColor: Color {
        if fileMissing { return OLED.offline }
        switch serverStatus {
        case .online: return OLED.online
        case .offline: return OLED.offline
        case .starting: return OLED.accent
        default: return OLED.muted
        }
    }
    private var caption: String {
        if isHiddenTile { return "Removed" }
        if fileMissing { return "Reconnect file" }
        if let status = serverStatus {
            if status == .offline, state.linkEntry(for: tile)?.startupFile != nil { return "Start server" }
            return status.rawValue
        }
        switch tile.kind {
        case .chromeProfile: return "Chrome profile"
        case .browser: return "Browser"
        case .workspace: return "Workspace"
        case .file:
            if case .openFile(let path, _) = tile.invocation {
                let ext = (path as NSString).pathExtension.uppercased()
                return ext.isEmpty ? "File" : ext
            }; return "File"
        case .link: return "Website"
        }
    }
    private var tileButton: some View {
        Button(action: { if !isHiddenTile { state.launch(tile) } }) {
            VStack(spacing: compact ? 3 : 7) {
                ZStack {
                    TileIcon(tile: tile, size: iconSize)
                    if state.launching.contains(tile.id) {
                        RoundedRectangle(cornerRadius: 9).fill(OLED.canvas.opacity(0.8))
                        ProgressView().controlSize(.small).tint(OLED.accent)
                    }
                }.frame(width: iconSize, height: iconSize)
                Text(tile.label)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                    .foregroundStyle(OLED.text)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                    .frame(height: compact ? 23 : 29, alignment: .center)
                HStack(spacing: 4) {
                    if serverStatus != nil || fileMissing {
                        Circle().fill(statusColor).frame(width: 5, height: 5)
                    }
                    Text(caption).font(.system(size: 10, weight: .medium)).lineLimit(1)
                }.foregroundStyle(statusColor)
            }
            .frame(maxWidth: .infinity).frame(height: tileHeight).padding(.horizontal, 7)
            .background(isSelected ? OLED.accent.opacity(0.09) : hovered ? OLED.raised : OLED.surface,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(isSelected ? OLED.accent : hovered ? Color(white: 0.32) : OLED.border, lineWidth: 1))
            .overlay(alignment: .topTrailing) { shortcutHint }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .scaleEffect(hovered && !reduceMotion ? 1.015 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovered)
        }
        .buttonStyle(JarvisPlainButtonStyle())
        .onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tile.label).accessibilityValue(detail)
        .accessibilityHint(isHiddenTile ? "Removed item" : "Opens \(tile.label)")
        .accessibilityAddTraits(.isButton)
        .modifier(NumberShortcut(index: isHiddenTile ? nil : shortcutIndex))
    }

    @ViewBuilder private var shortcutHint: some View {
        if let i = shortcutIndex, i < 9, !isHiddenTile {
            Text("\(i + 1)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? OLED.accent : OLED.muted)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(OLED.raised, in: RoundedRectangle(cornerRadius: 4))
                .padding(7).accessibilityHidden(true)
        }
    }

    @ViewBuilder private var normalMenu: some View {
        if tile.kind == .workspace {
            Button("Edit Workspace…") { editingWorkspace = true }
            if case .workspace(let id) = tile.invocation {
                Button("Remove Workspace", role: .destructive) { state.removeWorkspace(id) }
            }
        } else {
        Button("Rename…") { draftName = tile.label; renaming = true }
        Button("Set Image…") { pickImage() }
        if tile.customImage != nil { Button("Reset Image") { state.clearImage(tile) } }
        Menu("Group") {
            Button {
                state.setGroup(id: tile.id, to: nil)
            } label: {
                if state.groupName(for: tile.id) == nil { Label("None", systemImage: "checkmark") }
                else { Text("None") }
            }
            ForEach(state.groups, id: \.self) { g in
                Button {
                    state.setGroup(id: tile.id, to: g)
                } label: {
                    if state.groupName(for: tile.id) == g { Label(g, systemImage: "checkmark") }
                    else { Text(g) }
                }
            }
            Divider()
            Button("New Group…") { draftGroup = ""; addingGroup = true }
        }
        if tile.kind == .file {
            Button("Reveal in Finder") {
                if case .openFile(let p, _) = tile.invocation {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)])
                }
            }
            Button("Locate File…") { locateFile() }
            Button("Open With…") { pickApp() }
            if fileApp != nil {
                Button("Use Default App") { state.setFileApp(tile, to: nil) }
            }
            Divider()
            Button("Remove", role: .destructive) { state.removeFile(tile) }
        } else if tile.kind == .link {
            Button("Edit Link…") { editingLink = true }
            if let entry = state.linkEntry(for: tile), isLocalServer(entry.url), entry.startupFile != nil {
                Button("Start Server") { state.startServer(tile) }.disabled(serverStatus == .starting || serverStatus == .online)
            }
            Button("Copy URL") {
                if case .openURL(let u, _) = tile.invocation {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(u, forType: .string)
                }
            }
            Divider()
            Button("Remove", role: .destructive) { state.removeLink(tile) }
        } else {
            Button("Reset") { state.reset(tile) }
            Divider()
            Button("Remove", role: .destructive) { state.removeBrowser(tile) }
        }
    }

    }

    private var renamePopover: some View {
        HStack {
            TextField("Name", text: $draftName).frame(width: 180)
                .onSubmit { state.rename(tile, to: draftName); renaming = false }
            Button("Save") { state.rename(tile, to: draftName); renaming = false }
        }.padding(12).background(OLED.surface).preferredColorScheme(.dark)
    }

    private var groupPopover: some View {
        HStack {
            TextField("Group name", text: $draftGroup).frame(width: 180)
                .onSubmit { state.setGroup(id: tile.id, to: draftGroup); addingGroup = false }
            Button("Save") { state.setGroup(id: tile.id, to: draftGroup); addingGroup = false }
        }.padding(12).background(OLED.surface).preferredColorScheme(.dark)
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP, .image]
        if panel.runModal() == .OK, let url = panel.url { state.setImage(tile, from: url) }
    }

    private func locateFile() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true
        panel.message = "Choose the new location for \(tile.label). Its name, image and workspace membership will be kept."
        if panel.runModal() == .OK, let url = panel.url { state.locateFile(tile, at: url) }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url { state.setFileApp(tile, to: url) }
    }
}

/// Attaches ⌘1…⌘9 to the first nine tiles. A modifier because `keyboardShortcut`
/// takes a non-optional key, and most tiles have no shortcut at all.
private struct NumberShortcut: ViewModifier {
    let index: Int?

    @ViewBuilder func body(content: Content) -> some View {
        if let i = index, i < 9 {
            content.keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
        } else {
            content
        }
    }
}
