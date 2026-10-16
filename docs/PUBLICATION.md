# Publication Boundaries

This repository contains the public open-source edition of **Jarvis for macOS**, a native SwiftUI & AppKit AI & Developer Command Center.

## Included

- Full native macOS source code for the 5-pillar Command Center, Floating HUD (`⌥⌘J`), Menu Bar controller, Darwin kernel telemetry, BSD socket localhost port scanner, local Ollama streaming client, and AI & Cloud Spend tracker.
- Local OAuth quota readers (`AIQuotaReaders.swift`) that read the current user's own macOS Keychain / `.claude` / `.codex` session state at runtime without any hardcoded tokens or personal identifiers.
- Deterministic developer & AI stack fixtures (`SampleData.swift`) used when running `--demo`, `--check`, or `--render`.
- Automated regression tests (`Tests/JarvisDemoTests/CoreTests.swift`), domain invariant checks (`Sources/JarvisDemo/DemoChecks.swift`), and publication boundary checks (`scripts/check_publication.py`).
- High-resolution showcase screenshots in `docs/images/` rendered directly from the deterministic `--render` pipeline with PNG metadata stripped.

## Excluded

- Personal credentials, API keys, cookies, or OAuth tokens.
- Personal filesystem paths (`/Users/<name>`), private IP addresses, or private repository URLs.
- Unrelated legacy personal trackers or personal billing records.

## Verification Before Release

Always run the full verification suite before tagging a release:

```sh
python3 scripts/check_publication.py
bash scripts/test-core.sh
swift run JarvisDemo --check
swift run JarvisDemo --render docs/images
```

`scripts/check_publication.py` enforces an exact file allowlist, rejects symlinks, verifies PNG chunk hygiene, and scans all tracked text files for secret patterns, email addresses, personal home paths, and non-loopback IPv4 addresses.
