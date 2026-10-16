# Architecture

Jarvis for macOS is a standalone Swift Package Manager executable target (`JarvisDemo` / `Jarvis.app`) built with **SwiftUI** and **AppKit** for macOS 13.0+ with zero external package dependencies.

## Module Layout

| File | Responsibility |
| :--- | :--- |
| `DemoApp.swift` | `@main` entry point supporting interactive app launch, `--demo` fixture mode, `--check` verification suite, and `--render <dir>` deterministic PNG screenshot rendering. |
| `JarvisHome.swift` | Primary 5-pillar navigation shell (`Command`, `Assistant`, `Quotas`, `Dev Env`, `Launchers`, `AI Spend`), top status bar, Command Center overview, Dev Environment page, and Quick Launchers grid. |
| `AIQuotas.swift` | `AIQuotaStore`, `CircularQuotaRing`, `WorkspaceStatusStrip`, `AIQuotaPanel` popover, and the full `AIQuotasDashboardPage` (Claude 5h/Weekly, OpenAI Codex, and local GGUF models table). |
| `AIQuotaReaders.swift` | Zero-dependency local readers for Claude Code OAuth credentials (macOS Keychain / `.claude/.credentials.json`) and OpenAI Codex usage windows (`.codex/auth.json` + session JSONL fallback). |
| `Infrastructure.swift` | `MacTelemetry` (native Darwin `sysctlbyname`, `getloadavg`, Mach `host_statistics64`, `ProcessInfo`, and `FileManager`), non-blocking BSD socket `DevPortService` scanner, and local Ollama `/api/tags` model discovery. |
| `JarvisView.swift` | Local Ollama AI Assistant interface with model selector pills, engineering mode presets, streaming response cards, and executable workspace action buttons. |
| `DemoStores.swift` | `JarvisStore` (streaming `127.0.0.1:11434/api/generate` client with live system telemetry injection and local Git repository scanner) and `InboxStore` (subscription & workspace alerts). |
| `Subscriptions.swift` | `SubscriptionStore` and `SubscriptionsPage` for tracking AI & developer cloud subscriptions with 1-click templates and 30-day renewal timelines. |
| `OrbitComponents.swift` | Subscription domain models, multi-currency FX normalization (`USD`, `EUR`, `GBP`, `MAD`), backup validation, and service logo resolution. |
| `FloatingWidget.swift` | Always-on non-activating `NSPanel` floating HUD (`⌥⌘J`), `NSStatusItem` menu bar controller, and `FloatingQuickLaunch` popover for active ports and launchers. |
| `AppState.swift` | Workspace configuration store managing links, files, groups, Chrome profile detection, and first-launch macOS developer app discovery (`/Applications/Cursor.app`, `Xcode.app`, `VS Code`, etc.). |
| `Model.swift` | Pure transformation functions for tiles, groups, URL normalization, localhost detection, and workspace validation. |
| `Storage.swift` | Atomic persistence in `~/Library/Application Support/Jarvis/` with automatic `.backup` rotation and corruption recovery, plus isolated temporary directories in `--demo` mode. |
| `HomeDesk.swift` | Engineering Focus Queue (`HomeDeskStore`), priority checklist, and recent launcher history. |
| `TileView.swift` | Specular dark-glass launcher cards (`TileCard`), native `NSWorkspace.shared.icon(forFile:)` file/app icon rendering, and semantic developer badges. |
| `MissionControl.swift` | `MissionSource`, `MissionProject`, and `ProjectSetup` models for local dev servers and Git repositories. |
| `Diagnostics.swift` | `DiagnosticJournal` actor and `DiagnosticsPanel` sheet logging Darwin kernel, port scanner, and OAuth quota check timings. |
| `InboxModel.swift` & `InboxPanel.swift` | Unread alert archive and floating desktop notification banners. |
| `DarijaLatin.swift` | Deterministic Arabic/Darija-to-Latin transliteration utility tested by `CoreTests`. |
| `SampleData.swift` & `DemoFixtures.swift` | Realistic AI & developer stack fixtures used exclusively when launched with `--demo`, `--render`, or `--check`. |
| `DemoChecks.swift` | Self-contained domain invariant and telemetry verification suite (`swift run JarvisDemo --check`). |

## Live Mode vs. Demo Mode (`AppMode.isDemo`)

- **Live Mode (Default in `Jarvis.app` and `swift run Jarvis`):**
  - Persists configuration, focus tasks, chat history, and subscriptions to `~/Library/Application Support/Jarvis/`.
  - Auto-discovers installed macOS developer IDEs/terminals in `/Applications` and local Git repositories in common workspace folders (`~/Developer`, `~/Projects`, `~/Code`, `~/GitHub`).
  - Reads live hardware telemetry from the Darwin kernel, probes `127.0.0.1` developer ports via BSD sockets, queries `127.0.0.1:11434` for local Ollama models and streaming chat, and reads local Claude/Codex OAuth usage windows.
- **Demo Mode (`--demo`, `--render`, `--check`):**
  - Uses an isolated temporary directory and deterministic developer/AI stack fixtures (`SampleData.swift`) so automated CI checks and screenshot rendering never touch personal files or require active logins.
