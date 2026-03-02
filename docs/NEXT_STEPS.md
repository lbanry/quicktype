# Next Steps

## Obsidian plugin and QuickType integration

### Delivered in this phase

1. Added an Obsidian plugin project under `obsidian-plugin/`.
2. Implemented URI contract handling for `obsidian://quicktype-clip`.
3. Added strict payload decoding/validation with size guard and file handoff fallback.
4. Implemented save flow with:
- active vault default
- configurable default folder
- optional per-save folder chooser for existing folders
5. Added optional AI summarize-then-save workflow (BYO key, OpenAI-compatible endpoint).
6. Added attachment support for images and PDFs.
7. Added QuickType actions to send clips to Obsidian:
- save directly
- summarize then save
8. Added QuickType settings for Obsidian defaults (enabled, default folder, target vault hint, default summarize).
9. Extended CI to build/typecheck the plugin in addition to Swift build/test.

### Remaining follow-ups

1. Add plugin unit tests for payload validation and markdown rendering.
2. Add integration smoke test for URI handoff in a sample vault.
3. Add user-facing permission diagnostics for Accessibility and Obsidian URI failures.
4. Add optional custom global hotkey recorder for “Save to Obsidian” action.
5. Add release workflow for packaging/publishing plugin artifacts.
