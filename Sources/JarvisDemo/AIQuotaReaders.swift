import Foundation

enum AIQuotaReaders {
    static func matchesWindow(_ label: String, weekly: Bool) -> Bool {
        let name = label.lowercased()
        if weekly { return name == "weekly" || name == "codex · weekly" }
        return name.contains("5 hours") || name.contains("5h") || name.hasPrefix("session")
    }

    // MARK: - Claude Reader
    static func fetchClaudeQuotas() async throws -> [AIQuota] {
        guard let token = getClaudeToken() else {
            throw LaunchpadError(message: "Claude token not found in ~/.claude/.credentials.json or Keychain")
        }
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            throw LaunchpadError(message: "Invalid Claude usage endpoint")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/0.2.29", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw LaunchpadError(message: "Claude API returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        struct WindowInfo: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        struct UsageResponse: Decodable {
            let five_hour: WindowInfo?
            let seven_day: WindowInfo?
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
        var results: [AIQuota] = []
        let now = Date()

        if let fiveHour = usage.five_hour, let util = fiveHour.utilization {
            let resetDate = fiveHour.resets_at.flatMap { isoFormatter.date(from: $0) }
            results.append(AIQuota(id: "claude:session", provider: "claude", window: "5h", remaining: max(0, 100 - util), reset: resetDate, updated: now, live: true))
        }
        if let sevenDay = usage.seven_day, let util = sevenDay.utilization {
            let resetDate = sevenDay.resets_at.flatMap { isoFormatter.date(from: $0) }
            results.append(AIQuota(id: "claude:weekly", provider: "claude", window: "Weekly", remaining: max(0, 100 - util), reset: resetDate, updated: now, live: true))
        }
        return results
    }

    private static func getClaudeToken() -> String? {
        if let envToken = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"] {
            if let data = envToken.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let oauth = obj["claudeAiOauth"] as? [String: Any],
               let token = oauth["accessToken"] as? String {
                return token
            }
            return envToken
        }

        let credPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: credPath),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let oauth = obj["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String {
            return token
        }

        // Try reading from macOS Keychain
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        if (try? process.run()) != nil {
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    if let rawData = output.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
                       let oauth = obj["claudeAiOauth"] as? [String: Any],
                       let token = oauth["accessToken"] as? String {
                        return token
                    }
                    return output
                }
            }
        }
        return nil
    }

    // MARK: - OpenAI / Codex Reader
    static func fetchCodexQuotas() async throws -> [AIQuota] {
        guard let token = getCodexToken() else {
            throw LaunchpadError(message: "Codex token not found in ~/.codex/auth.json")
        }
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else {
            throw LaunchpadError(message: "Invalid Codex usage endpoint")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw LaunchpadError(message: "Codex API returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        struct WindowLimit: Decodable {
            let used_percent: Double?
            let reset_after_seconds: Double?
            let reset_at: Double?
        }
        struct RateLimit: Decodable {
            let primary_window: WindowLimit?
            let secondary_window: WindowLimit?
        }
        struct CodexUsageResponse: Decodable {
            let rate_limit: RateLimit?
        }

        let usage = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
        var results: [AIQuota] = []
        let now = Date()

        if let window = usage.rate_limit?.primary_window, let util = window.used_percent {
            var resetDate: Date? = nil
            if let at = window.reset_at {
                resetDate = Date(timeIntervalSince1970: at)
            } else if let after = window.reset_after_seconds {
                resetDate = now.addingTimeInterval(after)
            }
            results.append(AIQuota(id: "openai:weekly", provider: "openai", window: "Weekly", remaining: max(0, 100 - util), reset: resetDate, updated: now, live: true))
        }
        return results
    }

    private static func getCodexToken() -> String? {
        if let token = ProcessInfo.processInfo.environment["CODEX_ACCESS_TOKEN"] {
            return token
        }
        let authPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: authPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let token = obj["access_token"] as? String { return token }
        if let tokens = obj["tokens"] as? [String: Any], let token = tokens["access_token"] as? String { return token }
        return nil
    }
}
