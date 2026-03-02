import { Notice, requestUrl } from 'obsidian';
import type { PluginSettings, QuickTypeClipPayloadV1, SummaryResult } from '../types';

export async function summarizeClip(settings: PluginSettings, clip: QuickTypeClipPayloadV1): Promise<SummaryResult | null> {
  if (!settings.aiEnabled || !settings.aiApiKey.trim()) return null;

  const prompt = [
    'Summarize this clipped content for an Obsidian note.',
    'Keep it concise, factual, and useful as a quick reference.',
    'Include 3-6 bullet points and one short "Why it matters" line.',
    '',
    `Source app: ${clip.sourceAppName}`,
    clip.sourceUrl ? `Source URL: ${clip.sourceUrl}` : '',
    '',
    clip.contentText
  ].filter(Boolean).join('\n');

  try {
    const response = await requestUrl({
      url: settings.aiEndpoint,
      method: 'POST',
      headers: {
        Authorization: `Bearer ${settings.aiApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: settings.aiModel,
        temperature: settings.aiTemperature,
        max_tokens: settings.aiMaxTokens,
        messages: [
          { role: 'system', content: 'You produce concise, accurate note summaries.' },
          { role: 'user', content: prompt }
        ]
      })
    });

    const body = response.json as any;
    const text: string | undefined = body?.choices?.[0]?.message?.content;
    if (!text || !text.trim()) {
      throw new Error('AI response did not include summary text');
    }

    return {
      text: text.trim(),
      model: settings.aiModel
    };
  } catch (error) {
    new Notice('AI summary failed. You can still save the original clip.');
    console.error('QuickType summary failed', error);
    return null;
  }
}
