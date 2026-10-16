# Source Fidelity & Runtime Modes

Jarvis for macOS is engineered so that every view in the application operates seamlessly in both **Live macOS Runtime Mode** (`Jarvis.app` / `swift run Jarvis`) and **Deterministic Showcase Mode** (`--demo` / `--render` / `--check`).

## Core Subsystems

| Subsystem | Live Runtime Mode (`!AppMode.isDemo`) | Showcase / CI Mode (`AppMode.isDemo`) |
| :--- | :--- | :--- |
| **AI Token Quotas (`AIQuotaStore`)** | Reads live Claude Code (`5h` + `Weekly`) and OpenAI Codex (`Weekly`) utilization from macOS Keychain, `~/.claude/.credentials.json`, and `~/.codex/` | Supplies realistic developer quota windows (`76%` Claude 5h, `64%` Claude Weekly, `71%` Codex Weekly) |
| **Hardware Telemetry (`MacTelemetry`)** | Queries Darwin `sysctlbyname`, `getloadavg`, `host_statistics64`, and `FileManager` for real CPU load, Unified Memory, NVMe disk, and uptime | Supplies deterministic Apple M3 Max telemetry for reproducible screenshot rendering (`MacTelemetry.readLive()` is also verified in `--check`) |
| **Localhost Port Scanner (`InfrastructureStore`)** | Probes `127.0.0.1` ports (`3000`, `5173`, `8000`, `11434`, `5432`, `6379`, `8080`) using non-blocking BSD sockets (`connect` + `poll`) | Supplies representative listening dev server states with millisecond latencies |
| **Local Ollama Assistant (`JarvisStore`)** | Discovers installed GGUF models via `127.0.0.1:11434/api/tags` and streams responses via `/api/generate` with live system telemetry context | Pre-populates realistic multi-turn architecture & quota diagnostics for `--render` |
| **Git Repositories & Launchers (`AppState`)** | Auto-detects installed developer apps in `/Applications` (`Cursor`, `VS Code`, `Xcode`, `Ghostty`, `iTerm`, `Warp`, `Docker`) and scans local Git repositories | Supplies curated developer launchers and sample repositories |
| **AI & Cloud Spend (`SubscriptionStore`)** | Persists subscriptions to `~/Library/Application Support/Jarvis/subscriptions.json` and fetches live FX rates from `open.er-api.com` | Uses isolated in-memory developer subscription fixtures and reference FX rates |
