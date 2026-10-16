import SwiftUI
import AppKit

struct JarvisView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var jarvis: JarvisStore
    var embedded: Bool = false
    init(jarvis: JarvisStore, draft: Binding<String>, embedded: Bool = false) {
        self.jarvis = jarvis
        self._draft = draft
        self.embedded = embedded
    }
    @Environment(\.dismiss) private var dismiss
    @Binding private var draft: String
    @State private var preferences = false
    @FocusState private var focused: Bool

    private let presets = ["Code & Arch", "Burn Advisor", "DevOps"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                JarvisCore(active: jarvis.busy).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("LOCAL OLLAMA ENGINE").font(.system(size: 9.5, weight: .bold, design: .monospaced)).kerning(1.5).foregroundStyle(OLED.accent)
                        HStack(spacing: 5) {
                            Circle().fill(jarvis.busy ? OLED.warning : OLED.online).frame(width: 5.5, height: 5.5)
                            Text(jarvis.busy ? "GENERATING" : "METAL GPU READY").font(.system(size: 8.5, weight: .bold, design: .monospaced)).foregroundStyle(jarvis.busy ? OLED.warning : OLED.online)
                        }.padding(.horizontal, 7).padding(.vertical, 2.5).background(OLED.surface, in: Capsule())
                        Text("127.0.0.1:11434").font(.system(size: 9, design: .monospaced)).foregroundStyle(OLED.muted)
                    }
                    Text(jarvis.busy ? jarvis.progress : "Private On-Device AI & Workspace Automation")
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                }
                Spacer(minLength: 16)

                Button {
                    let md = jarvis.exportMarkdown()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(md, forType: .string)
                    state.notice = "Copied conversation transcript as Markdown to clipboard."
                } label: {
                    Label("Export MD", systemImage: "doc.on.doc").font(.system(size: 11, weight: .medium))
                }.buttonStyle(JarvisControlStyle()).foregroundStyle(OLED.text).help("Copy transcript as Markdown")

                Button { preferences = true } label: {
                    Label("System Context", systemImage: "slider.horizontal.3").font(.system(size: 11, weight: .medium))
                }.buttonStyle(JarvisControlStyle()).foregroundStyle(OLED.text).help("Preferences").accessibilityLabel("Preferences")

                if !jarvis.history.turns.isEmpty {
                    Button {
                        jarvis.clearHistory()
                        state.notice = "Cleared AI Assistant conversation history."
                    } label: {
                        Image(systemName: "trash").font(.system(size: 11))
                    }.buttonStyle(JarvisControlStyle()).foregroundStyle(OLED.muted).help("Clear conversation")
                }

                if !embedded { Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("Close Jarvis") }
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(OLED.surface.opacity(0.45))

            Rectangle().fill(LinearGradient(colors: [OLED.accent.opacity(0.65), OLED.cyan.opacity(0.35), OLED.accent.opacity(0.05)], startPoint: .leading, endPoint: .trailing)).frame(height: 1)

            // Preset, Model & Live Telemetry Context Strip
            HStack(spacing: 5) {
                Text("MODEL").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(OLED.muted).fixedSize()
                ForEach(jarvis.availableModels.prefix(3), id: \.self) { model in
                    let isSel = jarvis.selectedModel == model
                    Button { jarvis.selectedModel = model } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "cpu.fill").font(.system(size: 7.5))
                            Text(model).font(.system(size: 9.5, weight: .semibold, design: .monospaced)).lineLimit(1)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3.5)
                        .background(isSel ? OLED.accent.opacity(0.22) : OLED.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(isSel ? OLED.accent : OLED.border, lineWidth: 1))
                        .foregroundStyle(isSel ? OLED.text : OLED.muted)
                    }.buttonStyle(JarvisPlainButtonStyle()).fixedSize()
                }

                Divider().frame(height: 12).overlay(OLED.border).padding(.horizontal, 1)

                Text("PRESET").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(OLED.muted).fixedSize()
                ForEach(presets, id: \.self) { preset in
                    let active = jarvis.activePreset == preset || (preset == "Code & Arch" && jarvis.activePreset == "Architecture & Code")
                    Button { jarvis.activePreset = preset } label: {
                        Text(preset)
                            .font(.system(size: 9.5, weight: .semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 7).padding(.vertical, 3.5)
                            .background(active ? OLED.accent.opacity(0.16) : OLED.surface, in: Capsule())
                            .overlay(Capsule().stroke(active ? OLED.accent.opacity(0.6) : OLED.border, lineWidth: 1))
                            .foregroundStyle(active ? OLED.accent : OLED.muted)
                    }.buttonStyle(JarvisPlainButtonStyle()).fixedSize()
                }

                Spacer(minLength: 4)

                Text("CONTEXT").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(OLED.muted).fixedSize()
                contextTogglePill("Quotas", isOn: $jarvis.includeQuotasContext)
                contextTogglePill("Ports", isOn: $jarvis.includePortsContext)
                contextTogglePill("Hardware", isOn: $jarvis.includeHardwareContext)
                contextTogglePill("Repos", isOn: $jarvis.includeReposContext)
            }
            .padding(.horizontal, 22).padding(.vertical, 7)
            .background(OLED.canvas)

            Divider().overlay(OLED.border)

            if let issue = jarvis.issue { Text(issue).font(.caption).foregroundStyle(OLED.offline).padding(10) }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if jarvis.history.turns.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ready for local code synthesis, quota inspection, or port diagnostics.").font(.system(size: 20, weight: .semibold))
                                Text("Jarvis connects directly to your local Ollama daemon on port 11434 and can launch any configured IDE, dev server, or repository in a single command.").foregroundStyle(OLED.muted).fixedSize(horizontal: false, vertical: true)
                            }.padding(.vertical, 28)
                        }
                        ForEach(jarvis.history.turns) { turn in
                            conversationCard(turn)
                        }
                        if jarvis.busy { HStack { ProgressView().controlSize(.small); Text(jarvis.progress).font(.caption).foregroundStyle(OLED.muted) } }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(22)
                }.onChange(of: jarvis.history.turns.count) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    .onChange(of: jarvis.busy) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            }

            VStack(spacing: 9) {
                HStack(spacing: 6) {
                    ForEach(["/quotas", "/ports", "/hardware", "/repos", "/spend"], id: \.self) { slash in
                        Button { jarvis.send(slash, state: state) } label: {
                            Text(slash)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(OLED.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(OLED.accent.opacity(0.35), lineWidth: 1))
                                .foregroundStyle(OLED.accent)
                        }.buttonStyle(JarvisPlainButtonStyle()).disabled(jarvis.busy)
                    }
                    Divider().frame(height: 14).overlay(OLED.border)
                    suggestion("Audit Claude 5h & Codex token burn rate")
                    suggestion("Inspect active localhost ports (:3000, :8000)")
                    suggestion("Open Cursor AI IDE")
                    Spacer(minLength: 0)
                }
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "sparkles").foregroundStyle(OLED.accent).font(.system(size: 14))
                    TextField("Ask Jarvis (\(jarvis.selectedModel)), run /quotas or /ports, or type 'open <service>'…", text: $draft).textFieldStyle(.plain).focused($focused)
                        .font(.system(size: 13.5))
                        .onSubmit { submit() }.accessibilityLabel("Ask Jarvis")
                    if jarvis.busy {
                        Button("Stop") { jarvis.cancel() }.buttonStyle(JarvisPlainButtonStyle()).foregroundStyle(OLED.offline)
                    } else {
                        Button(action: submit) {
                            HStack(spacing: 5) {
                                Text("Run").font(.system(size: 11.5, weight: .semibold))
                                Image(systemName: "arrow.up.circle.fill").font(.system(size: 16))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(OLED.accent, in: Capsule())
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(JarvisPlainButtonStyle())
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Send to Jarvis")
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(OLED.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(focused ? OLED.accent : OLED.border, lineWidth: 1))
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
            .background(OLED.surface.opacity(0.35))
        }
        .frame(minWidth: 460, maxWidth: .infinity, minHeight: embedded ? 360 : 560, maxHeight: .infinity)
        .background(OLED.canvas).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
        .onAppear { focused = true }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("jarvis.focusComposer"))) { _ in focused = false; DispatchQueue.main.async { focused = true } }
        .task { await jarvis.prepare(state: state) }
        .sheet(isPresented: $preferences) { JarvisPreferences(jarvis: jarvis) }
    }

    private func contextTogglePill(_ label: String, isOn: Binding<Bool>) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 8.5))
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7).padding(.vertical, 3.5)
            .background(isOn.wrappedValue ? OLED.online.opacity(0.14) : OLED.surface, in: Capsule())
            .overlay(Capsule().stroke(isOn.wrappedValue ? OLED.online.opacity(0.45) : OLED.border, lineWidth: 1))
            .foregroundStyle(isOn.wrappedValue ? OLED.online : OLED.muted)
        }.buttonStyle(JarvisPlainButtonStyle()).fixedSize()
    }

    private func conversationCard(_ turn: JarvisTurn) -> some View {
        let user = turn.role == "user"
        let fill: Color = user ? OLED.raised.opacity(0.65) : OLED.surface
        let border: Color = user ? OLED.specular : OLED.accent.opacity(0.28)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: user ? "person.crop.circle.fill" : "cpu.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(user ? OLED.cyan : OLED.accent)
                Text(user ? "DEVELOPER" : "JARVIS · \(jarvis.selectedModel.uppercased())")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced)).kerning(1.2)
                    .foregroundStyle(user ? OLED.cyan : OLED.accent)
                Spacer()
                Text(user ? "Prompt" : "Local Metal Inference · 18ms TTFT")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(OLED.muted)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(turn.text, forType: .string)
                    state.notice = "Copied message to clipboard."
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc").font(.system(size: 9))
                        Text("Copy").font(.system(size: 9.5, weight: .medium))
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2.5)
                    .background(OLED.raised, in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(OLED.muted)
                }.buttonStyle(JarvisPlainButtonStyle())
            }
            Text(turn.text)
                .font(.system(size: 13.5))
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if !turn.actions.isEmpty {
                HStack(spacing: 10) {
                    ForEach(turn.actions) { action in
                        Button { jarvis.run(action, state: state) } label: {
                            HStack(spacing: 7) {
                                Image(systemName: action.kind == "start" ? "bolt.fill" : action.kind == "prepare" ? "square.stack.3d.up.fill" : "arrow.up.right.square.fill")
                                Text(jarvis.actionLabel(action)).font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(OLED.text)
                            .background(OLED.accent.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(OLED.accent.opacity(0.5), lineWidth: 1))
                        }.buttonStyle(JarvisPlainButtonStyle()).disabled(jarvis.busy)
                    }
                }.padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(border, lineWidth: 1))
        .padding(.leading, user ? 48 : 0)
        .padding(.trailing, user ? 0 : 24)
        .id(turn.id)
    }

    private func suggestion(_ text: String) -> some View {
        Button(text) { jarvis.send(text, state: state) }
            .font(.system(size: 10.5, weight: .medium))
            .buttonStyle(JarvisPlainButtonStyle())
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(OLED.surface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(OLED.border, lineWidth: 1))
            .foregroundStyle(OLED.muted)
            .disabled(jarvis.busy)
    }

    private func submit() {
        guard !jarvis.busy, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = draft; draft = ""; jarvis.send(text, state: state)
    }
}

private struct JarvisPreferences: View {
    @ObservedObject var jarvis: JarvisStore
    @Environment(\.dismiss) private var dismiss
    @State private var notes = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Jarvis System Context").font(.title3.bold())
            Text("Persistent instructions for local Ollama").font(.headline)
            Text("Add architecture conventions, preferred CLI tools, or repository paths to include in local AI turns.").font(.callout).foregroundStyle(OLED.muted)
            TextEditor(text: $notes).font(.body).frame(height: 180).scrollContentBackground(.hidden).padding(10).background(OLED.surface)
                .accessibilityLabel("Jarvis preferences")
            Text("\(notes.count) / 4000 characters").font(.caption).foregroundStyle(OLED.muted)
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Save") { jarvis.history.notes = notes; jarvis.save(); dismiss() }.disabled(notes.count > 4000) }
        }.padding(20).frame(width: 460).background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)
            .onAppear { notes = jarvis.history.notes }
    }
}
