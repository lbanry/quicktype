import { Notice, normalizePath, type App } from 'obsidian';
import type { ClipSaveResult, QuickTypeClipPayloadV1, SaveTarget, SummaryResult } from '../types';

function slugTimestamp(iso: string): string {
  const date = new Date(iso);
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  const ss = String(date.getSeconds()).padStart(2, '0');
  return `${y}${m}${d}-${hh}${mm}${ss}`;
}

async function nextAvailablePath(app: App, basePath: string): Promise<string> {
  if (!app.vault.getAbstractFileByPath(basePath)) return basePath;

  const ext = '.md';
  const stem = basePath.endsWith(ext) ? basePath.slice(0, -ext.length) : basePath;
  for (let i = 1; i < 10000; i += 1) {
    const candidate = `${stem}-${i}${ext}`;
    if (!app.vault.getAbstractFileByPath(candidate)) {
      return candidate;
    }
  }
  throw new Error('Unable to allocate clip filename');
}

function renderMarkdown(
  clip: QuickTypeClipPayloadV1,
  summary: SummaryResult | null,
  attachmentLinks: string[]
): string {
  const lines: string[] = [
    '# Captured Clip',
    '',
    `- Captured: ${clip.capturedAt}`,
    `- Source App: ${clip.sourceAppName} (${clip.sourceBundleId})`
  ];

  if (clip.sourceWindowTitle) lines.push(`- Source Window: ${clip.sourceWindowTitle}`);
  if (clip.sourceUrl) lines.push(`- Source URL: ${clip.sourceUrl}`);
  lines.push('');

  if (summary) {
    lines.push('## Summary');
    lines.push('');
    lines.push(summary.text);
    lines.push('');
  }

  lines.push('## Original Clip');
  lines.push('');
  lines.push('```');
  lines.push(clip.contentText);
  lines.push('```');
  lines.push('');

  if (attachmentLinks.length > 0) {
    lines.push('## Attachments');
    lines.push('');
    lines.push(...attachmentLinks);
    lines.push('');
  }

  return lines.join('\n');
}

export async function writeClipNote(
  app: App,
  clip: QuickTypeClipPayloadV1,
  target: SaveTarget,
  summary: SummaryResult | null,
  attachmentsSaved: string[],
  attachmentLinks: string[]
): Promise<ClipSaveResult> {
  const filename = `Clip-${slugTimestamp(clip.capturedAt)}.md`;
  const folderPath = target.folderPath ? normalizePath(target.folderPath) : '';

  if (folderPath) {
    const existingFolder = app.vault.getAbstractFileByPath(folderPath);
    if (!existingFolder) {
      await app.vault.createFolder(folderPath);
    }
  }

  const requestedPath = folderPath ? normalizePath(`${folderPath}/${filename}`) : filename;
  const finalPath = await nextAvailablePath(app, requestedPath);

  const markdown = renderMarkdown(clip, summary, attachmentLinks);
  await app.vault.create(finalPath, markdown);
  new Notice(`QuickType clip saved: ${finalPath}`);

  return {
    notePath: finalPath,
    attachmentsSaved,
    summaryIncluded: Boolean(summary)
  };
}
