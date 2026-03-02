import { Notice } from 'obsidian';
import { readFileSync } from 'node:fs';
import type { QuickTypeClipPayloadV1 } from '../types';

const MAX_INLINE_PAYLOAD_LENGTH = 3500;

function decodeBase64Url(value: string): string {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padLength = (4 - (normalized.length % 4)) % 4;
  const padded = normalized + '='.repeat(padLength);
  return Buffer.from(padded, 'base64').toString('utf8');
}

function parsePayloadJson(input: string): unknown {
  try {
    return JSON.parse(input);
  } catch {
    return null;
  }
}

function validatePayload(candidate: unknown): candidate is QuickTypeClipPayloadV1 {
  if (!candidate || typeof candidate !== 'object') return false;
  const clip = candidate as Record<string, unknown>;
  return (
    clip.version === 1 &&
    typeof clip.clipId === 'string' &&
    typeof clip.capturedAt === 'string' &&
    typeof clip.sourceAppName === 'string' &&
    typeof clip.sourceBundleId === 'string' &&
    typeof clip.contentText === 'string' &&
    (clip.requestedAction === 'save' || clip.requestedAction === 'summarize_then_save')
  );
}

export function decodeQuickTypePayload(params: Record<string, string>): QuickTypeClipPayloadV1 | null {
  const inlinePayload = params.payload;
  const filePayload = params.payloadFile;

  let raw: string | null = null;

  if (inlinePayload) {
    if (inlinePayload.length > MAX_INLINE_PAYLOAD_LENGTH) {
      new Notice('QuickType payload is too large, expecting file handoff.');
      return null;
    }
    raw = decodeBase64Url(inlinePayload);
  } else if (filePayload) {
    try {
      raw = readFileSync(filePayload, 'utf8');
    } catch {
      new Notice('Unable to read QuickType payload file.');
      return null;
    }
  }

  if (!raw) {
    new Notice('Missing QuickType payload.');
    return null;
  }

  const parsed = parsePayloadJson(raw);
  if (!validatePayload(parsed)) {
    new Notice('Invalid QuickType payload format.');
    return null;
  }

  return parsed;
}
