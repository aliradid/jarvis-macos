#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
jarvis_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/jarvis-core-checks.XXXXXX")
trap 'rm -rf "$jarvis_test_dir"' EXIT
swiftc -sdk "${JARVIS_SDK:-$(xcrun --show-sdk-path)}" \
  -module-cache-path "$jarvis_test_dir/modules" \
  Sources/JarvisDemo/Model.swift Sources/JarvisDemo/Storage.swift \
  Sources/JarvisDemo/DarijaLatin.swift Sources/JarvisDemo/DemoFixtures.swift \
  Tests/JarvisDemoTests/CoreTests.swift -o "$jarvis_test_dir/checks"
"$jarvis_test_dir/checks"
