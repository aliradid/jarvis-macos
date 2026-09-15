import Foundation
import SwiftUI

struct MachineHealth: Identifiable {
    var id: String; var name: String; var subtitle: String; var online: Bool
    var memory: String = "—"; var load: String = "—"; var disk: String = "—"
}
struct ConnectionHealth: Identifiable {
    var id: String; var name: String; var detail: String; var healthy: Bool?
}
@MainActor final class InfrastructureStore: ObservableObject {
    static let shared = InfrastructureStore()
    @Published var machines: [MachineHealth] = []
    @Published var connections: [ConnectionHealth] = []
    @Published var refreshing = false
    @Published var updated: Date?
    init() { machines = SampleData.machines; connections = SampleData.connections; updated = Date() }
    func refresh() async { updated = Date() }
}

struct InfrastructurePanel: View {
    @ObservedObject var store: InfrastructureStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Machines").font(.system(size: 16, weight: .medium)); Spacer(); Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(JarvisPlainButtonStyle()).disabled(store.refreshing).accessibilityLabel("Refresh infrastructure") }
            VStack(spacing: 0) {
                HStack { Text("DEVICE").frame(maxWidth: .infinity, alignment: .leading); Text("MEMORY").frame(width: 104, alignment: .trailing); Text("LOAD · 1M").frame(width: 66, alignment: .trailing); Text("DISK USED").frame(width: 76, alignment: .trailing) }.font(.system(size: 10, weight: .medium)).foregroundStyle(OLED.muted).padding(.bottom, 4)
                if store.machines.isEmpty { Text("Checking your Mac and VPS…").foregroundStyle(OLED.muted).padding(.vertical, 8) }
                ForEach(store.machines) { machine in
                    HStack(spacing: 12) {
                        Image(systemName: machine.id == "mac" ? "desktopcomputer" : "server.rack").font(.system(size: 19, weight: .light)).frame(width: 32)
                        VStack(alignment: .leading, spacing: 5) { HStack { Text(machine.name).font(.system(size: 15, weight: .medium)).lineLimit(1); Circle().fill(machine.online ? OLED.online : OLED.offline).frame(width: 6, height: 6) }; Text(machine.online ? machine.subtitle : "SSH unreachable").font(.system(size: 11)).foregroundStyle(OLED.muted) }.frame(maxWidth: .infinity, alignment: .leading)
                        Text(machine.memory).frame(width: 104, alignment: .trailing)
                        Text(machine.load).frame(width: 66, alignment: .trailing)
                        Text(machine.disk).frame(width: 76, alignment: .trailing)
                    }.font(.system(size: 14, design: .monospaced)).padding(.vertical, 8)
                    Divider()
                }
            }
            HStack { Text("Connections").font(.system(size: 16, weight: .medium)); Spacer(); Text("\(store.connections.filter { $0.healthy == true }.count) / \(store.connections.count) healthy").foregroundStyle(OLED.muted).font(.callout) }
            VStack(spacing: 0) {
                ForEach(store.connections) { link in
                    HStack(spacing: 14) {
                        Image(systemName: link.id == "tunnel" ? "point.3.connected.trianglepath.dotted" : link.id == "mobile" ? "simcard" : "network").font(.system(size: 17, weight: .light)).frame(width: 32)
                        VStack(alignment: .leading, spacing: 5) { Text(link.name).font(.system(size: 14, weight: .medium)); Text(link.detail).font(.system(size: 11)).foregroundStyle(OLED.muted) }
                        Spacer()
                        Text(link.healthy == true ? "Connected" : "Unavailable").font(.system(size: 12)).foregroundStyle(link.healthy == true ? OLED.online : OLED.offline)
                    }.padding(.vertical, 7)
                    Divider()
                }
            }
            HStack { Circle().fill(store.refreshing ? OLED.offline : OLED.online).frame(width: 5, height: 5); Text(store.refreshing ? "Checking connections…" : "Checked \(store.updated?.formatted(date: .omitted, time: .shortened) ?? "—") · Sample readings") }.font(.system(size: 10)).foregroundStyle(OLED.muted)
        }.padding(18).help("Memory shows Mac capacity and VPS usage. Load is a one-minute load average, not CPU percentage.")

    }
}
