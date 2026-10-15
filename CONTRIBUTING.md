# Contributing to Jarvis

Thank you for your interest in contributing to **Jarvis for macOS**! We welcome bug reports, feature suggestions, UI polish, and pull requests from everyone.

---

## 🛠️ Development Setup

Jarvis is a native macOS application written in **SwiftUI** and **AppKit** with zero external dependencies.

### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 15+ / Swift 5.9+

### Quick Start
```bash
# 1. Clone your fork
git clone https://github.com/<your-username>/jarvis-macos.git
cd jarvis-macos

# 2. Build the project
swift build

# 3. Run regression checks
python3 scripts/check_publication.py
bash scripts/test-core.sh

# 4. Run the app locally
swift run Jarvis
```

---

## 🧪 Testing & Publication Integrity

Before submitting any Pull Request, ensure all checks pass:

```bash
# 1. Publication allowlist and secret pattern scans
python3 scripts/check_publication.py

# 2. Core regression and data recovery suite
bash scripts/test-core.sh

# 3. Model calculations and sample isolation checks
swift run Jarvis --check
```

---

## 📋 Pull Request Guidelines

1. **Keep it atomic**: One feature, refactor, or fix per pull request.
2. **Local-first & privacy**: Never add telemetry, tracking, or cloud requirements. User data must always stay local on device.
3. **Clean code**: Follow SwiftUI and modern concurrency (`async/await`, `@MainActor`) idioms.
4. **Preserve tests**: Any change to data encoding or models must pass existing recovery tests in `test-core.sh`.

---

## 💡 Ideas to Contribute

Check out our [ROADMAP.md](ROADMAP.md) for open initiatives, including:
- Hotkey triggers for the floating HUD widget
- Additional AI provider monitors (DeepSeek, OpenRouter)
- Custom widgets & modular HUD panes

Thank you for building with us!
