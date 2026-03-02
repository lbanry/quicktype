# QuickType Clip Inbox (Obsidian Plugin)

Obsidian plugin to receive QuickType clips via `obsidian://quicktype-clip` and save them into your vault with optional AI summarization.

## Features

- URI payload handler: `obsidian://quicktype-clip?payload=...`
- Large payload fallback via `payloadFile` handoff
- Save clips to selected existing folder in active vault
- Configurable default folder and per-save folder prompt
- Attachment import for images and PDFs
- Optional AI summarization using BYO API key (OpenAI-compatible endpoint)

## Development

```bash
cd obsidian-plugin
npm install
npm run typecheck
npm run build
```

Bundle output:

- `obsidian-plugin/main.js`

## Payload contract

Expected payload schema version:

- `QuickTypeClipPayloadV1` (`version: 1`)

With fields:

- `clipId`, `capturedAt`, source metadata, `contentText`
- `attachments[]` (`name`, `mimeType`, `sourcePath|bytes`)
- `requestedAction` (`save` or `summarize_then_save`)
- `targetHint` (`vaultName?`, `folderPath?`)
