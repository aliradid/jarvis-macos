import Foundation

// Curated AI & Developer stack fixtures; all values are fictional samples.
enum SampleData {
    static let now = Date()
    static func day(_ offset: Int) -> Date { Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: now))! }
    static let rates = [("EUR", 0.9), ("GBP", 0.8), ("MAD", 10.0)].map { OrbitFXRate(date: isoDayString(now), base: "USD", quote: $0.0, rate: $0.1) }

    static let subscriptionFixtures: [(name: String, amount: Double, currency: String, cycle: String, category: String, status: String, offset: Int)] = [
        ("Claude Max 20x", 200.0, "USD", "Monthly", "Software", "Active", 4),
        ("ChatGPT Pro 20x", 200.0, "USD", "Monthly", "Software", "Active", 11),
        ("Cursor Pro", 20.0, "USD", "Monthly", "Software", "Active", 6),
        ("GitHub Copilot Pro+", 39.0, "USD", "Monthly", "Software", "Active", 14),
        ("AWS Cloud Compute", 45.0, "USD", "Monthly", "Cloud & storage", "Active", 18),
        ("Vercel Pro", 20.0, "USD", "Monthly", "Cloud & storage", "Active", 9),
        ("ElevenLabs Creator", 22.0, "USD", "Monthly", "Software", "Active", 15),
        ("Supabase Pro", 25.0, "USD", "Monthly", "Cloud & storage", "Active", 21),
        ("Google AI Pro 5 TB", 20.0, "USD", "Monthly", "Cloud & storage", "Active", 19),
        ("Linear Plus", 12.0, "USD", "Monthly", "Software", "Active", 25),
        ("Raycast Pro + AI", 16.0, "USD", "Monthly", "Utilities", "Active", 7),
        ("Adobe Creative Cloud Pro", 54.0, "EUR", "Monthly", "Software", "Active", 17),
        ("Kimi AI Research", 15.0, "USD", "Monthly", "Software", "Trial", 3),
        ("CleanMyMac X", 96.0, "USD", "Yearly", "Utilities", "Active", 27),
        ("iCloud+ 2 TB", 10.0, "USD", "Monthly", "Cloud & storage", "Active", 12),
        ("Cloudflare Workers Paid", 5.0, "USD", "Monthly", "Cloud & storage", "Ending", 5)
    ]

    static var subscriptions: [OrbitSubscription] {
        subscriptionFixtures.enumerated().map { index, spec in
            var item = OrbitSubscription(
                name: spec.name,
                amount: spec.amount,
                currency: spec.currency,
                cycle: spec.cycle,
                date: day(spec.offset),
                category: spec.category,
                status: spec.status
            )
            item.id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!
            item.notes = "Developer & AI stack plan. Amount, dates, billing cycle and status are fictional demonstration values."
            item.priceKnown = spec.status != "Needs review"
            item.dateKnown = spec.status != "Needs review"
            item.dateBasis = "Confirmed"
            item.priceBasis = "Confirmed"
            return item
        }
    }

    static var sources: [MissionSource] {
        [
            MissionSource(id: "nextjs", name: "Next.js App Router", root: "apps/web", port: 3000, primaryLanguage: "typescript"),
            MissionSource(id: "vite", name: "Vite Design System", root: "packages/ui", port: 5173, primaryLanguage: "typescript"),
            MissionSource(id: "fastapi", name: "FastAPI Agent Core", root: "services/inference", port: 8000, primaryLanguage: "python"),
            MissionSource(id: "ollama", name: "Ollama LLM Server", root: "runtime/ollama", port: 11434, primaryLanguage: "go"),
            MissionSource(id: "postgres", name: "PostgreSQL 16 + pgvector", root: "infra/postgres", port: 5432, primaryLanguage: "sql"),
            MissionSource(id: "docker", name: "Docker Engine API", root: "infra/containers", port: 8080, primaryLanguage: "go")
        ]
    }

    static var devPorts: [DevPortService] {
        [
            DevPortService(port: 3000, name: "Next.js App Router", stack: "TypeScript · React 19 · Turbopack", icon: "globe.americas.fill", online: true, responseMs: 4),
            DevPortService(port: 5173, name: "Vite UI Workbench", stack: "Vite 6 · Tailwind CSS · Storybook", icon: "flame.fill", online: true, responseMs: 2),
            DevPortService(port: 8000, name: "FastAPI Agent Core", stack: "Python 3.12 · Uvicorn · Pydantic v2", icon: "bolt.horizontal.circle.fill", online: true, responseMs: 6),
            DevPortService(port: 11434, name: "Ollama Local Runtime", stack: "Metal GPU · llama3.2 + deepseek-r1", icon: "cpu.fill", online: true, responseMs: 1),
            DevPortService(port: 5432, name: "PostgreSQL 16 Vector DB", stack: "pgvector · HNSW index · Local", icon: "cylinder.split.1x2.fill", online: true, responseMs: 3),
            DevPortService(port: 6379, name: "Redis 7 Session Store", stack: "In-memory · Pub/Sub queue", icon: "memorychip.fill", online: true, responseMs: 1),
            DevPortService(port: 8080, name: "Docker Compose Gateway", stack: "OrbStack · 4 containers active", icon: "shippingbox.fill", online: false, responseMs: 0)
        ]
    }

    static var ollamaModels: [OllamaLocalModel] {
        [
            OllamaLocalModel(name: "llama3.2:latest", family: "LLAMA 3.2", parameterSize: "3.2B", quantization: "Q4_K_M", sizeGB: 2.0, warm: true),
            OllamaLocalModel(name: "deepseek-r1:14b", family: "DEEPSEEK R1", parameterSize: "14.8B", quantization: "Q4_K_M", sizeGB: 9.0, warm: true),
            OllamaLocalModel(name: "qwen2.5-coder:32b", family: "QWEN 2.5", parameterSize: "32.5B", quantization: "Q4_K_M", sizeGB: 19.8, warm: false),
            OllamaLocalModel(name: "nomic-embed-text:latest", family: "NOMIC BERT", parameterSize: "137M", quantization: "F16", sizeGB: 0.3, warm: true)
        ]
    }

    static var browserProfiles: [Tile] {
        [
            Tile(id: "dev:github", kind: .link, label: "GitHub PRs", detectedLabel: "GitHub", subtitle: "Pull requests & CI", invocation: .openURL(url: "https://github.com"), customImage: nil, iconSourcePath: nil),
            Tile(id: "dev:cursor", kind: .link, label: "Cursor AI IDE", detectedLabel: "Cursor", subtitle: "Workspace editor", invocation: .openURL(url: "cursor://"), customImage: nil, iconSourcePath: nil),
            Tile(id: "dev:claude", kind: .link, label: "Claude Console", detectedLabel: "Claude", subtitle: "Anthropic workbench", invocation: .openURL(url: "https://claude.ai"), customImage: nil, iconSourcePath: nil),
            Tile(id: "dev:openai", kind: .link, label: "OpenAI Platform", detectedLabel: "OpenAI", subtitle: "Codex & API logs", invocation: .openURL(url: "https://chatgpt.com"), customImage: nil, iconSourcePath: nil),
            Tile(id: "dev:terminal", kind: .link, label: "Ghostty / iTerm", detectedLabel: "Terminal", subtitle: "Zsh + tmux session", invocation: .openURL(url: "terminal://"), customImage: nil, iconSourcePath: nil),
            Tile(id: "dev:localhost", kind: .link, label: "Localhost :3000", detectedLabel: "Next.js", subtitle: "http://127.0.0.1:3000", invocation: .openURL(url: "http://127.0.0.1:3000"), customImage: nil, iconSourcePath: nil)
        ]
    }

    static var workspace: Config {
        var c = Config()
        let files = [
            ("model-weights", "Models/llama-3.2-3b.gguf", "LLaMA 3.2 Weights"),
            ("api-spec", "Specs/openapi-v3.json", "OpenAPI 3.1 Spec"),
            ("system-arch", "Design/Architecture.sketch", "System Topology"),
            ("db-schema", "Database/schema.sql", "pgvector Schema"),
            ("swift-pkg", "Sources/Package.swift", "SwiftPM Manifest"),
            ("env-config", "Config/production.json", "Cluster Config")
        ]
        for f in files {
            let file = FileEntry(id: f.0, path: f.1)
            c.files.append(file); c = renamed(c, id: "file:" + file.id, label: f.2)
        }
        for source in sources {
            c.links.append(LinkEntry(id: source.id, url: "http://127.0.0.1:\(source.port)"))
            c = renamed(c, id: "link:" + source.id, label: source.name)
        }
        return c
    }

    static var projects: [MissionProject] {
        [
            ("jarvis-macos", "running", "main · 98% CI Pass", "Native Swift 6 & AppKit AI Command Center for macOS", "Swift 6.0"),
            ("neural-router-api", "running", "feat/mcp-tools · :8000", "High-throughput FastAPI + Ollama tool-calling gateway", "Python 3.12"),
            ("design-system-web", "finished", "v2.4.0 · :3000", "Next.js 15 App Router dashboard with zero-runtime tokens", "TypeScript"),
            ("vector-indexer", "review", "PR #42 · Benchmark", "Hybrid BM25 + pgvector HNSW semantic code search engine", "Rust / SQL")
        ].enumerated().map { i, r in
            MissionProject(
                id: "project-\(i)",
                sourceID: i == 0 ? "nextjs" : "fastapi",
                source: "GitHub · Local Clone",
                language: r.4,
                title: r.0,
                folder: "Workspace/\(r.0)",
                status: r.1,
                stage: r.2,
                detail: r.3,
                modified: now.addingTimeInterval(Double(-i * 1800)),
                video: r.1 == "finished" ? "build-ok" : nil,
                thumbnails: []
            )
        }
    }

    static var quotas: [AIQuota] {
        [
            AIQuota(id: "claude:session", provider: "claude", window: "5h", remaining: 76, reset: now.addingTimeInterval(3 * 3600 + 18 * 60), updated: now, live: true),
            AIQuota(id: "claude:weekly", provider: "claude", window: "Weekly", remaining: 64, reset: day(5), updated: now, live: true),
            AIQuota(id: "openai:weekly", provider: "openai", window: "Weekly", remaining: 71, reset: day(4), updated: now, live: true)
        ]
    }

    static let machines = [
        MachineHealth(id: "mac", name: "MacBook Pro 16\"", subtitle: "Apple M3 Max · macOS 15.2", online: true, memory: "18.6 / 36 GB", load: "1.42", disk: "41%")
    ]
    static let connections = [
        ConnectionHealth(id: "ollama", name: "Ollama Metal Runtime", detail: "127.0.0.1:11434 · 4 GGUF models", healthy: true),
        ConnectionHealth(id: "claude", name: "Anthropic OAuth Session", detail: "Keychain · Claude Code Max 20x", healthy: true),
        ConnectionHealth(id: "codex", name: "OpenAI Codex Session", detail: "~/.codex/auth.json · Pro 20x", healthy: true)
    ]
}
