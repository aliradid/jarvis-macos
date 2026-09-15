import SwiftUI

struct JarvisView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var jarvis: JarvisStore
    var embedded: Bool = false
    init(jarvis: JarvisStore, draft: Binding<String>, embedded: Bool = false) { self.jarvis = jarvis; self._draft = draft; self.embedded = embedded }
    @Environment(\.dismiss) private var dismiss
    @Binding private var draft: String
    @State private var preferences = false
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                JarvisCore(active: jarvis.busy).frame(width: embedded ? 48 : 86, height: embedded ? 48 : 86)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Assistant").font(.system(size: 9, weight: .medium, design: .monospaced)).kerning(2).foregroundStyle(OLED.accent)
                    Text(jarvis.busy ? "Working on it." : "At your command.").font(.system(size: embedded ? 21 : 25, weight: .light, design: .rounded))
                    HStack(spacing: 6) {
                        Circle().fill(jarvis.busy ? OLED.offline : OLED.accent).frame(width: 4, height: 4)
                        Text(jarvis.busy ? jarvis.progress : "Your projects. Your next move.").font(.system(size: 10, design: .monospaced)).foregroundStyle(OLED.muted).lineLimit(2)
                    }
                }
                Spacer()
                Button { preferences = true } label: { Image(systemName: "slider.horizontal.3") }.buttonStyle(JarvisControlStyle()).foregroundStyle(OLED.accent).help("Preferences").accessibilityLabel("Preferences")
                if !embedded { Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(JarvisPlainButtonStyle()).accessibilityLabel("Close Jarvis") }
            }.padding(.horizontal, 24).padding(.vertical, 18)
            Rectangle().fill(LinearGradient(colors: [OLED.accent.opacity(0.65), OLED.accent.opacity(0.06)], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
            if let issue = jarvis.issue { Text(issue).font(.caption).foregroundStyle(OLED.offline).padding(10) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if jarvis.history.turns.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("What can I take off your plate?").font(.system(size: 24, weight: .semibold))
                                Text("This demo contains sample Mission Control projects. Choose a project from Projects to explore its setup.").foregroundStyle(OLED.muted).fixedSize(horizontal: false, vertical: true)
                            }.padding(.vertical, 35)
                        }
                        ForEach(jarvis.history.turns) { turn in
                            conversationCard(turn)
                        }
                        if jarvis.busy { HStack { ProgressView().controlSize(.small); Text(jarvis.progress).font(.caption).foregroundStyle(OLED.muted) } }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(20)
                }.onChange(of: jarvis.history.turns.count) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    .onChange(of: jarvis.busy) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    suggestion("What’s ready to upload?")
                    suggestion("What needs attention?")
                    suggestion("What’s running?")
                    Spacer(minLength: 0)
                }
                HStack(alignment: .center, spacing: 10) {
                    TextField("Ask Jarvis or type a command…", text: $draft).textFieldStyle(.plain).focused($focused)
                        .onSubmit { submit() }.accessibilityLabel("Ask Jarvis")
                    if jarvis.busy {
                        Button("Stop") { jarvis.cancel() }.buttonStyle(JarvisPlainButtonStyle()).foregroundStyle(OLED.offline)
                    } else {
                        Button(action: submit) { Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(OLED.accent) }
                            .buttonStyle(JarvisPlainButtonStyle()).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Send to Jarvis")
                    }
                }.padding(16).background(OLED.accent.opacity(0.035), in: JarvisPanel(cut: 12))
                    .overlay(JarvisPanel(cut: 12).stroke(OLED.accent.opacity(focused ? 0.65 : 0.3), lineWidth: 1))
                    .shadow(color: OLED.accent.opacity(focused ? 0.08 : 0), radius: 12)
                Text("Demo mode: no AI account is connected. Messages and preferences stay in this session; external commands are disabled.")
                    .font(.system(size: 10)).foregroundStyle(OLED.muted).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(20)
        }.frame(minWidth: 460, maxWidth: .infinity, minHeight: embedded ? 360 : 560, maxHeight: .infinity).background(OLED.canvas).foregroundStyle(OLED.text).tint(OLED.accent).preferredColorScheme(.dark)
            .onAppear { focused = true }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("jarvis.focusComposer"))) { _ in focused = false; DispatchQueue.main.async { focused = true } }
            .task { await jarvis.prepare(state: state) }
            .sheet(isPresented: $preferences) { JarvisPreferences(jarvis: jarvis) }
    }
    private func conversationCard(_ turn: JarvisTurn) -> some View {
        let user = turn.role == "user"
        let fill: Color = user ? Color.white.opacity(0.035) : OLED.accent.opacity(0.025)
        let border: Color = user ? Color.white.opacity(0.09) : OLED.accent.opacity(0.15)
        return VStack(alignment: .leading, spacing: 9) {
                                Text(turn.role == "user" ? "You" : "Jarvis").font(.system(size: 9, weight: .medium, design: .monospaced)).kerning(1.5)
                                    .foregroundStyle(turn.role == "user" ? OLED.muted : OLED.accent)
                                Text(turn.text).font(.system(size: 14)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                ForEach(turn.actions) { action in
                                    Button { jarvis.run(action, state: state) } label: {
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: action.kind == "start" ? "power" : action.kind == "prepare" ? "square.stack.3d.up" : action.kind == "focus" ? "scope" : "arrow.up.forward")
                                            Text(jarvis.actionLabel(action)).multilineTextAlignment(.leading).lineLimit(3)
                                            Spacer(minLength: 0)
                                        }.font(.callout).padding(11).foregroundStyle(OLED.accent)
                                            .background(OLED.accent.opacity(0.07), in: JarvisPanel(cut: 6)).overlay(JarvisPanel(cut: 6).stroke(OLED.accent.opacity(0.2), lineWidth: 1))
                                    }.buttonStyle(JarvisPlainButtonStyle()).disabled(jarvis.busy)
                                }
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(fill, in: JarvisPanel())
                                .overlay(JarvisPanel().stroke(border, lineWidth: 1))
                                .padding(.leading, turn.role == "user" ? 28 : 0)
                                .padding(.trailing, turn.role == "user" ? 0 : 12)
                                .id(turn.id)
    }
    private func suggestion(_ text: String) -> some View {
        Button(text) { jarvis.send(text, state: state) }.font(.system(size: 10, weight: .medium)).buttonStyle(JarvisPlainButtonStyle())
            .padding(8).background(OLED.accent.opacity(0.035), in: JarvisPanel(cut: 5)).overlay(JarvisPanel(cut: 5).stroke(OLED.accent.opacity(0.18), lineWidth: 1)).disabled(jarvis.busy)
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
            Text("Jarvis preferences").font(.title3.bold())
            Text("What should Jarvis remember?").font(.headline)
            Text("Add preferences or context you want included in AI conversations. You can also type ‘remember that…’ in chat.").font(.callout).foregroundStyle(OLED.muted)
            TextEditor(text: $notes).font(.body).frame(height: 180).scrollContentBackground(.hidden).padding(10).background(OLED.surface)
                .accessibilityLabel("Jarvis preferences")
            Text("\(notes.count) / 4000 characters").font(.caption).foregroundStyle(OLED.muted)
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Save") { jarvis.history.notes = notes; jarvis.save(); dismiss() }.disabled(notes.count > 4000) }
        }.padding(20).frame(width: 460).background(OLED.canvas).foregroundStyle(OLED.text).preferredColorScheme(.dark)
            .onAppear { notes = jarvis.history.notes }
    }
}
