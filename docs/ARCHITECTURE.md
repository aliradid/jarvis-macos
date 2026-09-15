# Architecture

The public edition keeps the original SwiftUI views and model calculations. Small fixture stores replace private persistence, account readers, infrastructure probes and project discovery.

| Source | Contents |
| --- | --- |
| JarvisHome.swift, HomeDesk.swift | Navigation, original home, project library, setup preview, checklist, pins, quota strip |
| Subscriptions.swift, OrbitComponents.swift | Orbit subscription UI, editor, billing and FX calculations, validation |
| CatExpenses.swift | Cat expense UI, editor, validation and explicit import/export |
| YouTubeMonitor.swift | Original analytics pages, charts and calculations |
| AIQuotas.swift, Infrastructure.swift | Original quota and machine detail views with sample stores |
| FloatingWidget.swift | Original bar composition, drag handle and channel popover; standalone demo window controller |
| TileView.swift, ShortcutEditors.swift | Original tiles, context menus, link and workspace editors |
| JarvisView.swift, InboxPanel.swift, Diagnostics.swift | Original assistant, preferences, messages, alerts and diagnostic views |
| SampleData.swift, DemoStores.swift | Fictional records and disconnected service adapters |
| Model.swift, Storage.swift, DarijaLatin.swift | Extracted shortcut model, recovery helpers and transliteration |
| DemoApp.swift | App entry, environment injection and offscreen rendering |

## Data and actions

The app starts from source-defined samples, never personal exports. It does not discover browser profiles, read the personal app's preferences, access credentials, scan project folders, launch commands or poll providers. Editing records and preferences changes session memory.

Explicit file selection can read the files chosen by the person running the demo. Cat import/export remains functional. Selected shortcut artwork is copied into a unique temporary demo directory. The standalone storage helpers also accept caller-supplied paths and are exercised independently by the recovery tests.

Provider links remain ordinary, user-initiated links. Synthetic video and channel destinations use example.com. Thumbnail fetching is disconnected and uses the original placeholder. The assistant shows its actual composer and preferences; its adapter reports that no message was sent.

## Recovery and validation

Configuration decoding preserves unreadable bytes and attempts recovery from a validated backup. The returned `canSave` flag must be honored by callers. Atomic replacement and backups support recovery; they are not encryption or a database transaction.

Subscription and cat edits use their original validators before accepting a new in-memory record. Original monthly normalization, currency conversion, status exclusions and analytics calculations are retained.

## Floating panel

The panel uses `.borderless` and `.nonactivatingPanel`, a `.floating` level and `.canJoinAllSpaces` / `.fullScreenAuxiliary`. The drag handle delegates movement to AppKit. Hiding retains the panel for restoration. Its stores are shared with the main window. The demo does not reuse the personal app's saved position or preferences.
