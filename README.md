# QuickType

QuickType is a local-first, privacy-focused macOS quick-capture app inspired by Type.

## Implemented V1 foundation

- Native SwiftUI/AppKit macOS app shell with `MenuBarExtra`
- Global hotkey service (Carbon) with in-app recorder
- Multi-target note capture to `.txt` / `.md`
- Configurable insertion position and timestamp formatting
- JSON-based typed settings + schema migration path
- Atomic write workflow with rolling backups
- Conflict-aware write path with latest-content merge fallback
- Security-scoped bookmark create/resolve support
- Integrity/recovery scan for missing/stale/unreadable note targets
- Diagnostics copy and settings export
- URL scheme capture stub: `quicktype://capture?text=...&target=<uuid>`
- Obsidian integration actions:
  - Save selection to Obsidian
  - Summarize then save to Obsidian

## Obsidian Plugin

An Obsidian companion plugin now lives in [`obsidian-plugin/`](obsidian-plugin/README.md).

It supports:

- `obsidian://quicktype-clip` URI payload ingestion
- Existing-folder selection + default folder behavior
- Image/PDF attachment import
- Optional AI summarize-then-save (BYO API key, OpenAI-compatible endpoint)

## Build

```bash
swift build
swift run
swift test
```

## GitHub-first distribution

QuickType is distributed through GitHub Releases (not DMG).

- CI workflow: `.github/workflows/ci.yml`
- Release workflow: `.github/workflows/release.yml`

To publish a release artifact:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow builds `QuickType` in release mode and uploads:

- `quicktype-vX.Y.Z-macos-arm64.tar.gz`
- `quicktype-vX.Y.Z-macos-arm64.tar.gz.sha256`

## Data locations

- Settings: `~/Library/Application Support/QuickType/settings.json`
- Note index: `~/Library/Application Support/QuickType/notes_index.json`
- Backups: `~/Library/Application Support/QuickType/Backups/`
- Logs: `~/Library/Application Support/QuickType/quicktype.log`

## Notes

This repository intentionally avoids third-party telemetry SDKs. Diagnostics are local-only.
