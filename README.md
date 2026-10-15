# Jarvis for macOS

<p align="center">
  <img src="docs/images/logo.png" width="120" height="120" alt="Jarvis macOS Logo">
</p>

<h2 align="center">The OLED-dark native macOS workspace & real-time AI quota command center.</h2>

<p align="center">
  <a href="https://github.com/aliradid/jarvis-macos/releases"><img src="https://img.shields.io/github/v/release/aliradid/jarvis-macos?color=7C3AED&logo=github" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/Platform-macOS%2013%2B-black.svg?logo=apple" alt="macOS 13+"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9%2B-F05138.svg?logo=swift" alt="Swift 5.9+"></a>
  <a href="https://github.com/aliradid/jarvis-macos/actions/workflows/checks.yml"><img src="https://github.com/aliradid/jarvis-macos/actions/workflows/checks.yml/badge.svg" alt="CI Checks"></a>
</p>

<p align="center">
  <a href="https://github.com/aliradid/jarvis-macos/releases/latest">Download DMG</a> •
  <a href="#quick-install-terminal">Quick Install</a> •
  <a href="ROADMAP.md">Roadmap</a> •
  <a href="CONTRIBUTING.md">Contributing</a> •
  <a href="docs/ARCHITECTURE.md">Architecture</a>
</p>

---

Jarvis brings your active projects, browser shortcuts, recurring subscriptions, pet expenses, and real-time AI quota monitoring (Claude Code & OpenAI Codex) into a single high-performance native macOS app built with SwiftUI and AppKit.

* 🚀 **Floating HUD Widget:** Always-accessible draggable floating pill displaying live Claude session & weekly usage, Codex quotas, machine health, and quick-launch channels.
* 🤖 **Local Offline AI Assistant:** Direct connection to local [Ollama](https://ollama.com) (`127.0.0.1:11434`) with dynamic model detection (`llama3.2`, `mistral`, `deepseek-r1`). 100% private, zero token costs.
* ⚡ **Global Shortcuts & Menu Bar:** Press `⌥⌘J` anytime to toggle the floating HUD from any macOS Space, or `⌥⌘W` to bring it to front. Click the sparkles icon in the menu bar for one-click controls.
* 📊 **Live AI Usage Tracking:** Direct integration with Claude Code (`~/.claude/.credentials.json` & Keychain) and OpenAI Codex CLI (`~/.codex/auth.json`) to track remaining tokens and sliding-window resets.
* 💳 **Orbit Subscriptions:** Local-first recurring cost manager with currency normalization (USD/MAD/EUR/GBP), live exchange rates via ECB, renewal alerts, and trial countdowns.
* 🐾 **Pet Expenses:** Full monthly breakdown, category filtering, search, and native JSON backup import/export.
* 🔒 **Local & Private:** Zero telemetry, no cloud accounts required. All data persists safely in `~/Library/Application Support/Jarvis/`. Run with `--demo` anytime to explore with isolated sample fixtures.

## Workspace

![Workspace with sample projects and shortcuts](docs/images/overview.png)

The home dashboard features quick access shortcuts, design files, recent work, daily checklist, pinned actions, and items needing immediate attention.

## Floating HUD Widget

![Floating widget with sample readings](docs/images/floating-widget.png)

Choose **Widget → Show floating widget** (`⌥⌘W`) or press `⌥⌘J` to toggle. Drag the handle to reposition anywhere on screen, click quota or status indicators for deep-dive panels, or jump straight back to the main workspace.

![Original quota panel with sample values](docs/images/widget-details.png)

## Subscriptions & Finances

![Orbit subscription interface with real providers and billing data](docs/images/subscriptions.png)

The Orbit interface includes monthly and yearly USD/MAD totals, billing-cycle conversion, a renewal timeline, trials, ending plans, records needing review, search, sorting and archiving. The subscription editor retains price and date certainty, reminder settings, notes and source fields.

## Expenses and Analytics

![Cat expenses](docs/images/cats.png)

Cat expenses retain the original monthly view, category totals, search, filters, editing, archiving and import/export controls.

![YouTube analytics with channels](docs/images/youtube.png)

![Revenue and RPM chart](docs/images/revenue.png)

## Projects & Local AI Assistant

![Project cards with sample projects](docs/images/projects.png)

![Original shortcuts interface](docs/images/shortcuts.png)

![Assistant interface](docs/images/assistant.png)

The assistant connects to your local Ollama instance (`127.0.0.1:11434`) for private local AI conversations, auto-detecting any models you have pulled locally.

## Installation & Download

### Quick Install (Terminal)
Install the latest release directly to `/Applications` with a single command:

```sh
curl -fsSL https://raw.githubusercontent.com/aliradid/jarvis-macos/main/scripts/install.sh | bash
```

### Manual Download
Download the latest `Jarvis.dmg` from the **[Releases](https://github.com/aliradid/jarvis-macos/releases)** page, double-click to open, and drag **Jarvis.app** into your `/Applications` folder.

### Build from Source
Requires macOS 13 or later and Swift 5.9 or later. Zero third-party package dependencies.

```sh
git clone https://github.com/aliradid/jarvis-macos.git
cd jarvis-macos

# Run Jarvis (starts your own real workspace, saved locally)
swift run Jarvis

# Or explore in isolated demo mode with synthetic fixtures
swift run Jarvis --demo
```

## Global Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| `⌥⌘J` | Toggle Floating HUD Widget | Global (any application or Space) |
| `⌥⌘W` | Show & Focus Floating Widget | In-app / Global |
| `⌘F` | Focus Workspace Search | Main Window |

## Verification & Checks

```sh
python3 scripts/check_publication.py
swift build
bash scripts/test-core.sh
swift run JarvisDemo --check
```

The regression suite validates configuration recovery from corruption, duplicate ID rejection, URL safety filters, and model calculations.

See [architecture](docs/ARCHITECTURE.md), [source fidelity](docs/SOURCE_FIDELITY.md), [publication boundaries](docs/PUBLICATION.md) and [security](SECURITY.md).

## License

This project is licensed under the [MIT License](LICENSE). Brand artwork is included solely to identify compatible external services; trademarks remain the property of their respective owners.
