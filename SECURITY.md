# Security

The public demo runs offline with fictional fixtures. It does not connect to accounts, read browser sessions, run shell commands or open the personal application's data directory. UI edits remain in memory. Tests write to unique temporary directories; the explicit `--render` command writes PNGs to the output directory supplied by the caller.

The extracted storage helpers operate on caller-supplied paths and are not a sandbox. Do not expose them to untrusted paths or treat their JSON backups as encrypted storage.

If reporting a possible vulnerability, use GitHub's private vulnerability reporting when available. Do not post credentials or personal information in a public issue.
