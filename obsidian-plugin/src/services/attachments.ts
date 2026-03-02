import { normalizePath, type App } from 'obsidian';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import type { AttachmentInput } from '../types';

function isEmbeddableImage(mimeType: string): boolean {
  return mimeType.startsWith('image/');
}

function markdownLinkFor(filePath: string, mimeType: string): string {
  return isEmbeddableImage(mimeType) ? `![[${filePath}]]` : `[[${filePath}]]`;
}

async function ensureFolder(app: App, folderPath: string): Promise<void> {
  if (!folderPath) return;
  const existing = app.vault.getAbstractFileByPath(folderPath);
  if (!existing) {
    await app.vault.createFolder(folderPath);
  }
}

function decodeMaybeBase64(bytes?: string): Buffer | null {
  if (!bytes) return null;
  try {
    return Buffer.from(bytes, 'base64');
  } catch {
    return null;
  }
}

export async function importAttachments(
  app: App,
  attachmentInputs: AttachmentInput[] | undefined,
  attachmentFolderPath: string
): Promise<{ savedPaths: string[]; embedLines: string[] }> {
  if (!attachmentInputs || attachmentInputs.length === 0) {
    return { savedPaths: [], embedLines: [] };
  }

  await ensureFolder(app, attachmentFolderPath);

  const savedPaths: string[] = [];
  const embedLines: string[] = [];

  for (const attachment of attachmentInputs) {
    const safeName = attachment.name.replace(/[\\/:*?"<>|]/g, '-');
    const targetPath = normalizePath(
      attachmentFolderPath.length > 0 ? `${attachmentFolderPath}/${safeName}` : safeName
    );

    let data: Buffer | null = null;
    if (attachment.sourcePath) {
      try {
        data = await readFile(attachment.sourcePath);
      } catch {
        data = null;
      }
    }

    if (!data) {
      data = decodeMaybeBase64(attachment.bytes);
    }

    if (!data) continue;

    const binary = Uint8Array.from(data).buffer;
    await app.vault.adapter.writeBinary(targetPath, binary);
    savedPaths.push(targetPath);
    embedLines.push(markdownLinkFor(targetPath, attachment.mimeType));
  }

  return { savedPaths, embedLines };
}
