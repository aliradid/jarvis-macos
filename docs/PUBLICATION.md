# Publication boundaries

This repository was assembled as a separate public edition from explicitly selected source files. It starts with fresh history and does not contain the personal application's repository history.

## Included

- Reviewed model, storage and transliteration components.
- The original SwiftUI views with fictional fixtures and disconnected integration adapters.
- Behavioral tests and documentation.
- PNG images rendered directly from the public demo views.

## Excluded

- Credentials, authentication adapters, cookies and session material.
- Personal configuration, account identifiers and billing records.
- Infrastructure addresses, service configuration and private workspace paths.
- Operational logs, private datasets, original app binaries and old build bundles.
- Screenshots or recordings of the personal application's live state.

## Releasing changes

Run `python3 scripts/check_publication.py` and `bash scripts/test-core.sh` before publishing. The publication check uses an exact file allowlist, rejects symlinks and checks text for common secret and personal-data patterns. Its findings report file locations and rule names without printing matching values.

An allowlist or a pattern scan cannot prove that all sensitive information is absent. Review every new file and image manually. Do not add real configuration or credentials to make this demo functional; use synthetic fixtures.

The render command creates images from known fictional views rather than capturing the desktop. Review regenerated images before committing them.
