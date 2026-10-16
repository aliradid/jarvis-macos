import Foundation
import SwiftUI
import Darwin

struct MacTelemetry: Equatable {
    var hostName: String = "MacBook Pro"
    var chipName: String = "Apple M3 Max"
    var osVersion: String = "macOS 15.2"
    var cpuUsagePercent: Double = 18.4
    var cpuCores: Int = 14
    var loadAverage1m: Double = 1.42
    var memoryUsedGB: Double = 18.6
    var memoryTotalGB: Double = 36.0
    var diskUsedGB: Double = 412.0
    var diskTotalGB: Double = 1000.0
    var uptimeString: String = "6d 14h"
    var thermalState: String = "Nominal"

    var memoryPercent: Double {
        guard memoryTotalGB > 0 else { return 0 }
        return min(100, max(0, (memoryUsedGB / memoryTotalGB) * 100))
    }
    var diskPercent: Double {
        guard diskTotalGB > 0 else { return 0 }
        return min(100, max(0, (diskUsedGB / diskTotalGB) * 100))
    }

    static let sample = MacTelemetry()

    static func capture() -> MacTelemetry {
        if AppMode.isDemo { return .sample }
        var info = MacTelemetry()
        let proc = ProcessInfo.processInfo
        info.hostName = Host.current().localizedName ?? proc.hostName
        info.cpuCores = proc.activeProcessorCount

        let os = proc.operatingSystemVersion
        info.osVersion = "macOS \(os.majorVersion).\(os.minorVersion)"

        if let brand = sysctlString("machdep.cpu.brand_string"), !brand.isEmpty {
            info.chipName = brand
        } else {
            info.chipName = "Apple Silicon (\(info.cpuCores)-core)"
        }

        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) > 0 {
            info.loadAverage1m = loads[0]
            let estimated = (loads[0] / Double(max(1, info.cpuCores))) * 100.0
            info.cpuUsagePercent = min(100, max(2.0, estimated))
        }

        let totalBytes = Double(proc.physicalMemory)
        info.memoryTotalGB = totalBytes / 1_073_741_824.0
        if let usedBytes = currentMemoryUsedBytes() {
            info.memoryUsedGB = min(info.memoryTotalGB, Double(usedBytes) / 1_073_741_824.0)
        } else {
            info.memoryUsedGB = info.memoryTotalGB * 0.52
        }

        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let total = (attrs[.systemSize] as? NSNumber)?.doubleValue,
           let free = (attrs[.systemFreeSize] as? NSNumber)?.doubleValue {
            info.diskTotalGB = total / 1_000_000_000.0
            info.diskUsedGB = max(0, (total - free) / 1_000_000_000.0)
        }

        let up = Int(proc.systemUptime)
        let days = up / 86400
        let hours = (up % 86400) / 3600
        let mins = (up % 3600) / 60
        info.uptimeString = days > 0 ? "\(days)d \(hours)h" : "\(hours)h \(mins)m"

        switch proc.thermalState {
        case .nominal: info.thermalState = "Nominal"
        case .fair: info.thermalState = "Warm"
        case .serious: info.thermalState = "Elevated"
        case .critical: info.thermalState = "Throttling"
        @unknown default: info.thermalState = "Nominal"
        }
        return info
    }

    private static func sysctlString(_ key: String) -> String? {
        var size: Int = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &buf, &size, nil, 0) == 0 else { return nil }
        return String(cString: buf)
    }

    private static func currentMemoryUsedBytes() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        return active + wired + compressed
    }
}

struct DevPortService: Identifiable, Equatable {
    var id: String { "\(port)" }
    let port: Int
    let name: String
    let stack: String
    let icon: String
    var online: Bool
    var responseMs: Int
    var url: String { "http://127.0.0.1:\(port)" }
}

struct OllamaLocalModel: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let family: String
    let parameterSize: String
    let quantization: String
    let sizeGB: Double
    let warm: Bool
}

struct MachineHealth: Identifiable {
    var id: String; var name: String; var subtitle: String; var online: Bool
    var memory: String = "—"; var load: String = "—"; var disk: String = "—"
}
struct ConnectionHealth: Identifiable {
    var id: String; var name: String; var detail: String; var healthy: Bool?
}

@MainActor final class InfrastructureStore: ObservableObject {
    static let shared = InfrastructureStore()
    @Published var telemetry: MacTelemetry = .capture()
    @Published var devPorts: [DevPortService] = []
    @Published var ollamaModels: [OllamaLocalModel] = []
    @Published var machines: [MachineHealth] = []
    @Published var connections: [ConnectionHealth] = []
    @Published var refreshing = false
    @Published var updated: Date?

    static let catalogPorts: [(Int, String, String, String)] = [
        (3000, "Next.js App Router", "TypeScript · React 19", "globe"),
        (5173, "Vite HMR Dev Server", "Vite · Tailwind CSS", "bolt.horizontal.fill"),
        (8000, "FastAPI Inference API", "Python 3.12 · Uvicorn", "terminal.fill"),
        (11434, "Ollama LLM Runtime", "Local GGUF · Metal GPU", "cpu.fill"),
        (5432, "PostgreSQL 16", "Database · Local cluster", "cylinder.split.1x2.fill"),
        (6379, "Redis Cache", "In-memory · Keystore", "memorychip.fill"),
        (8080, "Docker Gateway", "Containers · Bridge", "shippingbox.fill")
    ]

    init() {
        telemetry = MacTelemetry.capture()
        devPorts = SampleData.devPorts
        ollamaModels = SampleData.ollamaModels
        machines = SampleData.machines
        connections = SampleData.connections
        updated = Date()
        if !AppMode.isDemo {
            Task { await refresh() }
        }
    }

    func refresh() async {
        refreshing = true
        defer { refreshing = false; updated = Date() }
        telemetry = MacTelemetry.capture()
        if AppMode.isDemo {
            devPorts = SampleData.devPorts
            ollamaModels = SampleData.ollamaModels
            return
        }
        var scanned: [DevPortService] = []
        for (port, name, stack, icon) in Self.catalogPorts {
            let start = DispatchTime.now()
            let isUp = await Self.checkPort(port)
            let elapsed = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
            scanned.append(DevPortService(port: port, name: name, stack: stack, icon: icon, online: isUp, responseMs: isUp ? max(1, elapsed) : 0))
        }
        devPorts = scanned

        if let models = await Self.fetchOllamaModels(), !models.isEmpty {
            ollamaModels = models
        }
        machines = [
            MachineHealth(
                id: "mac",
                name: telemetry.hostName,
                subtitle: "\(telemetry.chipName) · \(telemetry.osVersion)",
                online: true,
                memory: String(format: "%.1f / %.0f GB", telemetry.memoryUsedGB, telemetry.memoryTotalGB),
                load: String(format: "%.2f", telemetry.loadAverage1m),
                disk: String(format: "%.0f%%", telemetry.diskPercent)
            )
        ]
    }

    private static func checkPort(_ port: Int) async -> Bool {
        await Task.detached(priority: .utility) {
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            guard sock >= 0 else { return false }
            defer { close(sock) }
            let flags = fcntl(sock, F_GETFL, 0)
            _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(UInt16(port).bigEndian)
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")

            let res = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if res == 0 { return true }
            guard errno == EINPROGRESS else { return false }

            var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
            let polled = poll(&pfd, 1, 120)
            guard polled > 0 else { return false }
            var soError: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(sock, SOL_SOCKET, SO_ERROR, &soError, &len)
            return soError == 0
        }.value
    }

    private static func fetchOllamaModels() async -> [OllamaLocalModel]? {
        guard let url = URL(string: "http://127.0.0.1:11434/api/tags") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 1.5)
        req.httpMethod = "GET"
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["models"] as? [[String: Any]] else { return nil }
        return list.enumerated().compactMap { idx, item in
            guard let name = item["name"] as? String else { return nil }
            let sizeBytes = (item["size"] as? NSNumber)?.doubleValue ?? 0
            let details = item["details"] as? [String: Any]
            let family = (details?["family"] as? String)?.uppercased() ?? "LLAMA"
            let params = (details?["parameter_size"] as? String) ?? "8B"
            let quant = (details?["quantization_level"] as? String) ?? "Q4_K_M"
            return OllamaLocalModel(name: name, family: family, parameterSize: params, quantization: quant, sizeGB: max(0.5, sizeBytes / 1_073_741_824.0), warm: idx == 0)
        }
    }
}

struct InfrastructurePanel: View {
    @ObservedObject var store: InfrastructureStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SYSTEM TELEMETRY & LOCAL RUNTIME").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(OLED.accent)
                    Text("\(store.telemetry.hostName) · \(store.telemetry.chipName)").font(.system(size: 16, weight: .semibold))
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(OLED.online).frame(width: 6, height: 6)
                    Text("Uptime \(store.telemetry.uptimeString)").font(.system(size: 11, design: .monospaced)).foregroundStyle(OLED.muted)
                }.padding(.horizontal, 10).padding(.vertical, 5).background(OLED.surface, in: Capsule())
                Button { Task { await store.refresh() } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 28, height: 28)
                }.buttonStyle(JarvisControlStyle()).disabled(store.refreshing).accessibilityLabel("Refresh infrastructure")
            }

            HStack(spacing: 12) {
                telemetryGaugeCard(
                    title: "CPU LOAD",
                    value: String(format: "%.0f%%", store.telemetry.cpuUsagePercent),
                    subtitle: String(format: "Load %.2f · %d cores", store.telemetry.loadAverage1m, store.telemetry.cpuCores),
                    percent: store.telemetry.cpuUsagePercent,
                    tint: OLED.accent
                )
                telemetryGaugeCard(
                    title: "UNIFIED MEMORY",
                    value: String(format: "%.1f GB", store.telemetry.memoryUsedGB),
                    subtitle: String(format: "of %.0f GB (%.0f%%)", store.telemetry.memoryTotalGB, store.telemetry.memoryPercent),
                    percent: store.telemetry.memoryPercent,
                    tint: OLED.cyan
                )
                telemetryGaugeCard(
                    title: "NVMe STORAGE",
                    value: String(format: "%.0f GB", store.telemetry.diskUsedGB),
                    subtitle: String(format: "of %.0f GB (%.0f%%)", store.telemetry.diskTotalGB, store.telemetry.diskPercent),
                    percent: store.telemetry.diskPercent,
                    tint: OLED.online
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("LISTENING LOCALHOST PORTS").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(OLED.muted)
                    Spacer()
                    let activeCount = store.devPorts.filter(\.online).count
                    Text("\(activeCount) of \(store.devPorts.count) online").font(.system(size: 11, weight: .medium)).foregroundStyle(OLED.online)
                }
                VStack(spacing: 6) {
                    ForEach(store.devPorts.prefix(5)) { svc in
                        HStack(spacing: 10) {
                            Image(systemName: svc.icon).font(.system(size: 13)).foregroundStyle(svc.online ? OLED.accent : OLED.muted).frame(width: 24, height: 24).background(OLED.raised, in: RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(svc.name).font(.system(size: 12, weight: .semibold))
                                Text(svc.stack).font(.system(size: 10)).foregroundStyle(OLED.muted)
                            }
                            Spacer()
                            Text(":" + String(svc.port)).font(.system(size: 11, weight: .semibold, design: .monospaced)).padding(.horizontal, 7).padding(.vertical, 3).background(OLED.raised, in: RoundedRectangle(cornerRadius: 5))
                            HStack(spacing: 5) {
                                Circle().fill(svc.online ? OLED.online : OLED.muted.opacity(0.4)).frame(width: 6, height: 6)
                                Text(svc.online ? "\(svc.responseMs) ms" : "Idle").font(.system(size: 11, design: .monospaced)).foregroundStyle(svc.online ? OLED.online : OLED.muted)
                            }.frame(width: 58, alignment: .trailing)
                        }.padding(.horizontal, 10).padding(.vertical, 7).background(OLED.surface, in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }

            HStack {
                Circle().fill(store.refreshing ? OLED.warning : OLED.online).frame(width: 5, height: 5)
                Text(store.refreshing ? "Scanning Darwin kernel & TCP sockets…" : "Darwin Mach telemetry · \(store.telemetry.thermalState) thermals · Updated \(store.updated?.formatted(date: .omitted, time: .shortened) ?? "now")")
            }.font(.system(size: 10)).foregroundStyle(OLED.muted)
        }
        .padding(20)
        .background(OLED.canvas)
    }

    private func telemetryGaugeCard(title: String, value: String, subtitle: String, percent: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(OLED.muted)
            Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(OLED.raised)
                    Capsule().fill(tint).frame(width: max(4, geo.size.width * CGFloat(min(100, max(0, percent)) / 100.0)))
                }
            }.frame(height: 5)
            Text(subtitle).font(.system(size: 10)).foregroundStyle(OLED.muted).lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OLED.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(OLED.border, lineWidth: 1))
    }
}
