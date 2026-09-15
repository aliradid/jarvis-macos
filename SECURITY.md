# Security

The demo uses an explicitly reviewed list of real provider and plan names. Account labels, store names, personal domains, people and channel/community names are removed; duplicate account entries are combined. All other record fields are fictional, including amounts, dates, billing cycles and statuses. It does not access account credentials, browser sessions, personal application storage, machine probes, remote shells or project directories. No live integration adapter is included.

Record edits and preferences remain in session memory. Explicit import/export and artwork selection use native file pickers; these actions read or write only when requested. Artwork is stored in a unique temporary demo directory. Public provider links open when clicked. Synthetic channel and video links use example.com; thumbnails do not make network requests.

The storage helpers accept caller-supplied paths and are not a filesystem sandbox. Their JSON backups are not encrypted. Tests use temporary directories. The explicit `--render` command writes PNGs to its supplied output directory.

The publication checker uses an exact allowlist, secret-pattern checks and PNG metadata checks. Manual review is also required: pattern matching alone cannot establish that a file contains no private information.

Report suspected vulnerabilities through GitHub's private vulnerability reporting. Do not put credentials or personal information in public issues.
