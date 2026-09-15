# Source fidelity

This edition reuses the personal application's views. Demo adaptation happens primarily in the stores that supply them.

## Retained interfaces

- `JarvisHome`: original navigation, header, home composition, project cards, project library, setup preview and retained page host.
- `HomeDesk` and `HomeAttention`: original checklist, recent items, pinned actions and attention rows.
- `SubscriptionsPage`, `OrbitSubscriptionRow` and `OrbitEditor`: original layout, filters, sorting, totals, timeline, editing and archive controls.
- `CatsView` and `CatExpenseEditor`: original expense interface and editor.
- `YouTubeMonitorPage`, `YouTubeRPMChart` and `YouTubeComparisonChart`: original analytics sections and charts.
- `WorkspaceStatusStrip`, `AIQuotaPanel`, `AIQuotaDetails` and `InfrastructurePanel`: original status and detail views.
- `FloatingChannelAccess`: original channel popover. The bar retains the original composition and native drag handle.
- `TileView`, `LinkEditor`, `WorkspaceEditor`, `JarvisView`, preferences, messages, desktop alerts and diagnostic views: original UI.

## Deliberate differences

| Boundary | Public-edition change |
| --- | --- |
| Personal identity and records | Approved provider and plan labels with identifying additions removed; fictional record fields, projects, paths, figures and readings; generic workspace label |
| Account, machine and project readers | Replaced with fixture stores; no discovery, credentials, CLI calls, shell commands or probes |
| Persistence | Session memory; isolated temporary artwork storage; original explicit file import/export retained |
| Saved preferences | In-memory state instead of reading personal defaults |
| Brand artwork | Bundled public brand assets instead of installed app paths or private custom images |
| Video thumbnails | Original placeholder without remote fetching |
| Channel/video destinations | Reserved example.com destinations for sample identifiers |
| Assistant and integration descriptions | State when a service is disconnected or a reading is a sample |
| App entry and panel controller | Standalone demo entry, rendering support and session-local panel restoration |
| File availability checks | Disabled for fictional shortcut paths |

The subscription model, billing normalization, FX conversion, validation, chart calculations and financial-window models retain the original implementation. Source comparisons were run for 14 view/model groups. The complete demo was built, its ten overview/widget images reviewed, and subscription editing and filtering checked in the running app.

Fixture data illustrates existing states and controls. It does not represent provider pricing, live accounts, completed external actions or a different product design.
