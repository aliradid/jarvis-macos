# Roadmap

Jarvis for macOS is an open-source, zero-cost (`$0`) native SwiftUI & AppKit **AI & Developer Command Center** for macOS 13+.

## Shipped (`v2.0.0`)

- **5-Pillar Developer & AI Command Center (`JarvisHome.swift`):**
  1. **Command Center (`Overview`):** Unified dashboard combining circular AI quota gauges, Darwin hardware telemetry, listening localhost ports, keyboard-driven IDE launchers (`⌘1`–`⌘6`), active Git repositories, and engineering focus tasks.
  2. **Local Ollama AI Assistant (`JarvisView.swift` & `DemoStores.swift`):** Streaming local LLM chat (`127.0.0.1:11434`) with model switching (`llama3.2:latest`, `deepseek-r1:14b`, `qwen2.5-coder:32b`), mode presets (*Architecture & Code*, *Quota & Burn Advisor*, *Shell & DevOps*), live system telemetry injection, and executable workspace actions.
  3. **AI Quotas & Local Models (`AIQuotas.swift` & `AIQuotaReaders.swift`):** Live OAuth token window readers for Claude Code (`5h` sliding session + `7d` rolling weekly cap via macOS Keychain / `.credentials.json`) and OpenAI Codex (weekly compute window via `.codex/auth.json` + JSONL session logs), alongside an inventory of installed local Ollama GGUF models.
  4. **Dev Environment & Ports (`Infrastructure.swift` & `MissionControl.swift`):** Non-blocking BSD socket port scanner probing standard local developer servers (`:3000`, `:5173`, `:8000`, `:11434`, `:5432`, `:6379`, `:8080`) with response-time measurements and auto-discovery of local Git repositories.
  5. **AI & Cloud Spend (`Subscriptions.swift` & `OrbitComponents.swift`):** Recurring subscription ledger purpose-built for AI and cloud engineering stacks (`Claude Max`, `ChatGPT Pro`, `Cursor`, `Copilot`, `AWS`, `Vercel`, `Supabase`) with live multi-currency normalization (`USD`, `EUR`, `GBP`, `MAD`) and 1-click stack templates.
- **Always-On Floating HUD & Menu Bar (`FloatingWidget.swift`):**
  - Global `⌥⌘J` shortcut and `NSStatusItem` menu bar icon (`sparkles`) with live quota & hardware summary.
  - Non-activating floating `NSPanel` pill across all macOS Spaces with interactive AI Quota, Telemetry, and Quick-Launch popovers.
- **Zero-Data-Loss Local Persistence (`Storage.swift`):**
  - Atomic writes with automatic `.backup` preservation and corruption recovery in `~/Library/Application Support/Jarvis/`.

## Planned (`v2.1+`)

- **Custom Port Watchlist:** User-configurable TCP port definitions and custom health-check paths in `config.json`.
- **Additional AI Provider Readers:** Optional local usage readers for Cursor, Windsurf, and OpenRouter API keys.
- **Menu Bar Sparklines:** Optional inline CPU/Memory mini-sparkline in the macOS menu bar item.
