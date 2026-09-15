#!/usr/bin/env python3
"""Conservative release check. Reports locations and categories, never matched values."""
from pathlib import Path
import re
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ALLOW = {
    '.github/workflows/checks.yml',
    '.gitignore',
    'Package.swift',
    'README.md',
    'SECURITY.md',
    'Sources/JarvisDemo/AIQuotaReaders.swift',
    'Sources/JarvisDemo/AIQuotas.swift',
    'Sources/JarvisDemo/AppState.swift',
    'Sources/JarvisDemo/CatExpenses.swift',
    'Sources/JarvisDemo/DarijaLatin.swift',
    'Sources/JarvisDemo/DemoApp.swift',
    'Sources/JarvisDemo/DemoChecks.swift',
    'Sources/JarvisDemo/DemoFixtures.swift',
    'Sources/JarvisDemo/DemoStores.swift',
    'Sources/JarvisDemo/Diagnostics.swift',
    'Sources/JarvisDemo/FloatingWidget.swift',
    'Sources/JarvisDemo/HomeDesk.swift',
    'Sources/JarvisDemo/InboxModel.swift',
    'Sources/JarvisDemo/InboxPanel.swift',
    'Sources/JarvisDemo/Infrastructure.swift',
    'Sources/JarvisDemo/JarvisHome.swift',
    'Sources/JarvisDemo/JarvisModel.swift',
    'Sources/JarvisDemo/JarvisView.swift',
    'Sources/JarvisDemo/MissionControl.swift',
    'Sources/JarvisDemo/Model.swift',
    'Sources/JarvisDemo/OrbitComponents.swift',
    'Sources/JarvisDemo/Resources/Brands/anthropic.png',
    'Sources/JarvisDemo/Resources/Brands/openai.png',
    'Sources/JarvisDemo/Resources/Brands/photoshop.png',
    'Sources/JarvisDemo/Resources/Brands/youtube.png',
    'Sources/JarvisDemo/SampleData.swift',
    'Sources/JarvisDemo/ShortcutEditors.swift',
    'Sources/JarvisDemo/Storage.swift',
    'Sources/JarvisDemo/Subscriptions.swift',
    'Sources/JarvisDemo/TileView.swift',
    'Sources/JarvisDemo/YouTubeMonitor.swift',
    'Tests/JarvisDemoTests/CoreTests.swift',
    'docs/ARCHITECTURE.md',
    'docs/BRANDS.md',
    'docs/PUBLICATION.md',
    'docs/SOURCE_FIDELITY.md',
    'docs/images/assistant.png',
    'docs/images/cats.png',
    'docs/images/floating-widget.png',
    'docs/images/overview.png',
    'docs/images/projects.png',
    'docs/images/revenue.png',
    'docs/images/shortcuts.png',
    'docs/images/subscriptions.png',
    'docs/images/widget-details.png',
    'docs/images/youtube.png',
    'scripts/check_publication.py',
    'scripts/test-core.sh',
}

RULES = {
    'private-key': r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    'provider-token': r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16})\b',
    'email-address': r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
    'personal-path': r'/(?:Users|home)/[A-Za-z0-9_.-]+',
    'jwt': r'\beyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,}',
}

failures = []
# Inspect working files and tracked files, including tracked files that are ignored.
files = set()
for path in ROOT.rglob('*'):
    rel = path.relative_to(ROOT)
    if rel.parts[0] in {'.git', '.build', '.swiftpm'}:
        continue
    if path.is_file() or path.is_symlink():
        files.add(rel.as_posix())
if (ROOT / '.git').exists():
    tracked = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '-z']).decode().split('\0')
    files.update(name for name in tracked if name)
for name in sorted(files):
    path = ROOT / name
    if name not in ALLOW:
        failures.append((name, 'unexpected-file'))
        continue
    if path.is_symlink() or not path.is_file():
        failures.append((name, 'symlink-or-missing-file'))
        continue
    data = path.read_bytes()
    if name.endswith('.png'):
        if not data.startswith(b'\x89PNG\r\n\x1a\n'):
            failures.append((name, 'invalid-png'))
            continue
        offset = 8
        ended = False
        while offset + 12 <= len(data):
            size = struct.unpack('>I', data[offset:offset+4])[0]
            kind = data[offset+4:offset+8]
            if kind not in {b'IHDR', b'PLTE', b'tRNS', b'IDAT', b'IEND', b'sRGB', b'gAMA', b'cHRM', b'pHYs'}:
                failures.append((name, 'unapproved-png-metadata'))
            offset += 12 + size
            if kind == b'IEND':
                ended = True
                break
        if not ended or offset != len(data):
            failures.append((name, 'malformed-png-or-trailing-data'))
        continue
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        failures.append((name, 'unexpected-binary'))
        continue
    for rule, pattern in RULES.items():
        for match in re.finditer(pattern, text):
            if rule == 'email-address' and match.group().endswith('@example.com'):
                continue  # Reserved example domain used by URL-rejection tests.
            line = text.count('\n', 0, match.start()) + 1
            failures.append((f'{name}:{line}', rule))
    for match in re.finditer(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', text):
        if match.group() != '127.0.0.1':
            failures.append((name, 'non-loopback-ipv4'))
missing = ALLOW - files
for name in sorted(missing):
    failures.append((name, 'missing-required-file'))
if failures:
    for location, rule in failures:
        print(f'FAIL {location}: {rule}')
    sys.exit(1)
print(f'PASS: {len(files)} allowed files; no matching secret/personal-data patterns; PNG metadata checked.')
print('Manual source and image review is still required.')
